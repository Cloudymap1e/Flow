import SwiftUI
import AppKit

// MARK: - Mini Timer Window Coordinator
@MainActor
class MiniTimerWindowCoordinator: ObservableObject {
    static let shared = MiniTimerWindowCoordinator()
    
    private var miniPanel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    @Published var isMiniTimerShowing = false
    var timer: TimerViewModel?
    
    private init() {
        // Listen for window close notifications
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleWindowClose(notification)
            }
        }
    }
    
    private func handleWindowClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Check if main window is closing (not the mini timer)
        let isMiniTimer = miniPanel != nil && window == miniPanel
        
        if !isMiniTimer {
            // Main window is closing, show mini timer immediately
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                self.showMiniTimer()
            }
        } else {
            // Mini timer is closing
            isMiniTimerShowing = false
            miniPanel = nil
            hostingController = nil
        }
    }
    
    func showMiniTimer() {
        guard !isMiniTimerShowing, let timer = timer else { return }
        
        // Create the mini timer panel if it doesn't exist
        if miniPanel == nil {
            createMiniTimerPanel(timer: timer)
        }
        
        // Show the panel
        miniPanel?.orderFrontRegardless()
        miniPanel?.makeKeyAndOrderFront(nil)
        isMiniTimerShowing = true
    }
    
    private func createMiniTimerPanel(timer: TimerViewModel) {
        // Create hosting controller with mini timer view
        let view = AnyView(
            MiniTimerView()
                .environmentObject(timer)
                .frame(width: 280, height: 80)
        )
        let hosting = NSHostingController(rootView: view)
        self.hostingController = hosting
        
        // Create floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.contentViewController = hosting
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        self.miniPanel = panel
    }
    
    func hideMiniTimer() {
        miniPanel?.close()
        miniPanel = nil
        hostingController = nil
        isMiniTimerShowing = false
    }
    
    func restoreMainWindow() {
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Look for existing main window
        for window in NSApp.windows {
            let isMiniTimer = miniPanel != nil && window == miniPanel
            if !isMiniTimer && window.isVisible {
                window.makeKeyAndOrderFront(nil)
                hideMiniTimer()
                return
            }
        }
        
        // If no main window exists, hide mini timer and let user reopen app
        hideMiniTimer()
    }
}

// MARK: - Mini Timer Window Content
struct MiniTimerWindowView: View {
    @EnvironmentObject var timer: TimerViewModel
    
    var body: some View {
        MiniTimerView()
            .environmentObject(timer)
            .onAppear {
                MiniTimerWindowCoordinator.shared.timer = timer
            }
    }
}
