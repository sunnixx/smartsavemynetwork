import CoreData
import Foundation

@objc(Contact)
public class Contact: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var title: String?
    @NSManaged public var company: String?
    @NSManaged public var email: String?
    @NSManaged public var phone: String?
    @NSManaged public var cardImagePath: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var conversationNotes: String?
    @NSManaged public var nextSteps: String?
    @NSManaged public var followUpDate: Date?
}

extension Contact {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Contact> {
        return NSFetchRequest<Contact>(entityName: "Contact")
    }
}
