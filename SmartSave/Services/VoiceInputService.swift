import Speech
import AVFoundation
import Foundation

// Not @MainActor — handles audio on whatever thread the system uses
private final class AudioBridge: @unchecked Sendable {
    private let engine: AVAudioEngine
    private let request: SFSpeechAudioBufferRecognitionRequest

    init(engine: AVAudioEngine, request: SFSpeechAudioBufferRecognitionRequest) {
        self.engine = engine
        self.request = request
    }

    func startTap() throws {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "VoiceInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"])
        }

        let req = request
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        try engine.start()
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request.endAudio()
    }
}

@MainActor
class VoiceInputService: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var needsPermission = false

    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var bridge: AudioBridge?

    func startRecording(appending existingText: String) {
        if isRecording {
            stopRecording()
            return
        }

        let micStatus = AVAudioApplication.shared.recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        // If both granted, record immediately
        if micStatus == .granted && speechStatus == .authorized {
            beginRecording(appending: existingText)
            return
        }

        // Need to request permissions — just request, don't auto-record
        requestPermissions()
    }

    private func requestPermissions() {
        Task {
            // Request mic permission off main actor
            let micGranted: Bool = await {
                if #available(iOS 17.0, *) {
                    return await AVAudioApplication.requestRecordPermission()
                } else {
                    return await withCheckedContinuation { c in
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            c.resume(returning: granted)
                        }
                    }
                }
            }()

            guard micGranted else {
                needsPermission = true
                return
            }

            // Request speech permission
            let speechGranted = await withCheckedContinuation { c in
                SFSpeechRecognizer.requestAuthorization { status in
                    c.resume(returning: status == .authorized)
                }
            }

            guard speechGranted else {
                needsPermission = true
                return
            }
            // Permissions granted — user can tap mic again to start recording
        }
    }

    private func beginRecording(appending existingText: String) {
        recognizer = SFSpeechRecognizer()
        guard recognizer?.isAvailable == true else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let audioBridge = AudioBridge(engine: engine, request: request)
        self.bridge = audioBridge

        do {
            try audioBridge.startTap()
        } catch {
            self.bridge = nil
            return
        }

        isRecording = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let newText = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.transcript = existingText.isEmpty ? newText : existingText + " " + newText
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor [weak self] in
                    self?.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        bridge?.stop()
        task?.cancel()
        bridge = nil
        task = nil
        recognizer = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
