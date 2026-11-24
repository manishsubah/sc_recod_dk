import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

/// The recording light: solid tally red while live, a hollow
/// grey ring while paused. Changes are animated once, never looped.
class TallyDot extends StatelessWidget {
  const TallyDot({super.key, required this.live, this.size = AppSize.tallyDot});

  final bool live;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.ease,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: live ? t.tally : Colors.transparent,
        border: Border.all(color: live ? t.tally : t.inkMuted, width: 2),
      ),
    );
  }
}
