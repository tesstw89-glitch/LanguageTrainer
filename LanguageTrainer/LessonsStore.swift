import Foundation

struct LessonItemProgress: Codable {
    var stage: Int          // 0 = new, higher = more mastered
    var lastSeen: Date
    var wrongStreak: Int
}

@MainActor
final class LessonsStore: ObservableObject {

    @Published private var fr: [UUID: LessonItemProgress] = [:]
    @Published private var es: [UUID: LessonItemProgress] = [:]

    private let keyFR = "lessons_progress_fr_v1"
    private let keyES = "lessons_progress_es_v1"

    init() {
        fr = load(key: keyFR)
        es = load(key: keyES)
    }

    func stage(language: AppLanguage, id: UUID) -> Int {
        progress(language: language, id: id)?.stage ?? 0
    }

    func progress(language: AppLanguage, id: UUID) -> LessonItemProgress? {
        switch language {
        case .french:  return fr[id]
        case .spanish: return es[id]
        }
    }

    func markCorrect(language: AppLanguage, id: UUID) {
        var p = progress(language: language, id: id) ?? LessonItemProgress(stage: 0, lastSeen: .distantPast, wrongStreak: 0)
        p.stage = min(p.stage + 1, 6)
        p.lastSeen = Date()
        p.wrongStreak = 0
        set(language: language, id: id, p)
    }

    func markWrong(language: AppLanguage, id: UUID) {
        var p = progress(language: language, id: id) ?? LessonItemProgress(stage: 0, lastSeen: .distantPast, wrongStreak: 0)
        p.stage = max(p.stage - 1, 0)
        p.lastSeen = Date()
        p.wrongStreak += 1
        set(language: language, id: id, p)
    }

    private func set(language: AppLanguage, id: UUID, _ p: LessonItemProgress) {
        switch language {
        case .french:
            fr[id] = p
            save(fr, key: keyFR)
        case .spanish:
            es[id] = p
            save(es, key: keyES)
        }
    }

    private func load(key: String) -> [UUID: LessonItemProgress] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([UUID: LessonItemProgress].self, from: data)) ?? [:]
    }

    private func save(_ dict: [UUID: LessonItemProgress], key: String) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
