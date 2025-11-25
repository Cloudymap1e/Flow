import Foundation

struct CountdownEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var startDate: Date
    var targetDate: Date
    var sortOrder: Int = 0
}

enum CountdownStorage {
    static let eventsKey = "Countdown.eventsJSON"
    static let legacyTargetKey = "Countdown.targetTimestamp"
    static let legacyStartKey = "Countdown.startTimestamp"
    private static let legacySharedDirectoryName = "FlowCountdownShared"

    private static let fileManager = FileManager.default
    private static var hasMigratedLegacyDirectory = false

    private static var storageDirectory: URL {
        let appSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "LearningTimer"
        let directory = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        ensureDirectoryExists(directory)
        return directory
    }

    private static var eventsURL: URL {
        storageDirectory.appendingPathComponent("CountdownEvents.json", isDirectory: false)
    }

    static func loadEvents() -> [CountdownEvent] {
        migrateLegacySharedDirectoryIfNeeded()
        if let data = try? Data(contentsOf: eventsURL),
           let decoded = try? JSONDecoder().decode([CountdownEvent].self, from: data) {
            return decoded
        }
        return []
    }

    static func save(events: [CountdownEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        ensureDirectoryExists(storageDirectory)
        try? data.write(to: eventsURL, options: [.atomic])
    }

    static func migrateLegacyDataIfNeeded() {
        guard loadEvents().isEmpty else { return }
        let defaults = UserDefaults.standard
        if let json = defaults.string(forKey: eventsKey),
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CountdownEvent].self, from: data),
           !decoded.isEmpty {
            save(events: decoded)
            return
        }

        let legacyTargetTimestamp = defaults.double(forKey: legacyTargetKey)
        let legacyStartTimestamp = defaults.double(forKey: legacyStartKey)
        guard legacyTargetTimestamp > 0 else { return }
        let start = legacyStartTimestamp > 0
            ? Date(timeIntervalSince1970: legacyStartTimestamp)
            : Date()
        let target = Date(timeIntervalSince1970: legacyTargetTimestamp)
        let sanitizedTarget = max(target, start.addingTimeInterval(60))
        let event = CountdownEvent(title: "Countdown", startDate: start, targetDate: sanitizedTarget)
        save(events: [event])
    }

    private static func migrateLegacySharedDirectoryIfNeeded() {
        guard !hasMigratedLegacyDirectory else { return }
        hasMigratedLegacyDirectory = true
        let legacyDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(legacySharedDirectoryName)", isDirectory: true)
        let legacyURL = legacyDirectory.appendingPathComponent("CountdownEvents.json", isDirectory: false)
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }
        guard !fileManager.fileExists(atPath: eventsURL.path) else { return }
        ensureDirectoryExists(storageDirectory)
        try? fileManager.copyItem(at: legacyURL, to: eventsURL)
    }

    private static func ensureDirectoryExists(_ url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
