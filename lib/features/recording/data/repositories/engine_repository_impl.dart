import 'dart:io';

import 'package:flutter/services.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';
import 'package:reclite/features/recording/domain/repositories/engine_repository.dart';
import 'package:reclite_engine/reclite_engine.dart';

class EngineRepositoryImpl implements EngineRepository {
  EngineRepositoryImpl(this._engine);

  final RecliteEngine _engine;

  @override
  Future<EngineInfo> getEngineInfo() async {
    try {
      final c = await _engine.getCapabilities();
      return EngineInfo(
        platformName: switch (c.platform) {
          HostPlatform.macos => 'macOS',
          HostPlatform.windows => 'Windows',
        },
        osVersion: c.osVersion,
        minimumOsVersion: c.minimumOsVersion,
        meetsMinimumOs: c.meetsMinimumOs,
        supportsSystemAudio: c.supportsSystemAudio,
        supportsMicrophoneViaScreenCapture:
            c.supportsMicrophoneViaScreenCapture,
        hasHardwareH264Encoder: c.hasHardwareH264Encoder,
        hasHardwareHevcEncoder: c.hasHardwareHevcEncoder,
        engineVersion: c.engineVersion,
      );
    } on PlatformException catch (e) {
      throw Failure.fromPlatformException(e);
    }
  }

  @override
  Future<StorageInfo> getStorageInfo(String folder) async {
    try {
      final space = await _engine.getDiskSpace(_nearestExisting(folder));
      return StorageInfo(
        path: folder,
        freeBytes: space.freeBytes,
        totalBytes: space.totalBytes,
      );
    } on PlatformException catch (e) {
      throw Failure.fromPlatformException(e);
    }
  }

  static String _nearestExisting(String folder) {
    var dir = Directory(folder);
    while (!dir.existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return dir.path;
  }
}
