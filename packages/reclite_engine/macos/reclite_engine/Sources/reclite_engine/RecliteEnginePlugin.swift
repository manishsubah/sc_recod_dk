import FlutterMacOS
import Foundation

/// Entry point of the native engine on macOS.
///
/// Only wires the Pigeon host API to the engine's components. Real work lives in
/// `Engine/`, `Capture/`, `Audio/`, `Writer/` and `Storage/` (see docs/PLAN.md §7).
public final class RecliteEnginePlugin: NSObject, FlutterPlugin, EngineHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = RecliteEnginePlugin()
    EngineHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
  }

  func getCapabilities() throws -> EngineCapabilities {
    CapabilitiesProbe.current()
  }

  func getDiskSpace(path: String) throws -> DiskSpace {
    try DiskSpaceProbe.query(path: path)
  }
}
