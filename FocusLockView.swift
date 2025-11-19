import SwiftUI

struct FocusLockView: View {
    @StateObject private var manager = FocusLockManager()
    @State private var showingAddSheet = false
    @State private var newItemName = ""
    @State private var newItemBundleID = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Focus Lock")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                Toggle("", isOn: $manager.isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: manager.isEnabled) { enabled in
                        if enabled { manager.startMonitoring() }
                        else { manager.stopMonitoring() }
                    }
            }
            .padding(20)
            .background(.ultraThinMaterial)

            Divider()

            // List
            List {
                if manager.blockedItems.isEmpty {
                    Text("No blocked apps configured.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(manager.blockedItems) { item in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                if let bid = item.bundleIdentifier {
                                    Text(bid)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { idx in
                            let item = manager.blockedItems[idx]
                            manager.removeItem(id: item.id)
                        }
                    }
                }
            }
            .listStyle(.inset)

            // Footer / Add
            HStack {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add App to Blocklist", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(20)
            .background(.ultraThinMaterial)
        }
        .frame(width: 400, height: 500)
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 20) {
                Text("Add App to Block")
                    .font(.headline)
                
                TextField("App Name (e.g. Calculator)", text: $newItemName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Bundle ID (Optional)", text: $newItemBundleID)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Cancel") { showingAddSheet = false }
                    Button("Add") {
                        let item = BlockedItem(
                            name: newItemName,
                            bundleIdentifier: newItemBundleID.isEmpty ? nil : newItemBundleID,
                            type: .app
                        )
                        manager.addItem(item)
                        newItemName = ""
                        newItemBundleID = ""
                        showingAddSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newItemName.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 300)
        }
        .overlay(alignment: .top) {
            if let alert = manager.violationAlert {
                VStack {
                    Text(alert)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 20)
                        .onTapGesture {
                            manager.violationAlert = nil
                        }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation { manager.violationAlert = nil }
                    }
                }
            }
        }
    }
}
