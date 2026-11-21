part of 'help_cubit.dart';

class HelpState extends Equatable {
  const HelpState({this.error});

  /// Shown once, then cleared by the next state.
  final String? error;

  @override
  List<Object?> get props => [error];
}
