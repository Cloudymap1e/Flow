import Foundation

/// MARK: - JSON SCHEMA (documented for import/export)
/// Root object written on disk:
/// {
///   "version": 1,
///   "sessions": [ Session, Session, ... ]
/// }
///
/// Session object:
/// {
///   "id": "UUID-string",
///   "title": "Flow | Short Break | Long Break | Custom",
///   "kind": "flow" | "shortBreak" | "longBreak" | "custom",
///   "durationSeconds": 1500,                      // Intended duration at start (>=0)
///   "actualSeconds": 1491,                        // Actual elapsed; may be < duration if stopped early
///   "startTimestamp": "2025-03-14T10:02:00Z",     // Optional (ISO-8601)
///   "endTimestamp": "2025-03-14T10:27:31Z"        // Optional (ISO-8601)
/// }
///
/// Notes:
/// - We keep both intended `durationSeconds` and `actualSeconds` for clear statistics.
/// - Missing timestamps are allowed (e.g., imported historical data).
/// - Import merges by `id`; if an incoming id already exists it is skipped.

enum SessionKind: String, Codable, CaseIterable {
    case flow, shortBreak, longBreak, custom
}

struct Session: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var kind: SessionKind
    var durationSeconds: Int
    var actualSeconds: Int
    var startTimestamp: Date?
    var endTimestamp: Date?
}

enum StatsGranularity: String, CaseIterable, Identifiable {
    case day = "D", week = "W", month = "M", year = "Y"
    var id: String { rawValue }

    var lowerGranularity: StatsGranularity? {
        switch self {
        case .year: return .month
        case .month: return .week
        case .week: return .day
        case .day: return nil
        }
    }
}

/// Bucket used to drive charts/lists for a given period.
struct StatsBucket: Identifiable {
    let id = UUID()
    let label: String    // e.g., "Mon", "14", "Mar", "2025"
    let start: Date
    let end: Date
    let totalSeconds: Int
    let count: Int
}
