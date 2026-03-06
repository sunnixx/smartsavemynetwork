import CoreData

final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SmartSave")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("CoreData load error: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext { container.viewContext }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    // MARK: - CRUD

    func createContact(name: String) -> Contact {
        let contact = Contact(context: context)
        contact.id = UUID()
        contact.name = name
        contact.createdAt = Date()
        save()
        return contact
    }

    func delete(_ contact: Contact) {
        context.delete(contact)
        save()
    }

    func allContacts(searchText: String = "") -> [Contact] {
        let request = Contact.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        if !searchText.isEmpty {
            request.predicate = NSPredicate(
                format: "name CONTAINS[cd] %@ OR company CONTAINS[cd] %@ OR email CONTAINS[cd] %@",
                searchText, searchText, searchText
            )
        }
        return (try? context.fetch(request)) ?? []
    }

    func importFromDeviceContactsIfNeeded() {
        let request = Contact.fetchRequest()
        request.fetchLimit = 1
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }

        guard let imported = try? ContactSyncService.importFromDeviceContacts(), !imported.isEmpty else { return }

        for item in imported {
            let contact = Contact(context: context)
            contact.id = UUID()
            contact.name = item.name
            contact.title = item.title
            contact.company = item.company
            contact.email = item.email
            contact.phone = item.phone
            contact.conversationNotes = item.conversationNotes
            contact.nextSteps = item.nextSteps
            contact.followUpDate = item.followUpDate
            contact.cnContactIdentifier = item.cnIdentifier
            contact.createdAt = Date()

            if let date = item.followUpDate, date > Date(), let id = contact.id {
                NotificationService.schedule(contactID: id, contactName: item.name, date: date)
            }
        }

        save()
    }
}
