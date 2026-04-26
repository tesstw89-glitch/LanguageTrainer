import SwiftUI

struct MatchView: View {
    let language: AppLanguage
    let allTerms: [TermPair]

    var secondsTotalOverride: Int? = nil
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var starStore: StarStore
    @StateObject private var speaker = SpeechHelper()

    @AppStorage("isSoundMuted") private var isSoundMuted: Bool = false

    private let visibleCount = 6

    private var secondsTotal: Int {
        secondsTotalOverride ?? 120
    }

    @State private var deck: [TermPair] = []
    @State private var visible: [TermPair] = []
    @State private var leftOrder: [UUID] = []
    @State private var rightOrder: [UUID] = []

    @State private var selectedLeft: UUID? = nil
    @State private var selectedRight: UUID? = nil

    @State private var magnify: MagnifyPayload? = nil

    @State private var secondsLeft: Int = 120
    @State private var timeUp: Bool = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum MagnifySide {
        case left, right
    }

    struct MagnifyPayload: Identifiable, Equatable {
        let id = UUID()
        let side: MagnifySide
        let text: String
        let title: String
    }

    private var speechCode: String {
        switch language {
        case .french:
            return "fr-FR"
        case .spanish:
            return "es-ES"
        }
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 14) {
                topBar
                columnsView
                Spacer(minLength: 12)
            }

            if let magnify {
                MagnifyOverlay(
                    title: magnify.title,
                    text: magnify.text,
                    onClose: { self.magnify = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(999)
            }
        }
        .onAppear {
            startGame()
        }
        .onReceive(ticker) { _ in
            handleTick()
        }
        .animation(.easeInOut(duration: 0.18), value: magnify != nil)
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
        HStack(spacing: 10) {
            Text("Time left: \(format(secondsLeft))")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer()

            Button {
                isSoundMuted.toggle()
            } label: {
                Image(systemName: isSoundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(isSoundMuted ? Color.red.opacity(0.85) : Color.green.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSoundMuted ? "Unmute sound" : "Mute sound")

            if timeUp {
                Button {
                    dismiss()
                } label: {
                    Text("Home")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var columnsView: some View {
        HStack(alignment: .top, spacing: 12) {
            leftColumn
            rightColumn
        }
        .padding(.horizontal, 18)
    }

    private var leftColumn: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(leftOrder, id: \.self) { id in
                    if let term = visible.first(where: { $0.id == id }) {
                        leftRow(for: term, id: id)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var rightColumn: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(rightOrder, id: \.self) { id in
                    if let term = visible.first(where: { $0.id == id }) {
                        rightRow(for: term, id: id)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func leftRow(for term: TermPair, id: UUID) -> some View {
        HStack(spacing: 10) {
            MatchToken(
                text: term.foreign,
                isSelected: selectedLeft == id
            )

            StarButton(id: term.id)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                guard !timeUp else { return }
                magnify = MagnifyPayload(
                    side: .left,
                    text: term.foreign,
                    title: "Foreign"
                )
            }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                guard !timeUp else { return }
                handleLeftTap(term)
            }
        )
    }

    @ViewBuilder
    private func rightRow(for term: TermPair, id: UUID) -> some View {
        MatchToken(
            text: term.english,
            isSelected: selectedRight == id
        )
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                guard !timeUp else { return }
                magnify = MagnifyPayload(
                    side: .right,
                    text: term.english,
                    title: "English"
                )
            }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                guard !timeUp else { return }
                handleRightTap(term)
            }
        )
    }

    // MARK: - Eligibility

    // MARK: - Eligibility

    private var eligibleTerms: [TermPair] {
        dedupedTerms(allTerms)
            .filter { !$0.foreign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { wordCount($0.foreign) <= 7 }
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

    private func wordCount(_ s: String) -> Int {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .count
    }

    // MARK: - Game setup

    private func startGame() {
        secondsLeft = secondsTotal
        timeUp = false

        deck = eligibleTerms.fisherYatesShuffled()
        visible = Array(deck.prefix(visibleCount))
        deck.removeFirst(min(deck.count, visibleCount))

        reshuffleColumns()

        selectedLeft = nil
        selectedRight = nil
        magnify = nil
    }

    private func reshuffleColumns() {
        let ids = visible.map(\.id)
        leftOrder = ids.fisherYatesShuffled()
        rightOrder = ids.fisherYatesShuffled()
    }

    // MARK: - Timer

    private func handleTick() {
        guard !timeUp else { return }

        secondsLeft -= 1

        if secondsLeft <= 0 {
            secondsLeft = 0
            timeUp = true
            selectedLeft = nil
            selectedRight = nil
            magnify = nil

            onFinished?()
        }
    }

    // MARK: - Tap handling

    private func handleLeftTap(_ term: TermPair) {
        if !isSoundMuted {
            speaker.speak(term.foreign, languageCode: speechCode)
        }

        selectedLeft = term.id
        tryResolveMatch()
    }

    private func handleRightTap(_ term: TermPair) {
        selectedRight = term.id
        tryResolveMatch()
    }

    private func tryResolveMatch() {
        guard let l = selectedLeft, let r = selectedRight else { return }

        if l == r {
            withAnimation(.easeInOut(duration: 0.18)) {
                replaceMatched(id: l)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                selectedLeft = nil
                selectedRight = nil
            }
        }
    }

    private func replaceMatched(id: UUID) {
        visible.removeAll { $0.id == id }
        leftOrder.removeAll { $0 == id }
        rightOrder.removeAll { $0 == id }

        if let next = deck.first {
            deck.removeFirst()
            visible.append(next)
        }

        reshuffleColumns()

        selectedLeft = nil
        selectedRight = nil
        magnify = nil
    }

    private func format(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Uniform token with shrink-to-fit text

private struct MatchToken: View {
    let text: String
    let isSelected: Bool

    private let compactHeight: CGFloat = 68
    private let maxFont: CGFloat = 16
    private let minScale: CGFloat = 10 / 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.orange.opacity(0.75) : Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.green, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)

            Text(text)
                .font(.system(size: maxFont, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .truncationMode(.tail)
                .minimumScaleFactor(minScale)
                .allowsTightening(true)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compactHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Floating magnify overlay

private struct MagnifyOverlay: View {
    let title: String
    let text: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    Text(text)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }
                .frame(maxHeight: 420)
            }
            .padding(16)
            .frame(maxWidth: 520)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 18, y: 8)
            .padding(.horizontal, 18)
        }
    }
}
