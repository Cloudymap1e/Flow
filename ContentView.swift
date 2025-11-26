import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timer: TimerViewModel
    @EnvironmentObject private var scheduler: FlowScheduler

    @State private var selectedTab: Int = 0 // 0 = Timer, 1 = Stats, 2 = Calendar, 3 = Countdown
    @State private var showErrorBanner: Bool = false

    var body: some View {
        MainView(selectedTab: $selectedTab)
            .onAppear {
                timer.attach(store: store)
                scheduler.attach(timer: timer)
            }
            .overlay(alignment: .bottom) {
                if let msg = store.lastErrorMessage, !msg.isEmpty {
                    ErrorBanner(text: msg)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { store.lastErrorMessage = nil }
                            }
                        }
                }
            }
    }
}

struct MainView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var timer: TimerViewModel
    @Namespace private var tabSelectionNamespace
    
    var body: some View {
        ZStack {
            // 1. Dynamic Background
            BackgroundView()

            // 2. Main Content
            VStack(spacing: 0) {
                // Custom Tab Bar
                HStack(spacing: 0) {
                    tabButton(title: "Timer", tag: 0)
                    tabButton(title: "Statistics", tag: 1)
                    tabButton(title: "Calendar", tag: 2)
                    tabButton(title: "Countdown", tag: 3)
                }
                .padding(4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 20)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                // Content Area
                Group {
                    switch selectedTab {
                    case 0:
                        TimerView()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    case 1:
                        StatsView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case 2:
                        CalendarTabView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    default:
                        CountdownView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
        }
    }
    
    private func tabButton(title: String, tag: Int) -> some View {
        Button {
            withAnimation { selectedTab = tag }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selectedTab == tag ? .primary : .secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(alignment: .center) {
                    if selectedTab == tag {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                            )
                            .matchedGeometryEffect(id: "tabSelection", in: tabSelectionNamespace)
                            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

private struct ErrorBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.red.opacity(0.9), in: .capsule)
            .padding(.bottom, 12)
    }
}

// MARK: - Background View
struct BackgroundView: View {
    var body: some View {
        Color.white.opacity(0.3)
            .ignoresSafeArea()
    }
}

// Helper for NSVisualEffectView in SwiftUI
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#if os(macOS)
/// Mac-only borderless date picker so it blends with the glassmorphic cards.
struct BorderlessDatePicker: NSViewRepresentable {
    @Binding var date: Date
    var minimumDate: Date?
    var maximumDate: Date?
    var onCommit: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.datePickerStyle = .textFieldAndStepper
        picker.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        picker.drawsBackground = false
        picker.isBordered = false
        picker.isBezeled = false
        picker.focusRingType = .none
        picker.backgroundColor = .clear
        picker.textColor = NSColor.labelColor
        picker.controlSize = .large
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.valueChanged(_:))
        picker.dateValue = date
        picker.minDate = minimumDate
        picker.maxDate = maximumDate

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidEndEditing(_:)),
            name: NSControl.textDidEndEditingNotification,
            object: picker
        )

        return picker
    }

    func updateNSView(_ nsView: NSDatePicker, context: Context) {
        if nsView.dateValue != date { nsView.dateValue = date }
        if nsView.minDate != minimumDate { nsView.minDate = minimumDate }
        if nsView.maxDate != maximumDate { nsView.maxDate = maximumDate }
    }

    static func dismantleNSView(_ nsView: NSDatePicker, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(
            coordinator,
            name: NSControl.textDidEndEditingNotification,
            object: nsView
        )
    }

    final class Coordinator: NSObject {
        private let parent: BorderlessDatePicker

        init(parent: BorderlessDatePicker) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSDatePicker) {
            parent.date = sender.dateValue
        }

        @objc func textDidEndEditing(_ notification: Notification) {
            guard let picker = notification.object as? NSDatePicker else { return }
            parent.date = picker.dateValue
            parent.onCommit?()
        }
    }
}
#endif

