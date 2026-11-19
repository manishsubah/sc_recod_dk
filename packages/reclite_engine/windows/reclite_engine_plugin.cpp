#include "reclite_engine_plugin.h"

#include <memory>

#include "engine/capabilities_probe.h"
#include "storage/disk_space_probe.h"

namespace reclite_engine {

void RecliteEnginePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<RecliteEnginePlugin>();
  EngineHostApi::SetUp(registrar->messenger(), plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

RecliteEnginePlugin::RecliteEnginePlugin() = default;

RecliteEnginePlugin::~RecliteEnginePlugin() = default;

ErrorOr<EngineCapabilities> RecliteEnginePlugin::GetCapabilities() {
  return QueryCapabilities();
}

ErrorOr<DiskSpace> RecliteEnginePlugin::GetDiskSpace(const std::string& path) {
  return QueryDiskSpace(path);
}

}  // namespace reclite_engine
