import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    // Paint the app's own background until Flutter draws its first frame, so
    // launch shows a calm empty window instead of a black flash. Must match
    // scaffoldBackgroundColor in lib/app/theme/app_theme.dart.
    let launchBackground = NSColor(name: "RecLiteLaunchBackground") { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0x12 / 255, green: 0x13 / 255, blue: 0x18 / 255, alpha: 1)
        : NSColor(srgbRed: 0xFA / 255, green: 0xF8 / 255, blue: 0xFF / 255, alpha: 1)
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
