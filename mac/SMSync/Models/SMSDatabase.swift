import Foundation
import CommonCrypto
import CoreData

class SMSDatabase: ObservableObject {
    static let shared = SMSDatabase()

    private let container: NSPersistentContainer

    @Published var conversations: [Conversation] = []

    init() {
        let container = NSPersistentContainer(
            name: "SMSync",
            managedObjectModel: Self.makeModel()
        )

        if let storeURL = SMSDatabase.storeURL {
            let description = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        self.container = container
    }

    static var storeURL: URL? {
        let baseURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            .map { $0.appendingPathComponent("SMSync", isDirectory: true) }
        guard let baseURL else { return nil }
        try? FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )
        return baseURL.appendingPathComponent("SMSync.sqlite")
    }

    private static func makeModel() -> NSManagedObjectModel {
        let messageEntity = NSEntityDescription()
        messageEntity.name = "SMSMessageEntity"
        messageEntity.managedObjectClassName = "SMSMessageEntity"
        messageEntity.properties = [
            NSAttributeDescription(name: "id", type: .integer64AttributeType, optional: false),
            NSAttributeDescription(name: "address", type: .stringAttributeType, optional: false),
            NSAttributeDescription(name: "body", type: .stringAttributeType, optional: false),
            NSAttributeDescription(name: "date", type: .dateAttributeType, optional: false),
            NSAttributeDescription(name: "type", type: .integer16AttributeType, optional: false),
            NSAttributeDescription(name: "read", type: .booleanAttributeType, optional: false),
            NSAttributeDescription(name: "contactName", type: .stringAttributeType, optional: true),
            NSAttributeDescription(name: "threadHash", type: .stringAttributeType, optional: true)
        ]

        let syncStateEntity = NSEntityDescription()
        syncStateEntity.name = "SyncStateEntity"
        syncStateEntity.managedObjectClassName = "SyncStateEntity"
        syncStateEntity.properties = [
            NSAttributeDescription(name: "deviceID", type: .stringAttributeType, optional: true),
            NSAttributeDescription(name: "lastSyncTimestamp", type: .dateAttributeType, optional: true),
            NSAttributeDescription(name: "pairedAt", type: .dateAttributeType, optional: true),
            NSAttributeDescription(name: "totalSynced", type: .integer64AttributeType, optional: false)
        ]

        let model = NSManagedObjectModel()
        model.entities = [messageEntity, syncStateEntity]
        return model
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func insertMessages(_ messages: [SMSSyncClient.SMSMessageJSON]) {
        let context = container.newBackgroundContext()
        context.perform { [weak self] in
            for messageData in messages {
                let fetchRequest: NSFetchRequest<SMSMessageEntity> = SMSMessageEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %lld", messageData.id)

                let exists = (try? context.count(for: fetchRequest)) ?? 0 > 0
                guard !exists else { continue }

                let entity = SMSMessageEntity(context: context)
                entity.id = messageData.id
                entity.address = messageData.address
                entity.body = messageData.body
                entity.date = Date(timeIntervalSince1970: TimeInterval(messageData.date / 1000))
                entity.type = Int16(messageData.type)
                entity.read = messageData.read
                entity.threadHash = self?.computeThreadHash(addresses: [messageData.address])
            }

            try? context.save()
            DispatchQueue.main.async {
                self?.refreshConversations()
            }
        }
    }

    func fetchConversations() -> [Conversation] {
        let fetchRequest: NSFetchRequest<SMSMessageEntity> = SMSMessageEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        guard let entities = try? viewContext.fetch(fetchRequest) else { return [] }

        var threadMap: [String: [SMSMessageEntity]] = [:]
        for entity in entities {
            let hash = entity.threadHash ?? "unknown"
            if threadMap[hash] == nil {
                threadMap[hash] = []
            }
            threadMap[hash]?.append(entity)
        }

        return threadMap.map { hash, messages in
            Conversation(
                id: hash,
                contactName: messages.first?.address ?? "Unknown",
                messages: messages.map { entity in
                    SMSMessage(
                        id: entity.id,
                        address: entity.address ?? "",
                        body: entity.body ?? "",
                        date: Int64((entity.date?.timeIntervalSince1970 ?? 0) * 1000),
                        type: Int(entity.type),
                        read: entity.read
                    )
                }
            )
        }.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    func refreshConversations() {
        conversations = fetchConversations()
    }

    private func computeThreadHash(addresses: [String]) -> String {
        let sorted = addresses.sorted()
        let combined = sorted.joined(separator: ":")
        return combined.sha256()
    }
}

private extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType, optional: Bool) {
        self.init()
        self.name = name
        self.attributeType = type
        self.isOptional = optional
    }
}

extension String {
    func sha256() -> String {
        let data = self.data(using: .utf8)!
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: 32)
            CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}