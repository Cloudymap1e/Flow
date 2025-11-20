#if os(macOS)
import SwiftUI
import AppKit

final class FloatingWindowManager {
    private var controller: FloatingTimerWindowController?
    private var lastFrame: NSRect?

    func show(for timer: TimerViewModel, expandAction: @escaping () -> Void) {
        if let controller {
            controller.update(timer: timer, expandAction: expandAction)
            controller.reveal()
            return
        }
        let controller = FloatingTimerWindowController(
            timer: timer,
            expandAction: expandAction,
            initialFrame: lastFrame,
            frameChanged: { [weak self] frame in
                self?.lastFrame = frame
            })
        self.controller = controller
        controller.reveal()
    }

    func hide() {
        controller?.close()
        controller = nil
    }
}

private final class FloatingTimerWindowController: NSWindowController, NSWindowDelegate {
    private let panel: FloatingTimerPanel
    private let hostingController: NSHostingController<AnyView>
    private let frameChanged: (NSRect) -> Void

    init(timer: TimerViewModel, expandAction: @escaping () -> Void, initialFrame: NSRect?, frameChanged: @escaping (NSRect) -> Void) {
        let panel = FloatingTimerPanel()
        self.panel = panel
        self.frameChanged = frameChanged
        let view = AnyView(
            MiniTimerView(restoreAction: expandAction)
                .environmentObject(timer)
        )
        let hosting = NSHostingController(rootView: view)
        self.hostingController = hosting
        panel.contentViewController = hosting
        super.init(window: panel)
        panel.delegate = self
        if let initialFrame {
            panel.setFrame(initialFrame, display: false)
        } else {
            positionWindow(panel)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reveal() {
        guard let window = window else { return }
        ensureFrameVisible(window)
        window.alphaValue = 1
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    func update(timer: TimerViewModel, expandAction: @escaping () -> Void) {
        hostingController.rootView = AnyView(
            MiniTimerView(restoreAction: expandAction)
                .environmentObject(timer)
        )
    }

    func windowDidMove(_ notification: Notification) {
        if let window = window {
            frameChanged(window.frame)
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        if let window = window {
            frameChanged(window.frame)
        }
    }

    private func positionWindow(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let size = FloatingTimerPanel.defaultSize
        let margin: CGFloat = 64
        var target = NSRect(
            x: screen.visibleFrame.maxX - size.width - margin,
            y: screen.visibleFrame.minY + margin,
            width: size.width,
            height: size.height)
        target = window.constrainFrameRect(target, to: screen)
        window.setFrame(target, display: false)
        frameChanged(target)
    }

    private func ensureFrameVisible(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let current = window.frame
        if screen.visibleFrame.contains(current) { return }
        positionWindow(window)
    }
}

private final class FloatingTimerPanel: NSPanel {
    static let defaultSize = CGSize(width: 220, height: 220)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
#endif
