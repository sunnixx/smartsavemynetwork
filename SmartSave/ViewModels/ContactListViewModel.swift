import Foundation
import Combine

@MainActor
class ContactListViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var searchText: String = "" {
        didSet { fetch() }
    }

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        fetch()
    }

    func fetch() {
        contacts = persistence.allContacts(searchText: searchText)
    }

    func delete(at offsets: IndexSet) {
        offsets.map { contacts[$0] }.forEach {
            NotificationService.cancel(contactID: $0.id ?? UUID())
            persistence.delete($0)
        }
        fetch()
    }
}
