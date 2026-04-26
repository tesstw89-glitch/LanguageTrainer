import SwiftUI
import AVFoundation

struct MatchWriteView: View {

    let language: AppLanguage
    let allTerms: [TermPair]

    // Optional overrides for FullStudyFlow / Lessons
    let totalQsOverride: Int?
    let onFinished: (() -> Void)?
    let onCorrect: ((TermPair) -> Void)?

    init(
        language: AppLanguage,
        allTerms: [TermPair],
        totalQsOverride: Int? = nil,
        onFinished: (() -> Void)? = nil,
        onCorrect: ((TermPair) -> Void)? = nil
    ) {
        self.language = language
        self.allTerms = allTerms
        self.totalQsOverride = totalQsOverride
        self.onFinished = onFinished
        self.onCorrect = onCorrect
    }

    private var totalQs: Int {
        totalQsOverride ?? 20
    }

    private let optionCount = 5

    @State private var queue: [TermPair] = []
    @State private var index: Int = 0
    @State private var current: TermPair? = nil

    @State private var options: [TermPair] = []
    @State private var typed: String = ""
    @State private var isCorrect: Bool = false

    @FocusState private var isTyping: Bool

    private var languageName: String {
        switch language {
        case .french:
            return "French"
        case .spanish:
            return "Spanish"
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    // Progress
                    HStack {
                        Text("Question \(min(index + 1, max(queue.count, 1))) / \(max(queue.count, 1))")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                    // English prompt
                    Text(current?.english ?? "")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.top, 4)

                    // Type box
                    TextField("Type the \(languageName) here", text: $typed)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.done)
                        .focused($isTyping)
                        .onSubmit {
                            validateTyped()
                        }
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 18)
                        .onChange(of: typed) { _, _ in
                            validateTyped()
                        }

                    // Options
                    VStack(spacing: 10) {
                        ForEach(options) { term in
                            Button {
                                handleOptionTap(term)
                            } label: {
                                Text(displayForeign(term.foreign))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 12)
                                    .background(optionBackground(term))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.25), radius: 10, y: 6)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 18)
                        }
                    }
                    .padding(.top, 6)

                    Spacer(minLength: 12)

                    // Next button appears only when correct
                    if isCorrect {
                        Button {
                            next()
                        } label: {
                            Text(index >= queue.count - 1 ? "Finish" : "Next")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .padding(.horizontal, 18)
                                .padding(.bottom, 18)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 70)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture {
            isTyping = false
        }
        .onAppear {
            startQueue()
            isTyping = true
        }
    }

    // MARK: - Source terms

    // MARK: - Source terms

    // MARK: - Source terms

    private var matchWriteTerms: [TermPair] {
        dedupedTerms(allTerms)
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
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: - Flow

    private func startQueue() {
        let pool = matchWriteTerms

        guard !pool.isEmpty else {
            queue = []
            index = 0
            current = nil
            options = []
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
            options = []
            return
        }

        current = queue[index]
        buildOptions()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isTyping = true
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

    // MARK: - Options

    private func buildOptions() {
        guard let current else {
            options = []
            return
        }

        let pool = matchWriteTerms

        let distractors = pool
            .filter { $0.id != current.id }
            .fisherYatesShuffled()
            .prefix(max(0, optionCount - 1))

        var list = Array(distractors)
        list.append(current)

        options = list.fisherYatesShuffled()
    }

    private func handleOptionTap(_ tapped: TermPair) {
        guard let current else { return }

        if tapped.id == current.id {
            typed = displayForeign(current.foreign)

            if !isCorrect {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            isCorrect = true
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func optionBackground(_ term: TermPair) -> Color {
        guard let current else {
            return Color.white.opacity(0.94)
        }

        if !isCorrect {
            return Color.white.opacity(0.94)
        }

        return term.id == current.id
            ? Color.cyan.opacity(0.35)
            : Color.white.opacity(0.94)
    }

    // MARK: - Typed validation

    private func validateTyped() {
        guard let current else { return }

        let target = canonicalForCompare(current.foreign)
        let attempt = canonicalForCompare(typed)

        if !target.isEmpty, attempt == target {
            if !isCorrect {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            isCorrect = true
        } else {
            isCorrect = false
        }
    }

    // MARK: - Cleaning

    private func displayForeign(_ s: String) -> String {
        stripParentheses(s)
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func canonicalForCompare(_ s: String) -> String {
        displayForeign(s)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "[.,!?;:()\\[\\]{}\"“”«»…-]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripParentheses(_ s: String) -> String {
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
