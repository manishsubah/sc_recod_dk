#include "segment_writer.h"

#include <codecapi.h>
#include <mferror.h>
#include <strmif.h>

#include <algorithm>
#include <cmath>
#include <system_error>

#include "../core/strings.h"
#include "../core/ticks.h"

namespace reclite_engine {
namespace {

constexpr UINT32 kSampleRate = 48'000;
constexpr UINT32 kChannels = 2;
constexpr UINT32 kAudioBitrateBytes = 20'000;  // 160 kbps AAC

// ~0.08 bits per pixel per frame (≈5 Mbps at 1080p30), clamped — same as macOS.
UINT32 VideoBitrate(int width, int height, int fps) {
  const double raw = static_cast<double>(width) * height * fps * 0.08;
  return static_cast<UINT32>(std::clamp(raw, 1'500'000.0, 16'000'000.0));
}

HRESULT AddVideoStream(IMFSinkWriter* writer, const SegmentWriter::Format& f,
                       DWORD* stream) {
  ComPtr<IMFMediaType> output;
  HRESULT hr = ::MFCreateMediaType(&output);
  if (FAILED(hr)) return hr;
  output->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  output->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
  output->SetUINT32(MF_MT_AVG_BITRATE, VideoBitrate(f.width, f.height, f.frames_per_second));
  output->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
  output->SetUINT32(MF_MT_MPEG2_PROFILE, eAVEncH264VProfile_High);
  ::MFSetAttributeSize(output.Get(), MF_MT_FRAME_SIZE, static_cast<UINT32>(f.width),
                       static_cast<UINT32>(f.height));
  ::MFSetAttributeRatio(output.Get(), MF_MT_FRAME_RATE,
                        static_cast<UINT32>(f.frames_per_second), 1);
  ::MFSetAttributeRatio(output.Get(), MF_MT_PIXEL_ASPECT_RATIO, 1, 1);
  hr = writer->AddStream(output.Get(), stream);
  if (FAILED(hr)) return hr;

  ComPtr<IMFMediaType> input;
  hr = ::MFCreateMediaType(&input);
  if (FAILED(hr)) return hr;
  input->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  input->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_NV12);
  input->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
  ::MFSetAttributeSize(input.Get(), MF_MT_FRAME_SIZE, static_cast<UINT32>(f.width),
                       static_cast<UINT32>(f.height));
  ::MFSetAttributeRatio(input.Get(), MF_MT_FRAME_RATE,
                        static_cast<UINT32>(f.frames_per_second), 1);
  ::MFSetAttributeRatio(input.Get(), MF_MT_PIXEL_ASPECT_RATIO, 1, 1);
  hr = writer->SetInputMediaType(*stream, input.Get(), nullptr);
  if (FAILED(hr)) return hr;

  // A keyframe every 2 s keeps seeking fast and crash fragments small.
  ComPtr<ICodecAPI> codec;
  if (SUCCEEDED(writer->GetServiceForStream(*stream, GUID_NULL, IID_PPV_ARGS(&codec)))) {
    VARIANT gop;
    ::VariantInit(&gop);
    gop.vt = VT_UI4;
    gop.ulVal = static_cast<ULONG>(f.frames_per_second * 2);
    codec->SetValue(&CODECAPI_AVEncMPVGOPSize, &gop);
  }
  return S_OK;
}

HRESULT AddAudioStream(IMFSinkWriter* writer, DWORD* stream) {
  ComPtr<IMFMediaType> output;
  HRESULT hr = ::MFCreateMediaType(&output);
  if (FAILED(hr)) return hr;
  output->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
  output->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC);
  output->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, kChannels);
  output->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, kSampleRate);
  output->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
  output->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, kAudioBitrateBytes);
  hr = writer->AddStream(output.Get(), stream);
  if (FAILED(hr)) return hr;

  // The Windows AAC encoder takes 16-bit PCM.
  ComPtr<IMFMediaType> input;
  hr = ::MFCreateMediaType(&input);
  if (FAILED(hr)) return hr;
  input->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
  input->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
  input->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, kChannels);
  input->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, kSampleRate);
  input->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
  input->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, kChannels * 2);
  input->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, kSampleRate * kChannels * 2);
  return writer->SetInputMediaType(*stream, input.Get(), nullptr);
}

}  // namespace

