import SwiftUI
import AppKit

@MainActor
final class FloatingWindowManager: NSObject, ObservableObject {
    static let shared = FloatingWindowManager()

    private enum ShowReason {
        case forced
        case preference
    }

    private let panelSize = CGSize(
        width: MiniTimerView.defaultDiameter,
        height: MiniTimerView.defaultDiameter
    )
    private let positionKey = "FloatingTimerPanelOrigin"
    private let floatingPanelAlpha: CGFloat = 0.9

    private weak var timer: TimerViewModel?
    private weak var mainWindow: NSWindow?
    private var mainWindowDelegate: WindowEventHandler?
    private var floatingPanel: NSPanel?
    private var hostingController: NSHostingController<MiniTimerContainerView>?
    private var panelMoveObserver: NSObjectProtocol?
    private var panelScreenObserver: NSObjectProtocol?
    private var isRequestingMainWindow = false
    private var hasConfiguredMainWindow = false

    private var isPreferenceEnabled = false
    private var isAppActive = true
    private var isForcedVisible = false

    private override init() {
        super.init()

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configure(mainWindow: NSWindow?, timer: TimerViewModel) {
        self.timer = timer
        guard let window = mainWindow else { return }
        guard self.mainWindow !== window else { return }

        self.mainWindow = window
        hasConfiguredMainWindow = true
        isRequestingMainWindow = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.isOpaque = false
        window.backgroundColor = .clear

        let delegate = WindowEventHandler()
        delegate.closeRequested = { [weak self] in
            self?.handleMainWindowDismissal()
        }
        delegate.miniaturizeRequested = { [weak self] in
            self?.handleMainWindowDismissal()
        }
        delegate.becameKey = { [weak self] in
            self?.handleMainWindowActivated()
        }
        window.delegate = delegate
        mainWindowDelegate = delegate

        if window.isVisible {
            handleMainWindowActivated()
        }
    }

    func setFloatingEnabled(_ enabled: Bool) {
        isPreferenceEnabled = enabled
        if enabled {
            if !isAppActive {
                showFloatingPanel(reason: .preference)
            }
        } else if !isForcedVisible {
            hideFloatingPanel()
        }
    }

    func restoreMainWindow() {
        isForcedVisible = false
        hideFloatingPanel()

        if showExistingMainWindow() { return }
        guard hasConfiguredMainWindow else { return }

        requestMainWindowCreationIfNeeded()
    }

    private func handleMainWindowDismissal() {
        guard mainWindow?.isVisible == true else {
            showFloatingPanel(reason: .forced)
            return
        }
        mainWindow?.orderOut(nil)
        showFloatingPanel(reason: .forced)
    }

    private func handleMainWindowActivated() {
        isForcedVisible = false
        hideFloatingPanel()
    }

    private func showFloatingPanel(reason: ShowReason) {
        guard reason == .forced || isPreferenceEnabled else { return }
        guard let timer else { return }

        if floatingPanel == nil {
            createFloatingPanel(timer: timer)
        } else {
            hostingController?.rootView = MiniTimerContainerView(timer: timer)
        }

        isForcedVisible = reason == .forced

        guard let panel = floatingPanel else { return }
        panel.alphaValue = floatingPanelAlpha
        panel.orderFrontRegardless()
        constrainAndPersistPanelPosition()
    }

    private func hideFloatingPanel() {
        stopObservingPanelMovement()
        floatingPanel?.orderOut(nil)
        floatingPanel = nil
        hostingController = nil
    }

    private func createFloatingPanel(timer: TimerViewModel) {
        let rect = panelFrame()
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.worksWhenModal = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.tabbingMode = .disallowed
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let hosting = NSHostingController(rootView: MiniTimerContainerView(timer: timer))
        hosting.view.frame = CGRect(origin: .zero, size: panelSize)
        hosting.view.wantsLayer = true
        hosting.view.layer?.masksToBounds = false
        panel.contentViewController = hosting

        floatingPanel = panel
        hostingController = hosting

        startObservingPanelMovement(panel)
    }

    private func panelFrame() -> NSRect {
        let defaultScreen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let saved = savedOrigin()

        let origin: CGPoint
        if let saved, screen(containing: saved) != nil {
            origin = saved
        } else {
            origin = CGPoint(
                x: defaultScreen.maxX - panelSize.width - 40,
                y: defaultScreen.minY + 80
            )
        }

        return NSRect(origin: origin, size: NSSize(width: panelSize.width, height: panelSize.height))
    }

    private func savedOrigin() -> CGPoint? {
        guard
            let stored = UserDefaults.standard.dictionary(forKey: positionKey) as? [String: Double],
            let x = stored["x"],
            let y = stored["y"]
        else { return nil }

        return CGPoint(x: x, y: y)
    }

    private func saveOrigin(_ origin: CGPoint) {
        let dict: [String: Double] = ["x": origin.x, "y": origin.y]
        UserDefaults.standard.set(dict, forKey: positionKey)
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.visibleFrame.contains(point)
        }
    }

