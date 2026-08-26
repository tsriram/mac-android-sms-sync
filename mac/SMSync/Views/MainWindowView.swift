import SwiftUI

struct MainWindowView: View {
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationSplitView {
            ConversationListView(selectedConversation: $selectedConversation)
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

#Preview {
    MainWindowView()
}
