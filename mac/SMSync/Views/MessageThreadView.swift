import SwiftUI

struct MessageThreadView: View {
    let conversation: Conversation

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversation.messages, id: \.id) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if let lastMessage = conversation.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack {
                Text("Reply from Mac not supported in V1")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle(conversation.contactName)
    }
}

struct MessageBubble: View {
    let message: SMSMessage

    var isOutgoing: Bool {
        message.type == 2
    }

    var body: some View {
        HStack {
            if isOutgoing { Spacer() }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOutgoing ? Color.blue : Color(nsColor: .controlBackgroundColor))
                    .foregroundColor(isOutgoing ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(Date(timeIntervalSince1970: TimeInterval(message.date / 1000)), style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if !isOutgoing { Spacer() }
        }
    }
}
