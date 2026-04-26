import Foundation
import SwiftUI

struct WeekEngine {
    let itemsPerWeek: Int

    init(itemsPerWeek: Int = 200) {
        self.itemsPerWeek = max(1, itemsPerWeek)
    }

    // MARK: - Basic week maths

    func totalWeeks(termCount: Int) -> Int {
        guard termCount > 0 else { return 1 }
        return Int(ceil(Double(termCount) / Double(itemsPerWeek)))
    }

    func clampWeek(_ week: Int, termCount: Int) -> Int {
        let tw = totalWeeks(termCount: termCount)
        return min(max(week, 1), tw)
    }

    func nextWeek(from current: Int, termCount: Int) -> Int {
        let tw = totalWeeks(termCount: termCount)
        if tw <= 1 { return 1 }
        return (current % tw) + 1
    }

    // MARK: - Existing old-style term slicing

    func terms(forWeek week: Int, allTerms: [TermPair]) -> [TermPair] {
        let w = clampWeek(week, termCount: allTerms.count)
        let start = (w - 1) * itemsPerWeek
        let end = min(start + itemsPerWeek, allTerms.count)

        guard start < end else { return [] }

        return Array(allTerms[start..<end])
    }

    // MARK: - New lesson sentence slicing

    func lessonItems(forWeek week: Int, allLessons: [LessonItem]) -> [LessonItem] {
        let w = clampWeek(week, termCount: allLessons.count)
        let start = (w - 1) * itemsPerWeek
        let end = min(start + itemsPerWeek, allLessons.count)

        guard start < end else { return [] }

        return Array(allLessons[start..<end])
    }

    func lessonSentences(forWeek week: Int, allLessons: [LessonItem]) -> [TermPair] {
        lessonItems(forWeek: week, allLessons: allLessons)
            .map { $0.asTermPair }
    }

    // MARK: - New lemma/chunk extraction for Match-style games

    func lemmaTerms(forWeek week: Int, allLessons: [LessonItem]) -> [TermPair] {
        let weekLessons = lessonItems(forWeek: week, allLessons: allLessons)

        var seen = Set<String>()
        var result: [TermPair] = []

        for lesson in weekLessons {
            for lemma in lesson.lemmas {
                let cleanedForeign = lemma.foreign.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedEnglish = lemma.english.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !cleanedForeign.isEmpty else { continue }
                guard !cleanedEnglish.isEmpty else { continue }

                let count = wordCount(cleanedForeign)
                guard count >= 1 && count <= 3 else { continue }

                let key = normalisedKey(cleanedForeign)
                guard !seen.contains(key) else { continue }

                seen.insert(key)

                result.append(
                    TermPair(
                        id: lemma.id,
                        foreign: cleanedForeign,
                        english: cleanedEnglish
                    )
                )
            }
        }

        return result
    }

    // MARK: - Helpers

    private func wordCount(_ text: String) -> Int {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .count
    }

    private func normalisedKey(_ text: String) -> String {
        var value = text
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "´", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value
    }
}
