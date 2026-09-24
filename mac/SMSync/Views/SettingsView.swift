import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        TabView {
            ConnectionSettingsTab(viewModel: viewModel)
                .tabItem { Label("Connection", systemImage: "wifi") }

            SyncSettingsTab(viewModel: viewModel)
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 300)
    }
}

struct ConnectionSettingsTab: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("State", value: statusText)
                if let name = viewModel.deviceName {
                    LabeledContent("Device", value: name)
                }
            }

            Section("Actions") {
                if viewModel.isConnected {
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Connect") {
                        viewModel.startDiscovery()
                    }
                }
            }
        }
        .padding()
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .disconnected: return "Disconnected"
        case .discovering: return "Searching..."
        case .discovered: return "Found"
        case .pairing: return "Pairing"
        case .connected: return "Connected"
        case .syncing: return "Syncing"
        case .error: return "Error"
        }
    }
}

struct SyncSettingsTab: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        Form {
            Section("Sync Status") {
                LabeledContent("Last Sync", value: viewModel.lastSyncDate?.formatted() ?? "Never")
                LabeledContent("Messages Synced", value: "\(viewModel.messagesSynced)")
                Button("Sync Now") {
                    viewModel.connectAndSync()
                }
                .disabled(!viewModel.isConnected)
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
