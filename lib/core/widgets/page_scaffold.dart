import 'package:flutter/material.dart';

/// Common page layout: title + centred, width-limited, scrollable content.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static const double maxContentWidth = 760;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
