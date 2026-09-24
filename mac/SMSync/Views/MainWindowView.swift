import SwiftUI

struct MainWindowView: View {
    @ObservedObject var viewModel: SyncViewModel
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ConversationListView(selectedConversation: $selectedConversation, viewModel: viewModel)
            }
            .frame(minWidth: 280, idealWidth: 320)
            .background(.bar)
        } detail: {
            if let conversation = selectedConversation {
                MessageThreadView(conversation: conversation)
                    .id(conversation.id)
            } else {
                EmptyConversationView()
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

struct EmptyConversationView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Conversation Selected")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .textBackgroundColor),
                         Color(nsColor: .windowBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
