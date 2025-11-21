#if os(macOS)
import AppKit

@MainActor
final class WindowEventHandler: NSObject, NSWindowDelegate {
    var closeRequested: (() -> Void)?
    var miniaturizeRequested: (() -> Void)?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        closeRequested?()
        return false
    }
}

extension WindowEventHandler {
    @objc func windowShouldMiniaturize(_ sender: NSWindow) -> Bool {
        miniaturizeRequested?()
        return false
    }
}
#endif
