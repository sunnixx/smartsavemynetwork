import Foundation
import UIKit

@MainActor
class ContactDetailViewModel: ObservableObject {
    @Published var name: String
    @Published var title: String
    @Published var company: String
    @Published var email: String
    @Published var phone: String
    @Published var conversationNotes: String
    @Published var nextSteps: String
    @Published var followUpDate: Date?
    @Published var cardImage: UIImage?

    let contact: Contact
    private let persistence: PersistenceController
    let onSave: () -> Void

    init(contact: Contact, persistence: PersistenceController = .shared, onSave: @escaping () -> Void) {
        self.contact = contact
        self.persistence = persistence
        self.onSave = onSave

        name = contact.name ?? ""
        title = contact.title ?? ""
        company = contact.company ?? ""
        email = contact.email ?? ""
        phone = contact.phone ?? ""
        conversationNotes = contact.conversationNotes ?? ""
        nextSteps = contact.nextSteps ?? ""
        followUpDate = contact.followUpDate

        if let path = contact.cardImagePath {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(path)
            cardImage = UIImage(contentsOfFile: url.path)
        }
    }

    func save() {
        contact.name = name
        contact.title = title
        contact.company = company
        contact.email = email
        contact.phone = phone
        contact.conversationNotes = conversationNotes
        contact.nextSteps = nextSteps
        contact.followUpDate = followUpDate

        if let date = followUpDate, let id = contact.id {
            NotificationService.schedule(contactID: id, contactName: name, date: date)
        } else if let id = contact.id {
            NotificationService.cancel(contactID: id)
        }

        // Sync edits back to device Contacts
        if let cnId = contact.cnContactIdentifier {
            try? ContactSyncService.updateDeviceContact(
                identifier: cnId,
                name: name,
                title: title.isEmpty ? nil : title,
                company: company.isEmpty ? nil : company,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                conversationNotes: conversationNotes.isEmpty ? nil : conversationNotes,
                nextSteps: nextSteps.isEmpty ? nil : nextSteps,
                followUpDate: followUpDate
            )
        }

        persistence.save()
        onSave()
    }
}
