import Cocoa
import FlutterMacOS
import macos_window_utils

private let kInitialWindowFrameAppliedKey = "DriftDbInspector.initialWindowFrameApplied"

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let windowFrame = self.frame
    let macOSWindowUtilsViewController = MacOSWindowUtilsViewController()
    self.contentViewController = macOSWindowUtilsViewController
    self.setFrame(windowFrame, display: true)
    MainFlutterWindowManipulator.start(mainFlutterWindow: self)
    RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)
    super.awakeFromNib()

    // Do not attach an empty NSToolbar with .unified here: it reserves a second
    // chrome row and roughly doubles the title-bar height. Traffic-light
    // hit-testing is handled via Flutter (double-tap strip) where needed; see
    // lib/widgets/macos_title_bar_zoom_strip.dart.

    if #available(macOS 11.0, *) {
      titlebarSeparatorStyle = .none
    }

    applyInitialWindowFrameIfNeeded()
  }

  /// First launch only: 90% of visible screen, centered (ignores XIB 800×600).
  private func applyInitialWindowFrameIfNeeded() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: kInitialWindowFrameAppliedKey) {
      return
    }
    defaults.set(true, forKey: kInitialWindowFrameAppliedKey)

    guard let screen = self.screen ?? NSScreen.main else { return }
    let vf = screen.visibleFrame
    let w = floor(vf.width * 0.9)
    let h = floor(vf.height * 0.9)
    let x = vf.origin.x + (vf.width - w) / 2
    let y = vf.origin.y + (vf.height - h) / 2
    setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: false)
  }
}
