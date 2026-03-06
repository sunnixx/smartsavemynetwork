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
                Section("Conversation Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .onChange(of: voiceNotes.transcript) { _, newValue in
                            notes = newValue
                        }

                    MicButton(service: voiceNotes, existingText: notes)
                }

                Section("Next Steps") {
                    TextEditor(text: $nextSteps)
                        .frame(minHeight: 100)
                        .onChange(of: voiceNextSteps.transcript) { _, newValue in
                            nextSteps = newValue
                        }

                    MicButton(service: voiceNextSteps, existingText: nextSteps)
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
            Label(
                service.isRecording ? "Stop Recording" : "Speak Notes",
                systemImage: service.isRecording ? "stop.circle.fill" : "mic.circle"
            )
            .foregroundColor(service.isRecording ? .red : .accentColor)
        }
    }
}
