// Platform-independent tests for the Windows audio mixer/pipeline (same cases as
// the macOS AudioMixer). Build anywhere:
//   c++ -std=c++17 -I.. test/audio_mixer_test.cpp audio/audio_mixer.cpp audio/audio_pipeline.cpp
#include <cmath>
#include <cstdio>
#include <vector>

#include "../audio/audio_mixer.h"
#include "../audio/audio_pipeline.h"

using reclite_engine::AudioMixer;
using reclite_engine::AudioPipeline;

static int failures = 0;
static void Check(bool ok, const char* name) {
  std::printf("%s %s\n", ok ? "PASS" : "FAIL", name);
  if (!ok) ++failures;
}
static std::vector<float> Stereo(int frames, float v) { return std::vector<float>(frames * 2, v); }
static bool All(const std::vector<float>& s, size_t from, size_t to, float v) {
  for (size_t i = from; i < to; ++i) if (std::fabs(s[i] - v) > 1e-6f) return false;
  return true;
}

int main() {
  { AudioMixer m(1); m.Push(0, Stereo(100, 0.5f), 0); auto o = m.Pull(100);
    Check(o.size() == 200 && All(o, 0, 200, 0.5f), "single source passes through");
    Check(!m.EndFrame(0).has_value(), "fully consumed"); }
  { AudioMixer m(2); m.Push(0, Stereo(50, 0.25f), 0); m.Push(1, Stereo(50, 0.5f), 0);
    Check(All(m.Pull(50), 0, 100, 0.75f), "two sources are summed"); }
  // Real breaks (well beyond timestamp jitter) still become silence / are trimmed.
  { AudioMixer m(1); m.Push(0, Stereo(10, 1), 0); m.Push(0, Stereo(10, 1), 4810); auto o = m.Pull(4820);
    Check(o.size() == 9640 && All(o, 0, 20, 1) && All(o, 20, 9620, 0) && All(o, 9620, 9640, 1), "gap becomes silence"); }
  { AudioMixer m(1); m.Push(0, Stereo(9600, 1), 0); m.Push(0, Stereo(9600, 0.5f), 4800); auto o = m.Pull(14400);
    Check(All(o, 0, 19200, 1) && All(o, 19200, 28800, 0.5f), "overlap is trimmed, first data wins"); }
  // Windows' packet timestamps jitter by a few ms; that must not cut holes in the sound.
  { AudioMixer m(1); long pushed = 0; std::vector<float> out;
    const int jitter[] = {0, 90, -70, 40, -96, 13, 75, -30};
    for (int i = 0; i < 400; ++i) {
      m.Push(0, Stereo(480, 0.5f), i * 480LL + jitter[i % 8]);
      pushed += 480;
      auto o = m.Pull(i * 480LL);
      out.insert(out.end(), o.begin(), o.end());
    }
    auto rest = m.Pull(400 * 480LL + 200);
    out.insert(out.end(), rest.begin(), rest.end());
    size_t holes = 0;
    for (size_t k = 0; k + 1 < out.size() - 400; ++k) if (out[k] == 0.0f) ++holes;
    Check(holes == 0, "jittered timestamps stay continuous (no clicks)"); }
  { AudioMixer m(1); m.Push(0, Stereo(480, 1), 0); m.Push(0, Stereo(480, 1), 480 + 1500);
    Check(*m.EndFrame(0) == 480 + 1500 + 480, "drift beyond 30 ms re-syncs to the timestamp"); }
  { AudioMixer m(1); m.Push(0, Stereo(480, 1), 0); m.Pull(480); m.Push(0, Stereo(480, 1), 480 + 60);
    Check(*m.EndFrame(0) == 960, "continuity holds after the queue was emptied"); }
  { AudioMixer m(2); m.Push(0, Stereo(100, 0.5f), 0); auto a = m.Pull(60);
    m.Push(1, Stereo(100, 0.25f), 30); auto b = m.Pull(100);
    Check(All(a, 0, a.size(), 0.5f), "missing source is silence");
    Check(All(b, 0, b.size(), 0.75f), "late samples dropped, rest mixed in place"); }
  { AudioMixer m(1); m.Push(0, Stereo(10, 0.5f), 40); auto o = m.Pull(60);
    Check(All(o, 0, 80, 0) && All(o, 80, 100, 0.5f) && All(o, 100, 120, 0), "late start lands at the right position"); }
  { AudioMixer m(2); m.Push(0, Stereo(10, 0.8f), 0); m.Push(1, Stereo(10, 0.8f), 0);
    Check(All(m.Pull(10), 0, 20, 1), "clipped to full scale"); }
  { AudioMixer m(1); long total = 0;
    for (int i = 0; i < 2000; ++i) { m.Push(0, Stereo(1024, 0.1f), i * 1024LL); total += (long)m.Pull(i * 1024LL + 512).size() / 2; }
    Check(total == 2000L * 1024 - 512, "long run keeps continuity"); }
  { AudioMixer m(1); m.Push(0, Stereo(10, 1), 0); m.Push(0, Stereo(10, 1), 48000LL * 60);
    Check(*m.EndFrame(0) <= 10 + AudioMixer::kMaxGapFrames + 10, "huge gap is bounded"); }

  // Pipeline: boundary split + pause ceiling (times in 100 ns ticks).
  { AudioPipeline p(1); std::vector<std::pair<int64_t, size_t>> out; int64_t boundary_hit = -1;
    p.set_output([&](const std::vector<float>& s, int64_t t) { out.push_back({t, s.size() / 2}); });
    p.Start(0);
    p.SetBoundary(5'000'000, [&](int64_t t) { boundary_hit = t; });  // 0.5 s
    p.Push(0, Stereo(48000, 0.2f), 0);                                // 1 s of audio
    p.Pump(10'000'000, std::nullopt);
    Check(out.size() == 2 && out[0].second == 24000 && out[1].first == 5'000'000, "output splits exactly at the boundary");
    Check(boundary_hit == 5'000'000, "boundary callback fires at the boundary"); }
  { AudioPipeline p(1); size_t frames = 0;
    p.set_output([&](const std::vector<float>& s, int64_t) { frames += s.size() / 2; });
    p.Start(0); p.Pump(30'000'000, 10'000'000);  // quiet source, paused at 1 s
    Check(frames == 48000, "pause ceiling stops silence at the pause point"); }

  std::printf(failures == 0 ? "ALL PASSED\n" : "%d FAILED\n", failures);
  return failures == 0 ? 0 : 1;
}
