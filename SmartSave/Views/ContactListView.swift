import SwiftUI

struct ContactListView: View {
    @StateObject private var vm = ContactListViewModel()
    @State private var showAddSheet = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if vm.contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.system(size: 56))
                            .foregroundStyle(.tertiary)
                        Text(vm.searchText.isEmpty ? "No Contacts Yet" : "No Results")
                            .font(.title2.weight(.semibold))
                        Text(vm.searchText.isEmpty ? "Tap + to save your first contact." : "Try a different search.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(vm.contacts, id: \.id) { contact in
                            NavigationLink(value: contact) {
                                ContactRowView(contact: contact)
                            }
                        }
                        .onDelete(perform: vm.delete)
                    }
                    .listStyle(.plain)
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
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: vm.fetch) {
                AddContactView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openContact)) { note in
            guard let contactID = note.object as? UUID,
                  let contact = vm.contacts.first(where: { $0.id == contactID }) else { return }
            navigationPath.append(contact)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.fetch()
        }
        .task {
            _ = await ContactSyncService.requestAccess()
            _ = await PhotoSyncService.requestAccess()
        }
    }
}

struct ContactRowView: View {
    let contact: Contact

    private var initials: String {
        let name = contact.name ?? ""
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.7), .accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Text(initials)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name ?? "Unknown")
                    .font(.body.weight(.medium))
                if let company = contact.company, !company.isEmpty {
                    Text(company)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let title = contact.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let followUp = contact.followUpDate {
                VStack(spacing: 2) {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                    Text(followUp, style: .date)
                        .font(.caption2)
                }
                .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}
