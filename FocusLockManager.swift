import Foundation
import AppKit
import Combine

struct BlockedItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var bundleIdentifier: String? // For apps
    var urlString: String?        // For websites (if we could block them, mainly for display now)
    var type: ItemType

    enum ItemType: String, Codable {
        case app
        case website
    }
}

@MainActor
class FocusLockManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var blockedItems: [BlockedItem] = []
    @Published var violationAlert: String? = nil

    private var timer: Timer?

    init() {
        load()
    }

    func startMonitoring() {
        guard isEnabled else { return }
        stopMonitoring()
        
        // Check every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkRunningApps()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkRunningApps() {
        guard isEnabled else { return }

        let runningApps = NSWorkspace.shared.runningApplications
        
        for item in blockedItems where item.type == .app {
            // Match by bundle ID or Name
            if let bundleID = item.bundleIdentifier {
                if runningApps.contains(where: { $0.bundleIdentifier == bundleID }) {
                    triggerViolation(for: item)
                }
            } else {
                if runningApps.contains(where: { $0.localizedName == item.name }) {
                    triggerViolation(for: item)
                }
            }
        }
    }

    private func triggerViolation(for item: BlockedItem) {
        // In a sandboxed app, we can't kill the process easily.
        // We will just alert the user.
        violationAlert = "Focus Violation: You opened \(item.name) while Focus Lock is active!"
        
        // Play a sound
        NSSound.beep()
    }

    // MARK: - Persistence
    private var fileURL: URL {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "LearningTimer"
        let dir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        return dir.appendingPathComponent("focus_lock.json")
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(blockedItems)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save blocked items: \(error)")
        }
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            blockedItems = try JSONDecoder().decode([BlockedItem].self, from: data)
        } catch {
            blockedItems = []
        }
    }

    func addItem(_ item: BlockedItem) {
        blockedItems.append(item)
        save()
    }

    func removeItem(id: UUID) {
        blockedItems.removeAll { $0.id == id }
        save()
    }
}
