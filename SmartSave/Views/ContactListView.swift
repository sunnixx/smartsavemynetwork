import SwiftUI

struct ContactListView: View {
    @StateObject private var vm = ContactListViewModel()
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.contacts, id: \.id) { contact in
                    NavigationLink(destination: ContactDetailView(contact: contact, onSave: vm.fetch)) {
                        ContactRowView(contact: contact)
                    }
                }
                .onDelete(perform: vm.delete)
            }
            .searchable(text: $vm.searchText, prompt: "Search by name, company, email")
            .navigationTitle("Contacts")
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