std::unique_ptr<SegmentWriter> SegmentWriter::Create(int index,
                                                     const std::filesystem::path& final_path,
                                                     const Format& format,
                                                     IMFDXGIDeviceManager* manager,
                                                     std::string* error) {
  auto segment = std::unique_ptr<SegmentWriter>(new SegmentWriter());
  segment->index_ = index;
  segment->final_path_ = final_path;
  segment->part_path_ = final_path;
  segment->part_path_ += L".part";
  segment->format_ = format;
  segment->format_.frames_per_second = std::max(1, format.frames_per_second);

  ComPtr<IMFAttributes> attributes;
  HRESULT hr = ::MFCreateAttributes(&attributes, 5);
  if (SUCCEEDED(hr)) {
    // Fragmented MP4: the container is chosen here, not by the ".part" extension.
    attributes->SetGUID(MF_TRANSCODE_CONTAINERTYPE, MFTranscodeContainerType_FMPEG4);
    attributes->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);
    attributes->SetUINT32(MF_LOW_LATENCY, TRUE);
    attributes->SetUnknown(MF_SINK_WRITER_D3D_MANAGER, manager);
    hr = ::MFCreateSinkWriterFromURL(segment->part_path_.c_str(), nullptr, attributes.Get(),
                                     &segment->writer_);
  }
  if (SUCCEEDED(hr)) {
    hr = AddVideoStream(segment->writer_.Get(), format, &segment->video_stream_);
  }
  if (SUCCEEDED(hr) && format.with_audio) {
    hr = AddAudioStream(segment->writer_.Get(), &segment->audio_stream_);
  }
  if (SUCCEEDED(hr)) {
    hr = segment->writer_->BeginWriting();
  }
  if (FAILED(hr)) {
    *error = "Could not create the video file (" + HresultMessage(hr) + ").";
    segment->writer_.Reset();
    std::error_code ignored;
    std::filesystem::remove(segment->part_path_, ignored);
    return nullptr;
  }
  return segment;
}

SegmentWriter::~SegmentWriter() = default;

int64_t SegmentWriter::BytesOnDisk() const {
  std::error_code ec;
  const auto& path = finished_ ? final_path_ : part_path_;
  const auto size = std::filesystem::file_size(path, ec);
  return ec ? 0 : static_cast<int64_t>(size);
}

void SegmentWriter::StartSession(int64_t time) {
  if (session_start_ < 0) {
    session_start_ = time;
  }
}

void SegmentWriter::AppendVideo(ID3D11Texture2D* nv12, int64_t time) {
  if (!writer_ || failed() || nv12 == nullptr) {
    return;
  }
  StartSession(time);
  if (time < session_start_ || time <= last_video_time_) {
    return;
  }
  last_video_time_ = time;
  const int64_t slot = SlotOf(time);
  if (slot >= next_slot_) {
    FillTo(slot);
    if (!WriteSlot(nv12)) {
      ++dropped_frames_;
    }
  }
  // A frame landing in an already written slot shows from the next slot on.
  last_frame_ = nv12;
}

void SegmentWriter::FillUntil(int64_t time) {
  if (session_start_ >= 0 && time > session_start_) {
    FillTo(SlotOf(time));
  }
}

int64_t SegmentWriter::SlotOf(int64_t time) const {
  return (time - session_start_) * format_.frames_per_second / kTicksPerSecond;
}

int64_t SegmentWriter::SlotTime(int64_t slot) const {
  return slot * kTicksPerSecond / format_.frames_per_second;
}

void SegmentWriter::FillTo(int64_t slot) {
  while (last_frame_ && next_slot_ < slot && !failed()) {
    WriteSlot(last_frame_.Get());
  }
}

bool SegmentWriter::WriteSlot(ID3D11Texture2D* nv12) {
  const int64_t start = SlotTime(next_slot_);
  if (!WriteVideoSample(nv12, start, SlotTime(next_slot_ + 1) - start)) {
    return false;
  }
  ++next_slot_;
  return true;
}

bool SegmentWriter::WriteVideoSample(ID3D11Texture2D* nv12, int64_t relative_time,
                                     int64_t duration) {
  ComPtr<IMFMediaBuffer> buffer;
  HRESULT hr = ::MFCreateDXGISurfaceBuffer(__uuidof(ID3D11Texture2D), nv12, 0, FALSE, &buffer);
  ComPtr<IMF2DBuffer> buffer_2d;
  DWORD length = 0;
  if (SUCCEEDED(hr)) hr = buffer.As(&buffer_2d);
  if (SUCCEEDED(hr)) hr = buffer_2d->GetContiguousLength(&length);
  if (SUCCEEDED(hr)) hr = buffer->SetCurrentLength(length);
  ComPtr<IMFSample> sample;
  if (SUCCEEDED(hr)) hr = ::MFCreateSample(&sample);
  if (SUCCEEDED(hr)) hr = sample->AddBuffer(buffer.Get());
  if (SUCCEEDED(hr)) hr = sample->SetSampleTime(relative_time);
  if (SUCCEEDED(hr)) hr = sample->SetSampleDuration(duration);
  if (SUCCEEDED(hr)) hr = writer_->WriteSample(video_stream_, sample.Get());
  if (FAILED(hr)) {
    Fail("The video encoder stopped", hr);
    return false;
  }
  return true;
}

