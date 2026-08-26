import SwiftUI

struct MenuBarView: View {
    @StateObject private var discovery = BonjourDiscovery()
    @StateObject private var syncClient = SMSSyncClient()
    @StateObject private var pairingManager = PairingManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(discovery.discoveredDevice != nil ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(discovery.discoveredDevice != nil ? "Connected" : "Searching...")
                    .font(.caption)
                Spacer()
            }

            Divider()

            if let device = discovery.discoveredDevice {
                Text(device.name)
                    .font(.headline)
            }

            Button("Sync Now") {
                Task {
                    await performSync()
                }
            }
            .disabled(discovery.discoveredDevice == nil)

            Divider()

            Button("Open Full Window") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "SMSync" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Settings...") {
                // TODO: Open settings
            }

            Divider()

            Button("Quit SMSync") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            discovery.startDiscovery()
        }
        .onDisappear {
            discovery.stopDiscovery()
        }
    }

    private func performSync() async {
        guard let device = discovery.discoveredDevice else { return }
        syncClient.configure(host: device.hostName, port: device.port)
        // TODO: Trigger full sync
    }
}

#Preview {
    MenuBarView()
}
