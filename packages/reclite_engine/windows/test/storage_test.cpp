// Platform-independent tests for session.json and the disk guard. Build anywhere:
//   c++ -std=c++17 test/storage_test.cpp storage/session_manifest.cpp storage/disk_guard.cpp
#include <cstdio>
#include <fstream>
#include <sstream>

#include "../storage/disk_guard.h"
#include "../storage/session_manifest.h"

using namespace reclite_engine;

static int failures = 0;
static void Check(bool ok, const char* name) {
  std::printf("%s %s\n", ok ? "PASS" : "FAIL", name);
  if (!ok) ++failures;
}

int main(int argc, char** argv) {
  SessionManifest m;
  m.session_id = "2026-11-19_10-00-00";
  m.started_at = "2026-11-19T04:30:00Z";
  m.status = "recording";
  m.source_type = "area";
  m.source_name = "DELL \"U2720Q\"";
  m.directory = "C:\\Users\\Ann\xC3\xA9" "e\\Videos\\RecLite";  // "Année", UTF-8
  m.area = {100, 80, 1280, 720};
  m.system_audio = true;
  m.width = 1280; m.height = 720; m.fps = 30; m.segment_seconds = 900;
  m.AddSegment({2, "RecLite_2026-11-19_10-15-00_Part02.mp4", 900000, 2000, "complete"});
  m.AddSegment({1, "RecLite_2026-11-19_10-00-00_Part01.mp4", 900000, 1000, "complete"});
  m.AddSegment({1, "duplicate.mp4", 1, 1, "complete"});

  const auto back = SessionManifest::FromJson(m.ToJson());
  Check(back.has_value(), "round trip parses");
  Check(back && back->segments.size() == 2 && back->segments[0].index == 1, "segments sorted, duplicate ignored");
  Check(back && back->source_name == m.source_name, "quotes survive escaping");
  Check(back && back->area.size() == 4 && back->area[2] == 1280, "area kept");
  Check(back && back->system_audio && !back->microphone && back->fps == 30, "audio + video fields");
  Check(back && back->TotalDurationMs() == 1800000, "total duration");
  Check(back && back->directory == m.directory, "save folder kept (backslashes, accents)");
  Check(SessionManifest::FromJson("{\"sessionId\":\"x\",\"startedAt\":\"t\"}")->directory.empty(),
        "old manifest without a folder still reads");
  Check(!SessionManifest::FromJson("{not json").has_value(), "garbage is rejected");

  if (argc > 1) {  // A session.json written by the macOS app.
    std::ifstream file(argv[1]);
    std::stringstream text; text << file.rdbuf();
    const auto mac = SessionManifest::FromJson(text.str());
    Check(mac.has_value(), "reads the macOS app's session.json");
    if (mac) std::printf("     macOS manifest: status=%s segments=%zu total=%lld ms fps=%d\n",
                         mac->status.c_str(), mac->segments.size(), (long long)mac->TotalDurationMs(), mac->fps);
  }

  Check(disk_guard::Check(3'000'000'000) == disk_guard::Verdict::kOk, "3 GB free is fine");
  Check(disk_guard::Check(1'500'000'000) == disk_guard::Verdict::kLow, "1.5 GB free warns");
  Check(disk_guard::Check(400'000'000) == disk_guard::Verdict::kCritical, "400 MB free stops");
  std::printf("     %s\n", disk_guard::LowSpaceMessage(1'500'000'000, 625'000).c_str());

  std::printf(failures == 0 ? "ALL PASSED\n" : "%d FAILED\n", failures);
  return failures == 0 ? 0 : 1;
}
