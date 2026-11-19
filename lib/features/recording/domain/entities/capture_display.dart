import 'package:equatable/equatable.dart';

class CaptureDisplay extends Equatable {
  const CaptureDisplay({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.isMain,
  });

  final int id;
  final String name;
  final int width;
  final int height;
  final bool isMain;

  String get label => '$name ($width × $height)';

  @override
  List<Object?> get props => [id, name, width, height, isMain];
}
