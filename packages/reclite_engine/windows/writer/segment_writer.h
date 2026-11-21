#ifndef RECLITE_ENGINE_WRITER_SEGMENT_WRITER_H_
#define RECLITE_ENGINE_WRITER_SEGMENT_WRITER_H_

#include <cstdint>
#include <filesystem>
#include <memory>
#include <string>
#include <vector>

#include "../core/win.h"

#include <d3d11.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>

namespace reclite_engine {

// Encodes one MP4 part with Media Foundation: hardware H.264 from GPU NV12
// textures + AAC from 48 kHz stereo float. Written as fragmented MP4 to
// `<name>.mp4.part` (playable up to the last fragment after a crash) and renamed
// to `<name>.mp4` when finished.
//
// Times are media-timeline ticks; the file starts at the part's session start.
// Use from one thread, except Finish(), which blocks and runs on its own thread
// once nothing else touches the writer.
class SegmentWriter {
 public:
  struct Format {
    int width = 0;
    int height = 0;
    int frames_per_second = 30;
    bool with_audio = false;
  };

  static std::unique_ptr<SegmentWriter> Create(int index,
                                               const std::filesystem::path& final_path,
                                               const Format& format,
                                               IMFDXGIDeviceManager* manager,
                                               std::string* error);
  ~SegmentWriter();

  SegmentWriter(const SegmentWriter&) = delete;
  SegmentWriter& operator=(const SegmentWriter&) = delete;

  int index() const { return index_; }
  const std::filesystem::path& final_path() const { return final_path_; }
  bool has_session() const { return session_start_ >= 0; }
  int64_t session_start() const { return session_start_; }
  ID3D11Texture2D* last_frame() const { return last_frame_.Get(); }
  int dropped_frames() const { return dropped_frames_; }
  bool failed() const { return !failure_.empty(); }
  const std::string& failure() const { return failure_; }
  int64_t BytesOnDisk() const;

  // Later parts start exactly at the boundary instead of at their first frame.
  void StartSession(int64_t time);
  void AppendVideo(ID3D11Texture2D* nv12, int64_t time);
  // Repeats the last picture for every slot before `time` (called while the screen is still).
  void FillUntil(int64_t time);
  void AppendAudio(const std::vector<float>& samples, int64_t time);
  int64_t DurationUntil(int64_t end) const;

  // Writes the held last frame lasting until `end` (a still screen keeps its length), finalizes
  // and renames the file. Blocking.
  bool Finish(int64_t end, std::string* error);

  // Throws away a part that never received frames (e.g. a pre-created next part).
  void Cancel();

 private:
  SegmentWriter() = default;
  int64_t SlotOf(int64_t time) const;
  int64_t SlotTime(int64_t slot) const;
  void FillTo(int64_t slot);
  bool WriteSlot(ID3D11Texture2D* nv12);
  bool WriteVideoSample(ID3D11Texture2D* nv12, int64_t relative_time, int64_t duration);
  void Fail(const std::string& message, long hr);

  int index_ = 0;
  std::filesystem::path final_path_;
  std::filesystem::path part_path_;
  Format format_;
  ComPtr<IMFSinkWriter> writer_;
  DWORD video_stream_ = 0;
  DWORD audio_stream_ = 0;
  int64_t session_start_ = -1;
  int64_t last_video_time_ = -1;
  int64_t next_audio_time_ = -1;
  // Media Foundation's H.264 encoder stamps the Nth frame at N / fps whatever time it
  // is given, so video is written at a constant rate: one frame per slot, with the
  // last picture repeated for slots where the screen did not change.
  int64_t next_slot_ = 0;
  ComPtr<ID3D11Texture2D> last_frame_;
  int dropped_frames_ = 0;
  std::string failure_;
  bool finished_ = false;
};

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_WRITER_SEGMENT_WRITER_H_