// MARK: - Countdown View
struct CountdownView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timer: TimerViewModel
    @State private var displayMode: RemainingDisplayMode = .days
    @State private var events: [CountdownEvent] = []
    @State private var hasLoadedEvents: Bool = false
    @State private var draggingEventID: UUID? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            countdownContent(now: timeline.date)
        }
        .onAppear { loadEventsIfNeeded() }
        .onChange(of: events) { _, _ in
            draggingEventID = nil
            saveEvents()
        }
        .simultaneousGesture(TapGesture().onEnded { dismissEditing() })
    }

    @ViewBuilder
    private func countdownContent(now: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                let ordered = orderedEvents(now: now)
                if ordered.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(ordered) { event in
                            if let binding = binding(for: event) {
                                let completed = isCompleted(event, now: now)
                                let moves = moveAvailability(for: event, ordered: ordered, now: now)
                                HStack(alignment: .top, spacing: 10) {
                                    reorderControls(
                                        eventID: event.id,
                                        isCompleted: completed,
                                        canMoveUp: moves.up,
                                        canMoveDown: moves.down,
                                        now: now
                                    )
                                    countdownCard(for: binding, now: now, isCompleted: completed)
                                        .overlay {
                                            if draggingEventID == event.id {
                                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 3)
                                            }
                                        }
                                }
                                .padding(.horizontal, 2)
                                .onDrag {
                                    guard !completed else {
                                        draggingEventID = nil
                                        return NSItemProvider()
                                    }
                                    draggingEventID = event.id
                                    return NSItemProvider(object: event.id.uuidString as NSString)
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    let ids = items.compactMap(UUID.init)
                                    guard let sourceID = ids.first,
                                          sourceID != event.id,
                                          !completed else { return false }
                                    moveActive(draggedID: sourceID, destinationID: event.id, now: now)
                                    draggingEventID = nil
                                    return true
                                } isTargeted: { hovering in
                                    if !hovering {
                                        draggingEventID = nil
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: draggingEventID)
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack {
            Text("Countdowns")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Spacer()
            Button(action: addEvent) {
                Label("Add", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No countdowns yet")
                .font(.headline)
            Text("Add a target date to start tracking progress and effective focus time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: addEvent) {
                Label("Add Countdown", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func reorderControls(eventID: UUID, isCompleted: Bool, canMoveUp: Bool, canMoveDown: Bool, now: Date) -> some View {
        VStack(spacing: 6) {
            Button {
                shiftActive(id: eventID, offset: -1, now: now)
            } label: {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .disabled(isCompleted || !canMoveUp)
            .opacity(isCompleted || !canMoveUp ? 0.35 : 0.8)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isCompleted ? Color.secondary.opacity(0.35) : Color.secondary)
                .frame(width: 24, height: 24)
                .opacity(isCompleted ? 0.45 : 1)

            Button {
                shiftActive(id: eventID, offset: 1, now: now)
            } label: {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .disabled(isCompleted || !canMoveDown)
            .opacity(isCompleted || !canMoveDown ? 0.35 : 0.8)
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private func countdownCard(for event: Binding<CountdownEvent>, now: Date, isCompleted: Bool) -> some View {
        let current = event.wrappedValue
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                TextField("Countdown title", text: event.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 48)
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
                Button(role: .destructive) { removeEvent(current.id) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 32) {
                dateColumn(
                    title: "Start Date",
                    date: Binding(
                        get: { current.startDate },
                        set: { newValue in updateStart(for: current.id, date: newValue) }
                    ),
                    minimum: nil,
                    maximum: current.targetDate.addingTimeInterval(-60)
                )

                Spacer(minLength: 12)

                dateColumn(
                    title: "Target Date",
                    date: Binding(
                        get: { current.targetDate },
                        set: { newValue in updateTarget(for: current.id, date: newValue) }
                    ),
                    minimum: current.startDate.addingTimeInterval(60),
                    maximum: nil
                )
            }
            .padding(.top, 6)

            Divider().opacity(0.15)

            remainingSection(for: current, now: now)

            progressSection(
                title: "Time Progress",
                value: progress(for: current, now: now),
                colors: [.blue, .purple, .pink]
            )

            progressSection(
                title: "Efficiency",
                value: efficiency(for: current, now: now),
                colors: [.green, .teal, .blue],
                footer: "Focus \(formatHoursMinutes(seconds: focusSeconds(for: current, now: now))) of \(formatHoursMinutes(seconds: Int(effectiveBaseSeconds(for: current, upTo: clampedNow(for: current, now: now))))) (12h/day cap)"
            )
        }
        .padding(24)
        .background(cardBackground(for: current, now: now))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
        .contentShape(Rectangle())
        .onTapGesture { dismissEditing() }
    }

    private func remainingSection(for event: CountdownEvent, now: Date) -> some View {
        let completed = isCompleted(event, now: now)
        return VStack(alignment: .leading, spacing: 6) {
            Text(remainingText(for: event, now: now))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .onTapGesture { cycleDisplayMode() }
                .animation(.easeInOut, value: displayMode)
            Text(completed ? "Tap to view elapsed in different units" : "Tap to toggle units (days → hours → weeks → months → years)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func progressSection(title: String, value: Double, colors: [Color], footer: String? = nil) -> some View {
        let sanitizedValue = max(0, value)
        let clampedValue = min(1, sanitizedValue)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(value.isFinite ? String(format: "%.1f%%", value * 100) : "0.0%")
                    .font(.body.monospacedDigit())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, proxy.size.width * clampedValue))
                }
                .overlay {
                    if sanitizedValue > 1 {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                            .shadow(color: Color.white.opacity(0.3), radius: 6, x: 0, y: 0)
                            .blendMode(.screen)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: value)
            }
            .frame(height: 18)
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cardBackground(for event: CountdownEvent, now: Date) -> some View {
        let colors = isCompleted(event, now: now)
            ? [Color.green.opacity(0.35), Color.blue.opacity(0.25)]
            : [Color.blue.opacity(0.35), Color.purple.opacity(0.3)]
        return RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func orderedEvents(now: Date) -> [CountdownEvent] {
        let normalized = normalizeSortOrders(for: events)
        let active = normalized.filter { !isCompleted($0, now: now) }
        let completed = normalized.filter { isCompleted($0, now: now) }
        return active + completed
    }

    private func isCompleted(_ event: CountdownEvent, now: Date) -> Bool {
        now >= event.targetDate
    }

    private func progress(for event: CountdownEvent, now: Date) -> Double {
        let clampedNow = clampedNow(for: event, now: now)
        let total = totalDuration(for: event)
        guard total > 0 else { return 0 }
        let elapsed = max(0, clampedNow.timeIntervalSince(event.startDate))
        return min(1, max(0, elapsed / total))
    }

    private func efficiency(for event: CountdownEvent, now: Date) -> Double {
        let clampedNow = clampedNow(for: event, now: now)
        let base = effectiveBaseSeconds(for: event, upTo: clampedNow)
        guard base > 0 else { return 0 }
        let focused = Double(focusSeconds(for: event, now: now))
        return min(1, max(0, focused / base))
    }

    private func remainingText(for event: CountdownEvent, now: Date) -> String {
        // Use a clamped "now" that stops at the target and never precedes the chosen start
        // so start-date edits immediately reflect in the visible countdown.
        let clampedNow = clampedNow(for: event, now: now)
        let referenceDate = max(clampedNow, event.startDate)
        let delta = event.targetDate.timeIntervalSince(referenceDate)
        let isPositive = now <= event.targetDate
        let interval = abs(isPositive ? delta : event.targetDate.timeIntervalSince(now))
        let value: Double
        let unit: String
        switch displayMode {
        case .days:
            value = interval / 86400
            unit = value == 1 ? "day" : "days"
        case .hours:
            value = interval / 3600
            unit = value == 1 ? "hour" : "hours"
        case .weeks:
            value = interval / (7 * 86400)
            unit = value == 1 ? "week" : "weeks"
        case .months:
            value = interval / (30 * 86400)
            unit = value == 1 ? "month" : "months"
        case .years:
            value = interval / (365 * 86400)
            unit = value == 1 ? "year" : "years"
        }
        let formatted = String(format: "%.2f", max(0, value))
        if isPositive {
            return "\(formatted) \(unit)"
        } else {
            return "\(formatted) \(unit) ago"
        }
    }

    private func totalDuration(for event: CountdownEvent) -> TimeInterval {
        max(0, event.targetDate.timeIntervalSince(event.startDate))
    }

    private func effectiveBaseSeconds(for event: CountdownEvent, upTo end: Date) -> Double {
        EffectiveFocusCalculator.baselineSeconds(from: event.startDate, to: end)
    }

    private func focusSeconds(for event: CountdownEvent, now: Date) -> Int {
        let windowEnd = clampedNow(for: event, now: now)
        return recordedFocusSeconds(for: event, windowEnd: windowEnd) + liveFocusContribution(for: event, now: now, windowEnd: windowEnd)
    }

    private func recordedFocusSeconds(for event: CountdownEvent, windowEnd: Date) -> Int {
        let windowStart = event.startDate
        guard windowEnd > windowStart else { return 0 }
        return store.sessions.reduce(0) { total, session in
            // Count focus-like sessions. Imported history may be stored as `.custom`,
            // so treat `.flow` and `.custom` as valid focus; ignore breaks.
            guard session.kind == .flow || session.kind == .custom else { return total }
            guard let interval = sessionInterval(for: session) else { return total }
            let overlapStart = max(interval.start, windowStart)
            let overlapEnd = min(interval.end, windowEnd)
            guard overlapEnd > overlapStart else { return total }
            return total + Int(overlapEnd.timeIntervalSince(overlapStart))
        }
    }

    private func sessionInterval(for session: Session) -> (start: Date, end: Date)? {
        let actualSeconds = TimeInterval(max(0, session.actualSeconds))
        if let start = session.startTimestamp, let end = session.endTimestamp {
            let recordedDuration = max(0, end.timeIntervalSince(start))
            // Prefer the measured `actualSeconds` and cap it by the recorded interval to avoid overcounting long pauses.
            let duration: TimeInterval
            if actualSeconds > 0 {
                duration = recordedDuration > 0 ? min(actualSeconds, recordedDuration) : actualSeconds
            } else {
                duration = recordedDuration
            }
            guard duration > 0 else { return nil }
            return (start, start.addingTimeInterval(duration))
        } else if let start = session.startTimestamp {
            guard actualSeconds > 0 else { return nil }
            let end = start.addingTimeInterval(actualSeconds)
            return (start, end)
        } else if let end = session.endTimestamp {
            guard actualSeconds > 0 else { return nil }
            let start = end.addingTimeInterval(-actualSeconds)
            return (start, end)
        }
        return nil
    }

    private func liveFocusContribution(for event: CountdownEvent, now: Date, windowEnd: Date) -> Int {
        guard timer.mode == .flow, let start = timer.currentSessionStartDate else { return 0 }
        let elapsed = TimeInterval(timer.elapsedInCurrentSession)
        guard elapsed > 0 else { return 0 }
        let windowStart = event.startDate
        guard windowEnd > windowStart else { return 0 }
        let sessionEnd = start.addingTimeInterval(elapsed)
        let overlapStart = max(start, windowStart)
        let overlapEnd = min(sessionEnd, windowEnd)
        guard overlapEnd > overlapStart else { return 0 }
        return Int(overlapEnd.timeIntervalSince(overlapStart))
    }

    private func clampedNow(for event: CountdownEvent, now: Date) -> Date {
        min(event.targetDate, now)
    }

    private func dismissEditing() {
        if let window = NSApp?.keyWindow {
            window.endEditing(for: nil)
            window.makeFirstResponder(nil)
        }
    }

    private func cycleDisplayMode() {
        guard let idx = RemainingDisplayMode.allCases.firstIndex(of: displayMode) else { return }
        displayMode = RemainingDisplayMode.allCases[(idx + 1) % RemainingDisplayMode.allCases.count]
    }

    private func loadEventsIfNeeded() {
        guard !hasLoadedEvents else { return }
        hasLoadedEvents = true
        CountdownStorage.migrateLegacyDataIfNeeded()
        let stored = CountdownStorage.loadEvents()
        let seeded = stored.isEmpty ? [defaultEvent()] : stored
        events = normalizeSortOrders(for: seeded)
    }

    private func saveEvents() {
        guard hasLoadedEvents else { return }
        let normalized = normalizeSortOrders(for: events)
        if normalized != events {
            events = normalized
            return
        }
        CountdownStorage.save(events: normalized)
    }

    private func addEvent() {
        var newEvent = defaultEvent(title: "Countdown \(events.count + 1)")
        newEvent.sortOrder = nextSortOrder()
        withAnimation {
            events.append(newEvent)
            renumberSortOrdersPreservingOrder()
        }
    }

    private func binding(for event: CountdownEvent) -> Binding<CountdownEvent>? {
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return nil }
        return $events[idx]
    }

    private func removeEvent(_ id: UUID) {
        withAnimation {
            events.removeAll { $0.id == id }
            renumberSortOrdersPreservingOrder()
        }
    }

    private func moveActive(draggedID: UUID, destinationID: UUID?, now: Date) {
        let normalized = normalizeSortOrders(for: events)
        var active = normalized.filter { !isCompleted($0, now: now) }
        let completed = normalized.filter { isCompleted($0, now: now) }
        guard let sourceIndex = active.firstIndex(where: { $0.id == draggedID }) else { return }
        let destinationIndex = destinationID.flatMap { dest in active.firstIndex(where: { $0.id == dest }) } ?? (active.count - 1)
        guard sourceIndex != destinationIndex else { return }

        let item = active.remove(at: sourceIndex)
        active.insert(item, at: max(0, min(destinationIndex, active.count)))
        applyOrderedEvents(active: active, completed: completed)
    }

    private func shiftActive(id: UUID, offset: Int, now: Date) {
        guard offset != 0 else { return }
        let normalized = normalizeSortOrders(for: events)
        var active = normalized.filter { !isCompleted($0, now: now) }
        let completed = normalized.filter { isCompleted($0, now: now) }
        guard let idx = active.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = max(0, min(active.count - 1, idx + offset))
        guard targetIndex != idx else { return }
        let item = active.remove(at: idx)
        active.insert(item, at: targetIndex)
        applyOrderedEvents(active: active, completed: completed)
    }

    private func updateTarget(for id: UUID, date: Date) {
        guard let idx = events.firstIndex(where: { $0.id == id }) else { return }
        var updated = events[idx]
        updated.targetDate = sanitizedTarget(date, start: updated.startDate)
        events[idx] = updated
    }

    private func updateStart(for id: UUID, date: Date) {
        guard let idx = events.firstIndex(where: { $0.id == id }) else { return }
        var updated = events[idx]
        let sanitizedStart = date
        let minimumTarget = sanitizedTarget(updated.targetDate, start: sanitizedStart)
        updated.startDate = sanitizedStart
        updated.targetDate = minimumTarget
        events[idx] = updated
    }

    private func defaultEvent(title: String = "Countdown") -> CountdownEvent {
        let now = Date()
        let target = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 3600)
        return CountdownEvent(title: title, startDate: now, targetDate: sanitizedTarget(target, start: now), sortOrder: nextSortOrder())
    }

    private func applyOrderedEvents(active: [CountdownEvent], completed: [CountdownEvent]) {
        var reordered: [CountdownEvent] = []
        for (idx, var event) in active.enumerated() {
            event.sortOrder = idx
            reordered.append(event)
        }
        for (offset, var event) in completed.enumerated() {
            event.sortOrder = reordered.count + offset
            reordered.append(event)
        }
        events = reordered
    }

    private func sanitizedTarget(_ date: Date, start: Date) -> Date {
        max(date, start.addingTimeInterval(60))
    }

    private func normalizeSortOrders(for source: [CountdownEvent]) -> [CountdownEvent] {
        var working = source
        let hasUniqueOrders = Set(working.map { $0.sortOrder }).count == working.count
        if hasUniqueOrders {
            working.sort { $0.sortOrder < $1.sortOrder }
        }
        for idx in working.indices {
            working[idx].sortOrder = idx
        }
        return working
    }

    private func renumberSortOrdersPreservingOrder() {
        for idx in events.indices {
            events[idx].sortOrder = idx
        }
    }

    private func nextSortOrder() -> Int {
        (events.map { $0.sortOrder }.max() ?? -1) + 1
    }

    private func dateColumn(title: String, date: Binding<Date>, minimum: Date?, maximum: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            BorderlessDatePicker(
                date: date,
                minimumDate: minimum,
                maximumDate: maximum,
                onCommit: dismissEditing
            )
            .frame(width: 240, alignment: .leading)
        }
    }

    private func moveAvailability(for event: CountdownEvent, ordered: [CountdownEvent], now: Date) -> (up: Bool, down: Bool) {
        let active = ordered.filter { !isCompleted($0, now: now) }
        guard let idx = active.firstIndex(where: { $0.id == event.id }) else { return (false, false) }
        return (idx > 0, idx < active.count - 1)
    }

    private func formatHoursMinutes(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private enum RemainingDisplayMode: CaseIterable {
        case days, hours, weeks, months, years
    }
}
