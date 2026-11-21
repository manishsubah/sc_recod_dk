import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/capture_area.dart';
import 'package:reclite/features/recording/domain/entities/capture_display.dart';
import 'package:reclite/features/recording/domain/entities/capture_window.dart';
import 'package:reclite/features/recording/domain/repositories/recorder_repository.dart';

part 'sources_state.dart';

/// Screen permission gate, display picker and optional area or window.
class SourcesCubit extends Cubit<SourcesState> {
  SourcesCubit(this._recorder) : super(const SourcesLoading());

  final RecorderRepository _recorder;

  Future<void> load() async {
    final previous = state;
    final keepId = previous is SourcesLoaded ? previous.selectedId : null;
    final keepArea = previous is SourcesLoaded ? previous.area : null;
    emit(const SourcesLoading());
    try {
      if (!await _recorder.hasScreenPermission()) {
        emit(const SourcesPermissionRequired(requested: false));
        return;
      }
      final displays = await _recorder.listDisplays();
      if (displays.isEmpty) {
        emit(const SourcesFailed('No displays found.'));
        return;
      }
      final selected = displays.any((d) => d.id == keepId)
          ? keepId!
          : displays
                .firstWhere((d) => d.isMain, orElse: () => displays.first)
                .id;
      emit(
        SourcesLoaded(
          displays: displays,
          selectedId: selected,
          area: selected == keepId ? keepArea : null,
        ),
      );
    } on Failure catch (f) {
      emit(SourcesFailed(f.message));
    }
  }

  Future<void> requestPermission() async {
    try {
      if (await _recorder.requestScreenPermission()) {
        await load();
      } else {
        emit(const SourcesPermissionRequired(requested: true));
      }
    } on Failure catch (f) {
      emit(SourcesFailed(f.message));
    }
  }

  Future<void> openPermissionSettings() async {
    try {
      await _recorder.openScreenPermissionSettings();
    } on Failure catch (f) {
      emit(SourcesFailed(f.message));
    }
  }

  /// An area belongs to one display, so switching display clears it.
  void select(int displayId) {
    final current = state;
    if (current is SourcesLoaded &&
        current.displays.any((d) => d.id == displayId)) {
      emit(SourcesLoaded(displays: current.displays, selectedId: displayId));
    }
  }

  /// Opens the drag-to-select overlay. Cancelling keeps the current choice.
  Future<void> selectArea() async {
    final current = state;
    if (current is! SourcesLoaded) return;
    try {
      final area = await _recorder.selectArea(current.selectedId);
      if (area != null && state == current) {
        emit(current.withArea(area));
      }
    } on Failure catch (f) {
      emit(SourcesFailed(f.message));
    }
  }

  void useFullScreen() {
    final current = state;
    if (current is SourcesLoaded &&
        (current.area != null || current.window != null)) {
      emit(current.withArea(null));
    }
  }

  /// Windows to choose from; empty when they can't be listed.
  Future<List<CaptureWindow>> availableWindows() async {
    try {
      return await _recorder.listWindows();
    } on Failure {
      return const [];
    }
  }

  void selectWindow(CaptureWindow window) {
    final current = state;
    if (current is SourcesLoaded) emit(current.withWindow(window));
  }
}
