import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summarySection

            Divider()

            List {
                Section("Recent Sessions") {
                    if sessions.isEmpty {
                        Text("No sessions yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sessions) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.title)
                                        .font(.headline)
                                    Text(subtitle(for: session))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(session.actualSeconds.clockString)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .listStyle(.automatic)
        }
        .padding(20)
    }

    private var sessions: [Session] {
        store.allSessions().reversed()
    }

    private var summarySection: some View {
        let totalSeconds = store.sessions.totalSeconds()
        let totalCount = store.sessions.count
        return VStack(alignment: .leading, spacing: 6) {
            Text("Statistics")
                .font(.title2.weight(.semibold))
            HStack(spacing: 18) {
                StatChip(title: "Sessions", value: "\(totalCount)")
                StatChip(title: "Time", value: totalSeconds.clockString)
            }
        }
    }

    private func subtitle(for session: Session) -> String {
        var parts: [String] = []
        if let start = session.startTimestamp {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            parts.append(df.string(from: start))
        }
        parts.append(session.kind.rawValue.capitalized)
        return parts.joined(separator: " • ")
    }
}

private struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 10))
    }
}
