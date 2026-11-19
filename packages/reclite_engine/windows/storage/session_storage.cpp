#include "session_storage.h"

#include "../core/win.h"

#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>

#include <algorithm>
#include <cstdio>
#include <cwchar>
#include <fstream>
#include <iterator>
#include <sstream>
#include <system_error>

#include "../core/strings.h"
#include "../core/ticks.h"

namespace reclite_engine {

namespace fs = std::filesystem;

namespace session_naming {

std::wstring Stamp(double seconds_from_now) {
  FILETIME now;
  ::GetSystemTimeAsFileTime(&now);
  ULARGE_INTEGER ticks;
  ticks.LowPart = now.dwLowDateTime;
  ticks.HighPart = now.dwHighDateTime;
  ticks.QuadPart += static_cast<ULONGLONG>(std::max(0.0, seconds_from_now) * kTicksPerSecond);
  FILETIME utc{ticks.LowPart, ticks.HighPart};
  FILETIME local;
  SYSTEMTIME t;
  ::FileTimeToLocalFileTime(&utc, &local);
  ::FileTimeToSystemTime(&local, &t);
  wchar_t text[32];
  std::swprintf(text, 32, L"%04u-%02u-%02u_%02u-%02u-%02u", t.wYear, t.wMonth, t.wDay, t.wHour,
                t.wMinute, t.wSecond);
  return text;
}

std::optional<fs::path> CreateSessionDirectory(const fs::path& parent,
                                               const std::wstring& stamp,
                                               std::string* error) {
  std::error_code ec;
  fs::create_directories(parent, ec);
  const std::wstring base = L"RecLite_" + stamp;
  for (int attempt = 1; attempt < 1000; ++attempt) {
    const fs::path candidate =
        parent / (attempt == 1 ? base : base + L"_" + std::to_wstring(attempt));
    if (::CreateDirectoryW(candidate.c_str(), nullptr)) {
      return candidate;
    }
    if (::GetLastError() != ERROR_ALREADY_EXISTS) {
      *error = "Could not create the recording folder (" +
               HresultMessage(HRESULT_FROM_WIN32(::GetLastError())) + ").";
      return std::nullopt;
    }
  }
  *error = "Could not create a new recording folder.";
  return std::nullopt;
}

std::wstring SegmentFileName(const std::wstring& stamp, int index) {
  wchar_t part[16];
  std::swprintf(part, 16, L"_Part%02d.mp4", index);
  return L"RecLite_" + stamp + part;
}

std::string UtcNow() {
  SYSTEMTIME t;
  ::GetSystemTime(&t);
  char text[32];
  std::snprintf(text, sizeof(text), "%04u-%02u-%02uT%02u:%02u:%02uZ", t.wYear, t.wMonth,
                t.wDay, t.wHour, t.wMinute, t.wSecond);
  return text;
}

}  // namespace session_naming

bool WriteManifest(const SessionManifest& manifest, const fs::path& directory) {
  const fs::path target = directory / SessionManifest::kFileName;
  fs::path temporary = target;
  temporary += L".tmp";
  {
    std::ofstream out(temporary, std::ios::binary | std::ios::trunc);
    if (!out) {
      return false;
    }
    out << manifest.ToJson();
    if (!out.good()) {
      return false;
    }
  }
  return ::MoveFileExW(temporary.c_str(), target.c_str(),
                       MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

std::optional<SessionManifest> ReadManifest(const fs::path& directory) {
  std::ifstream in(directory / SessionManifest::kFileName, std::ios::binary);
  if (!in) {
    return std::nullopt;
  }
  std::stringstream text;
  text << in.rdbuf();
  return SessionManifest::FromJson(text.str());
}

std::optional<double> PlayableSeconds(const fs::path& file) {
  ComPtr<IMFSourceReader> reader;
  if (FAILED(::MFCreateSourceReaderFromURL(file.c_str(), nullptr, &reader))) {
    return std::nullopt;
  }
  // Only the first video stream, without decoding: fast even for 15-minute parts.
  reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS), FALSE);
  if (FAILED(reader->SetStreamSelection(
          static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), TRUE))) {
    return std::nullopt;
  }

  // Finished files carry their duration; unfinished (crashed) ones are measured.
  PROPVARIANT duration;
  ::PropVariantInit(&duration);
  if (SUCCEEDED(reader->GetPresentationAttribute(
          static_cast<DWORD>(MF_SOURCE_READER_MEDIASOURCE), MF_PD_DURATION, &duration)) &&
      duration.vt == VT_UI8 && duration.uhVal.QuadPart > 0) {
    const double seconds = TicksToSeconds(static_cast<int64_t>(duration.uhVal.QuadPart));
    ::PropVariantClear(&duration);
    return seconds;
  }
  ::PropVariantClear(&duration);

