#if os(macOS)
import AppKit
import Foundation
import UserNotifications
import AVFoundation

final class AlertManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertManager()
    private let center: UNUserNotificationCenter?
    private var sound: NSSound?
    private var customSoundURL: URL?
    private var audioPlayer: AVAudioPlayer?
    private let customSoundURLKey = "AlertManager.customSoundURL"

    private override init() {
        if AlertManager.isRunningInsideAppBundle {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
        super.init()
        center?.delegate = self
        loadPersistedCustomSound()
        _ = reloadSound(forceCustom: true)
    }

    private func loadPersistedCustomSound() {
        guard let path = UserDefaults.standard.string(forKey: customSoundURLKey) else { return }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: customSoundURLKey)
            return
        }
        customSoundURL = url
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
        let title = completionTitle(finishedMode: finishedMode, flowTitle: flowTitle)
        let body = completionBody(nextMode: nextMode, flowTitle: flowTitle)
        deliverCompletionStyleAlert(title: title, body: body, volume: volume, shouldLoop: shouldLoop)
    }

    func deliverScheduledStartAlert(flowTitle: String, volume: Double, shouldLoop: Bool) {
        let title = "Scheduled focus started"
        let body = "Now focusing on \(flowTitle)."
        deliverCompletionStyleAlert(
            title: title,
            body: body,
            volume: volume,
            shouldLoop: shouldLoop,
            useCustomSound: false
        )
    }

    private func deliverCompletionStyleAlert(
        title: String,
        body: String,
        volume: Double,
        shouldLoop: Bool,
        useCustomSound: Bool = true
    ) {
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
        playSound(volume: volume, shouldLoop: shouldLoop, useCustomSound: useCustomSound)
    }

    private func completionTitle(finishedMode: TimerViewModel.Mode, flowTitle: String) -> String {
        switch finishedMode {
        case .flow:
            return "\"\(flowTitle)\" complete"
        case .shortBreak, .longBreak:
            return "\(finishedMode.title) complete"
        }
    }

    private func completionBody(nextMode: TimerViewModel.Mode, flowTitle: String) -> String {
        switch nextMode {
        case .flow:
            return "Time to get back to \(flowTitle)."
        case .shortBreak:
            return "Time for a short break."
        case .longBreak:
            return "Take a long break to recharge."
        }
    }
    @discardableResult
    private func playSound(volume: Double, shouldLoop: Bool, useCustomSound: Bool = true) -> Bool {
        let clamped = max(0, min(1, volume))
        guard clamped > 0 else { return false }

        let playBlock: () -> Bool = { [weak self] in
            guard let self else { return false }
            if useCustomSound {
                if self.sound == nil && self.audioPlayer == nil {
                    _ = self.reloadSound()
                }
            } else {
                self.audioPlayer?.stop()
                self.audioPlayer = nil
                self.sound = AlertManager.makeDefaultSound()
            }
            self.stopSound()

            var played = false
            if let player = self.audioPlayer {
                player.volume = Float(clamped)
                player.numberOfLoops = shouldLoop ? -1 : 0
                player.currentTime = 0
                played = player.play()
            } else if let sound = self.sound {
                sound.volume = Float(clamped)
                sound.loops = shouldLoop
                played = sound.play()
            }

            if useCustomSound && !played && self.reloadSound() {
                if let player = self.audioPlayer {
                    player.volume = Float(clamped)
                    player.numberOfLoops = shouldLoop ? -1 : 0
                    player.currentTime = 0
                    played = player.play()
                } else if let sound = self.sound {
                    sound.volume = Float(clamped)
                    sound.loops = shouldLoop
                    played = sound.play()
                }
            }

            if !played {
                NSSound.beep()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let self else { return }
                    let stillPlaying = (self.audioPlayer?.isPlaying == true) || (self.sound?.isPlaying == true)
                    if !stillPlaying {
                        NSSound.beep()
                    }
                }
            }
            return played
        }

        if Thread.isMainThread {
            return playBlock()
        } else {
            var played = false
            DispatchQueue.main.sync {
                played = playBlock()
            }
            return played
        }
    }

    func stopSound() {
        let stopAction = { [weak self] in
            self?.audioPlayer?.stop()
            self?.sound?.stop()
        }
        if Thread.isMainThread {
            stopAction()
        } else {
            DispatchQueue.main.async(execute: stopAction)
        }
    }

    func setCustomSound(url: URL?) -> URL? {
        guard let url else {
            clearPersistedCustomSound()
            _ = reloadSound(forceCustom: false)
            return nil
        }

        // Skip sandbox copy: rely on the original file the user picked.
        guard attemptLoadingCustomSound(from: url) else {
            clearPersistedCustomSound()
            _ = reloadSound(forceCustom: false)
            return nil
        }
        UserDefaults.standard.set(url.path, forKey: customSoundURLKey)
        return url
    }

    private func attemptLoadingCustomSound(from url: URL) -> Bool {
        customSoundURL = url
        let loaded = reloadSound(forceCustom: true)
        if !loaded {
            customSoundURL = nil
        }
        return loaded
    }

    @discardableResult
    private func reloadSound(forceCustom: Bool = false) -> Bool {
        sound?.stop()
        audioPlayer?.stop()
        sound = nil
        audioPlayer = nil

        if let url = customSoundURL {
            if loadSound(from: url) {
                return true
            }
            if forceCustom {
                clearPersistedCustomSound()
            }
        }

        if let fallback = AlertManager.makeDefaultSound() {
            sound = fallback
            return true
        }

        sound = nil
        return false
    }

    private func loadSound(from url: URL) -> Bool {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            audioPlayer = player
            sound = nil
            return true
        } catch {
            NSLog("Flow custom sound load failed: \(error.localizedDescription)")
            audioPlayer = nil
        }

        if let custom = NSSound(contentsOf: url, byReference: false) {
            custom.loops = false
            sound = custom
            audioPlayer = nil
            return true
        }

        return false
    }

    private func clearPersistedCustomSound() {
        customSoundURL = nil
        UserDefaults.standard.removeObject(forKey: customSoundURLKey)
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

#if DEBUG
    var debug_currentSoundURL: URL? { customSoundURL }

    @discardableResult
    func debug_reloadSound() -> Bool {
        reloadSound(forceCustom: true)
    }

    @discardableResult
    func debug_playCurrentSoundOnce() -> Bool {
        playSound(volume: 1, shouldLoop: false)
    }
#endif
}
#endif
