import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#else
import UIKit
#endif

struct StatsView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var granularity: StatsGranularity = .week
    @State private var periodOffset: Int = 0
    @State private var showRecentSessionsPopover: Bool = false
    @State private var viewMode: StatsViewMode = .charts // New mode switcher
    @State private var showingTotalTime: Bool = false

    enum StatsViewMode: String, CaseIterable, Identifiable {
        case charts = "Charts"
        case calendar = "Calendar"
        var id: String { rawValue }
    }

    private var granularitySelection: Binding<StatsGranularity> {
        Binding(
            get: { granularity },
            set: { newValue in
                withAnimation {
                    granularity = newValue
                    periodOffset = 0
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header with View Mode Picker
            HStack {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(StatsViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            if viewMode == .charts {
                statsCard
                    .padding(.top, -20)
                    .transition(.move(edge: .leading))
            } else {
                CalendarHeatmapView(sessions: store.allSessions())
                    .padding(.top, 20)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut, value: viewMode)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Picker("", selection: granularitySelection) {
                    ForEach(StatsGranularity.allCases) { option in
                        Text(option.rawValue)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                Spacer(minLength: 8)

                Menu {
                    Button("Reset to Today") { periodOffset = 0 }
#if os(macOS)
                    Divider()
                    Button("Import Sessions…") { importSessions() }
                    Button("Export Sessions…") { exportSessions() }
#endif
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
                .menuStyle(.borderlessButton)
            }

            chartHeader

            StatsBarChart(
                buckets: buckets,
                highlightColor: .accentColor,
                gradientColors: statsBarGradientColors,
                tooltipProvider: bucketTooltip,
                onSelect: handleBucketSelection
            )

            HStack(spacing: 18) {
                StatChip(title: "Sessions", value: "\(periodSessionCount)")
                StatChip(title: "Time", value: periodTotalSeconds.clockString)
                Spacer(minLength: 12)
                recentSessionsButton
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: granularity)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: periodOffset)
    }

    private var chartHeader: some View {
        HStack(spacing: 12) {
            navButton(-1)
            Spacer(minLength: 0)
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    showingTotalTime.toggle()
                }
            } label: {
                Text(chartTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityHint("Tap to switch between total flows and total focus time")
            Spacer(minLength: 0)
            navButton(1)
        }
    }

    private var statsBarGradientColors: [Color] {
        [
            Color.accentColor.lightened(by: 0.12),
            Color.accentColor,
            Color.accentColor.blended(with: .purple, amount: 0.35),
            Color.accentColor.blended(with: .pink, amount: 0.55)
        ]
    }

    private func navButton(_ direction: Int) -> some View {
        Button {
            periodOffset += direction
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }

    private var recentSessionsButton: some View {
        Button {
            showRecentSessionsPopover = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(recentSessionDurationText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(recentSessionsSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(width: 180, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showRecentSessionsPopover, arrowEdge: .bottom) {
            sessionsPopoverContent
        }
    }

    private var sessionsPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showRecentSessionsPopover = false
                }
                .buttonStyle(.borderless)
            }
            sessionsList
        }
        .padding(20)
        .frame(width: 420, height: 360)
    }

    private var sessionsList: some View {
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
                        .contextMenu {
                            Button(role: .destructive) {
                                store.delete(session)
                            } label: {
                                Label("Delete Session", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var sessions: [Session] {
        store.allSessions().reversed()
    }

    private var chartTitle: String {
        let detail: String
        if showingTotalTime {
            let focusLabel = durationDescription(for: periodTotalSeconds)
            detail = "\(focusLabel) focused"
        } else {
            let flowsWord = periodSessionCount == 1 ? "Flow" : "Flows"
            detail = "\(periodSessionCount) \(flowsWord)"
        }
        return "\(periodTitle) - \(detail)"
    }

    private var periodTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch granularity {
        case .year:
            let year = calendar.component(.year, from: currentPeriodStart)
            return "\(year)"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: currentPeriodStart)
        case .week:
            formatter.dateFormat = "MMM d"
            let start = currentPeriodStart
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .day:
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: currentPeriodStart)
        }
    }

    private var periodSessionCount: Int {
        buckets.reduce(0) { $0 + $1.count }
    }

    private var periodTotalSeconds: Int {
        buckets.reduce(0) { $0 + $1.totalSeconds }
    }

    private var buckets: [StatsBucket] {
        let start = currentPeriodStart
        let periodComponent = self.periodComponent(for: granularity)
        let bucketComponent = self.bucketComponent(for: granularity)
        let bucketCount = self.bucketCount(for: granularity, startDate: start)
        guard bucketCount > 0 else { return [] }

        var aggregates = Array(repeating: (seconds: 0, count: 0), count: bucketCount)
        let periodEnd = calendar.date(byAdding: periodComponent, value: 1, to: start) ?? start

        for session in store.sessions {
            guard let ts = session.startTimestamp else { continue }
            guard ts >= start && ts < periodEnd else { continue }
            guard let idx = bucketIndex(for: ts, startOfPeriod: start) else { continue }
            guard idx >= 0 && idx < aggregates.count else { continue }
            aggregates[idx].seconds += session.actualSeconds
            aggregates[idx].count += 1
        }

        var buckets: [StatsBucket] = []
        var bucketStart = start
        for idx in 0..<bucketCount {
            guard let bucketEnd = calendar.date(byAdding: bucketComponent, value: 1, to: bucketStart) else { continue }
            let label = label(for: bucketStart, index: idx)
            let agg = aggregates[idx]
            buckets.append(
                StatsBucket(
                    label: label,
                    start: bucketStart,
                    end: bucketEnd,
                    totalSeconds: agg.seconds,
                    count: agg.count
                )
            )
            bucketStart = bucketEnd
        }
        return buckets
    }

    private var currentPeriodStart: Date {
        let baseComponent = periodComponent(for: granularity)
        let calendar = self.calendar
        let anchor = calendar.date(byAdding: baseComponent, value: periodOffset, to: Date()) ?? Date()
        return startOfPeriod(for: anchor, granularity: granularity)
    }

    private func startOfPeriod(for date: Date, granularity: StatsGranularity) -> Date {
        let calendar = self.calendar
        switch granularity {
        case .year:
            let comps = calendar.dateComponents([.year], from: date)
            return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .day:
            return calendar.startOfDay(for: date)
        }
    }

    private func periodOffset(for targetDate: Date, granularity: StatsGranularity) -> Int {
        let calendar = self.calendar
        let component = periodComponent(for: granularity)
        let baseStart = startOfPeriod(for: Date(), granularity: granularity)
        let targetStart = startOfPeriod(for: targetDate, granularity: granularity)
        let comps = calendar.dateComponents([component], from: baseStart, to: targetStart)
        return comps.value(for: component) ?? 0
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    private func periodComponent(for granularity: StatsGranularity) -> Calendar.Component {
        switch granularity {
        case .year: return .year
        case .month: return .month
        case .week: return .weekOfYear
        case .day: return .day
        }
    }

    private func bucketComponent(for granularity: StatsGranularity) -> Calendar.Component {
        switch granularity {
        case .year: return .month
        case .month: return .day
        case .week: return .day
        case .day: return .hour
        }
    }

    private func bucketCount(for granularity: StatsGranularity, startDate: Date) -> Int {
        switch granularity {
        case .year: return 12
        case .month: return calendar.range(of: .day, in: .month, for: startDate)?.count ?? 30
        case .week: return 7
        case .day: return 24
        }
    }

    private func bucketIndex(for date: Date, startOfPeriod: Date) -> Int? {
        switch granularity {
        case .year:
            return calendar.component(.month, from: date) - 1
        case .month:
            return calendar.component(.day, from: date) - 1
        case .week:
            return calendar.dateComponents([.day], from: startOfPeriod, to: date).day
        case .day:
            return calendar.component(.hour, from: date)
        }
    }

    private func label(for bucketStart: Date, index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        switch granularity {
        case .year:
            let monthIdx = calendar.component(.month, from: bucketStart) - 1
            let symbols = formatter.shortMonthSymbols ?? []
            if monthIdx >= 0 && monthIdx < symbols.count {
                return String(symbols[monthIdx].prefix(1)).uppercased()
            }
            return ""
        case .month:
            formatter.dateFormat = "d"
            return formatter.string(from: bucketStart)
        case .week:
            formatter.dateFormat = "E"
            return formatter.string(from: bucketStart)
        case .day:
            formatter.dateFormat = "ha"
            return formatter.string(from: bucketStart)
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

    private var recentSessionsSummary: String {
        if sessions.isEmpty { return "No sessions logged yet" }
        if let latest = sessions.first, let start = latest.startTimestamp {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: start)
        }
        return "Tap to review your latest flows"
    }

    private var recentSessionDurationText: String {
        guard let latest = sessions.first else { return "--:--" }
        return latest.actualSeconds.clockString
    }

    private func bucketTooltip(_ bucket: StatsBucket) -> String {
        let intervalFormatter = DateIntervalFormatter()
        intervalFormatter.locale = Locale.current
        intervalFormatter.timeZone = calendar.timeZone
        switch granularity {
        case .day:
            intervalFormatter.dateStyle = .none
            intervalFormatter.timeStyle = .short
        default:
            intervalFormatter.dateStyle = .medium
            intervalFormatter.timeStyle = .none
        }
        let rangeText = intervalFormatter.string(from: bucket.start, to: bucket.end)
        if bucket.totalSeconds == 0 {
            return "\(rangeText)\nNo focus logged"
        }
        return "\(rangeText)\n\(durationDescription(for: bucket.totalSeconds)) focused"
    }

    private func handleBucketSelection(_ bucket: StatsBucket) {
        guard let nextGranularity = granularity.lowerGranularity else { return }
        let targetOffset = periodOffset(for: bucket.start, granularity: nextGranularity)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            granularity = nextGranularity
            periodOffset = targetOffset
        }
    }

    private func durationDescription(for seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        var components: [String] = []
        if hours > 0 { components.append("\(hours)h") }
        if minutes > 0 { components.append("\(minutes)m") }
        if components.isEmpty { components.append("\(secs)s") }
        return components.joined(separator: " ")
    }

    private func importSessions() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            do {
                if url.pathExtension.lowercased() == "csv" {
                    try store.importFromCSV(url: url)
                } else {
                    try store.importFromJSON(url: url)
                }
            } catch {
                store.lastErrorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
#else
        store.lastErrorMessage = "Import is only available on macOS."
#endif
    }

    private func exportSessions() {
#if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "sessions.json"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            do {
                try store.exportJSON(to: url)
            } catch {
                store.lastErrorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
#else
        store.lastErrorMessage = "Export is only available on macOS."
#endif
    }
}

// MARK: - Calendar Heatmap View
struct CalendarHeatmapView: View {
    let sessions: [Session]
    @State private var currentMonth: Date = Date()
    @State private var hoveredDate: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()
                Text(monthTitle)
                    .font(.title3.weight(.semibold))
                Spacer()

                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Days Grid
            LazyVGrid(columns: columns, spacing: 4) {
                // Weekday headers
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                // Days
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            seconds: seconds(for: date),
                            isHovered: hoveredDate == date
                        )
                        .onHover { isHovering in
                            hoveredDate = isHovering ? date : nil
                        }
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
        .padding(.horizontal, 20)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = firstWeekday - calendar.firstWeekday
        let leadingEmpty = offset >= 0 ? offset : offset + 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func seconds(for date: Date) -> Int {
        sessions.filter { session in
            guard let start = session.startTimestamp else { return false }
            return calendar.isDate(start, inSameDayAs: date)
        }.reduce(0) { $0 + $1.actualSeconds }
    }
}

struct DayCell: View {
    let date: Date
    let seconds: Int
    let isHovered: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color(for: seconds))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(isHovered ? 0.5 : 0), lineWidth: 2)
                )

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption.weight(.medium))
                .foregroundStyle(seconds > 0 ? .white : .primary)
        }
        .overlay(alignment: .top) {
            if isHovered {
                Tooltip(text: tooltipText)
                    .offset(y: -36)
                    .zIndex(1)
            }
        }
    }

    private var tooltipText: String {
        if seconds == 0 { return "No focus" }
        let mins = seconds / 60
        return "\(mins) mins focused"
    }

    private func color(for seconds: Int) -> Color {
        if seconds == 0 { return Color.secondary.opacity(0.1) }
        // Heatmap logic: more seconds -> darker/more intense color
        // Base max on 4 hours (14400 seconds) for full intensity
        let intensity = min(Double(seconds) / 14400.0, 1.0)
        return Color.accentColor.opacity(0.3 + (intensity * 0.7))
    }
}

struct Tooltip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
    }
}

