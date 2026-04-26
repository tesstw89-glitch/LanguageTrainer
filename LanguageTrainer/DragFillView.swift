import SwiftUI
import UniformTypeIdentifiers

struct DragFillView: View {

    let language: AppLanguage
    let terms: [TermPair]

    // ✅ overrides for FullStudyFlow / Lessons
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

    // MARK: - Defaults

    private var totalQs: Int { totalQsOverride ?? 20 }
    private let boxMinHeight: CGFloat = 54

    private var isCurrentSingleWord: Bool {
        guard let current else { return false }
        let cleaned = cleanForeignForDrag(current.foreign)
        return splitWords(cleaned).count == 1
    }

    private var speechCode: String {
        switch language {
        case .french:
            return "fr-FR"
        case .spanish:
            return "es-ES"
        }
    }

    // MARK: - Queue

    @State private var queue: [TermPair] = []
    @State private var index: Int = 0
    @State private var current: TermPair?

    // MARK: - Tokens

    @State private var bankTokens: [TokenItem] = []
    @State private var dropTokens: [TokenItem] = []
    @State private var isCorrect: Bool = false

    // MARK: - Drag state

    @State private var draggingToken: TokenItem? = nil
    @StateObject private var speaker = SpeechHelper()
    @AppStorage("isSoundMuted") private var isSoundMuted: Bool = false

