import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timer: TimerViewModel

    @State private var selectedTab: Int = 0 // 0 = Timer, 1 = Stats
    @State private var showErrorBanner: Bool = false

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
                }
                .padding(4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 20)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                // Content Area
                Group {
                    if selectedTab == 0 {
                        TimerView()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else {
                        StatsView()
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
        }
        .onAppear { timer.attach(store: store) }
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

    private func tabButton(title: String, tag: Int) -> some View {
        Button {
            withAnimation { selectedTab = tag }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selectedTab == tag ? .primary : .secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .opacity(selectedTab == tag ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
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
    @State private var animate: Bool = false

    var body: some View {
        ZStack {
            // Base color
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            // Animated Mesh Gradient simulation
            GeometryReader { proxy in
                ZStack {
                    // Blob 1
                    Circle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: proxy.size.width * 0.8, height: proxy.size.width * 0.8)
                        .blur(radius: 100)
                        .offset(x: animate ? -100 : 100, y: animate ? -50 : 50)
                        .animation(
                            Animation.easeInOut(duration: 20).repeatForever(autoreverses: true),
                            value: animate
                        )

                    // Blob 2
                    Circle()
                        .fill(Color.purple.opacity(0.4))
                        .frame(width: proxy.size.width * 0.7, height: proxy.size.width * 0.7)
                        .blur(radius: 100)
                        .offset(x: animate ? 150 : -150, y: animate ? 100 : -100)
                        .animation(
                            Animation.easeInOut(duration: 18).repeatForever(autoreverses: true),
                            value: animate
                        )

                    // Blob 3
                    Circle()
                        .fill(Color.cyan.opacity(0.3))
                        .frame(width: proxy.size.width * 0.9, height: proxy.size.width * 0.9)
                        .blur(radius: 120)
                        .offset(x: animate ? -50 : 50, y: animate ? 150 : -150)
                        .animation(
                            Animation.easeInOut(duration: 25).repeatForever(autoreverses: true),
                            value: animate
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()

            // Glass overlay to smooth everything out
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.3)
                .ignoresSafeArea()
        }
        .onAppear {
            animate = true
        }
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