private struct StatsBarChart: View {
    let buckets: [StatsBucket]
    var highlightColor: Color = .accentColor
    var gradientColors: [Color]? = nil
    var tooltipProvider: ((StatsBucket) -> String)?
    var onSelect: ((StatsBucket) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
#if os(macOS)
    @State private var hoveredBucketID: StatsBucket.ID?
#endif

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(buckets.map { $0.totalSeconds }.max() ?? 0, 1)
            let tooltipAllowance: CGFloat = 44
            let availableHeight = max(proxy.size.height - tooltipAllowance, 1)
            let spacing: CGFloat = buckets.count >= 20 ? 4 : 10
            let barWidth = barWidth(for: proxy.size.width, spacing: spacing)
            let fillGradient = barGradient(for: highlightColor, customColors: gradientColors)
            let trackGradient = trackGradient(for: colorScheme)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(trackGradient)
                                .frame(width: barWidth, height: availableHeight)

                            Capsule()
                                .fill(fillGradient)
                                .frame(
                                    width: barWidth,
                                    height: barHeight(for: bucket, maxHeight: availableHeight, maxValue: maxValue)
                                )
                                .opacity(bucket.totalSeconds == 0 ? 0.25 : 1)
                        }

                        Text(bucket.label.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: barWidth + 6)
                            .lineLimit(1)
                    }
