part of 'sources_cubit.dart';

sealed class SourcesState extends Equatable {
  const SourcesState();

  @override
  List<Object?> get props => [];
}

final class SourcesLoading extends SourcesState {
  const SourcesLoading();
}

final class SourcesPermissionRequired extends SourcesState {
  const SourcesPermissionRequired({required this.requested});

  /// The system prompt was already shown; only System Settings can grant access now.
  final bool requested;

  @override
  List<Object?> get props => [requested];
}

final class SourcesLoaded extends SourcesState {
  const SourcesLoaded({
    required this.displays,
    required this.selectedId,
    this.area,
    this.window,
  });

  final List<CaptureDisplay> displays;
  final int selectedId;

  /// Null records the whole display.
  final CaptureArea? area;

  /// Records only this window instead of the display; never set with [area].
  final CaptureWindow? window;

  CaptureDisplay get selected => displays.firstWhere((d) => d.id == selectedId);

  SourcesLoaded withArea(CaptureArea? area) =>
      SourcesLoaded(displays: displays, selectedId: selectedId, area: area);

  SourcesLoaded withWindow(CaptureWindow? window) =>
      SourcesLoaded(displays: displays, selectedId: selectedId, window: window);

  @override
  List<Object?> get props => [displays, selectedId, area, window];
}

final class SourcesFailed extends SourcesState {
  const SourcesFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
