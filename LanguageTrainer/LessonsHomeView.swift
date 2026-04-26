import SwiftUI

struct LessonsHomeView: View {
    let language: AppLanguage

    @EnvironmentObject private var lessons: LessonsStore
    private let engine = LessonEngine()

    private var allSentences: [TermPair] {
        LessonsDataLoader.lessons(for: language)
    }

    private var totalUnits: Int {
        engine.totalUnits(sentenceCount: allSentences.count)
    }

    var body: some View {
        List {
            Section {
                Text("30 sentences per unit • heavy repetition • Drag & Fill + Write")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            Section("Units") {
                ForEach(1...max(1, totalUnits), id: \.self) { u in
                    NavigationLink(value: AppRoute.lessonUnit(language, unit: u)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Unit \(u)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))

                                let progress = unitProgress(unit: u)
                                Text("\(progress.mastered)/\(progress.total) mastered")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Lessons")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func unitProgress(unit: Int) -> (mastered: Int, total: Int) {
        let unitItems = engine.sentences(forUnit: unit, all: allSentences)
        let mastered = unitItems.filter { lessons.stage(language: language, id: $0.id) >= 3 }.count
        return (mastered, unitItems.count)
    }
}
