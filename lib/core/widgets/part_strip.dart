import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

/// A recording's length drawn the way RecLite stores it: one segment per MP4
/// part, with a tick every minute along the edge, like edge marks on film.
///
/// [parts] is the number of segments; the last one is filled to [lastFill]
/// (0–1). Earlier parts are always full.
class PartStrip extends StatelessWidget {
  const PartStrip({
    super.key,
    required this.parts,
    this.lastFill = 1,
    this.color,
    this.ticksPerPart = 0,
    this.semanticsLabel,
  });

  /// A single part filling up as it records; ticks mark each minute.
  factory PartStrip.live({
    Key? key,
    required Duration elapsedInPart,
    required Duration partLength,
    Color? color,
  }) {
    final total = math.max(1, partLength.inSeconds);
    final minutes = partLength.inMinutes;
    return PartStrip(
      key: key,
      parts: 1,
      lastFill: (elapsedInPart.inSeconds / total).clamp(0, 1).toDouble(),
      color: color,
      ticksPerPart: minutes >= 2 && minutes <= 60 ? minutes : 0,
    );
  }

  /// A finished recording: full parts, then the last one filled to the time
  /// it actually ran. [partLength] is the split length in use.
  factory PartStrip.recorded({
    Key? key,
    required int parts,
    required Duration duration,
    required Duration partLength,
    Color? color,
    String? semanticsLabel,
  }) {
    final length = math.max(1, partLength.inSeconds);
    final last = duration.inSeconds - length * math.max(0, parts - 1);
    final minutes = partLength.inMinutes;
    return PartStrip(
      key: key,
      parts: parts,
      lastFill: last <= 0 ? 1 : (last / length).clamp(0.02, 1).toDouble(),
      color: color,
      ticksPerPart: parts <= 4 && minutes >= 2 && minutes <= 60 ? minutes : 0,
      semanticsLabel: semanticsLabel,
    );
  }

  final int parts;
  final double lastFill;
  final Color? color;
  final int ticksPerPart;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        height: AppSize.partStripHeight + AppSize.partTick,
        child: CustomPaint(
          painter: _PartStripPainter(
            parts: math.max(1, parts),
            lastFill: lastFill.clamp(0, 1).toDouble(),
            fill: color ?? t.accent,
            track: t.seam,
            tick: t.seamStrong,
            ticksPerPart: ticksPerPart,
            radius: AppRadius.xs,
          ),
        ),
      ),
    );
  }
}

class _PartStripPainter extends CustomPainter {
  _PartStripPainter({
    required this.parts,
    required this.lastFill,
    required this.fill,
    required this.track,
    required this.tick,
    required this.ticksPerPart,
    required this.radius,
  });

  final int parts;
  final double lastFill;
  final Color fill;
  final Color track;
  final Color tick;
  final int ticksPerPart;
  final double radius;

  static const double gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final barTop = 0.0;
    final barHeight = AppSize.partStripHeight;
    final segment = (size.width - gap * (parts - 1)) / parts;
    final trackPaint = Paint()..color = track;
    final fillPaint = Paint()..color = fill;
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 1;

    for (var i = 0; i < parts; i++) {
      final left = i * (segment + gap);
      final rect = Rect.fromLTWH(left, barTop, segment, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        trackPaint,
      );
      final amount = i == parts - 1 ? lastFill : 1.0;
      if (amount > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, barTop, segment * amount, barHeight),
            Radius.circular(radius),
          ),
          fillPaint,
        );
      }
      if (ticksPerPart > 1) {
        for (var m = 1; m < ticksPerPart; m++) {
          final x = left + segment * m / ticksPerPart;
          final long = ticksPerPart >= 10 && m % 5 == 0;
          canvas.drawLine(
            Offset(x, barTop + barHeight + 1),
            Offset(x, barTop + barHeight + (long ? AppSize.partTick : 2)),
            tickPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PartStripPainter old) =>
      old.parts != parts ||
      old.lastFill != lastFill ||
      old.fill != fill ||
      old.track != track ||
      old.ticksPerPart != ticksPerPart;
}
