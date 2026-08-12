import SwiftUI
import UIKit

struct SpeakView: View {
    let language: AppLanguage
    let terms: [TermPair]

    let totalQsOverride: Int?
    let onFinished: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = SpeechHelper()
    @StateObject private var stt: SpeechRecognizer

    // Queue
    private var totalQs: Int { totalQsOverride ?? 10 }
    private let passRatio: Double = 0.75
    private let graceSeconds: Double = 10

    // ✅ Keeps SpeakView sentences manageable
    private let minSpeakWords = 3
    private let maxSpeakWords = 22
    private let maxSpeakCharacters = 150
    private let maxSentenceChunks = 2

    @State private var queue: [TermPair] = []
    @State private var index: Int = 0
    @State private var current: TermPair? = nil
    @State private var isDone: Bool = false

    // Recognition state
    @State private var recognisedIndices: Set<Int> = []
    @State private var graceActive: Bool = false
    @State private var graceDeadline: Date? = nil
    @State private var graceWorkItem: DispatchWorkItem? = nil

    // UI state
    @State private var mainButtonMode: MainButtonMode = .speak

    enum MainButtonMode {
        case speak
        case keepGoing
        case next
    }

    init(
        language: AppLanguage,
        terms: [TermPair],
        totalQsOverride: Int? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        self.language = language
        self.terms = terms
        self.totalQsOverride = totalQsOverride
        self.onFinished = onFinished

        let localeID = (language == .french) ? "fr-FR" : "es-ES"
        _stt = StateObject(wrappedValue: SpeechRecognizer(locale: Locale(identifier: localeID)))
    }

    // MARK: - Inline sentence styling

    private struct SpeakInlineWord: View {
        let word: String
        let isRecognised: Bool

        var body: some View {
            Text(word)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.vertical, 2)
                .background(isRecognised ? Color.cyan.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(alignment: .bottom) {
                    DottedUnderline(
                        color: isRecognised
                            ? Color.cyan.opacity(0.9)
                            : Color.white.opacity(0.55)
                    )
                    .offset(y: 4)
                }
        }
    }

    private struct DottedUnderline: View {
        let color: Color