    private func constrainAndPersistPanelPosition() {
        guard let panel = floatingPanel else { return }
        guard let screen = panel.screen ?? NSScreen.main else { return }

        var frame = panel.frame
        let visible = screen.visibleFrame

        frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.width))
        frame.origin.y = max(visible.minY, min(frame.origin.y, visible.maxY - frame.height))

        panel.setFrame(frame, display: false)
        saveOrigin(frame.origin)
    }

    private func startObservingPanelMovement(_ panel: NSPanel) {
        stopObservingPanelMovement()

        panelMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.constrainAndPersistPanelPosition()
            }
        }

        panelScreenObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.constrainAndPersistPanelPosition()
            }
        }
    }

    private func stopObservingPanelMovement() {
        if let moveObserver = panelMoveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
            panelMoveObserver = nil
        }
        if let screenObserver = panelScreenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            panelScreenObserver = nil
        }
    }

    @objc private func appDidBecomeActive(_ notification: Notification) {
        isAppActive = true
        if !isForcedVisible {
            hideFloatingPanel()
            restoreMainWindowIfNeeded()
        }
    }

    @objc private func appDidResignActive(_ notification: Notification) {
        isAppActive = false
        collapseMainWindowForBackground()
        showFloatingPanel(reason: .preference)
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        constrainAndPersistPanelPosition()
    }

    private func restoreMainWindowIfNeeded() {
        guard floatingPanel == nil else { return }
        guard hasConfiguredMainWindow else { return }
        if !showExistingMainWindow() {
            requestMainWindowCreationIfNeeded()
        }
    }

    private func collapseMainWindowForBackground() {
        guard isPreferenceEnabled else { return }
        guard let window = mainWindow ?? findMainWindowInApplication() else { return }
        guard window.isVisible else { return }
        window.orderOut(nil)
    }
}

extension FloatingWindowManager {
    @discardableResult
    private func showExistingMainWindow() -> Bool {
        guard let window = mainWindow ?? findMainWindowInApplication() else { return false }

        mainWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private func requestMainWindowCreationIfNeeded() {
        guard !isRequestingMainWindow else { return }

        isRequestingMainWindow = true
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .flowOpenMainWindow, object: nil)
    }

    private func findMainWindowInApplication() -> NSWindow? {
        if let identified = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            return identified
        }

        return NSApp.windows.first { window in
            guard window !== floatingPanel else { return false }
            guard !(window is NSPanel) else { return false }
            return window.canBecomeMain
        }
    }
}

private struct MiniTimerContainerView: View {
    @ObservedObject var timer: TimerViewModel

    var body: some View {
        MiniTimerView()
            .environmentObject(timer)
            .frame(
                width: MiniTimerView.defaultDiameter,
                height: MiniTimerView.defaultDiameter
            )
            .background(Color.clear)
    }
}
