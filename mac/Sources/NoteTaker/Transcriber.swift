import AVFoundation
import Speech

@MainActor
final class Transcriber: ObservableObject {
    @Published var transcript: String = ""
    @Published var partial: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    // Bumped on every restart. Callbacks from a superseded session carry a
    // stale value and are ignored, so one dying session can't spawn two.
    private var generation = 0

    func toggle() {
        isRecording ? stop() : start()
    }

    func clear() {
        transcript = ""
        partial = ""
    }

    private func start() {
        errorMessage = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self else { return }
            Task { @MainActor in
                guard authStatus == .authorized else {
                    self.errorMessage = "Speech recognition permission was denied. Enable it in System Settings > Privacy & Security > Speech Recognition."
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Task { @MainActor in
                        guard granted else {
                            self.errorMessage = "Microphone permission was denied. Enable it in System Settings > Privacy & Security > Microphone."
                            return
                        }
                        self.beginRecording()
                    }
                }
            }
        }
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer is unavailable right now."
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Could not start the audio engine: \(error.localizedDescription)"
            inputNode.removeTap(onBus: 0)
            return
        }

        isRecording = true
        startRecognitionTask()
    }

    // SFSpeechRecognizer caps a single recognition session at roughly a minute
    // (on-device sessions are similarly time-limited), but a lecture runs far
    // longer. So every time a session ends (final result, error, or the
    // recognizer closing the task) we flush its text into `transcript` and,
    // as long as the user hasn't stopped recording, silently spin up a new
    // request on the still-running audio engine so no words are missed.
    private func startRecognitionTask() {
        guard let recognizer else { return }

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            newRequest.requiresOnDeviceRecognition = true
        }
        request = newRequest
        generation += 1
        let gen = generation

        task = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                guard gen == self.generation else { return }
                if let result {
                    if result.isFinal {
                        self.appendFinal(result.bestTranscription.formattedString)
                        self.restartIfNeeded()
                    } else {
                        self.partial = result.bestTranscription.formattedString
                    }
                }
                if let error {
                    let nsError = error as NSError
                    // Session end/no-speech errors are expected at the ~1 minute
                    // boundary; only surface unexpected ones to the user.
                    if nsError.domain != "kAFAssistantErrorDomain" {
                        self.errorMessage = error.localizedDescription
                    }
                    self.restartIfNeeded()
                }
            }
        }
    }

    private func restartIfNeeded() {
        guard isRecording else { return }
        task?.cancel()
        request?.endAudio()
        request = nil
        task = nil
        startRecognitionTask()
    }

    private func appendFinal(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        transcript = transcript.isEmpty ? trimmed : transcript + " " + trimmed
        partial = ""
    }

    private func stop() {
        isRecording = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        if !partial.isEmpty {
            appendFinal(partial)
        }

        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        partial = ""
    }
}
