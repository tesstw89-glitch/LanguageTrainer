import SwiftUI
import UniformTypeIdentifiers

struct DragFillView: View {

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

    // MARK: - Defaults

    private var totalQs: Int { totalQsOverride ?? 20 }

    private let boxMinHeight: CGFloat = 54
    private let dropAreaMaxHeight: CGFloat = 125
    private let tokenBankHeight: CGFloat = 170

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

    // MARK: - Floating English overlay

    @State private var showEnglishOverlay: Bool = false

    // MARK: - Drag state

    @State private var draggingToken: TokenItem? = nil
    @StateObject private var speaker = SpeechHelper()

    // Controls whether tapping a token speaks it
    @AppStorage("dragFillTokenAudioOn") private var tokenAudioOn: Bool = true

    var body: some View {
        ZStack {
            VStack(spacing: 18) {

                englishPromptSection

                dropAreaSection

                tokenBankSection

                controlsSection

                Spacer(minLength: 10)
            }
            .padding(.top, 10)

            if showEnglishOverlay {
                englishFloatingOverlay
            }
        }
        .onAppear {
            startQueue()
        }
        .onChange(of: dropTokens) { _, _ in
            checkCorrect()
        }
    }

    // MARK: - English Prompt Section

    private var englishPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .top, spacing: 10) {

                Text(current?.english ?? "")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        guard !(current?.english ?? "").isEmpty else { return }

                        withAnimation(.easeInOut(duration: 0.18)) {
                            showEnglishOverlay = true
                        }
                    }

                HStack(spacing: 10) {

                    Button {
                        playCurrentForeign()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(10)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play full sentence")

                    Button {
                        tokenAudioOn.toggle()
                    } label: {
                        Image(systemName: tokenAudioOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(tokenAudioOn ? .green : .red)
                            .padding(10)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke((tokenAudioOn ? Color.green : Color.red).opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tokenAudioOn ? "Turn token audio off" : "Turn token audio on")

                    if let current {
                        StarButton(id: current.id)
                    }
                }
                .fixedSize(horizontal: true, vertical: true)
            }

            if isCurrentSingleWord {
                Text(revealedForeignProgress())
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.blue.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    // MARK: - Drop Area

    private var dropAreaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drop Area")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                Wrap(words: dropTokens) { token in
                    dropTokenView(token)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: boxMinHeight, maxHeight: dropAreaMaxHeight, alignment: .topLeading)
            .background(Color.white.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.gray.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
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
    }

    // MARK: - Token Bank

    private var tokenBankSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isCurrentSingleWord ? "Letters" : "Tokens")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                Wrap(words: bankTokens) { token in
                    tokenView(token, inDrop: false)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: tokenBankHeight, alignment: .topLeading)
            .background(Color.white.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.blue.opacity(0.55), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
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
    }

    // MARK: - Controls

    private var controlsSection: some View {
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

            Button {
                giveClue()
            } label: {
                Text("Clue")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(canGiveClue ? Color.blue.opacity(0.85) : Color.gray.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canGiveClue)

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
    }

    private var canGiveClue: Bool {
        guard current != nil else { return false }
        guard !isCorrect else { return false }

        let targetTexts = targetTokenTexts()
        let prefixCount = correctPrefixCount(targetTexts: targetTexts)

        return prefixCount < targetTexts.count
    }

    // MARK: - Floating English Overlay

    private var englishFloatingOverlay: some View {
        VStack {
            Spacer()

            ScrollView(.vertical, showsIndicators: true) {
                Text(current?.english ?? "")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 280)
            .background(Color.white.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 18, y: 8)
            .padding(.horizontal, 22)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showEnglishOverlay = false
                }
            }

            Spacer()
        }
        .zIndex(50)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
            showEnglishOverlay = false
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
        showEnglishOverlay = false

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
        let isWrongInDrop = inDrop && !isTokenCorrectInDropPosition(token)

        return Text(token.text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isWrongInDrop ? Color.red.opacity(0.25) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isWrongInDrop ? Color.red.opacity(0.75) : Color.gray.opacity(0.18),
                        lineWidth: isWrongInDrop ? 2 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(0.12),
                radius: 4,
                y: 2
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                if tokenAudioOn {
                    playToken(token)
                }

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

    private func isTokenCorrectInDropPosition(_ token: TokenItem) -> Bool {
        guard let dropIndex = dropTokens.firstIndex(where: { $0.id == token.id }) else {
            return true
        }

        let targetTexts = targetTokenTexts()

        guard dropIndex < targetTexts.count else {
            return false
        }

        return token.text == targetTexts[dropIndex]
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

    // MARK: - Clue

    private func giveClue() {
        let targetTexts = targetTokenTexts()
        guard !targetTexts.isEmpty else { return }

        let prefixCount = correctPrefixCount(targetTexts: targetTexts)

        guard prefixCount < targetTexts.count else {
            checkCorrect()
            return
        }

        let neededText = targetTexts[prefixCount]

        var clueToken: TokenItem?

        // First choice: take the next correct token from the bank.
        if let bankIndex = bankTokens.firstIndex(where: { $0.text == neededText }) {
            clueToken = bankTokens.remove(at: bankIndex)
        }

        // If the correct token is already later in the drop area, move it into the right place.
        if clueToken == nil,
           let laterDropIndex = dropTokens.indices.first(where: {
               $0 >= prefixCount && dropTokens[$0].text == neededText
           }) {
            clueToken = dropTokens.remove(at: laterDropIndex)
        }

        // Fallback for repeated words or letters.
        if clueToken == nil,
           let anyDropIndex = dropTokens.firstIndex(where: { $0.text == neededText }) {
            clueToken = dropTokens.remove(at: anyDropIndex)
        }

        guard let clueToken else { return }

        let insertIndex = min(prefixCount, dropTokens.count)

        withAnimation(.easeInOut(duration: 0.16)) {
            dropTokens.insert(clueToken, at: insertIndex)
        }

        draggingToken = nil
        checkCorrect()
    }

    private func targetTokenTexts() -> [String] {
        guard let current else { return [] }

        let cleaned = cleanForeignForDrag(current.foreign)
        let words = splitWords(cleaned)

        if words.count == 1, let word = words.first {
            return splitLetters(word)
        } else {
            return words
        }
    }

    private func correctPrefixCount(targetTexts: [String]) -> Int {
        var count = 0

        for i in 0..<min(dropTokens.count, targetTexts.count) {
            if dropTokens[i].text == targetTexts[i] {
                count += 1
            } else {
                break
            }
        }

        return count
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
        showEnglishOverlay = false
    }

    // MARK: - Audio

    private func playCurrentForeign() {
        guard let current else { return }

        let cleaned = cleanForeignForDrag(current.foreign)
        speaker.speak(cleaned, languageCode: speechCode)
    }

    private func playToken(_ token: TokenItem) {
        let cleaned = cleanTokenForSpeech(token.text)
        guard !cleaned.isEmpty else { return }

        speaker.speak(cleaned, languageCode: speechCode)
    }

    private func cleanTokenForSpeech(_ s: String) -> String {
        s.replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:()[]{}\"“”«»…"))
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

        // Normalise repeated spacing first.
        out = out.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        // Attach punctuation to the word before it.
        // Example: "Tu viens ?" becomes "Tu viens?"
        // Example: "Oui ! Bien sûr ." becomes "Oui! Bien sûr."
        out = out.replacingOccurrences(
            of: "\\s+([.,!?;:…])",
            with: "$1",
            options: .regularExpression
        )

        // Attach closing quotation/bracket marks to the word before them.
        out = out.replacingOccurrences(
            of: "\\s+([»”\\)])",
            with: "$1",
            options: .regularExpression
        )

        return out
    }

    private func normalize(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        out = out.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        out = out.replacingOccurrences(
            of: "\\s+([.,!?;:…])",
            with: "$1",
            options: .regularExpression
        )

        out = out.replacingOccurrences(
            of: "\\s+([»”\\)])",
            with: "$1",
            options: .regularExpression
        )

        return out
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
