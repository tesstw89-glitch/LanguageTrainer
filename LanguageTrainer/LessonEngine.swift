import Foundation

struct LessonEngine {
    let unitSize: Int = 30

    // Lessons 1–5 = new+review, Lesson 6 = review-only
    let lessonsPerUnit: Int = 6
    let newPerLesson: Int = 6          // 5 * 6 = 30
    let reviewPerLesson: Int = 9       // lots of repetition

    struct Plan {
        let lessonItems: [TermPair]    // pool used by DragFill + Write + Listen&Write
        let dragFillCount: Int
        let writeCount: Int
        let listenWriteCount: Int
    }

    func totalUnits(sentenceCount: Int) -> Int {
        guard sentenceCount > 0 else { return 1 }
        return Int(ceil(Double(sentenceCount) / Double(unitSize)))
    }

    func sentences(forUnit unit: Int, all: [TermPair]) -> [TermPair] {
        let u = max(1, unit)
        let start = (u - 1) * unitSize
        let end = min(start + unitSize, all.count)
        guard start < end else { return [] }
        return Array(all[start..<end])
    }

    /// ✅ MainActor because it reads `LessonsStore` (which is MainActor-isolated)
    @MainActor
    func plan(
        language: AppLanguage,
        unit: Int,
        lesson: Int,
        unitSentences: [TermPair],
        store: LessonsStore
    ) -> Plan {

        let lessonClamped = max(1, min(lesson, lessonsPerUnit))

        // Lesson 6 = review hammer (weak first)
        if lessonClamped == lessonsPerUnit {
            let ordered = unitSentences.sorted { a, b in
                store.stage(language: language, id: a.id) < store.stage(language: language, id: b.id)
            }

            return Plan(
                lessonItems: ordered,
                dragFillCount: 10,
                writeCount: 5,
                listenWriteCount: 6
            )
        }

        // Lessons 1–5: 6 scheduled new items each
        let newRangeStart = (lessonClamped - 1) * newPerLesson
        let newRangeEnd = min(newRangeStart + newPerLesson, unitSentences.count)

        let scheduledNew: [TermPair] =
            (newRangeStart < newRangeEnd) ? Array(unitSentences[newRangeStart..<newRangeEnd]) : []

        var newItems: [TermPair] = scheduledNew

        // Top-up with true stage-0 items if needed
        if newItems.count < newPerLesson {
            let stage0 = unitSentences.filter { store.stage(language: language, id: $0.id) == 0 }
            for s in stage0 {
                if newItems.count >= newPerLesson { break }
                if !newItems.contains(where: { $0.id == s.id }) {
                    newItems.append(s)
                }
            }
        }

        // Review pool: anything seen before
        let reviewPool = unitSentences.filter { store.stage(language: language, id: $0.id) > 0 }

        // Weighted: prefer low stage + higher wrongStreak + older lastSeen
        let weighted = reviewPool.sorted { a, b in
            let sa = store.stage(language: language, id: a.id)
            let sb = store.stage(language: language, id: b.id)

            let wa = (6 - sa) + (store.progress(language: language, id: a.id)?.wrongStreak ?? 0) * 2
            let wb = (6 - sb) + (store.progress(language: language, id: b.id)?.wrongStreak ?? 0) * 2

            if wa == wb {
                let la = store.progress(language: language, id: a.id)?.lastSeen ?? .distantPast
                let lb = store.progress(language: language, id: b.id)?.lastSeen ?? .distantPast
                return la < lb
            }

            return wa > wb
        }

        let reviewItems = Array(weighted.prefix(reviewPerLesson))

        // Merge (dedupe by id)
        let merged = dedupeByID(newItems + reviewItems)

        return Plan(
            lessonItems: merged,
            dragFillCount: 8,
            writeCount: 4,
            listenWriteCount: 5
        )
    }

    private func dedupeByID(_ items: [TermPair]) -> [TermPair] {
        var seen = Set<UUID>()
        var out: [TermPair] = []
        out.reserveCapacity(items.count)

        for item in items {
            if seen.insert(item.id).inserted {
                out.append(item)
            }
        }
        return out
    }
}
