import SwiftUI

struct MiniTimerView: View {
    @EnvironmentObject var timer: TimerViewModel
    @Environment(\.colorScheme) private var colorScheme
    private static let dialSize: CGFloat = 220
    private static let padding: CGFloat = 8

    static var defaultDiameter: CGFloat {
        dialSize + padding * 2
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(dialGradient)
                .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 12)

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 8)

            Circle()
                .trim(from: 0, to: CGFloat(timer.progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .pink, .blue]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timer.progress)

            VStack(spacing: 14) {
                Text(timer.displayTitle)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 20)

                Text(timer.remaining.clockString)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))

                HStack(spacing: 18) {
                    controlButton(
                        systemName: timer.isRunning ? "pause.fill" : "play.fill",
                        accessibilityLabel: timer.isRunning ? "Pause timer" : "Start timer",
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                timer.isRunning ? timer.pause() : timer.start()
                            }
                        }
                    )

                    controlButton(
                        systemName: "arrow.up.left.and.arrow.down.right",
                        accessibilityLabel: "Restore Flow window",
                        action: {
                            FloatingWindowManager.shared.restoreMainWindow()
                        }
                    )

                    if timer.isAlarmRinging {
                        alertStopButton
                    }
                }
            }
            .padding(.top, 24)
        }
        .frame(width: Self.dialSize, height: Self.dialSize)
        .padding(Self.padding)
        .contentShape(
            Circle()
                .inset(by: -Self.padding)
        )
        .onTapGesture(count: 2) {
            FloatingWindowManager.shared.restoreMainWindow()
        }
        .help("Double-click to restore the main Flow window")
    }

    private var dialGradient: RadialGradient {
        let center = colorScheme == .dark ? Color.white.opacity(0.35) : Color.white.opacity(0.95)
        let edge = colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.35)
        return RadialGradient(
            gradient: Gradient(colors: [center, edge]),
            center: .center,
            startRadius: 0,
            endRadius: 160
        )
    }

    private func controlButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var alertStopButton: some View {
        Button {
            timer.stopAlarmSound()
        } label: {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .shadow(color: Color.red.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop alert sound")
    }
}
