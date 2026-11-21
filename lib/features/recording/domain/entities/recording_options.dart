import 'package:equatable/equatable.dart';

/// The user's recording choices from Settings; used for the next recording.
class RecordingOptions extends Equatable {
  const RecordingOptions({
    this.segmentDuration = const Duration(minutes: 15),
    this.framesPerSecond = 30,
    this.maxHeight = 1440,
    this.showCursor = true,
  });

  /// Recorded time per MP4 part; pauses don't count.
  final Duration segmentDuration;
  final int framesPerSecond;

  /// Video is scaled down to at most this height, keeping its shape.
  final int maxHeight;
  final bool showCursor;

  RecordingOptions copyWith({
    Duration? segmentDuration,
    int? framesPerSecond,
    int? maxHeight,
    bool? showCursor,
  }) => RecordingOptions(
    segmentDuration: segmentDuration ?? this.segmentDuration,
    framesPerSecond: framesPerSecond ?? this.framesPerSecond,
    maxHeight: maxHeight ?? this.maxHeight,
    showCursor: showCursor ?? this.showCursor,
  );

  @override
  List<Object?> get props => [
    segmentDuration,
    framesPerSecond,
    maxHeight,
    showCursor,
  ];
}
