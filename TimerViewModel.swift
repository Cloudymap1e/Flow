import Foundation
import Combine
import SwiftUI

@MainActor
final class TimerViewModel: ObservableObject {
    enum Mode {
        case flow, shortBreak, longBreak
        var title: String {
            switch self {
            case .flow: return "Flow"
            case .shortBreak: return "Short Break"
            case .longBreak: return "Long Break"
            }
        }
    }

    // User-adjustable durations (mirrors your iOS menu).
    @Published var flowDuration: Int = 25 * 60     // seconds
    @Published var shortBreak: Int = 5 * 60
    @Published var longBreak: Int = 30 * 60

    // Cycle: after 4 flows, propose a long break.
    @Published private(set) var completedFlowsInCycle: Int = 0
    @Published private(set) var mode: Mode = .flow
    @AppStorage("floatOnBackground") var floatOnBackground: Bool = false
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var remaining: Int = 25 * 60
    @Published private(set) var sessionTitle: String
    @Published private(set) var isAlarmRinging: Bool = false
#if os(macOS)
    @AppStorage("TimerView.alertSoundPath") private var alertSoundPath: String = ""
#endif

    var displayTitle: String {
        mode == .flow ? sessionTitle : mode.title
    }

    var currentDurationSeconds: Int { intendedSeconds() }
    var hasProgress: Bool { remaining < currentDurationSeconds }
    var currentSessionStartDate: Date? { startTS }
    var elapsedInCurrentSession: Int { max(0, intendedSeconds() - remaining) }

    var progress: Double {
        let total = Double(intendedSeconds())
        guard total > 0 else { return 0 }
        let current = Double(remaining)
        return 1.0 - (current / total)
    }

    private let customTitleKey = "TimerView.sessionTitle"
    private var startTS: Date?
    private var tickCancellable: AnyCancellable?

    // Hook to persist sessions
    weak var store: SessionStore?

    // MARK: Life
    init() {
        let storedTitle = UserDefaults.standard.string(forKey: customTitleKey) ?? "Flow"
        self.sessionTitle = storedTitle
        self.remaining = flowDuration
#if os(macOS)
        if let url = customAlertSoundURL {
            if !AlertManager.shared.setCustomSound(url: url) {
                alertSoundPath = ""
                AlertManager.shared.setCustomSound(url: nil)
            }
        } else {
            AlertManager.shared.setCustomSound(url: nil)
        }
#endif
    }

    func attach(store: SessionStore) { self.store = store }

    // MARK: Controls
    func start() {
        stopAlarmSound()
        guard !isRunning else { return }
        isRunning = true
        if startTS == nil { startTS = Date() }
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        tickCancellable?.cancel()
    }

    func stopAndSavePartial() {
        stopAlarmSound()
        // If we have elapsed > 0, persist as a partial session.
        let elapsed = intendedSeconds() - remaining
        if elapsed > 0 {
            persistSession(actualSeconds: elapsed)
        }
        resetAfterStop()
    }

    func complete() {
        let finishedMode = mode
        let upcomingMode = nextMode(afterCompleting: finishedMode)
        persistSession(actualSeconds: intendedSeconds())
        // Advance cycle logic
        if mode == .flow {
            completedFlowsInCycle += 1
        }
#if os(macOS)
        AlertManager.shared.deliverCompletionAlert(
            finishedMode: finishedMode,
            nextMode: upcomingMode,
            flowTitle: sessionTitle,
            volume: 1,
            shouldLoop: true
        )
#endif
        isAlarmRinging = true
        advanceModeAfterCompletion()
    }

    func resetToFlow() {
        stopAlarmSound()
        mode = .flow
        remaining = flowDuration
        isRunning = false
        tickCancellable?.cancel()
        startTS = nil
    }

    func resetCurrentSession() {
        stopAlarmSound()
        pause()
        startTS = nil
        remaining = intendedSeconds()
    }

    func fastForward() {
        let elapsed = max(0, intendedSeconds() - remaining)
        stopAlarmSound()
        pause()
        persistSession(actualSeconds: elapsed)
        if mode == .flow {
            completedFlowsInCycle += 1
        }
        isAlarmRinging = false
        advanceModeAfterCompletion()
    }

    func renameSession(to rawTitle: String) {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed.isEmpty ? "Flow" : trimmed
        sessionTitle = sanitized
        UserDefaults.standard.set(sanitized, forKey: customTitleKey)
    }

    func stopAlarmSound() {
#if os(macOS)
        AlertManager.shared.stopSound()
#endif
        isAlarmRinging = false
    }

#if os(macOS)
    var hasCustomAlertSound: Bool { customAlertSoundURL != nil }

    var alertSoundDescription: String {
        if let url = customAlertSoundURL {
            return url.lastPathComponent
        }
        return "Funk (Default)"
    }

    @discardableResult
    func applyCustomAlertSound(url: URL) -> Bool {
        if AlertManager.shared.setCustomSound(url: url) {
            alertSoundPath = url.path
            return true
        }
        return false
    }

    func clearCustomAlertSoundSelection() {
        alertSoundPath = ""
        AlertManager.shared.setCustomSound(url: nil)
    }

    private var customAlertSoundURL: URL? {
        guard !alertSoundPath.isEmpty else { return nil }
        return URL(fileURLWithPath: alertSoundPath)
    }
#endif

    // MARK: Internal
    private func tick() {
        guard remaining > 0 else {
            pause()
            complete()
            return
        }
        remaining -= 1
    }

    private func intendedSeconds() -> Int {
        switch mode {
        case .flow: return flowDuration
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }

    private func persistSession(actualSeconds: Int) {
        guard let store = store else { return }
        let now = Date()
        let label = mode == .flow ? sessionTitle : mode.title
        let s = Session(
            title: label,
            kind: mode == .flow ? .flow : (mode == .shortBreak ? .shortBreak : .longBreak),
            durationSeconds: intendedSeconds(),
            actualSeconds: max(0, actualSeconds),
            startTimestamp: startTS,
            endTimestamp: now)
        store.add(s)
    }

    private func resetAfterStop() {
        pause()
        startTS = nil
        remaining = intendedSeconds()
    }

    private func advanceModeAfterCompletion() {
        // Flow -> (short/long) break; Break -> Flow
        if mode == .flow {
            if completedFlowsInCycle > 0 && completedFlowsInCycle % 4 == 0 {
                mode = .longBreak
            } else {
                mode = .shortBreak
            }
        } else {
            mode = .flow
        }
        startTS = nil
        remaining = intendedSeconds()
    }

    private func nextMode(afterCompleting finishedMode: Mode) -> Mode {
        switch finishedMode {
        case .flow:
            let nextCount = completedFlowsInCycle + 1
            if nextCount > 0 && nextCount % 4 == 0 {
                return .longBreak
            } else {
                return .shortBreak
            }
        case .shortBreak, .longBreak:
            return .flow
        }
    }

    // Called when durations change via menu
    func applyDurations(flow: Int? = nil, short: Int? = nil, long: Int? = nil) {
        if let f = flow { flowDuration = f }
        if let s = short { shortBreak = s }
        if let l = long  { longBreak = l }
        if !isRunning {
            remaining = intendedSeconds()
        }
    }
}

// MARK: - Simple time formatting used by the UI
extension Int {
    /// Formats seconds as mm:ss or h:mm:ss when >= 1h.
    var clockString: String {
        let s = self
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}
