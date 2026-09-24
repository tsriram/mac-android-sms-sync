import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: SyncViewModel
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ConnectionBanner(viewModel: viewModel)
                ConversationListView(selectedConversation: $selectedConversation, viewModel: viewModel)
            }
        } detail: {
            if let conversation = selectedConversation {
                MessageThreadView(conversation: conversation)
            } else {
                Text("Select a conversation")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

struct ConnectionBanner: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
            Spacer()
            if viewModel.isConnected {
                if let name = viewModel.deviceName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Sync") {
                    viewModel.connectAndSync()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
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
        case .syncing: return "Syncing messages..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
