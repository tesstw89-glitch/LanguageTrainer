import SwiftUI
import AVFoundation

struct ListenMatchView: View {

    let language: AppLanguage
    let allTerms: [TermPair]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = SpeechHelper()

    private let visibleCount = 6
    private let secondsTotal = 120

    @State private var deck: [TermPair] = []
    @State private var visible: [TermPair] = []
    @State private var leftOrder: [UUID] = []
    @State private var rightOrder: [UUID] = []

    @State private var selectedLeft: UUID? = nil
    @State private var selectedRight: UUID? = nil

    // ✅ For nice fade/shrink when a pair is matched
    @State private var dissolvingIDs: Set<UUID> = []

    struct MagnifyPayload: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let title: String
    }

    @State private var magnify: MagnifyPayload? = nil

    @State private var secondsLeft: Int = 120
    @State private var timeUp: Bool = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                ListenMatchMagnifyOverlay(
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

    // MARK: - Main views

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
            Text("Time left: \(format(secondsLeft))")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer()

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
                        ListenToken(isSelected: selectedLeft == id)
                            .opacity(dissolvingIDs.contains(id) ? 0 : 1)
                            .scaleEffect(dissolvingIDs.contains(id) ? 0.92 : 1)
                            .animation(.easeInOut(duration: 0.22), value: dissolvingIDs)
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    guard !timeUp else { return }
                                    guard dissolvingIDs.isEmpty else { return }
                                    handleLeftTap(term)
                                }
                            )
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
                        ListenMatchTextToken(
                            text: term.english,
                            isSelected: selectedRight == id
                        )
                        .opacity(dissolvingIDs.contains(id) ? 0 : 1)
                        .scaleEffect(dissolvingIDs.contains(id) ? 0.92 : 1)
                        .animation(.easeInOut(duration: 0.22), value: dissolvingIDs)
                        .highPriorityGesture(
                            TapGesture(count: 2).onEnded {
                                guard !timeUp else { return }
                                guard dissolvingIDs.isEmpty else { return }

                                magnify = MagnifyPayload(
                                    text: term.english,
                                    title: "English"
                                )
                            }
                        )
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                guard !timeUp else { return }
                                guard dissolvingIDs.isEmpty else { return }
                                handleRightTap(term)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

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
        dissolvingIDs = []
    }

    private func reshuffleColumns() {
        let ids = visible.map { $0.id }
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
            dissolvingIDs = []
        }
    }

    // MARK: - Tap handling

    private func handleLeftTap(_ term: TermPair) {
        speaker.speak(term.foreign, languageCode: speechCode)

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
            selectedLeft = nil
            selectedRight = nil

            withAnimation(.easeInOut(duration: 0.22)) {
                dissolvingIDs.insert(l)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    replaceMatched(id: l)
                    dissolvingIDs.remove(l)
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                selectedLeft = nil
                selectedRight = nil
            }
        }
    }

    private func replaceMatched(id: UUID) {
        // Remove only the matched pair
        visible.removeAll { $0.id == id }
        leftOrder.removeAll { $0 == id }
        rightOrder.removeAll { $0 == id }

        // Add only ONE new pair, without reshuffling existing cards
        if let next = deck.first {
            deck.removeFirst()
            visible.append(next)

            let leftInsertIndex = Int.random(in: 0...leftOrder.count)
            let rightInsertIndex = Int.random(in: 0...rightOrder.count)

            leftOrder.insert(next.id, at: leftInsertIndex)
            rightOrder.insert(next.id, at: rightInsertIndex)
        }

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

// MARK: - Left token: audio-only

private struct ListenToken: View {
    let isSelected: Bool

    private let size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.orange.opacity(0.75) : Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.green, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)

            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: size)
        .contentShape(Rectangle())
    }
}

// MARK: - English token

private struct ListenMatchTextToken: View {
    let text: String
    let isSelected: Bool

    private let compactHeight: CGFloat = 56

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .frame(height: compactHeight)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.orange.opacity(0.75) : Color.white.opacity(0.94))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.green, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)
    }
}

// MARK: - Magnify overlay

private struct ListenMatchMagnifyOverlay: View {
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
