#include "include/reclite_engine/reclite_engine_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "reclite_engine_plugin.h"

void RecliteEnginePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  reclite_engine::RecliteEnginePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