#if os(macOS)
                    .onHover { hovering in
                        if hovering {
                            hoveredBucketID = bucket.id
                        } else if hoveredBucketID == bucket.id {
                            hoveredBucketID = nil
                        }
                    }
                    .overlay(alignment: .top) {
                        if hoveredBucketID == bucket.id, let tooltip = tooltipProvider?(bucket) {
                            ChartTooltip(text: tooltip)
                                .offset(y: -28)
                        }
                    }
#endif
                    .help(tooltipProvider?(bucket) ?? bucket.label)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect?(bucket)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            .padding(.top, 24)
        }
        .frame(height: 220)
    }

    private func barGradient(for color: Color, customColors: [Color]?) -> LinearGradient {
        let colors = customColors ?? defaultBarColors(for: color)
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func defaultBarColors(for color: Color) -> [Color] {
        [
            color.lightened(by: 0.15),
            color,
            color.blended(with: .purple, amount: 0.3),
            color.blended(with: .pink, amount: 0.5)
        ]
    }

    private func trackGradient(for scheme: ColorScheme) -> LinearGradient {
        let topAlpha: CGFloat = scheme == .dark ? 0.25 : 0.32
        let bottomAlpha: CGFloat = scheme == .dark ? 0.08 : 0.16
        let top = Color.white.opacity(topAlpha)
        let bottom = Color.white.opacity(bottomAlpha)
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: top, location: 0),
                .init(color: bottom, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func barHeight(for bucket: StatsBucket, maxHeight: CGFloat, maxValue: Int) -> CGFloat {
        guard maxValue > 0 else { return 8 }
        let ratio = CGFloat(bucket.totalSeconds) / CGFloat(maxValue)
        return max(8, ratio * maxHeight)
    }

    private func barWidth(for width: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = max(1, buckets.count)
        let totalSpacing = spacing * CGFloat(max(0, count - 1))
        let raw = (width - totalSpacing) / CGFloat(count)
        return max(8, min(34, raw))
    }
}

#if os(macOS)
private struct ChartTooltip: View {
    let text: String
    private var lines: [String] {
        text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 150, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
    }
}
#endif

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

private extension Color {
    func lightened(by amount: CGFloat) -> Color {
        blended(with: .white, amount: abs(amount))
    }

    func darkened(by amount: CGFloat) -> Color {
        blended(with: .black, amount: abs(amount))
    }

    func blended(with color: Color, amount: CGFloat) -> Color {
        let t = max(0, min(1, amount))
        guard let lhs = rgbaComponents(), let rhs = color.rgbaComponents() else { return self }
        let r = lhs.r + (rhs.r - lhs.r) * t
        let g = lhs.g + (rhs.g - lhs.g) * t
        let b = lhs.b + (rhs.b - lhs.b) * t
        let a = lhs.a + (rhs.a - lhs.a) * t
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }

    private func rgbaComponents() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
#if os(macOS)
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return (nsColor.redComponent, nsColor.greenComponent, nsColor.blueComponent, nsColor.alphaComponent)
#else
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
#endif
    }
}
