import 'package:equatable/equatable.dart';

/// Part of a display, in points, origin at the display's top-left.
class CaptureArea extends Equatable {
  const CaptureArea({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  String get label => '${width.round()} × ${height.round()}';

  @override
  List<Object?> get props => [x, y, width, height];
}
