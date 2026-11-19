import 'package:reclite/features/recording/domain/entities/engine_info.dart';
import 'package:reclite/features/recording/domain/entities/storage_info.dart';

abstract interface class EngineRepository {
  Future<EngineInfo> getEngineInfo();

  Future<StorageInfo> getStorageInfo(String folder);
}
