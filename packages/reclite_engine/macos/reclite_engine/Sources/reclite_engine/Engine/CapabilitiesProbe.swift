import CoreMedia
import Foundation
import VideoToolbox

/// Detects what this Mac can do. Cheap; safe to call on the platform thread.
enum CapabilitiesProbe {
  static let engineVersion = "0.1.0"

  /// ScreenCaptureKit system-audio capture starts at macOS 13.
  static let minimumOs = OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)

  static func current() -> EngineCapabilities {
    let info = ProcessInfo.processInfo
    let v = info.operatingSystemVersion
    let encoders = hardwareEncoders()

    return EngineCapabilities(
      platform: .macos,
      osVersion: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
      minimumOsVersion: "\(minimumOs.majorVersion).\(minimumOs.minorVersion)",
      meetsMinimumOs: info.isOperatingSystemAtLeast(minimumOs),
      supportsSystemAudio: info.isOperatingSystemAtLeast(minimumOs),
      // SCStreamConfiguration.captureMicrophone is macOS 15+.
      supportsMicrophoneViaScreenCapture: info.isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)),
      hasHardwareH264Encoder: encoders.contains(kCMVideoCodecType_H264),
      hasHardwareHevcEncoder: encoders.contains(kCMVideoCodecType_HEVC),
      engineVersion: engineVersion
    )
  }

  /// Codec types that have at least one hardware-accelerated VideoToolbox encoder.
  private static func hardwareEncoders() -> Set<CMVideoCodecType> {
    var listRef: CFArray?
    guard VTCopyVideoEncoderList(nil, &listRef) == noErr,
      let list = listRef as? [[String: Any]]
    else { return [] }

    var result = Set<CMVideoCodecType>()
    for encoder in list {
      let isHardware =
        (encoder[kVTVideoEncoderList_IsHardwareAccelerated as String] as? NSNumber)?.boolValue
        ?? false
      guard isHardware,
        let codec = encoder[kVTVideoEncoderList_CodecType as String] as? NSNumber
      else { continue }
      result.insert(CMVideoCodecType(codec.uint32Value))
    }
    return result
  }
}
