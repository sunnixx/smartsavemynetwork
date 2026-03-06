import SwiftUI

struct ContactListView: View {
    @StateObject private var vm = ContactListViewModel()
    @State private var showAddSheet = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            if vm.contacts.isEmpty {
                ContentUnavailableView(
                    vm.searchText.isEmpty ? "No Contacts Yet" : "No Results",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text(vm.searchText.isEmpty ? "Tap + to add your first contact." : "Try a different search.")
                )
            } else {
                List {
                    ForEach(vm.contacts, id: \.id) { contact in
                        NavigationLink(value: contact) {
                            ContactRowView(contact: contact)
                        }
                    }
                    .onDelete(perform: vm.delete)
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Search by name, company, email")
        .navigationTitle("Contacts")
        .navigationDestination(for: Contact.self) { contact in
            ContactDetailView(contact: contact, onSave: vm.fetch)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: vm.fetch) {
            AddContactView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openContact)) { note in
            guard let contactID = note.object as? UUID,
                  let contact = vm.contacts.first(where: { $0.id == contactID }) else { return }
            navigationPath.append(contact)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.fetch()
        }
    }
}

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contact.name ?? "Unknown")
                .font(.headline)
            if let company = contact.company, !company.isEmpty {
                Text(company)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .trailing) {
            if let followUp = contact.followUpDate {
                Text(followUp, style: .date)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 4)
            }
        }
    }
}