    var body: some View {
        VStack(spacing: 18) {

            // English prompt + audio + star
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(current?.english ?? "")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.leading)

                    if isCurrentSingleWord {
                        Text(revealedForeignProgress())
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.blue.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        if isSoundMuted {
                            isSoundMuted = false
                        }

                        playCurrentForeign()
                    } label: {
                        Image(systemName: isSoundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isSoundMuted ? .red : .blue)
                            .padding(10)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke((isSoundMuted ? Color.red : Color.blue).opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    if let current {
                        StarButton(id: current.id)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            // DROP AREA
            VStack(alignment: .leading, spacing: 10) {
                Text("Drop Area")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Wrap(words: dropTokens) { token in
                    dropTokenView(token)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: boxMinHeight, alignment: .topLeading)
                .padding(12)
                .background(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            Color.gray.opacity(0.45),
                            style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onDrop(
                    of: [UTType.plainText],
                    delegate: DropAtEndDelegate(
                        dropTokens: $dropTokens,
                        bankTokens: $bankTokens,
                        draggingToken: $draggingToken,
                        onChanged: checkCorrect
                    )
                )
            }
            .padding(.horizontal, 18)

            // WORD / LETTER BANK
            VStack(alignment: .leading, spacing: 10) {
                Text(isCurrentSingleWord ? "Letters" : "Tokens")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Wrap(words: bankTokens) { token in
                    tokenView(token, inDrop: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: boxMinHeight, alignment: .topLeading)
                .padding(12)
                .background(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.blue.opacity(0.55), lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onDrop(
                    of: [UTType.plainText],
                    delegate: BankDropDelegate(
                        bankTokens: $bankTokens,
                        dropTokens: $dropTokens,
                        draggingToken: $draggingToken,
                        onChanged: checkCorrect
                    )
                )
            }
            .padding(.horizontal, 18)

            // CONTROLS
            HStack(spacing: 12) {
                Button {
                    resetTokens()
                } label: {
                    Text("Reset")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    goNext()
                } label: {
                    Text(index >= queue.count - 1 ? "Finish" : "Next")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(isCorrect ? Color.green.opacity(0.9) : Color.gray.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!isCorrect)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)

            Spacer(minLength: 10)
        }
        .padding(.top, 10)
        .onAppear { startQueue() }
        .onChange(of: dropTokens) { _, _ in
            checkCorrect()
        }
    }

    // MARK: - Eligibility

    private var eligibleTerms: [TermPair] {
        terms.filter { term in
            !cleanForeignForDrag(term.foreign).isEmpty
        }
    }

    // MARK: - Queue

    private func startQueue() {
        let pool = eligibleTerms

        guard !pool.isEmpty else {
            current = nil
            bankTokens = []
            dropTokens = []
            draggingToken = nil
            isCorrect = false
            return
        }

        queue = Array(pool.fisherYatesShuffled().prefix(min(totalQs, pool.count)))
        index = 0
        loadCurrent()
    }

    private func loadCurrent() {
        isCorrect = false
        bankTokens = []
        dropTokens = []
        draggingToken = nil

        guard index < queue.count else {
            onFinished?()
            return
        }

        current = queue[index]

        let cleaned = cleanForeignForDrag(queue[index].foreign)
        bankTokens = makeTokens(for: cleaned)
        dropTokens = []
        isCorrect = false
    }

    private func goNext() {
        guard isCorrect else { return }

        if index < queue.count {
            onCorrect?(queue[index])
        }

        let nextIndex = index + 1
        if nextIndex >= queue.count {
            onFinished?()
        } else {
            index = nextIndex
            loadCurrent()
        }
    }

    // MARK: - Token Views

    private func dropTokenView(_ token: TokenItem) -> some View {
        tokenView(token, inDrop: true)
            .onDrop(
                of: [UTType.plainText],
                delegate: DropReorderDelegate(
                    target: token,
                    dropTokens: $dropTokens,
                    bankTokens: $bankTokens,
                    draggingToken: $draggingToken,
                    onChanged: checkCorrect
                )
            )
    }

    private func tokenView(_ token: TokenItem, inDrop: Bool) -> some View {
        Text(token.text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.18), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.12),
                radius: 4,
                y: 2
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                moveToken(token, toDrop: !inDrop)
            }
            .onDrag {
                draggingToken = token
                return NSItemProvider(object: token.dragPayload as NSString)
            } preview: {
                Text(token.text)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
            }
    }

    // MARK: - Movement

    private func moveToken(_ token: TokenItem, toDrop: Bool) {
        if toDrop {
            moveTokenToDrop(withID: token.id, before: nil)
        } else {
            moveTokenToBank(withID: token.id)
        }

        draggingToken = nil
    }

    private func moveTokenToDrop(withID id: UUID, before targetID: UUID?) {
        if targetID == id { return }
        guard let token = extractToken(withID: id) else { return }

        if let targetID,
           let targetIndex = dropTokens.firstIndex(where: { $0.id == targetID }) {
            dropTokens.insert(token, at: targetIndex)
        } else {
            dropTokens.append(token)
        }

        checkCorrect()
    }

    private func moveTokenToBank(withID id: UUID) {
        guard let token = extractToken(withID: id) else { return }
        bankTokens.append(token)
        checkCorrect()
    }

    private func extractToken(withID id: UUID) -> TokenItem? {
        if let idx = bankTokens.firstIndex(where: { $0.id == id }) {
            return bankTokens.remove(at: idx)
        }

        if let idx = dropTokens.firstIndex(where: { $0.id == id }) {
            return dropTokens.remove(at: idx)
        }

        return nil
    }

    // MARK: - Checking

    private func checkCorrect() {
        guard let current else {
            isCorrect = false
            return
        }

        let built = normalize(builtDropText())
        let target = normalize(cleanForeignForDrag(current.foreign))

        isCorrect = !built.isEmpty && built == target
    }

    // MARK: - Reset

    private func resetTokens() {
        guard let current else { return }

        let cleaned = cleanForeignForDrag(current.foreign)
        bankTokens = makeTokens(for: cleaned)
        dropTokens = []
        draggingToken = nil
        isCorrect = false
    }

    // MARK: - Audio

    private func playCurrentForeign() {
        guard let current else { return }

        let cleaned = cleanForeignForDrag(current.foreign)
        speaker.speak(cleaned, languageCode: speechCode)
    }

    // MARK: - Helpers

    private func makeTokens(for cleaned: String) -> [TokenItem] {
        let words = splitWords(cleaned)

        if words.count == 1, let word = words.first {
            return splitLetters(word)
                .map { TokenItem(text: $0) }
                .fisherYatesShuffled()
        } else {
            return words
                .map { TokenItem(text: $0) }
                .fisherYatesShuffled()
        }
    }

    private func builtDropText() -> String {
        if isCurrentSingleWord {
            return dropTokens.map(\.text).joined()
        } else {
            return dropTokens.map(\.text).joined(separator: " ")
        }
    }

    private func revealedForeignProgress() -> String {
        guard isCurrentSingleWord, let current else { return "" }

        let target = cleanForeignForDrag(current.foreign)
        let targetLetters = splitLetters(target)
        let chosenLetters = dropTokens.map(\.text)

        var correctPrefix: [String] = []

        for (chosen, expected) in zip(chosenLetters, targetLetters) {
            if chosen == expected {
                correctPrefix.append(expected)
            } else {
                break
            }
        }

        return correctPrefix.joined()
    }

    private func splitLetters(_ word: String) -> [String] {
        word.map { String($0) }
    }

    // MARK: - Cleaning

    private func cleanForeignForDrag(_ s: String) -> String {
        var out = s

        while let start = out.firstIndex(of: "("),
              let end = out[start...].firstIndex(of: ")") {
            out.removeSubrange(start...end)
        }

        out = out.replacingOccurrences(of: "’", with: "'")
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        out = out.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return out
    }

    private func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func splitWords(_ phrase: String) -> [String] {
        phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }
}

// MARK: - Drop delegates

private struct DropReorderDelegate: DropDelegate {
    let target: TokenItem

    @Binding var dropTokens: [TokenItem]
    @Binding var bankTokens: [TokenItem]
    @Binding var draggingToken: TokenItem?

    let onChanged: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggingToken else { return }
        guard dragged.id != target.id else { return }

        let targetIndex = dropTokens.firstIndex(of: target)

        withAnimation(.easeInOut(duration: 0.12)) {
            bankTokens.removeAll { $0.id == dragged.id }

            if let fromIndex = dropTokens.firstIndex(of: dragged),
               let toIndex = targetIndex {

                if fromIndex != toIndex {
                    let moved = dropTokens.remove(at: fromIndex)
                    let adjustedIndex = fromIndex < toIndex ? (toIndex - 1) : toIndex
                    dropTokens.insert(moved, at: adjustedIndex)
                }

            } else if let toIndex = targetIndex {
                dropTokens.insert(dragged, at: toIndex)
            }
        }

        onChanged()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            draggingToken = nil
            onChanged()
        }
        return true
    }
}

private struct DropAtEndDelegate: DropDelegate {
    @Binding var dropTokens: [TokenItem]
    @Binding var bankTokens: [TokenItem]
    @Binding var draggingToken: TokenItem?

    let onChanged: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggingToken else { return }

        withAnimation(.easeInOut(duration: 0.12)) {
            bankTokens.removeAll { $0.id == dragged.id }
            dropTokens.removeAll { $0.id == dragged.id }
            dropTokens.append(dragged)
        }

        onChanged()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            draggingToken = nil
            onChanged()
        }
        return true
    }
}

private struct BankDropDelegate: DropDelegate {
    @Binding var bankTokens: [TokenItem]
    @Binding var dropTokens: [TokenItem]
    @Binding var draggingToken: TokenItem?

    let onChanged: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggingToken else { return }

        withAnimation(.easeInOut(duration: 0.12)) {
            dropTokens.removeAll { $0.id == dragged.id }
            if !bankTokens.contains(where: { $0.id == dragged.id }) {
                bankTokens.append(dragged)
            }
        }

        onChanged()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            draggingToken = nil
            onChanged()
        }
        return true
    }
}
