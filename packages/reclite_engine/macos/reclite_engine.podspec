#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint reclite_engine.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'reclite_engine'
  s.version          = '0.1.0'
  s.summary          = 'RecLite native recording engine.'
  s.description      = <<-DESC
RecLite native recording engine (ScreenCaptureKit, AVFoundation, VideoToolbox).
                       DESC
  s.homepage         = 'https://github.com/manishsubah'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'RecLite'

  s.source           = { :path => '.' }
  s.source_files = 'reclite_engine/Sources/reclite_engine/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'reclite_engine_privacy' => ['reclite_engine/Sources/reclite_engine/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
  s.frameworks = 'VideoToolbox', 'CoreMedia', 'ScreenCaptureKit', 'AVFoundation'
end
