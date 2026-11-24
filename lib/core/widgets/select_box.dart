import 'package:flutter/material.dart';

import 'package:reclite/app/theme/app_tokens.dart';
import 'package:reclite/app/theme/reclite_theme.dart';

/// A bordered drop-down field: a Windows ComboBox or a macOS pop-up button.
class SelectBox<T> extends StatelessWidget {
  const SelectBox({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// Fixed width; otherwise as wide as the longest item.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    final radius = BorderRadius.circular(t.controlRadius);
    return Container(
      width: width,
      height: t.controlHeight,
      padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: enabled ? t.paneRaised : t.pane,
        borderRadius: radius,
        border: Border.all(color: t.seamStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: width != null,
          isDense: true,
          borderRadius: BorderRadius.circular(t.paneRadius),
          dropdownColor: t.paneRaised,
          focusColor: Colors.transparent,
          iconSize: AppSize.iconMd,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled ? t.inkMuted : t.inkFaint,
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: enabled ? t.ink : t.inkMuted,
          ),
        ),
      ),
    );
  }
}
