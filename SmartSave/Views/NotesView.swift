import SwiftUI

struct NotesView: View {
    @Binding var notes: String
    @Binding var nextSteps: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceNotes = VoiceInputService()
    @StateObject private var voiceNextSteps = VoiceInputService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .onChange(of: voiceNotes.transcript) { _, newValue in
                            if !newValue.isEmpty {
                                notes = newValue
                            }
                        }

                    MicButton(service: voiceNotes, existingText: notes)
                } header: {
                    Label("Conversation Notes", systemImage: "text.quote")
                }

                Section {
                    TextEditor(text: $nextSteps)
                        .frame(minHeight: 100)
                        .onChange(of: voiceNextSteps.transcript) { _, newValue in
                            if !newValue.isEmpty {
                                nextSteps = newValue
                            }
                        }

                    MicButton(service: voiceNextSteps, existingText: nextSteps)
                } header: {
                    Label("Next Steps", systemImage: "arrow.right.circle")
                }
            }
            .navigationTitle("Notes & Next Steps")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        voiceNotes.stopRecording()
                        voiceNextSteps.stopRecording()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct MicButton: View {
    @ObservedObject var service: VoiceInputService
    let existingText: String

    var body: some View {
        Button {
            if service.isRecording {
                service.stopRecording()
            } else {
                service.startRecording(appending: existingText)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: service.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title3)
                    .symbolEffect(.pulse, isActive: service.isRecording)
                Text(service.isRecording ? "Stop Recording" : "Speak Notes")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(service.isRecording ? .red : .accentColor)
        }
    }
}
