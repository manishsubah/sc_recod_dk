import 'package:equatable/equatable.dart';
import 'package:reclite/features/recording/domain/entities/capture_area.dart';

class RecordingConfig extends Equatable {
  const RecordingConfig({
    required this.displayId,
    required this.outputFolder,
    required this.framesPerSecond,
    required this.maxHeight,
    this.area,
  });

  final int displayId;
  final String outputFolder;
  final int framesPerSecond;
  final int maxHeight;

  /// Null records the whole display.
  final CaptureArea? area;

  @override
  List<Object?> get props => [
    displayId,
    outputFolder,
    framesPerSecond,
    maxHeight,
    area,
  ];
}
