import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TimerView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timer: TimerViewModel
    @State private var isEditingTitle: Bool = false
    @State private var titleDraft: String = ""
    @FocusState private var titleFocused: Bool
    @State private var showingSettings: Bool = false
    @State private var flowMinutes: Double = 25
    @State private var shortMinutes: Double = 5
    @State private var longMinutes: Double = 30
    @State private var validationMessage: String?

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                VStack(spacing: 18) {
                    titleRow

                    Text(timer.remaining.clockString)
                        .font(.system(size: 92, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityIdentifier("time")
                        .padding(.top, 2)

                    progressDots
                        .padding(.top, 6)

                    controls
                        .padding(.top, 12)

                    Text("Flow \(timer.flowDuration/60)m • Short \(timer.shortBreak/60)m • Long \(timer.longBreak/60)m")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .padding(.top, 6)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { syncDurationsFromModel() }
        .sheet(isPresented: $showingSettings) { settingsSheet }
        .onChange(of: titleFocused) { isFocused in
            if !isFocused && isEditingTitle { commitTitle() }
        }
    }

    // MARK: Components
    private var titleRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer()
            if isEditingTitle && timer.mode == .flow {
                TextField("Flow", text: $titleDraft, onCommit: commitTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: 240)
                    .focused($titleFocused)
                    .onSubmit { commitTitle() }
                    .onAppear { titleDraft = timer.displayTitle }
            } else {
                Text(timer.displayTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .accessibilityIdentifier("title")
                    .onTapGesture {
                        guard timer.mode == .flow else { return }
                        titleDraft = timer.displayTitle
                        withAnimation { isEditingTitle = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            titleFocused = true
                        }
                    }
            }

            Button {
                showingSettings = true
                syncDurationsFromModel()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings")
            Spacer()
        }
    }

    private var progressDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { idx in
                Circle()
                    .fill(idx < timer.completedFlowsInCycle % 4 ? Color.primary.opacity(0.65) : Color.secondary.opacity(0.25))
                    .frame(width: 9, height: 9)
            }
        }
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: 14) {
            Spacer()
            Button {
                timer.isRunning ? timer.pause() : timer.start()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThickMaterial)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 6)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 86, height: 86)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("playpause")

            Button {
                timer.resetCurrentSession()
            } label: {
                Image(systemName: "gobackward")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Reset current session")
            .accessibilityIdentifier("reset")
            Spacer()
        }
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Timer Settings")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { showingSettings = false }
                    .keyboardShortcut(.defaultAction)
            }

            settingsRow(title: "Flow", binding: $flowMinutes)
            settingsRow(title: "Short Break", binding: $shortMinutes)
            settingsRow(title: "Long Break", binding: $longMinutes)

            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                importSessions()
            } label: {
                Label("Import Sessions (JSON or CSV)", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.bordered)

            HStack {
                Spacer()
                Button("Save") { saveDurations() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func settingsRow(title: String, binding: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .frame(width: 110, alignment: .leading)
            Stepper(value: binding, in: 1...180, step: 1) {
                Text("\(Int(binding.wrappedValue)) minutes")
            }
        }
    }

    // MARK: Helpers
    private func commitTitle() {
        timer.renameSession(to: titleDraft)
        withAnimation { isEditingTitle = false }
        titleFocused = false
    }

    private func syncDurationsFromModel() {
        flowMinutes = Double(timer.flowDuration / 60)
        shortMinutes = Double(timer.shortBreak / 60)
        longMinutes = Double(timer.longBreak / 60)
    }

    private func saveDurations() {
        let items = [flowMinutes, shortMinutes, longMinutes]
        guard items.allSatisfy({ $0 >= 1 && $0 <= 180 }) else {
            validationMessage = "Please keep values between 1 and 180 minutes."
            return
        }
        validationMessage = nil
        timer.applyDurations(
            flow: Int(flowMinutes) * 60,
            short: Int(shortMinutes) * 60,
            long: Int(longMinutes) * 60
        )
        showingSettings = false
    }

    private func importSessions() {
#if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json", "csv"]
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
#endif
    }
}
