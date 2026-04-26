import SwiftUI
import AVFoundation

struct MatchWriteView: View {

    let language: AppLanguage
    let allTerms: [TermPair]

    private let totalQs = 20
    private let optionCount = 5

    @State private var queue: [TermPair] = []
    @State private var index: Int = 0
    @State private var current: TermPair? = nil

    @State private var options: [TermPair] = []
    @State private var typed: String = ""
    @State private var isCorrect: Bool = false

    @FocusState private var isTyping: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    // Progress
                    HStack {
                        Text("Question \(min(index + 1, queue.count)) / \(max(queue.count, 1))")
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
                    TextField("Type the French here", text: $typed)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.done)
                        .focused($isTyping)
                        .onSubmit { validateTyped() }
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 18)

                    // Options
                    VStack(spacing: 10) {
                        ForEach(options) { term in
                            Button {
                                handleOptionTap(term)
                            } label: {
                                Text(displayFrench(term.foreign))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
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
                            Text("Next")
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
            .scrollDismissesKeyboard(.interactively)   // ✅ drag down to dismiss
        }
        .onTapGesture { isTyping = false }
        .onAppear {
            startQueue()
            isTyping = true
        }
    }

    // MARK: - Flow

    private func startQueue() {
        let pool = allTerms
        guard !pool.isEmpty else { return }

        queue = Array(pool.fisherYatesShuffled().prefix(min(totalQs, pool.count)))
        index = 0
        loadCurrent()
    }

    private func loadCurrent() {
        isCorrect = false
        typed = ""

        guard index < queue.count else {
            startQueue()
            return
        }

        current = queue[index]
        buildOptions()
        isTyping = true
    }

    private func next() {
        index += 1
        loadCurrent()
    }

    // MARK: - Options

    private func buildOptions() {
        guard let current else {
            options = []
            return
        }

        let distractors = allTerms
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
            typed = displayFrench(current.foreign)
            isCorrect = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func optionBackground(_ term: TermPair) -> Color {
        guard let current else { return Color.white.opacity(0.94) }
        if !isCorrect { return Color.white.opacity(0.94) }
        return (term.id == current.id) ? Color.cyan.opacity(0.35) : Color.white.opacity(0.94)
    }

    // MARK: - Typed validation

    private func validateTyped() {
        guard let current else { return }

        let target = canonicalForCompare(current.foreign)
        let attempt = canonicalForCompare(typed)

        if !target.isEmpty, attempt == target {
            isCorrect = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - Cleaning

    private func displayFrench(_ s: String) -> String {
        stripParentheses(s)
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func canonicalForCompare(_ s: String) -> String {
        let cleaned = displayFrench(s)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        let squashed = cleaned
            .replacingOccurrences(of: "[\\p{Punct}&&[^']]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return squashed
    }

    private func stripParentheses(_ s: String) -> String {
        var out = s
        while let start = out.firstIndex(of: "("),
              let end = out[start...].firstIndex(of: ")") {
            out.removeSubrange(start...end)
        }
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out
    }
}
