#ifndef FLUTTER_PLUGIN_RECLITE_ENGINE_PLUGIN_H_
#define FLUTTER_PLUGIN_RECLITE_ENGINE_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <string>

#include "messages.g.h"

namespace reclite_engine {

// Entry point of the native engine on Windows.
//
// Only wires the Pigeon host API to the engine's components. Real work lives in
// engine/, capture/, audio/, writer/ and storage/ (see docs/PLAN.md §7).
class RecliteEnginePlugin : public flutter::Plugin, public EngineHostApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  RecliteEnginePlugin();
  ~RecliteEnginePlugin() override;

  RecliteEnginePlugin(const RecliteEnginePlugin&) = delete;
  RecliteEnginePlugin& operator=(const RecliteEnginePlugin&) = delete;

  // EngineHostApi
  ErrorOr<EngineCapabilities> GetCapabilities() override;
  ErrorOr<DiskSpace> GetDiskSpace(const std::string& path) override;
};

}  // namespace reclite_engine

#endif  // FLUTTER_PLUGIN_RECLITE_ENGINE_PLUGIN_H_