void SegmentWriter::AppendAudio(const std::vector<float>& samples, int64_t time) {
  if (!writer_ || failed() || !format_.with_audio || session_start_ < 0 || samples.empty()) {
    return;
  }
  // Drop anything before the part's start (it belongs to the previous part).
  size_t skip_frames = 0;
  if (time < session_start_) {
    skip_frames = static_cast<size_t>(
        std::llround(TicksToSeconds(session_start_ - time) * kSampleRate));
    if (skip_frames * kChannels >= samples.size()) {
      return;
    }
    time = session_start_;
  }
  const size_t first = skip_frames * kChannels;
  const size_t count = samples.size() - first;
  const DWORD bytes = static_cast<DWORD>(count * sizeof(int16_t));

  ComPtr<IMFMediaBuffer> buffer;
  HRESULT hr = ::MFCreateMemoryBuffer(bytes, &buffer);
  BYTE* data = nullptr;
  if (SUCCEEDED(hr)) hr = buffer->Lock(&data, nullptr, nullptr);
  if (SUCCEEDED(hr)) {
    auto* pcm = reinterpret_cast<int16_t*>(data);
    for (size_t i = 0; i < count; ++i) {
      const float clamped = std::clamp(samples[first + i], -1.0f, 1.0f);
      pcm[i] = static_cast<int16_t>(std::lround(clamped * 32767.0f));
    }
    buffer->Unlock();
    hr = buffer->SetCurrentLength(bytes);
  }
  const int64_t frames = static_cast<int64_t>(count / kChannels);
  ComPtr<IMFSample> sample;
  if (SUCCEEDED(hr)) hr = ::MFCreateSample(&sample);
  if (SUCCEEDED(hr)) hr = sample->AddBuffer(buffer.Get());
  if (SUCCEEDED(hr)) hr = sample->SetSampleTime(time - session_start_);
  if (SUCCEEDED(hr)) hr = sample->SetSampleDuration(frames * kTicksPerSecond / kSampleRate);
  if (SUCCEEDED(hr)) hr = writer_->WriteSample(audio_stream_, sample.Get());
  if (FAILED(hr)) {
    Fail("The audio encoder stopped", hr);
    return;
  }
  next_audio_time_ = time + frames * kTicksPerSecond / kSampleRate;
}

int64_t SegmentWriter::DurationUntil(int64_t end) const {
  if (session_start_ < 0) {
    return 0;
  }
  return std::max(end, last_video_time_) - session_start_;
}

bool SegmentWriter::Finish(int64_t end, std::string* error) {
  if (!writer_ || session_start_ < 0 || last_video_time_ < 0) {
    Cancel();
    *error = "No video frames were captured.";
    return false;
  }
  // Repeat the last picture up to `end` so a still screen keeps its full length.
  const int64_t slot_length = SlotTime(1);
  FillTo(SlotOf(std::max(end, last_video_time_) + slot_length - 1));
  last_frame_.Reset();

  const HRESULT hr = writer_->Finalize();
  writer_.Reset();
  if (FAILED(hr)) {
    *error = "The video file could not be finished (" + HresultMessage(hr) + ").";
    return false;
  }
  // MOVEFILE flags 0: never replace an existing recording.
  if (!::MoveFileExW(part_path_.c_str(), final_path_.c_str(), 0)) {
    *error = "The finished file could not be renamed (" +
             HresultMessage(HRESULT_FROM_WIN32(::GetLastError())) + ").";
    return false;
  }
  finished_ = true;
  return true;
}

void SegmentWriter::Cancel() {
  writer_.Reset();  // Without Finalize: Media Foundation just closes the file.
  last_frame_.Reset();
  std::error_code ignored;
  std::filesystem::remove(part_path_, ignored);
}

void SegmentWriter::Fail(const std::string& message, long hr) {
  if (failure_.empty()) {
    failure_ = message + " (" + HresultMessage(hr) + ").";
  }
}

}  // namespace reclite_engine
