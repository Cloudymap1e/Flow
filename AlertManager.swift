#if os(macOS)
import AppKit
import Foundation
import UserNotifications

final class AlertManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertManager()
    private let center = UNUserNotificationCenter.current()
    private lazy var sound: NSSound? = {
        if let hero = NSSound(named: NSSound.Name("Hero")) {
            hero.loops = false
            return hero
        }
        if let bundled = Bundle.main.url(forResource: "FlowComplete", withExtension: "aiff"),
           let snd = NSSound(contentsOf: bundled, byReference: true) {
            snd.loops = false
            return snd
        }
        let systemURL = URL(fileURLWithPath: "/System/Library/Sounds/Basso.aiff")
        let snd = NSSound(contentsOf: systemURL, byReference: true)
        snd?.loops = false
        return snd
    }()

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("Flow notifications error: \(error.localizedDescription)")
            }
        }
    }

    func deliverCompletionAlert(
        finishedMode: TimerViewModel.Mode,
        nextMode: TimerViewModel.Mode,
        flowTitle: String,
        volume: Double
    ) {
        let title: String
        switch finishedMode {
        case .flow:
            title = "\"\(flowTitle)\" complete"
        case .shortBreak, .longBreak:
            title = "\(finishedMode.title) complete"
        }

        let body: String
        switch nextMode {
        case .flow:
            body = "Time to get back to \(flowTitle)."
        case .shortBreak:
            body = "Time for a short break."
        case .longBreak:
            body = "Take a long break to recharge."
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)

        playSound(volume: volume)
    }

    private func playSound(volume: Double) {
        let clamped = max(0, min(1, volume))
        let boosted = min(1, clamped * 3)
        guard boosted > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let sound = self.sound else { return }
            sound.stop()
            sound.volume = Float(boosted)
            sound.play()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
#endif
