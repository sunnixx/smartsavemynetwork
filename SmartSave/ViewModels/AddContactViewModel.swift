import Foundation
import SwiftUI

@MainActor
class AddContactViewModel: ObservableObject {
    @Published var name = ""
    @Published var title = ""
    @Published var company = ""
    @Published var email = ""
    @Published var phone = ""
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
        if let image = cardImage, let data = image.jpegData(compressionQuality: 0.8) {
            let filename = "\(UUID().uuidString).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
            try? data.write(to: url)
            contact.cardImagePath = filename
        }
        persistence.save()
    }
}
