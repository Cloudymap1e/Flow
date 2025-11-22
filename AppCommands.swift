import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AppCommands: Commands {
    @ObservedObject var store: SessionStore
    @ObservedObject var timer: TimerViewModel

    var body: some Commands {
        CommandMenu("Timer") {
            // Start / Pause
            Button(timer.isRunning ? "Pause" : "Start") {
                timer.isRunning ? timer.pause() : timer.start()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Stop & Save Partial") {
                timer.stopAndSavePartial()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Divider()

            // Duration menus similar to your screenshots
            Menu("Flow Duration") {
                durationButton(15) ; durationButton(20) ; durationButton(25, checked: true)
                durationButton(30) ; durationButton(35) ; durationButton(45)
                durationButton(50) ; durationButton(60) ; durationButton(90)
                Button("Custom…") { askForCustomDuration(forFlow: true) }
            }

            Menu("Break Duration") {
                Menu("Short Break") {
                    shortBreakButton(5, checked: true)
                    shortBreakButton(10)
                    Button("Custom…") { askForCustomDuration(shortBreak: true) }
                }
                Menu("Long Break") {
                    longBreakButton(15)
                    longBreakButton(20)
                    longBreakButton(30, checked: true)
                    Button("Custom…") { askForCustomDuration(longBreak: true) }
                }
            }
        }

    }

    // MARK: Helpers
    private func durationButton(_ minutes: Int, checked: Bool = false) -> some View {
        Button("\(minutes) minutes") { timer.applyDurations(flow: minutes * 60) }
    }

    private func shortBreakButton(_ minutes: Int, checked: Bool = false) -> some View {
        Button("\(minutes) minutes") { timer.applyDurations(short: minutes * 60) }
    }

    private func longBreakButton(_ minutes: Int, checked: Bool = false) -> some View {
        Button("\(minutes) minutes") { timer.applyDurations(long: minutes * 60) }
    }

    private func askForCustomDuration(forFlow: Bool = false, shortBreak: Bool = false, longBreak: Bool = false) {
#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Custom Duration (minutes)"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(string: "25")
        tf.frame = NSRect(x: 0, y: 0, width: 200, height: 24)
        alert.accessoryView = tf
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let minutes = Int(tf.stringValue) ?? 25
        if forFlow { timer.applyDurations(flow: minutes * 60) }
        if shortBreak { timer.applyDurations(short: minutes * 60) }
        if longBreak { timer.applyDurations(long: minutes * 60) }
#else
        // Not available on non-macOS platforms.
#endif
    }

}
