import SwiftUI
import AppKit

// MARK: - Mini Timer Window Coordinator
@MainActor
class MiniTimerWindowCoordinator: ObservableObject {
    static let shared = MiniTimerWindowCoordinator()
    
    private var miniWindow: NSWindow?
    @Published var isMiniTimerShowing = false
    
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
        let isMiniTimer = window.identifier?.rawValue == "miniTimer"
        
        if !isMiniTimer {
            // Main window is closing, show mini timer after a delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                self.openMiniTimerWindow()
            }
        } else {
            // Mini timer is closing
            isMiniTimerShowing = false
            miniWindow = nil
        }
    }
    
    func openMiniTimerWindow() {
        guard !isMiniTimerShowing else { return }
        
        // Post notification to open mini timer window
        NotificationCenter.default.post(name: Notification.Name("OpenMiniTimerWindow"), object: nil)
        
        // Mark as showing
        isMiniTimerShowing = true
        
        // Find the window after a delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            self.findMiniWindow()
        }
    }
    
    func hideMiniTimer() {
        miniWindow?.close()
        miniWindow = nil
        isMiniTimerShowing = false
    }
    
    func restoreMainWindow() {
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Look for existing main window
        for window in NSApp.windows {
            let isMiniTimer = window.identifier?.rawValue == "miniTimer"
            if !isMiniTimer && window.isVisible {
                window.makeKeyAndOrderFront(nil)
                hideMiniTimer()
                return
            }
        }
        
        // If no main window, open a new one
        NotificationCenter.default.post(name: Notification.Name("OpenMainWindow"), object: nil)
        
        // Close mini timer
        hideMiniTimer()
    }
    
    private func findMiniWindow() {
        // Find and configure the mini timer window
        for window in NSApp.windows {
            if window.identifier?.rawValue == "miniTimer" {
                miniWindow = window
                // Ensure it doesn't hide when deactivated
                window.hidesOnDeactivate = false
                break
            }
        }
    }
}

// MARK: - Mini Timer Window Content
struct MiniTimerWindowView: View {
    @EnvironmentObject var timer: TimerViewModel
    
    var body: some View {
        MiniTimerView()
            .environmentObject(timer)
    }
}
