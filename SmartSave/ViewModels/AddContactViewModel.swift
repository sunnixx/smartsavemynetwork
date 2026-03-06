import Foundation
import SwiftUI

@MainActor
class AddContactViewModel: ObservableObject {
    @Published var name = ""
    @Published var title = ""
    @Published var company = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var conversationNotes = ""
    @Published var nextSteps = ""
    @Published var cardImage: UIImage?

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func populate(from parsed: ParsedCard, image: UIImage?) {
        name = parsed.name ?? ""
        title = parsed.title ?? ""
        company = parsed.company ?? ""
        email = parsed.email ?? ""
        phone = parsed.phone ?? ""
        cardImage = image
    }

    func save() {
        let contact = persistence.createContact(name: name)
        contact.title = title
        contact.company = company
        contact.email = email
        contact.phone = phone
        contact.conversationNotes = conversationNotes
        contact.nextSteps = nextSteps

        // Save card image to Documents (for in-app use)
        if let image = cardImage, let data = image.jpegData(compressionQuality: 0.8) {
            let filename = "\(UUID().uuidString).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            try? data.write(to: url)
            contact.cardImagePath = filename

            // Save to Photos library for persistence
            if let assetId = try? PhotoSyncService.saveImage(image, contactName: name) {
                contact.photoAssetIdentifier = assetId
            }
        }

        // Auto-save to device Contacts for persistence
        if let cnId = try? ContactSyncService.saveToDeviceContacts(
            name: name,
            title: title.isEmpty ? nil : title,
            company: company.isEmpty ? nil : company,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            conversationNotes: conversationNotes.isEmpty ? nil : conversationNotes,
            nextSteps: nextSteps.isEmpty ? nil : nextSteps,
            followUpDate: nil
        ) {
            contact.cnContactIdentifier = cnId
        }

        persistence.save()
    }
}
