import SwiftUI

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddContactViewModel()
    @State private var showScanner = false
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Button {
                    showScanner = true
                } label: {
                    Label("Scan Business Card", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    showForm = true
                } label: {
                    Label("Enter Manually", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                CardScannerView { parsed, image in
                    vm.populate(from: parsed, image: image)
                    showScanner = false
                    showForm = true
                }
            }
            .sheet(isPresented: $showForm) {
                ContactFormView(vm: vm, onSave: {
                    vm.save()
                    dismiss()
                })
            }
        }
    }
}

struct ContactFormView: View {
    @ObservedObject var vm: AddContactViewModel
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let image = vm.cardImage {
                    Section("Card") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .cornerRadius(8)
                    }
                }
                Section("Contact Info") {
                    TextField("Name *", text: $vm.name)
                    TextField("Title", text: $vm.title)
                    TextField("Company", text: $vm.company)
                    TextField("Email", text: $vm.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $vm.phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Contact Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
