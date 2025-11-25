import SwiftUI

@main
struct LearningTimerApp: App {
    @StateObject private var store: SessionStore
    @StateObject private var timerVM: TimerViewModel

    init() {
        let store = SessionStore()
        let timer = TimerViewModel()
        _store = StateObject(wrappedValue: store)
        _timerVM = StateObject(wrappedValue: timer)
#if os(macOS)
        AlertManager.shared.requestAuthorization()
#endif
        CountdownStorage.migrateLegacyDataIfNeeded()
    }

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
    }
}

// Helper view to handle window opening notifications
struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var timer: TimerViewModel
    
    var body: some View {
        ContentView()
            .background(WindowAccessor { window in
                FloatingWindowManager.shared.configure(mainWindow: window, timer: timer)
            })
            .onAppear {
                FloatingWindowManager.shared.setFloatingEnabled(timer.floatOnBackground)
            }
            .onChange(of: timer.floatOnBackground) { _, newValue in
                FloatingWindowManager.shared.setFloatingEnabled(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .flowOpenMainWindow)) { _ in
                openWindow(id: "main")
            }
    }
}
