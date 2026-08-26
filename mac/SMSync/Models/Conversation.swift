import Foundation

struct Conversation: Identifiable, Hashable {
    let id: String
    let contactName: String
    let messages: [SMSMessage]

    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var lastMessage: SMSMessage? {
        messages.last
    }

    var lastMessageDate: Date {
        if let last = lastMessage {
            return Date(timeIntervalSince1970: TimeInterval(last.date / 1000))
        }
        return Date.distantPast
    }

    var unreadCount: Int {
        messages.filter { !$0.read }.count
    }

    var preview: String {
        lastMessage?.body ?? ""
    }
}
