import Foundation

struct SMSMessage: Identifiable {
    let id: Int64
    let address: String
    let body: String
    let date: Int64
    let type: Int
    let read: Bool

    var isOutgoing: Bool {
        type == 2
    }

    var contactName: String? {
        // Will be resolved by ContactResolver
        nil
    }
}
