import Speech
import AVFoundation
import Foundation

@MainActor
class VoiceInputService: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    init() {
        recognizer = SFSpeechRecognizer()
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    func startRecording(appending existingText: String) {
        guard !isRecording else { return }

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            return
        }

        task = recognizer?.recognitionTask(with: request!) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let newText = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcript = existingText.isEmpty ? newText : existingText + " " + newText
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isRecording = false
    }
}
