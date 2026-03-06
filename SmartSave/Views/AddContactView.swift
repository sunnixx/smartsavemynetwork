import SwiftUI

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddContactViewModel()
    @State private var showScanner = false
    @State private var showForm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor.opacity(0.6))

                Text("Add a New Contact")
                    .font(.title2.weight(.semibold))

                VStack(spacing: 14) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Business Card", systemImage: "camera.viewfinder")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        showForm = true
                    } label: {
                        Label("Enter Manually", systemImage: "pencil.line")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.tertiarySystemFill))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal)

                Spacer()
                Spacer()
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                CardScannerView { [vm] parsed, image in
                    Task { @MainActor in
                        vm.populate(from: parsed, image: image)
                        showScanner = false
                        showForm = true
                    }
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
    @StateObject private var voiceNotes = VoiceInputService()
    @StateObject private var voiceNextSteps = VoiceInputService()

    var body: some View {
        NavigationStack {
            Form {
                if let image = vm.cardImage {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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

                Section("Conversation Notes") {
                    TextEditor(text: $vm.conversationNotes)
                        .frame(minHeight: 80)
                        .onChange(of: voiceNotes.transcript) { _, newValue in
                            if !newValue.isEmpty {
                                vm.conversationNotes = newValue
                            }
                        }
                    MicButton(service: voiceNotes, existingText: vm.conversationNotes)
                }

                Section("Next Steps") {
                    TextEditor(text: $vm.nextSteps)
                        .frame(minHeight: 80)
                        .onChange(of: voiceNextSteps.transcript) { _, newValue in
                            if !newValue.isEmpty {
                                vm.nextSteps = newValue
                            }
                        }
                    MicButton(service: voiceNextSteps, existingText: vm.nextSteps)
                }
            }
            .navigationTitle("Contact Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        voiceNotes.stopRecording()
                        voiceNextSteps.stopRecording()
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
