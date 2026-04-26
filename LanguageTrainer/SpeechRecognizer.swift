import Foundation
import Speech
import AVFAudio

@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {

    @Published var transcript: String = ""
    @Published var isRunning: Bool = false
    @Published var errorMessage: String? = nil

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init(locale: Locale) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        super.init()
    }

    func clearError() {
        errorMessage = nil
    }

    func requestPermissions() async -> Bool {
        clearError()

        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        guard speechOK else {
            errorMessage = "Speech permission not granted."
            return false
        }

        let micOK: Bool
        if #available(iOS 17.0, *) {
            micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { ok in
                    cont.resume(returning: ok)
                }
            }
        } else {
            micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    cont.resume(returning: ok)
                }
            }
        }

        guard micOK else {
            errorMessage = "Microphone permission not granted."
            return false
        }

        return true
    }

    func start(languageCode: String = "fr-FR") {
        clearError()
        transcript = ""

        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recogniser unavailable."
            return
        }

        stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try session.setActive(true)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = false

        request = req
        isRunning = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Audio engine failed: \(error.localizedDescription)"
            isRunning = false
            return
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.transcript = result.bestTranscription.formattedString
            }

            guard let error else { return }

            let msg = error.localizedDescription.lowercased()
            let isHarmless =
                msg.contains("no speech") ||
                msg.contains("speech was not detected") ||
                msg.contains("canceled") ||
                msg.contains("cancelled") ||
                msg.contains("cancelled by user") ||
                msg.contains("recognition request was cancelled")

            if isHarmless {
                return
            }

            self.errorMessage = error.localizedDescription
            self.stop()
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        request?.endAudio()
        task?.cancel()

        request = nil
        task = nil
        isRunning = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
