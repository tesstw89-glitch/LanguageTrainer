import SwiftUI

struct ListenWriteView: View {

    let language: AppLanguage
    let terms: [TermPair]

    let totalQsOverride: Int?
    let onFinished: (() -> Void)?
    let onCorrect: ((TermPair) -> Void)?

    init(
        language: AppLanguage,
        terms: [TermPair],
        totalQsOverride: Int? = nil,
        onFinished: (() -> Void)? = nil,
        onCorrect: ((TermPair) -> Void)? = nil
    ) {
        self.language = language
        self.terms = terms
        self.totalQsOverride = totalQsOverride
        self.onFinished = onFinished
        self.onCorrect = onCorrect
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = SpeechHelper()

    private var totalQs: Int {
        totalQsOverride ?? 12
    }

    private var speechCode: String {
        switch language {
        case .french:
            return "fr-FR"
        case .spanish:
            return "es-ES"
        }
    }

    private var languageName: String {
        switch language {
        case .french:
            return "French"
        case .spanish:
            return "Spanish"
        }
    }

    @State private var queue: [TermPair] = []
    @State private var index: Int = 0
    @State private var current: TermPair? = nil

    @State private var typed: String = ""
    @State private var isCorrect: Bool = false
    @State private var hasReportedCorrect: Bool = false

    @State private var isSentenceRevealed: Bool = false
    @State private var isEnglishRevealed: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 16) {
                topBar
                promptView
                controlsView
                revealedSentenceView
                answerBox
                nextButton

                Spacer()
            }
        }
        .hideKeyboardOnTap()
        .onAppear {
            startQueue()
        }
    }

    // MARK: - Views

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Text("Question \(min(index + 1, max(queue.count, 1))) / \(max(queue.count, 1))")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            if let current {
                StarButton(id: current.id)
            }

            Button {
                dismiss()
            } label: {
                Text("Home")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var promptView: some View {
        if isEnglishRevealed {
            Text(current?.english ?? "")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.top, 4)
        } else {
            Text("Listen and type the \(languageName) sentence")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.top, 4)
        }
    }

    private var controlsView: some View {
        HStack(spacing: 12) {

            Button {
                play()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Listen")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.90))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSentenceRevealed.toggle()
                }
            } label: {
                Text(isSentenceRevealed ? "Hide sentence" : "Reveal sentence")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isEnglishRevealed.toggle()
                }
            } label: {
                Text(isEnglishRevealed ? "Hide English" : "Reveal English")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var revealedSentenceView: some View {
        if isSentenceRevealed, let sentence = current?.foreign {
            Text(cleanForWrite(sentence))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
    }

    private var answerBox: some View {
        TextField("Type what you hear…", text: $typed)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCorrect ? Color.green : Color.black.opacity(0.15), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 6, y: 3)
            .padding(.horizontal, 18)
            .focused($isFocused)
            .onChange(of: typed) { _, _ in
                checkAnswer()
            }
            .onSubmit {
                checkAnswer()
            }
    }

    private var nextButton: some View {
        Button {
            next()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                Text(index >= queue.count - 1 ? "Finish" : "Next")
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.green.opacity(0.90))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .opacity(isCorrect ? 1 : 0)
        .allowsHitTesting(isCorrect)
    }

    // MARK: - Audio

    private func play() {
        guard let sentence = current?.foreign else { return }
        speaker.speak(cleanForWrite(sentence), languageCode: speechCode)
    }

    private func play(_ term: TermPair) {
        speaker.speak(cleanForWrite(term.foreign), languageCode: speechCode)
    }

    // MARK: - Queue

    private func startQueue() {
        let pool = sentenceTerms

        guard !pool.isEmpty else {
            queue = []
            index = 0
            current = nil
            typed = ""
            isCorrect = false
            return
        }

        queue = Array(pool.fisherYatesShuffled().prefix(min(totalQs, pool.count)))
        index = 0
        loadCurrent()
    }

    private var sentenceTerms: [TermPair] {
        terms
            .filter { !$0.foreign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func loadCurrent() {
        isCorrect = false
        hasReportedCorrect = false
        typed = ""
        isSentenceRevealed = false
        isEnglishRevealed = false

        guard index < queue.count else {
            current = nil
            onFinished?()
            return
        }

        let term = queue[index]
        current = term

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            isFocused = true
            play(term)
        }
    }

    private func next() {
        guard isCorrect else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let nextIndex = index + 1

        if nextIndex >= queue.count {
            onFinished?()
        } else {
            index = nextIndex
            loadCurrent()
        }
    }

    // MARK: - Checking

    private func checkAnswer() {
        guard let current else { return }

        let target = normalizeForCompare(cleanForWrite(current.foreign))
        let user = normalizeForCompare(typed)

        let ok = !target.isEmpty && user == target

        if ok && !isCorrect {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        if ok && !hasReportedCorrect {
            hasReportedCorrect = true
            onCorrect?(current)
        }

        isCorrect = ok
    }

    // MARK: - Cleaning

    private func cleanForWrite(_ s: String) -> String {
        var out = s

        while let start = out.firstIndex(of: "("),
              let end = out[start...].firstIndex(of: ")") {
            out.removeSubrange(start...end)
        }

        while out.contains("  ") {
            out = out.replacingOccurrences(of: "  ", with: " ")
        }

        return out
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeForCompare(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "[.,!?;:()\\[\\]{}\"“”«»…-]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
