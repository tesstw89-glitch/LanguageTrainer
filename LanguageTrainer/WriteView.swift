import SwiftUI

struct WriteView: View {
    let language: AppLanguage
    let terms: [TermPair]

    // Overrides for FullStudyFlow / Lessons
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
    @EnvironmentObject private var starStore: StarStore
    @StateObject private var speaker = SpeechHelper()

    private var totalQs: Int {
        totalQsOverride ?? 20
    }

    private var speechCode: String {
        switch language {
        case .french:
            return "fr-FR"
        case .spanish:
            return "es-ES"
        }
    }

    @State private var queue: [TermPair] = []
    @State private var index: Int = 0
    @State private var current: TermPair? = nil

    @State private var typed: String = ""
    @State private var isCorrect: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 16) {
                topBar
                promptView
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

    // MARK: - Main subviews

    private var backgroundView: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.92)],
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

    private var promptView: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(current?.english ?? "")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.leading)

            Spacer()

            if let current {
                HStack(spacing: 8) {
                    Button {
                        speaker.speak(current.foreign, languageCode: speechCode)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(10)
                            .background(Color.black.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    StarButton(id: current.id)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    private var answerBox: some View {
        VStack(spacing: 10) {
            TextField("Type the \(language == .french ? "French" : "Spanish")…", text: $typed)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isCorrect ? Color.green : Color.black.opacity(0.15), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 6, y: 3)
                .focused($isFocused)
                .onChange(of: typed) { _, _ in
                    checkAnswer()
                }
                .onSubmit {
                    checkAnswer()
                }

            if isCorrect, let current {
                Text(cleanForWrite(current.foreign))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
        }
        .padding(.horizontal, 18)
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

    // MARK: - Source terms

    private var writeTerms: [TermPair] {
        let lemmaTerms = terms.flatMap { $0.lemmas ?? [] }

        let sourceTerms = lemmaTerms.isEmpty ? terms : lemmaTerms

        return dedupedTerms(sourceTerms)
            .filter { !$0.foreign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func dedupedTerms(_ terms: [TermPair]) -> [TermPair] {
        var seen = Set<String>()

        return terms.filter { term in
            let key = normaliseKey(term.foreign) + "||" + normaliseKey(term.english)
            return seen.insert(key).inserted
        }
    }

    private func normaliseKey(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "  ", with: " ")
    }

    // MARK: - Queue

    private func startQueue() {
        let pool = writeTerms

        guard !pool.isEmpty else {
            queue = []
            current = nil
            index = 0
            typed = ""
            isCorrect = false
            return
        }

        queue = Array(pool.fisherYatesShuffled().prefix(min(totalQs, pool.count)))
        index = 0
        loadCurrent()
    }

    private func loadCurrent() {
        isCorrect = false
        typed = ""

        guard index < queue.count else {
            current = nil
            return
        }

        current = queue[index]

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
        }
    }

    private func next() {
        guard isCorrect else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if index < queue.count {
            onCorrect?(queue[index])
        }

        let nextIndex = index + 1

        if nextIndex >= queue.count {
            if let onFinished {
                onFinished()
            } else {
                startQueue()
            }
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
