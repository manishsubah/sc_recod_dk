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
  "audio/audio_mixer.cpp"
  "audio/audio_mixer.h"
  "audio/audio_pipeline.cpp"
  "audio/audio_pipeline.h"
  "audio/wasapi_source.cpp"
  "audio/wasapi_source.h"
  "capture/display_catalog.cpp"
  "capture/display_catalog.h"
  "capture/frame_converter.cpp"
  "capture/frame_converter.h"
  "capture/gpu_device.cpp"
  "capture/gpu_device.h"
  "capture/screen_capture.cpp"
  "capture/screen_capture.h"
  "core/clock.h"
  "core/platform_dispatcher.cpp"
  "core/platform_dispatcher.h"
  "core/serial_queue.cpp"
  "core/serial_queue.h"
  "core/strings.cpp"
  "core/strings.h"
  "core/ticks.h"
  "core/win.h"
  "engine/capabilities_probe.cpp"
  "engine/capabilities_probe.h"
  "engine/recording_engine.cpp"
  "engine/recording_engine.h"
  "storage/disk_guard.cpp"
  "storage/disk_guard.h"
  "storage/disk_space_probe.cpp"
  "storage/disk_space_probe.h"
  "storage/session_manifest.cpp"
  "storage/session_manifest.h"
  "storage/session_storage.cpp"
  "storage/session_storage.h"
  "ui/area_windows.cpp"
  "ui/area_windows.h"
  "writer/segment_writer.cpp"
  "writer/segment_writer.h"
  "writer/segmented_recorder.cpp"
  "writer/segmented_recorder.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/reclite_engine/reclite_engine_plugin_c_api.h"
  "reclite_engine_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
# Flutter's standard settings disable STL exceptions; C++/WinRT reports errors with them.
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX UNICODE _UNICODE _HAS_EXCEPTIONS=1)
# /bigobj: C++/WinRT headers. /WX-: warnings stay visible in CI logs but don't block
# the build while the Windows engine is new; turn back on once it has settled.
target_compile_options(${PLUGIN_NAME} PRIVATE /bigobj /WX-)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  d3d11
  dxgi
  mfplat
  mfreadwrite
  mfuuid
  ole32
  shell32
  user32
  gdi32
  windowsapp
)

set(reclite_engine_bundled_libraries "" PARENT_SCOPE)
