import SwiftUI

struct CalendarTabView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var scheduler: FlowScheduler
    @EnvironmentObject private var timer: TimerViewModel

    @State private var selectedDate: Date = Date()
    @State private var showingScheduler: Bool = false
    @State private var scheduledStart: Date = Date()
    @State private var durationMinutes: Int = 25
    @State private var titleDraft: String = ""
    @State private var initialized: Bool = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                CalendarHeatmapView(
                    sessions: store.allSessions(),
                    selectedDate: selectedDate,
                    scheduledCountProvider: { scheduler.scheduledCount(on: $0) },
                    onSelectDate: handleDateSelection
                )

                scheduleList
            }
            .padding(.vertical, 20)
        }
        .sheet(isPresented: $showingScheduler) {
            schedulerSheet
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            scheduledStart = defaultStartTime(for: selectedDate)
            durationMinutes = max(1, timer.flowDuration / 60)
            titleDraft = timer.displayTitle
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Plan focus blocks and let Flow start them automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                handleDateSelection(selectedDate)
            } label: {
                Label("New Slot", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
    }

    private var scheduleList: some View {
        let entries = scheduler.entries(on: selectedDate)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(listTitle)
                    .font(.headline)
                Spacer()
                if !entries.isEmpty {
                    Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if entries.isEmpty {
                emptyScheduleState
            } else {
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        scheduleRow(for: entry)
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 20)
    }

    private var emptyScheduleState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No timers for this day.")
                .font(.subheadline.weight(.semibold))
            Text("Click a date on the calendar to add a focused session.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func scheduleRow(for entry: ScheduledTimerEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text("\(timeRangeText(for: entry)) • \(entry.durationSeconds / 60) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = entry.note, entry.status == .failed {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 12)
            statusBadge(for: entry)
            Button(role: .destructive) {
                scheduler.delete(entry)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private func statusBadge(for entry: ScheduledTimerEntry) -> some View {
        let info = statusInfo(for: entry)
        return Label(info.text, systemImage: info.icon)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(info.color.opacity(0.15), in: Capsule())
            .foregroundStyle(info.color)
    }

    private var schedulerSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Schedule Timer")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { showingScheduler = false }
                    .buttonStyle(.borderless)
            }

            Text(dateLabel(for: selectedDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Flow title", text: $titleDraft)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Start time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker(
                    "Start",
                    selection: $scheduledStart,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration (minutes)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Stepper(
                        value: $durationMinutes,
                        in: 1...240,
                        step: 5
                    ) {
                        Text("\(durationMinutes) min")
                            .font(.headline)
                    }
                    Spacer()
                }
            }

            Button {
                scheduleTimer()
            } label: {
                HStack {
                    Spacer()
                    Text("Schedule")
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 360)
    }

    private func handleDateSelection(_ date: Date) {
        selectedDate = date
        scheduledStart = defaultStartTime(for: date)
        if titleDraft.isEmpty {
            titleDraft = timer.displayTitle
        }
        showingScheduler = true
    }

    private func scheduleTimer() {
        let composedStart = composedStartDate()
        let start = max(composedStart, Date())
        scheduler.schedule(
            startDate: start,
            durationMinutes: durationMinutes,
            title: titleDraft
        )
        showingScheduler = false
    }

    private func composedStartDate() -> Date {
        let comps = calendar.dateComponents([.hour, .minute], from: scheduledStart)
        return calendar.date(
            bySettingHour: comps.hour ?? 9,
            minute: comps.minute ?? 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate
    }

    private func defaultStartTime(for date: Date) -> Date {
        let now = Date()
        if calendar.isDate(date, inSameDayAs: now) {
            let future = now.addingTimeInterval(15 * 60)
            return suggestedStartTime(for: future, on: date)
        }
        return suggestedStartTime(for: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date, on: date)
    }

    private func suggestedStartTime(for reference: Date, on day: Date? = nil) -> Date {
        let targetDay = day ?? reference
        let comps = calendar.dateComponents([.hour, .minute], from: reference)
        return calendar.date(
            bySettingHour: comps.hour ?? 9,
            minute: comps.minute ?? 0,
            second: 0,
            of: targetDay
        ) ?? targetDay
    }

    private var listTitle: String {
        dateLabel(for: selectedDate)
    }

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func timeRangeText(for entry: ScheduledTimerEntry) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: entry.startDate, to: entry.endDate)
    }

    private func statusInfo(for entry: ScheduledTimerEntry) -> (text: String, color: Color, icon: String) {
        switch entry.status {
        case .pending:
            return ("Scheduled", .accentColor, "clock")
        case .running:
            return ("Running", .blue, "play.fill")
        case .succeeded:
            return ("Completed", .green, "checkmark.circle.fill")
        case .failed:
            return ("Failed", .red, "xmark.circle.fill")
        }
    }
}
