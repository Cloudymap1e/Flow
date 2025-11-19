import Foundation
import Combine

/// Handles local persistence (+ JSON import/export) and exposes `sessions` to the UI.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published var lastErrorMessage: String? = nil

    private var autosaveCancellable: AnyCancellable?

    // File location: ~/Library/Application Support/<bundle-id>/sessions.json
    private var fileURL: URL {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "LearningTimer"
        let dir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("sessions.json")
    }

    init() {
        loadFromDisk()
        // Auto-save any time `sessions` changes.
        autosaveCancellable = $sessions
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveToDisk() }
    }

    // MARK: Load / Save
    func loadFromDisk() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let root = try decoder.decode(Root.self, from: data)
            sessions = root.sessions
        } catch {
            // First launch or corrupted file: start clean & record error.
            if (error as NSError).code != NSFileReadNoSuchFileError {
                lastErrorMessage = "Data file unreadable or corrupted. Starting with empty data. (\(error.localizedDescription))"
                print("SessionStore load error:", error)
            }
            sessions = []
            saveToDisk() // Ensure file exists for next run.
        }
    }

    func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Root(version: 1, sessions: sessions))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            lastErrorMessage = "Failed to save data: \(error.localizedDescription)"
            print("SessionStore save error:", error)
        }
    }

    // MARK: Mutations
    func add(_ session: Session) {
        sessions.append(session)
    }

    func replace(id: UUID, with session: Session) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx] = session
        }
    }

    func delete(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
    }

    func allSessions() -> [Session] { sessions.sorted { ($0.startTimestamp ?? .distantPast) < ($1.startTimestamp ?? .distantPast) } }

    // MARK: Import JSON (append/merge by id)
    /// Opens a file-chooser, decodes JSON, validates, and merges.
    func importFromJSON(url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let incoming = try decoder.decode(Root.self, from: data)

        var newOnes = 0
        var skipped = 0

        var existingIDs = Set(sessions.map { $0.id })
        for s in incoming.sessions {
            if existingIDs.contains(s.id) {
                skipped += 1
                continue
            }
            // Basic validation
            guard s.durationSeconds >= 0, s.actualSeconds >= 0 else { continue }
            sessions.append(s)
            existingIDs.insert(s.id)
            newOnes += 1
        }

        lastErrorMessage = "Imported \(newOnes) sessions (\(skipped) duplicated by id)."
    }

    // MARK: Import CSV (columns: Session,Started,Completed)
    func importFromCSV(url: URL) throws {
        let raw = try String(contentsOf: url, encoding: .utf8)
        let lines = raw.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else {
            lastErrorMessage = "CSV appears empty."
            return
        }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var imported = 0
        var skipped = 0

        // Avoid duplicates by matching on title + start timestamp.
        var existingKeys = Set(sessions.compactMap { session -> String? in
            guard let start = session.startTimestamp else { return nil }
            return "\(session.title.lowercased())|\(start.timeIntervalSince1970)"
        })

        for (idx, lineSlice) in lines.enumerated() where idx > 0 {
            let cols = parseCSVLine(String(lineSlice))
            guard cols.count >= 3 else { skipped += 1; continue }

            let title = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let start = df.date(from: cols[1])
            let end = df.date(from: cols[2])
            guard let startDate = start, let endDate = end else { skipped += 1; continue }

            let duration = max(0, Int(endDate.timeIntervalSince(startDate)))
            let key = "\(title.lowercased())|\(startDate.timeIntervalSince1970)"
            if existingKeys.contains(key) {
                skipped += 1
                continue
            }

            let session = Session(
                title: title.isEmpty ? "Session" : title,
                kind: .custom,
                durationSeconds: duration,
                actualSeconds: duration,
                startTimestamp: startDate,
                endTimestamp: endDate)

            sessions.append(session)
            existingKeys.insert(key)
            imported += 1
        }

        lastErrorMessage = "Imported \(imported) sessions from CSV (\(skipped) skipped)."
    }

    // MARK: Export (optional helper)
    func exportJSON(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Root(version: 1, sessions: sessions))
        try data.write(to: url, options: .atomic)
    }

    // Root wrapper used on disk
    private struct Root: Codable {
        let version: Int
        let sessions: [Session]
    }
}

// MARK: - Stats helpers

extension Collection where Element == Session {
    /// Sums actual seconds.
    func totalSeconds() -> Int {
        self.reduce(0) { $0 + $1.actualSeconds }
    }
}

// MARK: - Lightweight CSV helper
private func parseCSVLine(_ line: String) -> [String] {
    var parts: [String] = []
    var current = ""
    var inQuotes = false
    let chars = Array(line)
    var idx = 0

    while idx < chars.count {
        let ch = chars[idx]
        if ch == "\"" {
            if inQuotes && idx + 1 < chars.count && chars[idx + 1] == "\"" {
                current.append("\"")
                idx += 1
            } else {
                inQuotes.toggle()
            }
        } else if ch == "," && !inQuotes {
            parts.append(current)
            current = ""
        } else {
            current.append(ch)
        }
        idx += 1
    }
    parts.append(current)
    return parts
}
