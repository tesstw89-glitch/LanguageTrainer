import SwiftUI

struct FullStudyFlowView: View {
    let language: AppLanguage
    let sentenceTerms: [TermPair]
    let lemmaTerms: [TermPair]

    private enum Step {
        case match, dragFill, write, speak, done

        var title: String {
            switch self {
            case .match:    return "Match (2 mins)"
            case .dragFill: return "Drag & Fill (20)"
            case .write:    return "Write (10)"
            case .speak:    return "Speak (10)"
            case .done:     return "Done"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .match

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepView
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Exit") { dismiss() }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Full Study Flow")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Spacer()

            Text(step.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .match:
            MatchView(
                language: language,
                allTerms: lemmaTerms,
                secondsTotalOverride: 120,
                onFinished: { goNext() }
            )

        case .dragFill:
            DragFillView(
                language: language,
                terms: sentenceTerms,
                totalQsOverride: 20,
                onFinished: { goNext() }
            )

        case .write:
            WriteView(
                language: language,
                terms: lemmaTerms,
                totalQsOverride: 10,
                onFinished: { goNext() }
            )

        case .speak:
            SpeakView(
                language: language,
                terms: sentenceTerms,
                totalQsOverride: 10,
                onFinished: { goNext() }
            )

        case .done:
            doneView
        }
    }

    private var doneView: some View {
        VStack(spacing: 14) {
            Spacer()

            Text("Well done!")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("You completed the full study flow.")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Button { dismiss() } label: {
                Text("Home")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 18)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func goNext() {
        switch step {
        case .match:    step = .dragFill
        case .dragFill: step = .write
        case .write:    step = .speak
        case .speak:    step = .done
        case .done:     break
        }
    }
}
