import AVFoundation

func printFrenchVoices() {
    let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("fr") }

    for v in voices {
        print("name: \(v.name)")
        print("id: \(v.identifier)")
        print("lang: \(v.language)")
        print("quality: \(v.quality.rawValue)")
        print("-----")
    }
}
