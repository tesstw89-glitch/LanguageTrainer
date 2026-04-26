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

    // Overlay magnify (for English only)
    struct MagnifyPayload: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let title: String
    }
    @State private var magnify: MagnifyPayload? = nil

    // Timer
    @State private var secondsLeft: Int = 120
    @State private var timeUp: Bool = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var speechCode: String {
        switch language {
        case .french:  return "fr-FR"
        case .spanish: return "es-ES"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {

                // Top bar
                HStack {
                    Text("Time left: \(format(secondsLeft))")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Spacer()

                    if timeUp {
                        Button { dismiss() } label: {
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

                // Columns
                HStack(alignment: .top, spacing: 12) {

                    // LEFT: Audio buttons (foreign hidden)
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(leftOrder, id: \.self) { id in
                                if let term = visible.first(where: { $0.id == id }) {

                                    ListenToken(isSelected: selectedLeft == id)
                                        .simultaneousGesture(
                                            TapGesture().onEnded {
                                                guard !timeUp else { return }
                                                handleLeftTap(term)
                                            }
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // RIGHT: English text
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(rightOrder, id: \.self) { id in
                                if let term = visible.first(where: { $0.id == id }) {

                                    MatchToken(
                                        text: term.english,
                                        isSelected: selectedRight == id
                                    )
                                    // Double tap = overlay magnify
                                    .highPriorityGesture(
                                        TapGesture(count: 2).onEnded {
                                            guard !timeUp else { return }
                                            magnify = MagnifyPayload(
                                                text: term.english,
                                                title: "English"
                                            )
                                        }
                                    )
                                    // Single tap = select
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            guard !timeUp else { return }
                                            handleRightTap(term)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 18)

                Spacer(minLength: 12)
            }

            // Floating magnify overlay
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
        .onAppear { startGame() }
        .onReceive(ticker) { _ in
            guard !timeUp else { return }
            secondsLeft -= 1
            if secondsLeft <= 0 {
                secondsLeft = 0
                timeUp = true
                selectedLeft = nil
                selectedRight = nil
                magnify = nil
            }
        }
        .animation(.easeInOut(duration: 0.18), value: magnify != nil)
    }

    // MARK: - Eligibility (foreign <= 7 words)
    private var eligibleTerms: [TermPair] {
        allTerms.filter { wordCount($0.foreign) <= 7 }
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
        let ids = visible.map { $0.id }
        leftOrder = ids.fisherYatesShuffled()
        rightOrder = ids.fisherYatesShuffled()
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

// MARK: - Left token: rounded square audio-only
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
        .frame(height: size)     // uniform height like your MatchToken
        .contentShape(Rectangle())
    }
}

// MARK: - English token (same as yours)
private struct MatchToken: View {
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

// MARK: - Magnify overlay (same as yours)
private struct MagnifyOverlay: View {
    let title: String
    let text: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

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
