#if os(macOS)
import AppKit
import Foundation
import UserNotifications

final class AlertManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertManager()
    private let center: UNUserNotificationCenter?
    private var sound: NSSound?
    private var customSoundURL: URL?

    private override init() {
        if AlertManager.isRunningInsideAppBundle {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
        super.init()
        center?.delegate = self
        _ = reloadSound()
    }

    func requestAuthorization() {
        guard let center else { return }
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
        volume: Double,
        shouldLoop: Bool
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

        if let center {
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
        }
        playSound(volume: volume, shouldLoop: shouldLoop)
    }

    private func playSound(volume: Double, shouldLoop: Bool) {
        let clamped = max(0, min(1, volume))
        guard clamped > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.sound == nil {
                _ = self.reloadSound()
            }
            guard let sound = self.sound else { return }
            sound.stop()
            sound.currentTime = 0
            sound.volume = Float(clamped)
            sound.loops = shouldLoop
            sound.play()
        }
    }

    func stopSound() {
        DispatchQueue.main.async { [weak self] in
            self?.sound?.stop()
        }
    }

    @discardableResult
    func setCustomSound(url: URL?) -> Bool {
        customSoundURL = url
        return reloadSound(forceCustom: url != nil)
    }

    @discardableResult
    private func reloadSound(forceCustom: Bool = false) -> Bool {
        sound?.stop()

        if forceCustom, let customSoundURL,
           let custom = NSSound(contentsOf: customSoundURL, byReference: true) {
            custom.loops = false
            sound = custom
            return true
        }

        if let fallback = AlertManager.makeDefaultSound() {
            sound = fallback
            return true
        }

        sound = nil
        return false
    }

    private static func makeDefaultSound() -> NSSound? {
        let preferredNames = ["Funk", "Submarine", "Hero", "Glass", "Ping", "Basso"]
        for name in preferredNames {
            if let snd = NSSound(named: NSSound.Name(name)) {
                snd.loops = false
                return snd
            }
            let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
            if let snd = NSSound(contentsOf: url, byReference: true) {
                snd.loops = false
                return snd
            }
        }

        if let bundled = Bundle.main.url(forResource: "FlowComplete", withExtension: "aiff"),
           let snd = NSSound(contentsOf: bundled, byReference: true) {
            snd.loops = false
            return snd
        }

        return nil
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    private static var isRunningInsideAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }
}
#endif