        var body: some View {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: 1000, y: 0.5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [1.5, 3.0]))
            .foregroundColor(color)
            .frame(height: 1)
            .clipped()
        }
    }

    // MARK: - Config

    private var speechCode: String {
        switch language {
        case .french:
            return "fr-FR"
        case .spanish:
            return "es-ES"
        }
    }

    // ✅ SpeakView uses sentence terms, but filters out the massive ones
    private var eligible: [TermPair] {
        terms.filter { term in
            let cleaned = cleanForSpeak(term.foreign)
            let words = wordCount(cleaned)
            let chunks = sentenceChunkCount(cleaned)

            return !cleaned.isEmpty
                && words >= minSpeakWords
                && words <= maxSpeakWords
                && cleaned.count <= maxSpeakCharacters
                && chunks <= maxSentenceChunks
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isDone {
                doneView
            } else {
                mainView
            }
        }
        .onAppear {
            startQueue()
            Task {
                _ = await stt.requestPermissions()
            }
        }
        .onChange(of: stt.transcript) { _, newValue in
            handleTranscript(newValue)
        }
        .onDisappear {
            stt.stop()
            cancelGrace()
        }
    }

    private var mainView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Question \(min(index + 1, queue.count)) / \(max(queue.count, 1))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                if stt.isRunning {
                    Text("Listening…")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            HStack(alignment: .top, spacing: 10) {
                Text(current?.english ?? "")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity)

                if let current {
                    ContextHelpButton(context: current.context)
                }
            }
            .padding(.horizontal, 18)

            sentenceView
                .padding(.horizontal, 18)

            HStack(spacing: 12) {
                Button {
                    prepareForPlayback()

                    if let foreign = current?.foreign {
                        speaker.speak(cleanForSpeak(foreign), languageCode: speechCode)
                    }
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(12)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    skip()
                } label: {
                    Text("Skip")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)

            Button(action: handleMain) {
                HStack(spacing: 8) {
                    if mainButtonMode == .speak {
                        Image(systemName: "mic.fill")
                    }

                    Text(mainTitle)
                }
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(mainButtonColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 2)

            if shouldShowError, let err = stt.errorMessage {
                Text(err)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
            }

            Spacer()
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Well done!")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("You finished the speaking exercise.")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                startQueue()
            } label: {
                Text("Restart")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.90))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            Button {
                dismiss()
            } label: {
                Text("Home")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            Spacer()
        }
    }

    // MARK: - Error gating

    private var shouldShowError: Bool {
        guard mainButtonMode == .speak, stt.isRunning else { return false }
        guard let msg = stt.errorMessage, !msg.isEmpty else { return false }

        let m = msg.lowercased()

        if m.contains("cancelled") || m.contains("canceled") {
            return false
        }

        if m.contains("no speech detected") {
            return false
        }

        return true
    }

    // MARK: - Sentence view

    private struct WordToken: Identifiable, Hashable {
        let id: Int
        let word: String
    }

    private var sentenceView: some View {
        let cleanedSentence = cleanForSpeak(current?.foreign ?? "")

        let rawWords = cleanedSentence
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        let tokens: [WordToken] = rawWords.enumerated().map {
            WordToken(id: $0.offset, word: $0.element)
        }

        return VStack(spacing: 10) {
            Wrap(words: tokens, spacing: 6, lineSpacing: 10) { token in
                Button {
                    prepareForPlayback()

                    let spoken = tappableWordForSpeech(token.word)
                    guard !spoken.isEmpty else { return }

                    speaker.speak(spoken, languageCode: speechCode)
                } label: {
                    SpeakInlineWord(
                        word: token.word,
                        isRecognised: recognisedIndices.contains(token.id)
                    )
                }
                .buttonStyle(.plain)
            }

            if graceActive, let deadline = graceDeadline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let secondsLeft = max(0, Int(ceil(deadline.timeIntervalSince(context.date))))

                    Text("Keep going… \(secondsLeft)s")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var mainTitle: String {
        switch mainButtonMode {
        case .speak:
            return "Speak"
        case .keepGoing:
            return "Keep going…"
        case .next:
            return index >= queue.count - 1 ? "Finish" : "Next"
        }
    }

    private var mainButtonColor: Color {
        switch mainButtonMode {
        case .speak:
            return Color.green.opacity(0.90)
        case .keepGoing:
            return Color.orange.opacity(0.90)
        case .next:
            return Color.green.opacity(0.90)
        }
    }

    // MARK: - Flow

    private func startQueue() {
        let pool = eligible

        guard !pool.isEmpty else {
            queue = []
            current = nil
            isDone = false
            return
        }

        queue = Array(pool.fisherYatesShuffled().prefix(min(totalQs, pool.count)))
        index = 0
        isDone = false
        loadCurrent()
    }

    private func loadCurrent() {
        stt.stop()
        stt.clearError()
        cancelGrace()

        recognisedIndices = []
        mainButtonMode = .speak

        guard index < queue.count else {
            current = nil
            return
        }

        current = queue[index]

        if let foreign = current?.foreign {
            speaker.speak(cleanForSpeak(foreign), languageCode: speechCode)
        }
    }

    private func handleMain() {
        switch mainButtonMode {
        case .speak:
            stt.clearError()
            stt.start(languageCode: speechCode)

        case .keepGoing:
            break

        case .next:
            next()
        }
    }

    private func next() {
        stt.stop()
        stt.clearError()
        cancelGrace()

        let nextIndex = index + 1

        if nextIndex >= queue.count {
            if let onFinished {
                onFinished()
            } else {
                current = nil
                isDone = true
            }
        } else {
            index = nextIndex
            loadCurrent()
        }
    }

    private func skip() {
        stt.stop()
        stt.clearError()
        cancelGrace()
        next()
    }

    private func prepareForPlayback() {
        stt.stop()
        stt.clearError()

        if graceActive {
            cancelGrace()

            if mainButtonMode != .next {
                mainButtonMode = .speak
            }
        }
    }

    // MARK: - Matching logic

    private func handleTranscript(_ raw: String) {
        guard let current else { return }
        guard mainButtonMode != .next else { return }

        let canonicalTokens = SpeakNormalizer.sentenceCanonicalTokensAlignedToWords(
            cleanForSpeak(current.foreign)
        )

        let heardSet = SpeakNormalizer.transcriptTokenSet(raw)

        var newRecognised = recognisedIndices

        for (i, tok) in canonicalTokens.enumerated() {
            if newRecognised.contains(i) { continue }

            if !tok.isEmpty, heardSet.contains(tok) {
                newRecognised.insert(i)
            }
        }

        recognisedIndices = newRecognised

        let important = SpeakNormalizer.importantIndices(for: canonicalTokens)
        let importantTotal = important.count
        let importantRecognised = important.filter { recognisedIndices.contains($0) }.count

        let ratio = importantTotal == 0
            ? 0
            : Double(importantRecognised) / Double(importantTotal)

        if importantTotal > 0, importantRecognised == importantTotal {
            cancelGrace()
            mainButtonMode = .next
            stt.stop()
            stt.clearError()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        if !graceActive, ratio >= passRatio {
            beginGrace()
        }
    }

    private func beginGrace() {
        graceActive = true
        mainButtonMode = .keepGoing
        graceDeadline = Date().addingTimeInterval(graceSeconds)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        graceWorkItem?.cancel()

        let work = DispatchWorkItem {
            guard graceActive else { return }

            graceActive = false
            graceDeadline = nil
            graceWorkItem = nil

            mainButtonMode = .next
            stt.stop()
            stt.clearError()

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        graceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + graceSeconds, execute: work)
    }

    private func cancelGrace() {
        graceActive = false
        graceDeadline = nil
        graceWorkItem?.cancel()
        graceWorkItem = nil
    }

    // MARK: - Cleaning / eligibility helpers

    private func tappableWordForSpeech(_ word: String) -> String {
        word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:()[]{}\"“”«»…"))
    }

    private func cleanForSpeak(_ s: String) -> String {
        var out = s

        while let start = out.firstIndex(of: "("),
              let end = out[start...].firstIndex(of: ")") {
            out.removeSubrange(start...end)
        }

        out = out
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        out = out.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return out
    }

    private func wordCount(_ s: String) -> Int {
        cleanForSpeak(s)
            .split(whereSeparator: { $0.isWhitespace })
            .count
    }

    private func sentenceChunkCount(_ s: String) -> Int {
        let cleaned = cleanForSpeak(s)

        guard !cleaned.isEmpty else {
            return 0
        }

        let endings: Set<Character> = [".", "!", "?", "…"]
        let count = cleaned.filter { endings.contains($0) }.count

        return max(1, count)
    }
}
