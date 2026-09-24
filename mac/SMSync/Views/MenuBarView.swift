import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: SyncViewModel
    @State private var manualIP = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                Spacer()
            }

            Divider()

            if let name = viewModel.deviceName {
                Text(name)
                    .font(.headline)
            }

            HStack {
                Text("\(viewModel.messagesSynced) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastSync = viewModel.lastSyncDate {
                    Text(lastSync, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Sync Now") {
                viewModel.connectAndSync()
            }
            .disabled(!viewModel.isConnected)

            Divider()

            DisclosureGroup("Connect manually") {
                HStack {
                    TextField("Phone IP (e.g. 192.168.1.20)", text: $manualIP)
                        .textFieldStyle(.roundedBorder)
                    Button("Connect") {
                        viewModel.connectManually(to: manualIP)
                    }
                    .disabled(manualIP.isEmpty)
                }
                Text("Find your phone's IP in the Android app: the server status line shows it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Divider()

            Button("Open Full Window") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "SMSync" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "SMSync" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Divider()

            Button("Quit SMSync") {
                viewModel.disconnect()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected, .syncing: return .green
        case .discovering, .discovered: return .orange
        case .pairing: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .disconnected: return "Disconnected"
        case .discovering: return "Searching for phone..."
        case .discovered: return "Phone found"
        case .pairing: return "Pairing..."
        case .connected: return "Connected"
        case .syncing: return "Syncing..."
        case .error: return "Error"
        }
    }
}
