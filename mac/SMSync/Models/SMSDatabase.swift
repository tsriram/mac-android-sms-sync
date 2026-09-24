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

    func insertMessages(_ messages: [SMSSyncClient.SMSMessageJSON]) async {
        let context = container.newBackgroundContext()
        await context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SMSMessageEntity")
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["id"]
            let existingIDs = Set(((try? context.fetch(fetchRequest)) as? [[String: Any]])?
                    .compactMap { $0["id"] as? NSNumber }
                    .compactMap { $0.int64Value } ?? [])

            for messageData in messages where !existingIDs.contains(messageData.id) {
                let entity = SMSMessageEntity(context: context)
                entity.id = messageData.id
                entity.address = messageData.address
                entity.body = messageData.body
                entity.date = Date(timeIntervalSince1970: TimeInterval(messageData.date / 1000))
                entity.type = Int16(messageData.type)
                entity.read = messageData.read
                entity.threadHash = self.computeThreadHash(addresses: [messageData.address])
            }

            try? context.save()
        }
        await MainActor.run { refreshConversations() }
    }

    func latestMessageDate() -> Int64 {
        let fetchRequest: NSFetchRequest<SMSMessageEntity> = SMSMessageEntity.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        guard let latest = try? viewContext.fetch(fetchRequest).first,
              let date = latest.date else { return 0 }
        return Int64(date.timeIntervalSince1970 * 1000)
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

    func clearCache() {
        let context = container.newBackgroundContext()
        context.performAndWait {
            for entityName in ["SMSMessageEntity", "SyncStateEntity"] {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                do {
                    let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                    if let objectIDs = result?.result as? [NSManagedObjectID] {
                        NSManagedObjectContext.mergeChanges(
                            fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                            into: [container.viewContext]
                        )
                    }
                } catch {
                    print("Failed to clear entity \(entityName): \(error)")
                }
            }
            try? context.save()
        }
        DispatchQueue.main.async {
            self.conversations = []
        }
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