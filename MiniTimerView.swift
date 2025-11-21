import SwiftUI

struct MiniTimerView: View {
    @EnvironmentObject var timer: TimerViewModel
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            HStack(spacing: 8) {
                // Progress Ring - smaller
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timer.progress))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timer.progress)
                }
                .frame(width: 32, height: 32)
                
                // Time and Mode - more compact
                VStack(alignment: .leading, spacing: 1) {
                    Text(timer.remaining.clockString)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText(countsDown: true))
                    
                    Text(timer.mode.title)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Play/Pause Button - smaller
                Button {
                    withAnimation {
                        timer.isRunning ? timer.pause() : timer.start()
                    }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(timer.isRunning ? "Pause" : "Start")
                
                // Restore Button
                Button {
                    MiniTimerWindowCoordinator.shared.restoreMainWindow()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Restore main window")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
