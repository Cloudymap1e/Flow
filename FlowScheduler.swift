import Foundation
import Combine

enum ScheduledRunOutcome: Equatable {
    case succeeded
    case failed(reason: String)
}

struct ScheduledTimerEntry: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case pending
        case running
        case succeeded
        case failed
    }

    var id: UUID = UUID()
    var title: String
    var startDate: Date
    var durationSeconds: Int
    var status: Status = .pending
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var note: String? = nil
    var actualStart: Date?
    var actualEnd: Date?

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationSeconds))
    }
}

@MainActor
final class FlowScheduler: ObservableObject {
    @Published private(set) var entries: [ScheduledTimerEntry] = []
    @Published private(set) var activeEntryID: UUID?

    weak var timer: TimerViewModel?

    private var monitorCancellable: AnyCancellable?
    private let persistenceDisabled: Bool
    private var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()

    init(
        timer: TimerViewModel? = nil,
        entries: [ScheduledTimerEntry]? = nil,
        shouldMonitor: Bool = true,
        persistenceDisabled: Bool = false
    ) {
        self.timer = timer
        self.persistenceDisabled = persistenceDisabled
        if let entries {
            self.entries = entries
        } else {
            self.entries = FlowSchedulerStorage.load()
        }
        recoverRunningEntriesIfNeeded()
        if shouldMonitor {
            startMonitoring()
        }
    }

    deinit {
        monitorCancellable?.cancel()
    }

    func attach(timer: TimerViewModel) {
        self.timer = timer
    }

    func schedule(startDate: Date, durationMinutes: Int, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedTitle = trimmedTitle.isEmpty ? "Flow" : trimmedTitle
        let clampedDuration = max(1, durationMinutes) * 60
        let entry = ScheduledTimerEntry(
            title: sanitizedTitle,
            startDate: startDate,
            durationSeconds: clampedDuration,
            status: .pending
        )
        entries.append(entry)
        sortEntries()
        persist()
    }

    func delete(_ entry: ScheduledTimerEntry) {
        entries.removeAll { $0.id == entry.id }
        if activeEntryID == entry.id {
            activeEntryID = nil
        }
        persist()
    }

    func entries(on day: Date) -> [ScheduledTimerEntry] {
        entries
            .filter { calendar.isDate($0.startDate, inSameDayAs: day) }
            .sorted { $0.startDate < $1.startDate }
    }

    func scheduledCount(on day: Date) -> Int {
        entries(on: day).count
    }

    private func startMonitoring() {
        monitorCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                Task { @MainActor in
                    self?.tick(now: now)
                }
            }
    }

    func tick(now: Date) {
        failExpiredPendingEntries(at: now)
        guard let timer else {
            failDueEntriesWithoutTimer(now: now)
            return
        }
        if timer.isRunning, activeEntryID == nil, let next = nextRunnableEntry(at: now) {
            timer.stopAndSavePartial()
            start(entry: next, timer: timer, now: now)
            return
        }
        failConflictingPendingEntries(at: now, shouldFail: timer.isRunning && activeEntryID != nil)
        guard activeEntryID == nil else { return }
        guard !timer.isRunning else { return }
        guard let next = nextRunnableEntry(at: now) else { return }
        start(entry: next, timer: timer, now: now)
    }

    private func nextRunnableEntry(at date: Date) -> ScheduledTimerEntry? {
        entries
            .filter { $0.status == .pending && $0.startDate <= date && !$0.isExpired(relativeTo: date) }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    private func start(entry: ScheduledTimerEntry, timer: TimerViewModel, now: Date) {
        activeEntryID = entry.id
        updateEntry(id: entry.id) { mutable in
            mutable.status = .running
            mutable.actualStart = now
            mutable.updatedAt = now
        }
        timer.startScheduledRun(
            id: entry.id,
            title: entry.title,
            duration: entry.durationSeconds,
            startDate: entry.startDate
        ) { [weak self] id, outcome in
            Task { @MainActor in
                self?.handleScheduledCompletion(id: id, outcome: outcome)
            }
        }
        persist()
    }

    private func handleScheduledCompletion(id: UUID, outcome: ScheduledRunOutcome) {
        let note: String?
        let status: ScheduledTimerEntry.Status
        switch outcome {
        case .succeeded:
            status = .succeeded
            note = nil
        case .failed(let reason):
            status = .failed
            note = reason
        }
        mark(entryID: id, as: status, note: note)
        activeEntryID = nil
    }

    private func failConflictingPendingEntries(at date: Date, shouldFail: Bool) {
        guard shouldFail else { return }
        let conflicts = entries.filter { $0.status == .pending && $0.startDate <= date }
        for entry in conflicts {
            mark(entryID: entry.id, as: .failed, note: "Conflicted with a running timer")
        }
    }

    private func failDueEntriesWithoutTimer(now: Date) {
        let due = entries.filter { $0.status == .pending && $0.startDate <= now }
        for entry in due {
            mark(entryID: entry.id, as: .failed, note: "Timer unavailable")
        }
    }

    private func failExpiredPendingEntries(at date: Date) {
        let expired = entries.filter { $0.status == .pending && $0.isExpired(relativeTo: date) }
        for entry in expired {
            mark(entryID: entry.id, as: .failed, note: "Missed scheduled window")
        }
    }

    private func recoverRunningEntriesIfNeeded() {
        let running = entries.filter { $0.status == .running }
        guard !running.isEmpty else { return }
        for entry in running {
            mark(entryID: entry.id, as: .failed, note: "Restarted while running")
        }
    }

    private func mark(entryID: UUID, as status: ScheduledTimerEntry.Status, note: String?) {
        updateEntry(id: entryID) { mutable in
            mutable.status = status
            mutable.note = note
            mutable.actualEnd = Date()
            mutable.updatedAt = Date()
        }
        persist()
    }

    private func updateEntry(id: UUID, mutate: (inout ScheduledTimerEntry) -> Void) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        var copy = entries[idx]
        mutate(&copy)
        entries[idx] = copy
    }

    private func sortEntries() {
        entries.sort { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func persist() {
        guard !persistenceDisabled else { return }
        FlowSchedulerStorage.save(entries: entries)
    }
}

private extension ScheduledTimerEntry {
    func isExpired(relativeTo date: Date) -> Bool {
        endDate <= date
    }
}

private enum FlowSchedulerStorage {
    private static let fileManager = FileManager.default

    private static var storageURL: URL {
        let support = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        let bundleID = Bundle.main.bundleIdentifier ?? "LearningTimer"
        let directory = support.appendingPathComponent(bundleID, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("ScheduledTimers.json")
    }

    static func load() -> [ScheduledTimerEntry] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        guard let decoded = try? JSONDecoder().decode([ScheduledTimerEntry].self, from: data) else { return [] }
        return decoded
    }

    static func save(entries: [ScheduledTimerEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
