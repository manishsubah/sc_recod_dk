import '../entities/engine_info.dart';
import '../entities/storage_info.dart';

/// Access to the native recording engine.
///
/// Implementations throw a `Failure` (see `core/errors/failures.dart`).
abstract interface class EngineRepository {
  Future<EngineInfo> getEngineInfo();

  /// Disk space for [folder]. The folder does not need to exist yet: the
  /// nearest existing parent's volume is used.
  Future<StorageInfo> getStorageInfo(String folder);
}
