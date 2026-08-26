import SwiftUI

struct ConversationListView: View {
    @Binding var selectedConversation: Conversation?
    @State private var searchText = ""

    var body: some View {
        List(selection: $selectedConversation) {
            ForEach(filteredConversations) { conversation in
                ConversationRow(conversation: conversation)
                    .tag(conversation)
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations")
        .navigationTitle("Conversations")
    }

    private var filteredConversations: [Conversation] {
        // TODO: Filter from database
        []
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.contactName)
                    .font(.headline)
                Text(conversation.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.lastMessageDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationListView(selectedConversation: .constant(nil))
}
