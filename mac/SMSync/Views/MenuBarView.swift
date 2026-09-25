import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: SyncViewModel
    @State private var manualIP = ""
    @State private var confirmClearCache = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            statusCard

            statsCard

            if viewModel.showPairingSheet {
                MenuBarPairingView(viewModel: viewModel)
            }

            VStack(spacing: 2) {
                actionRow(title: "Sync Now", symbol: "arrow.clockwise", disabled: !viewModel.isConnected) {
                    viewModel.connectAndSync()
                }

                DisclosureGroup(isExpanded: $showManualConnect) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("IP e.g. 10.0.0.167", text: $manualIP)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                            Button("Connect") {
                                viewModel.connectManually(to: manualIP)
                                manualIP = ""
                            }
                            .disabled(manualIP.isEmpty)
                            .controlSize(.small)
                        }
                        Text("Found inside the Android app — the server status line shows the IP.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 8)
                    .padding(.leading, 22)
                } label: {
                    Label("Connect manually", systemImage: "link")
                        .font(.system(size: 13))
                }
                .font(.caption)
            }

            Divider()

            VStack(spacing: 2) {
                actionRow(title: "Open Full Window", symbol: "macwindow") {
                    openMainWindow()
                }
                actionRow(title: "Clear Local Cache…", symbol: "trash") {
                    confirmClearCache = true
                }
                actionRow(title: "Quit SMSync", symbol: "power") {
                    viewModel.disconnect()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .alert("Clear Local Cache?", isPresented: $confirmClearCache) {
            Button("Clear Cache", role: .destructive) {
                SMSDatabase.shared.clearCache()
                viewModel.resetAfterCacheClear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All synced SMS data will be deleted from this Mac and re-fetched on the next Sync. Your phone is untouched.")
        }
    }

    @State private var showManualConnect = false

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.85), Color.blue.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 34, height: 34)
                Image(systemName: "message.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 4, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text("SMSync")
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var subtitle: String {
        if let name = viewModel.deviceName {
            return name
        }
        return "Mac ↔ Android SMS sync"
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.18))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                if isActive {
                    Text(activeDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statTile(value: "\(viewModel.messagesSynced)", label: "Messages")
            statDivider
            statTile(value: "\(ContactResolver.shared.phoneContactCount)", label: "Contacts")
            statDivider
            statTile(value: lastSyncShort, label: "Last sync")
        }
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 26)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var lastSyncShort: String {
        guard let date = viewModel.lastSyncDate else { return "—" }
        return date.formatted(.relative(presentation: .named).locale(Locale(identifier: "en")))
    }

    private var isActive: Bool {
        switch viewModel.connectionState {
        case .connected, .syncing: return true
        default: return false
        }
    }

    private var activeDetail: String {
        switch viewModel.connectionState {
        case .syncing: return "Fetching messages…"
        case .connected:
            guard let date = viewModel.lastSyncDate else { return "Up to date" }
            return "Up to date as of \(date.formatted(date: .omitted, time: .shortened))"
        default: return ""
        }
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

    private func actionRow(title: String, symbol: String, role: ButtonRole? = nil, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .foregroundStyle(.primary)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "SMSync" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    struct MenuBarPairingView: View {
        @ObservedObject var viewModel: SyncViewModel
        @State private var enteredPin = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "link.badge.plus")
                        .foregroundStyle(.blue)
                    Text("Pair with phone")
                        .font(.system(size: 13, weight: .semibold))
                }

                if let error = viewModel.pairingError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Text("Enter the 6-digit PIN shown on your phone:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("PIN", text: $enteredPin)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .onChange(of: enteredPin) { newValue in
                            enteredPin = String(newValue.filter { $0.isNumber }.prefix(6))
                        }
                    Button("Pair") {
                        viewModel.completePairing(pin: enteredPin)
                    }
                    .disabled(enteredPin.count != 6)
                    .controlSize(.small)
                }

                HStack {
                    Text("PIN expires in 2 minutes.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        viewModel.cancelPairing()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}