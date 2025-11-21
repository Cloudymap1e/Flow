import SwiftUI

@main
struct LearningTimerApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var timerVM = TimerViewModel()
    @StateObject private var coordinator = MiniTimerWindowCoordinator.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowContent()
                .environmentObject(store)
                .environmentObject(timerVM)
                .frame(minWidth: 880, minHeight: 580)
        }
        // Reasonable desktop default; still resizable.
        .defaultSize(CGSize(width: 980, height: 640))
        // macOS-style commands: Import JSON, duration presets, start/stop.
        .commands {
            AppCommands(store: store, timer: timerVM)
        }
        
        // Mini Timer Window - always on top floating window
        WindowGroup(id: "miniTimer") {
            MiniTimerWindowContent()
                .environmentObject(store)
                .environmentObject(timerVM)
                .frame(width: 280, height: 80)
                .background(WindowAccessor { window in
                    guard let window = window else { return }
                    
                    window.level = .floating
                    window.styleMask.remove(.resizable)
                    window.styleMask.remove(.miniaturizable)
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.isMovableByWindowBackground = true
                    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
                    window.identifier = NSUserInterfaceItemIdentifier("miniTimer")
                    window.hidesOnDeactivate = false
                })
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 280, height: 80)
    }
}

// Helper view to handle window opening notifications
struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ContentView()
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenMainWindow"))) { _ in
                openWindow(id: "main")
            }
    }
}

// Helper view for mini timer
struct MiniTimerWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        MiniTimerWindowView()
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenMiniTimerWindow"))) { _ in
                openWindow(id: "miniTimer")
            }
    }
}

