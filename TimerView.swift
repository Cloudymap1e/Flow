import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
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
                VStack(spacing: 24) {
                    titleRow

                    // Timer Circle
                    ZStack {
                        // Glassy background circle
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 300, height: 300)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )

                        // Progress Ring
                        Circle()
                            .trim(from: 0, to: CGFloat(timer.progress))
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [.blue, .purple, .pink, .blue]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 260, height: 260)
                            .animation(.linear(duration: 1), value: timer.progress)

                        // Time Text
                        VStack(spacing: 4) {
                            Text(timer.remaining.clockString)
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText(countsDown: true))

                            Text(timer.mode.title)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 20)

                    progressDots
                        .padding(.top, 6)

                    controls
                        .padding(.top, 12)
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
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 280)
                    .focused($titleFocused)
                    .onSubmit { commitTitle() }
                    .onAppear { titleDraft = timer.displayTitle }
            } else {
                Text(timer.displayTitle)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings")
            
            Spacer()
        }
    }

    private var progressDots: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { idx in
                Circle()
                    .fill(idx < timer.completedFlowsInCycle % 4 ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.2))
                    .frame(width: 8, height: 8)
                    .animation(.spring, value: timer.completedFlowsInCycle)
            }
        }
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: 24) {
            Spacer()
            
            // Play/Pause Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    timer.isRunning ? timer.pause() : timer.start()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .frame(width: 80, height: 80)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("playpause")

            // Reset Button
            Button {
                withAnimation { timer.resetCurrentSession() }
            } label: {
                Image(systemName: "gobackward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
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
            
            Toggle("Float when backgrounded", isOn: $timer.floatOnBackground)
                .padding(.vertical, 4)

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
#endif
    }
}
