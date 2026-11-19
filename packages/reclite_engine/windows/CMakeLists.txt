cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "reclite_engine")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

# Must match the value of pluginClass in pubspec.yaml (snake_case).
set(PLUGIN_NAME "reclite_engine_plugin")

list(APPEND PLUGIN_SOURCES
  "reclite_engine_plugin.cpp"
  "reclite_engine_plugin.h"
  "messages.g.cpp"
  "messages.g.h"
  "engine/capabilities_probe.cpp"
  "engine/capabilities_probe.h"
  "storage/disk_space_probe.cpp"
  "storage/disk_space_probe.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/reclite_engine/reclite_engine_plugin_c_api.h"
  "reclite_engine_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

# Media Foundation (encoder discovery now; encoding/muxing in Phase 2).
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  mfplat
  mfuuid
  shell32
)

set(reclite_engine_bundled_libraries "" PARENT_SCOPE)
