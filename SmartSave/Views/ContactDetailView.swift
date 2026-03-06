import SwiftUI

struct ContactDetailView: View {
    @StateObject private var vm: ContactDetailViewModel
    @State private var showNotes = false
    @State private var showReminderPicker = false

    init(contact: Contact, onSave: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ContactDetailViewModel(contact: contact, onSave: onSave))
    }

    var body: some View {
        List {
            if let image = vm.cardImage {
                Section("Business Card") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .cornerRadius(8)
                }
            }

            Section("Contact Info") {
                DetailRow(label: "Name", value: vm.name)
                DetailRow(label: "Title", value: vm.title)
                DetailRow(label: "Company", value: vm.company)
                DetailRow(label: "Email", value: vm.email)
                DetailRow(label: "Phone", value: vm.phone)
            }

            Section("Conversation Notes") {
                if vm.conversationNotes.isEmpty {
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                } else {
                    Text(vm.conversationNotes)
                }
                Button("Edit Notes") { showNotes = true }
                    .foregroundColor(.accentColor)
            }

            Section("Next Steps") {
                if vm.nextSteps.isEmpty {
                    Text("No next steps")
                        .foregroundColor(.secondary)
                } else {
                    Text(vm.nextSteps)
                }
                Button("Edit Next Steps") { showNotes = true }
                    .foregroundColor(.accentColor)
            }

            Section("Follow-up Reminder") {
                if let date = vm.followUpDate {
                    HStack {
                        Text(date, style: .date)
                        Spacer()
                        Text(date, style: .time)
                            .foregroundColor(.secondary)
                    }
                    Button("Remove Reminder") {
                        vm.followUpDate = nil
                        vm.save()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Set Reminder") { showReminderPicker = true }
                        .foregroundColor(.accentColor)
                }
            }
        }
        .navigationTitle(vm.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showNotes, onDismiss: vm.save) {
            NotesPlaceholderView(notes: $vm.conversationNotes, nextSteps: $vm.nextSteps)
        }
        .sheet(isPresented: $showReminderPicker) {
            ReminderPlaceholderView(selectedDate: $vm.followUpDate, onConfirm: {
                showReminderPicker = false
                vm.save()
            })
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "\u{2014}" : value)
        }
    }
}

// Temporary placeholder - will be replaced in Task 9
struct NotesPlaceholderView: View {
    @Binding var notes: String
    @Binding var nextSteps: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Conversation Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
                Section("Next Steps") {
                    TextEditor(text: $nextSteps)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Notes & Next Steps")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// Temporary placeholder - will be replaced in Task 10
struct ReminderPlaceholderView: View {
    @Binding var selectedDate: Date?
    let onConfirm: () -> Void
    @State private var pickedDate = Date().addingTimeInterval(86400)

    var body: some View {
        NavigationStack {
            DatePicker("Follow-up Date", selection: $pickedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Set Reminder")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onConfirm() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set") {
                            selectedDate = pickedDate
                            onConfirm()
                        }
                    }
                }
        }
    }
}
