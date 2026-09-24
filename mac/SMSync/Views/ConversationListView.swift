import SwiftUI

private let sidebarTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
}()

private let sidebarDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMM"
    return formatter
}()

struct ConversationListView: View {
    @Binding var selectedThreadHash: String?
    @ObservedObject var viewModel: SyncViewModel
    @ObservedObject private var database = SMSDatabase.shared
    @ObservedObject private var contacts = ContactResolver.shared
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            sidebarSearchField

            Divider()

            List(selection: $selectedThreadHash) {
                ForEach(filteredConversations) { conversation in
                    ConversationRow(conversation: conversation)
                        .tag(conversation.id)
                }
            }
            .listStyle(.plain)
        }
        .onAppear {
            database.refreshConversations()
        }
        .onChange(of: viewModel.messagesSynced) { _ in
            database.refreshConversations()
        }
    }

    private var sidebarSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search conversations", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var filteredConversations: [Conversation] {
        let contacts = ContactResolver.shared
        if searchText.isEmpty {
            return database.conversations
        }
        return database.conversations.filter {
            let name = contacts.displayName(for: $0.contactName)
            return name.localizedCaseInsensitiveContains(searchText)
                || $0.contactName.localizedCaseInsensitiveContains(searchText)
                || $0.preview.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    @ObservedObject private var contacts = ContactResolver.shared

    private var contactName: String {
        contacts.displayName(for: conversation.contactName)
    }

    private var hasUnread: Bool {
        conversation.unreadCount > 0
    }

    private var lastMessageTime: String {
        let date = conversation.lastMessageDate
        if Calendar.current.isDateInToday(date) {
            return sidebarTimeFormatter.string(from: date)
        } else {
            return sidebarDateFormatter.string(from: date)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: contactName, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(contactName)
                        .font(.system(size: 13, weight: hasUnread ? .semibold : .medium))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(lastMessageTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text(conversation.preview)
                        .font(.system(size: 12))
                        .foregroundStyle(hasUnread ? .primary : .secondary)
                        .lineLimit(1)

                    if hasUnread {
                        Spacer(minLength: 8)
                        Circle()
                            .fill(.blue)
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}