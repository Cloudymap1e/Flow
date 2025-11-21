import SwiftUI

struct MiniTimerView: View {
    @EnvironmentObject var timer: TimerViewModel
    var restoreAction: (() -> Void)?

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 6)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            Circle()
                .trim(from: 0, to: CGFloat(timer.progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .pink, .blue]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timer.progress)

            VStack(spacing: 2) {
                Text(timer.remaining.clockString)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))

                Text(timer.mode.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .overlay(alignment: .topTrailing) {
            Button {
                restoreAction?()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .overlay(alignment: .bottom) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    timer.isRunning ? timer.pause() : timer.start()
                }
            } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
    }
}
