import 'package:equatable/equatable.dart';
import 'package:reclite/features/recording/domain/entities/capture_area.dart';

class RecordingConfig extends Equatable {
  const RecordingConfig({
    required this.displayId,
    required this.outputFolder,
    required this.framesPerSecond,
    required this.maxHeight,
    this.area,
    this.windowId,
    this.captureSystemAudio = true,
    this.captureMicrophone = false,
    this.segmentDuration = const Duration(minutes: 15),
    this.showCursor = true,
  });

  final int displayId;
  final String outputFolder;
  final int framesPerSecond;
  final int maxHeight;

  /// Null records the whole display.
  final CaptureArea? area;

  /// Records only this app window; [displayId] and [area] are then ignored.
  final int? windowId;

  final bool captureSystemAudio;
  final bool captureMicrophone;

  /// Recorded time per MP4 part; pauses don't count.
  final Duration segmentDuration;
  final bool showCursor;

  @override
  List<Object?> get props => [
    displayId,
    outputFolder,
    framesPerSecond,
    maxHeight,
    area,
    windowId,
    captureSystemAudio,
    captureMicrophone,
    segmentDuration,
    showCursor,
  ];
}
