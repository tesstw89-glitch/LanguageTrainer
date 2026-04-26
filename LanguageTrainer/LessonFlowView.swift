import SwiftUI

struct LessonFlowView: View {
    let language: AppLanguage
    let unit: Int
    let lesson: Int

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lessons: LessonsStore
    private let engine = LessonEngine()

    private var allSentences: [TermPair] { LessonsDataLoader.lessons(for: language) }
    private var unitSentences: [TermPair] { engine.sentences(forUnit: unit, all: allSentences) }

    private enum Step { case dragFill, write, listenWrite, done }
    @State private var step: Step = .dragFill

    var body: some View {
        let plan = engine.plan(
            language: language,
            unit: unit,
            lesson: lesson,
            unitSentences: unitSentences,
            store: lessons
        )

        VStack(spacing: 0) {
            header(step: step)
            Divider()

            switch step {
            case .dragFill:
                DragFillView(
                    language: language,
                    terms: plan.lessonItems,
                    totalQsOverride: plan.dragFillCount,
                    onFinished: { step = .write },
                    onCorrect: { term in lessons.markCorrect(language: language, id: term.id) }
                )

            case .write:
                WriteView(
                    language: language,
                    terms: plan.lessonItems,
                    totalQsOverride: plan.writeCount,
                    onFinished: { step = .listenWrite },
                    onCorrect: { term in lessons.markCorrect(language: language, id: term.id) }
                )

            case .listenWrite:
                ListenWriteView(
                    language: language,
                    terms: plan.lessonItems,
                    totalQsOverride: plan.listenWriteCount,   // we’ll add this
                    onFinished: { step = .done },
                    onCorrect: { term in lessons.markCorrect(language: language, id: term.id) }
                )

            case .done:
                doneView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Exit") { dismiss() }
            }
        }
    }

    private func header(step: Step) -> some View {
        HStack {
            Text("Unit \(unit) • \(lesson == engine.lessonsPerUnit ? "Review" : "Lesson \(lesson)")")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Spacer()

            Text(stepTitle(step))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func stepTitle(_ step: Step) -> String {
        switch step {
        case .dragFill: return "Drag & Fill"
        case .write:    return "Write"
        case .listenWrite:  return "Listen & Write"
        case .done:     return "Done"
        }
    }

    private var doneView: some View {
        VStack(spacing: 14) {
            Spacer()

            Text("Nice!")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Lesson complete — your weak sentences will keep coming back (on purpose 😈).")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Button { step = .dragFill } label: {
                Text("Repeat this lesson")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange.opacity(0.90))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 18)
            }
            .buttonStyle(.plain)

            Button { dismiss() } label: {
                Text("Back")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 18)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}
