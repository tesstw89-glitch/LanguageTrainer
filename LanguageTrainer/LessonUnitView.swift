import SwiftUI

struct LessonUnitView: View {
    let language: AppLanguage
    let unit: Int

    @EnvironmentObject private var lessons: LessonsStore
    private let engine = LessonEngine()

    private var allSentences: [TermPair] { LessonsDataLoader.lessons(for: language) }
    private var unitSentences: [TermPair] { engine.sentences(forUnit: unit, all: allSentences) }

    var body: some View {
        List {
            Section {
                let mastered = unitSentences.filter { lessons.stage(language: language, id: $0.id) >= 3 }.count
                Text("Unit \(unit) • \(mastered)/\(unitSentences.count) mastered")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Section("Lessons") {
                ForEach(1...engine.lessonsPerUnit, id: \.self) { l in
                    NavigationLink(value: AppRoute.lessonFlow(language, unit: unit, lesson: l)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(l == engine.lessonsPerUnit ? "Review lesson" : "Lesson \(l)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))

                                Text(lessonSubtitle(l))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Unit \(unit)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lessonSubtitle(_ lesson: Int) -> String {
        if unitSentences.isEmpty { return "No sentences in this unit yet" }

        if lesson == engine.lessonsPerUnit {
            let weak = unitSentences.filter { lessons.stage(language: language, id: $0.id) < 3 }.count
            return "Hammer weak items (\(weak) still shaky)"
        }

        let start = (lesson - 1) * engine.newPerLesson
        let end = min(start + engine.newPerLesson, unitSentences.count)
        if start >= end { return "Mixed practice" }

        let slice = Array(unitSentences[start..<end])
        let seen = slice.filter { lessons.stage(language: language, id: $0.id) > 0 }.count
        return "\(engine.newPerLesson) targets • \(seen)/\(slice.count) already seen"
    }
}
