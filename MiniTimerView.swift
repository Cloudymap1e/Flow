import SwiftUI

struct MiniTimerView: View {
    @EnvironmentObject var timer: TimerViewModel
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            HStack(spacing: 12) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timer.progress))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timer.progress)
                }
                .frame(width: 40, height: 40)
                
                // Time and Controls
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.remaining.clockString)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText(countsDown: true))
                    
                    Text(timer.mode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Play/Pause
                Button {
                    withAnimation {
                        timer.isRunning ? timer.pause() : timer.start()
                    }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }
}
