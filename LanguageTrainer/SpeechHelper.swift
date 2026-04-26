import Foundation
import AVFoundation

@MainActor
final class SpeechHelper: ObservableObject {
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String, languageCode: String, volume: Float = 1.0) {
        let cleaned = SpeechHelper.stripParentheses(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return }

        configureAudioSessionForTTS()

        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = bestVoice(for: languageCode)
        utterance.rate = 0.48
        utterance.volume = max(0, min(volume, 1))

        synth.speak(utterance)
    }

    private func bestVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(languageCodePrefix(for: languageCode)) }

        if let premium = voices.first(where: { $0.quality == .premium }) {
            return premium
        }

        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }

        return AVSpeechSynthesisVoice(language: languageCode) ?? voices.first
    }

    private func languageCodePrefix(for languageCode: String) -> String {
        if languageCode.hasPrefix("fr") { return "fr" }
        if languageCode.hasPrefix("es") { return "es" }
        return languageCode
    }

    private func configureAudioSessionForTTS() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            print("⚠️ Audio session (TTS) error:", error.localizedDescription)
        }
    }

    static func stripParentheses(_ s: String) -> String {
        var out = s
        while let start = out.firstIndex(of: "("),
              let end = out[start...].firstIndex(of: ")") {
            out.removeSubrange(start...end)
        }
        while out.contains("  ") {
            out = out.replacingOccurrences(of: "  ", with: " ")
        }
        return out
    }
}
