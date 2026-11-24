import 'package:flutter/material.dart';

/// Small tracked capitals for measurements, like the numbers printed along the
/// edge of a film strip: `PART 02`, `NEXT PART 12:13`. Data only, never a
/// heading's eyebrow.
class EdgeLabel extends StatelessWidget {
  const EdgeLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(
        color: color ?? style.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
