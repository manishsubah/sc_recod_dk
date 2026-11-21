import 'package:equatable/equatable.dart';

/// An app window that can be recorded on its own.
class CaptureWindow extends Equatable {
  const CaptureWindow({
    required this.id,
    required this.title,
    required this.appName,
    required this.width,
    required this.height,
  });

  /// Only valid while the window is open.
  final int id;
  final String title;
  final String appName;
  final int width;
  final int height;

  String get label =>
      appName.isEmpty || title.contains(appName) ? title : '$title — $appName';

  @override
  List<Object?> get props => [id, title, appName, width, height];
}
