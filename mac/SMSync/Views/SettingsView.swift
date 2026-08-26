import SwiftUI

struct SettingsView: View {
    @StateObject private var pairingManager = PairingManager()
    @State private var showPairingSheet = false

    var body: some View {
        TabView {
            ConnectionSettingsTab(pairingManager: pairingManager, showPairingSheet: $showPairingSheet)
                .tabItem { Label("Connection", systemImage: "wifi") }

            SyncSettingsTab()
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 300)
        .sheet(isPresented: $showPairingSheet) {
            PairingSheet(pairingManager: pairingManager)
        }
    }
}

struct ConnectionSettingsTab: View {
    @ObservedObject var pairingManager: PairingManager
    @Binding var showPairingSheet: Bool

    var body: some View {
        Form {
            Section("Paired Device") {
                if pairingManager.isPaired {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(pairingManager.pairedDeviceName ?? "Unknown Device")
                        Spacer()
                        Button("Unpair") {
                            pairingManager.unpair()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.orange)
                        Text("No device paired")
                        Spacer()
                        Button("Pair Device") {
                            showPairingSheet = true
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct SyncSettingsTab: View {
    var body: some View {
        Form {
            Section("Sync Status") {
                LabeledContent("Last Sync", value: "Never")
                LabeledContent("Messages Synced", value: "0")
                Button("Sync Now") {
                    // TODO: Trigger sync
                }
            }
        }
        .padding()
    }
}

struct AboutTab: View {
    var body: some View {
        Form {
            Section("About SMSync") {
                LabeledContent("Version", value: "1.0")
                Text("Syncs SMS from your Android phone to your Mac over local WiFi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("All data stays on your local network. No cloud services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct PairingSheet: View {
    @ObservedObject var pairingManager: PairingManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Pair with Android")
                .font(.title2)

            Text("Enter this PIN on your Android app:")
                .foregroundStyle(.secondary)

            if let pin = pairingManager.generatedPin {
                Text(pin)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Waiting for Android to connect...")
                .foregroundStyle(.secondary)
                .font(.caption)

            Button("Cancel") {
                dismiss()
            }
        }
        .padding(32)
        .frame(width: 350)
        .onAppear {
            _ = pairingManager.generatePin()
        }
    }
}

#Preview {
    SettingsView()
}
