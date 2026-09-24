import SwiftUI

struct MessageThreadView: View {
    let conversation: Conversation

    @State private var showDetails = false
    @ObservedObject private var contacts = ContactResolver.shared

    private let messageGroups: [MessageGroup]

    init(conversation: Conversation) {
        self.conversation = conversation
        let ascending = conversation.messages.sorted { $0.date < $1.date }
        self.messageGroups = MessageGroup.build(from: ascending)
    }

    private var contactName: String {
        ContactResolver.shared.displayName(for: conversation.contactName)
    }

    private var friendlyNumber: String {
        ContactResolver.shared.friendlyPhoneNumber(conversation.contactName)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                MessageScrollView(groups: messageGroups)
            }

            if showDetails {
                ThreadDetailsPanel(
                    name: contactName,
                    phone: friendlyNumber,
                    messageCount: conversation.messages.count,
                    lastMessageDate: conversation.lastMessageDate
                )
                .frame(width: 300)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                ConversationHeader(
                    name: contactName,
                    phone: friendlyNumber,
                    detailsActive: showDetails,
                    onToggleDetails: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showDetails.toggle() } }
                )
            }
        }
        .toolbarBackground(.visible, for: .windowToolbar)
    }
}

struct ConversationHeader: View {
    let name: String
    let phone: String
    let detailsActive: Bool
    let onToggleDetails: () -> Void

    var body: some View {
        Button(action: onToggleDetails) {
            HStack(spacing: 8) {
                if detailsActive {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text(name)
                        .font(.headline)
                        .lineLimit(1)
                    if !phone.isEmpty {
                        Text(phone)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .help("Toggle details")
    }
}

struct MessageScrollView: View {
    let groups: [MessageGroup]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(groups) { group in
                        if group.isDateSeparator {
                            DateSeparator(day: group.date)
                        } else {
                            MessageGroupView(group: group)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(nsColor: .textBackgroundColor),
                                 Color(nsColor: .windowBackgroundColor)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .onAppear {
                if let last = groups.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

struct ThreadDetailsPanel: View {
    let name: String
    let phone: String
    let messageCount: Int
    let lastMessageDate: Date

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                AvatarView(name: name, size: 72)
                    .padding(.top, 24)

                Text(name)
                    .font(.title2)
                    .multilineTextAlignment(.center)

                if !phone.isEmpty {
                    Text(phone)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text("\(messageCount) messages")
                } icon: {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                }

                Label {
                    Text("Last activity \(lastMessageDate.formatted(date: .abbreviated, time: .shortened))")
                } icon: {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.body)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            Text("SMS shown read-only")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .background(.background)
    }
}

struct MessageGroup: Identifiable {
    let date: Date
    let messages: [SMSMessage]
    let isOutgoing: Bool
    var isDateSeparator = false

    var id: Date { date }

    static func build(from messages: [SMSMessage]) -> [MessageGroup] {
        var groups: [MessageGroup] = []
        var currentDay: Date?
        var currentMessages: [SMSMessage] = []
        var currentOutgoing: Bool?

        let calendar = Calendar.current

        func flush() {
            guard !currentMessages.isEmpty else { return }
            groups.append(MessageGroup(
                date: Date(timeIntervalSince1970: TimeInterval(currentMessages.last!.date / 1000)),
                messages: currentMessages,
                isOutgoing: currentOutgoing ?? false
            ))
            currentMessages = []
            currentOutgoing = nil
        }

        for message in messages {
            let messageDay = calendar.startOfDay(
                for: Date(timeIntervalSince1970: TimeInterval(message.date / 1000))
            )

            if let day = currentDay, day != messageDay {
                groups.append(MessageGroup(date: messageDay, messages: [], isOutgoing: false, isDateSeparator: true))
            }

            let isOutgoing = message.isOutgoing

            if let forced = currentOutgoing, forced != isOutgoing {
                flush()
            }

            if let last = currentMessages.last,
               abs(last.date - message.date) > 15 * 60 * 1000 {
                flush()
            }

            currentDay = messageDay
            currentOutgoing = isOutgoing
            currentMessages.append(message)
        }
        flush()

        return groups
    }
}

struct DateSeparator: View {
    let day: Date

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        if calendar.isDate(day, equalTo: Date(), toGranularity: .weekOfYear) {
            return day.formatted(.dateTime.weekday(.wide))
        }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.thinMaterial, in: Capsule())
            .padding(.vertical, 6)
    }
}

struct MessageGroupView: View {
    let group: MessageGroup

    var body: some View {
        VStack(alignment: group.isOutgoing ? .trailing : .leading, spacing: 2) {
            ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                bubble(for: message, at: index)
            }

            Text(group.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, alignment: group.isOutgoing ? .trailing : .leading)
    }

    private func bubble(for message: SMSMessage, at index: Int) -> some View {
        let isLast = index == group.messages.count - 1
        let isFirst = index == 0

        return HStack {
            if group.isOutgoing { Spacer(minLength: 64) }

            Text(message.body)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(bubbleColor)
                        .mask(bubbleShape(isFirst: isFirst, isLast: isLast))
                )
                .foregroundColor(group.isOutgoing ? .white : .primary)

            if !group.isOutgoing { Spacer(minLength: 64) }
        }
    }

    private var bubbleColor: Color {
        group.isOutgoing ? .blue : Color(nsColor: .controlBackgroundColor)
    }

    private func bubbleShape(isFirst: Bool, isLast: Bool) -> some View {
        let tailRadius: CGFloat = 5
        let mainRadius: CGFloat = 16
        let side: Edge = group.isOutgoing ? .trailing : .leading

        return UnevenRoundedRectangle(
            topLeadingRadius: side == .leading && isFirst ? tailRadius : mainRadius,
            bottomLeadingRadius: side == .leading && isLast ? tailRadius : mainRadius,
            bottomTrailingRadius: side == .trailing && isLast ? tailRadius : mainRadius,
            topTrailingRadius: side == .trailing && isFirst ? tailRadius : mainRadius,
            style: .continuous
        )
    }
}