  int64_t end = -1;
  for (;;) {
    DWORD flags = 0;
    LONGLONG timestamp = 0;
    ComPtr<IMFSample> sample;
    if (FAILED(reader->ReadSample(static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM), 0,
                                  nullptr, &flags, &timestamp, &sample)) ||
        (flags & MF_SOURCE_READERF_ENDOFSTREAM) || (flags & MF_SOURCE_READERF_ERROR)) {
      break;
    }
    if (sample) {
      LONGLONG sample_duration = 0;
      sample->GetSampleDuration(&sample_duration);
      end = std::max<int64_t>(end, timestamp + sample_duration);
    }
  }
  if (end <= 0) {
    return std::nullopt;
  }
  return TicksToSeconds(end);
}

namespace {

constexpr double kMinimumPlayableSeconds = 0.25;

fs::path UniquePath(const fs::path& wanted) {
  std::error_code ec;
  if (!fs::exists(wanted, ec)) {
    return wanted;
  }
  const fs::path stem = wanted.parent_path() / wanted.stem();
  const std::wstring extension = wanted.extension().wstring();
  for (int n = 2; n < 1000; ++n) {
    fs::path candidate = stem;
    candidate += L"_" + std::to_wstring(n) + extension;
    if (!fs::exists(candidate, ec)) {
      return candidate;
    }
  }
  return wanted;
}

// RecLite_…_Part03.mp4 -> 3
int PartIndex(const std::wstring& name, int fallback) {
  const auto at = name.rfind(L"_Part");
  if (at == std::wstring::npos) {
    return fallback;
  }
  return static_cast<int>(std::wcstol(name.c_str() + at + 5, nullptr, 10));
}

std::optional<RecoveredSession> RecoverSession(const fs::path& directory) {
  std::error_code ec;
  std::vector<fs::path> partials;
  for (const auto& entry : fs::directory_iterator(directory, ec)) {
    const std::wstring name = entry.path().filename().wstring();
    if (name.size() > 9 && name.compare(name.size() - 9, 9, L".mp4.part") == 0) {
      partials.push_back(entry.path());
    }
  }
  std::sort(partials.begin(), partials.end());
  auto manifest = ReadManifest(directory);
  const bool interrupted = !partials.empty() || (manifest && manifest->status == "recording");
  if (!interrupted) {
    return std::nullopt;
  }

  for (const fs::path& partial : partials) {
    const auto size = fs::file_size(partial, ec);
    if (ec || size == 0) {
      fs::remove(partial, ec);
      continue;
    }
    fs::path target = partial;
    target.replace_extension();  // .mp4.part -> .mp4
    target = UniquePath(target);
    if (!::MoveFileExW(partial.c_str(), target.c_str(), 0)) {
      continue;
    }
    const auto seconds = PlayableSeconds(target);
    if (!seconds || *seconds < kMinimumPlayableSeconds) {
      fs::path unplayable = partial;
      unplayable += L".unplayable";
      ::MoveFileExW(target.c_str(), UniquePath(unplayable).c_str(), 0);
      continue;
    }
    if (manifest) {
      SessionManifest::Segment segment;
      segment.index = PartIndex(target.filename().wstring(),
                                static_cast<int>(manifest->segments.size()) + 1);
      segment.file = WideToUtf8(target.filename().wstring());
      segment.duration_ms = static_cast<int64_t>(*seconds * 1000);
      segment.bytes = static_cast<int64_t>(size);
      segment.status = "recovered";
      manifest->AddSegment(segment);
    }
  }

  RecoveredSession result;
  result.directory = directory;
  for (const auto& entry : fs::directory_iterator(directory, ec)) {
    if (entry.path().extension() == L".mp4") {
      result.files.push_back(entry.path());
    }
  }
  std::sort(result.files.begin(), result.files.end());

  if (manifest) {
    manifest->status = "recovered";
    if (manifest->ended_at.empty()) {
      manifest->ended_at = session_naming::UtcNow();
    }
    WriteManifest(*manifest, directory);
    result.duration_ms = manifest->TotalDurationMs();
  } else {
    for (const auto& file : result.files) {
      result.duration_ms += static_cast<int64_t>(PlayableSeconds(file).value_or(0) * 1000);
    }
  }
  if (result.files.empty()) {
    return std::nullopt;
  }
  return result;
}

}  // namespace

std::vector<RecoveredSession> RecoverSessions(const fs::path& parent, const fs::path& active) {
  std::vector<RecoveredSession> results;
  std::error_code ec;
  std::vector<fs::path> directories;
  for (const auto& entry : fs::directory_iterator(parent, ec)) {
    const std::wstring name = entry.path().filename().wstring();
    if (entry.is_directory(ec) && name.rfind(L"RecLite_", 0) == 0) {
      directories.push_back(entry.path());
    }
  }
  std::sort(directories.begin(), directories.end());
  for (const fs::path& directory : directories) {
    if (!active.empty() && fs::equivalent(directory, active, ec)) {
      continue;
    }
    if (auto recovered = RecoverSession(directory)) {
      results.push_back(std::move(*recovered));
    }
  }
  return results;
}

}  // namespace reclite_engine
