import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    // Paint the app's own background until Flutter draws its first frame, so
    // launch shows a calm empty window instead of a black flash. Must match
    // AppPalette.launchLight / launchDark in lib/app/theme/app_tokens.dart.
    let launchBackground = NSColor(name: "RecLiteLaunchBackground") { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0x20 / 255, green: 0x20 / 255, blue: 0x20 / 255, alpha: 1)
        : NSColor(srgbRed: 0xF3 / 255, green: 0xF3 / 255, blue: 0xF3 / 255, alpha: 1)
    }
    flutterViewController.backgroundColor = launchBackground
    self.backgroundColor = launchBackground

    self.contentViewController = flutterViewController

    // RecLite window: 960x660 on first launch (macOS restores the user's size
    // after that), can't shrink below 760x560.
    self.title = "RecLite"
    self.contentMinSize = NSSize(width: 760, height: 560)
    self.setContentSize(NSSize(width: 960, height: 660))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
