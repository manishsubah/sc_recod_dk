import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

/// A segmented audio level meter (0–1, a -60…0 dBFS scale). Segments light in
/// the accent colour, the top ones in warning and tally colours near clipping.
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level, required this.active});

  final double level;

  /// False draws the empty, dimmed track (source switched off).
  final bool active;

  static const int segments = 24;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: active ? 'Level ${(level * 100).round()} percent' : 'Off',
      child: SizedBox(
        width: AppSize.meterWidth,
        height: AppSize.meterHeight,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _MeterPainter(
              level: active ? level.clamp(0, 1).toDouble() : 0,
              track: active ? t.seam : t.seam.withValues(alpha: 0.5),
              low: t.accent,
              high: t.warning,
              peak: t.tally,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.level,
    required this.track,
    required this.low,
    required this.high,
    required this.peak,
  });

  final double level;
  final Color track;
  final Color low;
  final Color high;
  final Color peak;

  @override
  void paint(Canvas canvas, Size size) {
    const n = LevelMeter.segments;
    const gap = 2.0;
    final w = (size.width - gap * (n - 1)) / n;
    final lit = (level * n).round();
    final paint = Paint();
    for (var i = 0; i < n; i++) {
      final fraction = (i + 1) / n;
      paint.color = i >= lit
          ? track
          : fraction > 0.92
          ? peak
          : fraction > 0.75
          ? high
          : low;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w + gap), 0, w, size.height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.level != level || old.track != track || old.low != low;
}
