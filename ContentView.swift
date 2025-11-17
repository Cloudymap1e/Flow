import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timer: TimerViewModel

    @State private var selectedTab: Int = 0 // 0 = Timer, 1 = Stats
    @State private var showErrorBanner: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact top "tab" like your iOS segmented selector
            Picker("", selection: $selectedTab) {
                Text("Timer").tag(0)
                Text("Statistics").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.top, 12)

            Divider()

            Group {
                if selectedTab == 0 {
                    TimerView()
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                } else {
                    StatsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { timer.attach(store: store) }
        .overlay(alignment: .bottom) {
            if let msg = store.lastErrorMessage, !msg.isEmpty {
                ErrorBanner(text: msg)
                    .onAppear {
                        // auto hide after a moment; non-blocking, friendly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { store.lastErrorMessage = nil }
                        }
                    }
            }
        }
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
