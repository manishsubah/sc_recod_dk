import 'package:equatable/equatable.dart';

/// The engine stopped (or warned) on its own, e.g. the user ended sharing from
/// the menu bar or the disk failed.
class RecordingInterruption extends Equatable {
  const RecordingInterruption({required this.message, required this.isFatal});

  final String message;
  final bool isFatal;

  @override
  List<Object?> get props => [message, isFatal];
}
