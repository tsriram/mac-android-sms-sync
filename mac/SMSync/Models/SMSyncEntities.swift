import Foundation
import CoreData

@objc(SMSMessageEntity)
public class SMSMessageEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SMSMessageEntity> {
        return NSFetchRequest<SMSMessageEntity>(entityName: "SMSMessageEntity")
    }

    @NSManaged public var id: Int64
    @NSManaged public var address: String?
    @NSManaged public var body: String?
    @NSManaged public var date: Date?
    @NSManaged public var type: Int16
    @NSManaged public var read: Bool
    @NSManaged public var contactName: String?
    @NSManaged public var threadHash: String?
}

@objc(SyncStateEntity)
public class SyncStateEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncStateEntity> {
        return NSFetchRequest<SyncStateEntity>(entityName: "SyncStateEntity")
    }

    @NSManaged public var deviceID: String?
    @NSManaged public var lastSyncTimestamp: Date?
    @NSManaged public var pairedAt: Date?
    @NSManaged public var totalSynced: Int64
}
