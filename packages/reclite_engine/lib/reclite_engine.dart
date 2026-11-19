library;

import 'src/messages.g.dart';

export 'src/messages.g.dart' show DiskSpace, EngineCapabilities, HostPlatform;

class RecliteEngine {
  RecliteEngine({EngineHostApi? hostApi}) : _api = hostApi ?? EngineHostApi();

  final EngineHostApi _api;

  Future<EngineCapabilities> getCapabilities() => _api.getCapabilities();

  Future<DiskSpace> getDiskSpace(String path) => _api.getDiskSpace(path);
}
