#include "session_storage.h"

#include "../core/win.h"

#include <shlobj.h>

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

std::wstring UniqueBaseName(const fs::path& folder, const fs::path& sessions,
                            const std::wstring& stamp) {
  std::error_code ec;
  const std::wstring first = L"RecLite_" + stamp;
  for (int n = 1; n < 1000; ++n) {
    const std::wstring base = n == 1 ? first : first + L"_" + std::to_wstring(n);
    const bool taken = fs::exists(folder / (base + L".mp4"), ec) ||
                       fs::exists(folder / (base + L"_Part01.mp4"), ec) ||
                       fs::exists(folder / (base + L"_Part01.mp4.part"), ec) ||
                       fs::exists(sessions / (base + L".json"), ec);
    if (!taken) {
      return base;
    }
  }
  return first + L"_" + Stamp();  // Practically unreachable.
}

std::wstring SegmentFileName(const std::wstring& base, int index) {
  wchar_t part[16];
  std::swprintf(part, 16, L"_Part%02d.mp4", index);
  return base + part;
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

fs::path SessionsDirectory() {
  PWSTR local = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local))) {
    return {};
  }
  fs::path sessions = fs::path(local) / L"RecLite" / L"Sessions";
  ::CoTaskMemFree(local);
  std::error_code ec;
  fs::create_directories(sessions, ec);
  return ec ? fs::path() : sessions;
}

bool WriteManifest(const SessionManifest& manifest, const fs::path& target) {
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

std::optional<SessionManifest> ReadManifest(const fs::path& file) {
  std::ifstream in(file, std::ios::binary);
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

bool StartsWith(const std::wstring& text, const std::wstring& prefix) {
  return text.compare(0, prefix.size(), prefix) == 0;
}

std::optional<RecoveredSession> RecoverSession(const fs::path& manifest_file) {
  auto manifest = ReadManifest(manifest_file);
  if (!manifest || manifest->status != "recording" || manifest->directory.empty()) {
    return std::nullopt;
  }
  const fs::path directory(Utf8ToWide(manifest->directory));
  const std::wstring parts_prefix = manifest_file.stem().wstring() + L"_Part";

  std::error_code ec;
  std::vector<fs::path> partials;
  for (const auto& entry : fs::directory_iterator(directory, ec)) {
    const std::wstring name = entry.path().filename().wstring();
    if (StartsWith(name, parts_prefix) && name.size() > 9 &&
        name.compare(name.size() - 9, 9, L".mp4.part") == 0) {
      partials.push_back(entry.path());
    }
  }
  std::sort(partials.begin(), partials.end());

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
    SessionManifest::Segment segment;
    segment.index = PartIndex(target.filename().wstring(),
                              static_cast<int>(manifest->segments.size()) + 1);
    segment.file = WideToUtf8(target.filename().wstring());
    segment.duration_ms = static_cast<int64_t>(*seconds * 1000);
    segment.bytes = static_cast<int64_t>(size);
    segment.status = "recovered";
    manifest->AddSegment(segment);
  }

  manifest->status = "recovered";
  if (manifest->ended_at.empty()) {
    manifest->ended_at = session_naming::UtcNow();
  }
  TidySinglePart(&*manifest);
  WriteManifest(*manifest, manifest_file);

  RecoveredSession result;
  result.directory = directory;
  for (const auto& segment : manifest->segments) {
    const fs::path file = directory / Utf8ToWide(segment.file);
    if (fs::exists(file, ec)) {
      result.files.push_back(file);
    }
  }
  result.duration_ms = manifest->TotalDurationMs();
  if (result.files.empty()) {
    return std::nullopt;
  }
  return result;
}

}  // namespace

fs::path TidySinglePart(SessionManifest* manifest) {
  if (manifest->segments.empty()) {
    return {};
  }
  const fs::path directory(Utf8ToWide(manifest->directory));
  SessionManifest::Segment& only = manifest->segments.front();
  const fs::path current = directory / Utf8ToWide(only.file);
  if (manifest->segments.size() != 1) {
    return current;
  }
  const std::wstring name = current.filename().wstring();
  const auto at = name.rfind(L"_Part01.mp4");
  if (at == std::wstring::npos || at + 11 != name.size()) {
    return current;
  }
  const fs::path single = directory / (name.substr(0, at) + L".mp4");
  // MOVEFILE flags 0: never replace an existing file.
  if (!::MoveFileExW(current.c_str(), single.c_str(), 0)) {
    return current;
  }
  only.file = WideToUtf8(single.filename().wstring());
  return single;
}

std::vector<RecoveredSession> RecoverSessions(const fs::path& sessions, const fs::path& active) {
  std::vector<RecoveredSession> results;
  std::error_code ec;
  std::vector<fs::path> manifests;
  for (const auto& entry : fs::directory_iterator(sessions, ec)) {
    if (entry.path().extension() == L".json") {
      manifests.push_back(entry.path());
    }
  }
  std::sort(manifests.begin(), manifests.end());
  for (const fs::path& manifest : manifests) {
    if (!active.empty() && fs::equivalent(manifest, active, ec)) {
      continue;
    }
    if (auto recovered = RecoverSession(manifest)) {
      results.push_back(std::move(*recovered));
    }
  }
  return results;
}

}  // namespace reclite_engine
