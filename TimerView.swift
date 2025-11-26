import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct TimerView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timer: TimerViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditingTitle: Bool = false
    @State private var titleDraft: String = ""
    @FocusState private var titleFocused: Bool
    @State private var showingSettings: Bool = false
    @State private var flowMinutes: Int = 25
    @State private var shortMinutes: Int = 5
    @State private var longMinutes: Int = 30
    @State private var validationMessage: String?
#if os(macOS)
    @State private var soundImportMessage: String?
    @State private var soundImportIsError: Bool = false
#endif
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.65
    @AppStorage("forceDarkMode") private var forceDarkMode: Bool = false
    @State private var showingAppearancePopover: Bool = false

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
                            .fill(timerFaceGradient)
                            .frame(width: 260, height: 260)
                            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

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
        .onChange(of: titleFocused) { _, isFocused in
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

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    forceDarkMode.toggle()
                }
            } label: {
                Image(systemName: forceDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help(forceDarkMode ? "Switch to light background" : "Switch to dark background")

            Button {
                showingAppearancePopover.toggle()
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingAppearancePopover, arrowEdge: .top) {
                appearancePopover
            }
            .help("Adjust background transparency")
            
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

            Button {
                timer.fastForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Fast-forward to the next session")
            .accessibilityIdentifier("fastForward")
            .disabled(!timer.hasProgress)
            .opacity(timer.hasProgress ? 1 : 0.4)
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

            if timer.isAlarmRinging {
                Button {
                    timer.stopAlarmSound()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.red.opacity(0.25), radius: 10, x: 0, y: 5)

                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 70, height: 70)
                }
                .buttonStyle(.plain)
                .help("Stop alert sound")
                .accessibilityIdentifier("stopAlertSound")
            }
            Spacer()
        }
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Timer Settings")
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            settingsRow(title: "Flow", binding: $flowMinutes)
            settingsRow(title: "Short Break", binding: $shortMinutes)
            settingsRow(title: "Long Break", binding: $longMinutes)

#if os(macOS)
            Divider()
                .padding(.top, 4)

            soundSettingsSection
#endif
            
            Toggle("Float when backgrounded", isOn: $timer.floatOnBackground)
                .padding(.vertical, 4)

            appearanceSection

            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            HStack {
                Button("Cancel") {
                    showingSettings = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { saveDurations() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background Transparency")
                .font(.headline)
            opacitySliderControls
        }
        .padding(.vertical, 4)
    }

    private var appearancePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)
            opacitySliderControls
        }
        .padding(18)
        .frame(width: 240)
    }

    private var opacitySliderControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Slider(value: $backgroundOpacity, in: 0.2...1.0)
            HStack {
                Text("More transparent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(backgroundOpacity * 100))% opacity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timerFaceGradient: RadialGradient {
        let highlight = colorScheme == .dark ? Color.white.opacity(0.25) : Color.white.opacity(0.65)
        let shade = colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.2)
        return RadialGradient(
            gradient: Gradient(colors: [highlight, shade]),
            center: .center,
            startRadius: 10,
            endRadius: 180
        )
    }

    private func settingsRow(title: String, binding: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 110, alignment: .leading)
            HStack(spacing: 8) {
                TextField("Minutes", value: binding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .onChange(of: binding.wrappedValue) { _, _ in
                        enforceMinuteBounds(binding)
                    }
                Text("min")
                    .foregroundStyle(.secondary)
            }
            Stepper("", value: binding, in: 1...180, step: 1)
                .labelsHidden()
        }
    }

    // MARK: Helpers
    private func commitTitle() {
        timer.renameSession(to: titleDraft)
        withAnimation { isEditingTitle = false }
        titleFocused = false
    }

    private func syncDurationsFromModel() {
        flowMinutes = timer.flowDuration / 60
        shortMinutes = timer.shortBreak / 60
        longMinutes = timer.longBreak / 60
    }

    private func saveDurations() {
        let items = [flowMinutes, shortMinutes, longMinutes]
        guard items.allSatisfy({ $0 >= 1 && $0 <= 180 }) else {
            validationMessage = "Please keep values between 1 and 180 minutes."
            return
        }
        validationMessage = nil
        timer.applyDurations(
            flow: flowMinutes * 60,
            short: shortMinutes * 60,
            long: longMinutes * 60
        )
        showingSettings = false
    }

    private func enforceMinuteBounds(_ binding: Binding<Int>) {
        let clamped = min(max(binding.wrappedValue, 1), 180)
        if clamped != binding.wrappedValue {
            binding.wrappedValue = clamped
        }
    }

#if os(macOS)
    private var soundSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alert Sound")
                .font(.headline)
            HStack {
                Label(timer.alertSoundDescription, systemImage: timer.hasCustomAlertSound ? "music.note" : "speaker.wave.2.fill")
                Spacer()
                Button("Choose File…") {
                    soundImportMessage = nil
                    soundImportIsError = false
                    presentSoundPicker()
                }
            }
            if timer.hasCustomAlertSound {
                Button("Use Default Sound") {
                    timer.clearCustomAlertSoundSelection()
                    soundImportMessage = "Reverted to default alert."
                    soundImportIsError = false
                }
                .buttonStyle(.borderless)
            }
            if let message = soundImportMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(soundImportIsError ? Color.red : Color.secondary)
            }
        }
    }

    private func handleSoundSelection(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }
        if timer.applyCustomAlertSound(url: url) {
            soundImportIsError = false
            soundImportMessage = "Using \(url.lastPathComponent)"
        } else {
            soundImportIsError = true
            soundImportMessage = "Could not load \(url.lastPathComponent). Using default alert."
        }
    }

    private func presentSoundPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            handleSoundSelection(url: url)
        }
    }
#endif
}
