import SwiftUI

@main
struct LearningTimerApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var timerVM = TimerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
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
