import Foundation
import SwiftUI

struct WeekEngine {
    let itemsPerWeek: Int

    init(itemsPerWeek: Int = 200) {
        self.itemsPerWeek = max(1, itemsPerWeek)
    }

    func totalWeeks(termCount: Int) -> Int {
        guard termCount > 0 else { return 1 }
        return Int(ceil(Double(termCount) / Double(itemsPerWeek)))
    }

    func clampWeek(_ week: Int, termCount: Int) -> Int {
        let tw = totalWeeks(termCount: termCount)
        return min(max(week, 1), tw)
    }

    func terms(forWeek week: Int, allTerms: [TermPair]) -> [TermPair] {
        let w = clampWeek(week, termCount: allTerms.count)
        let start = (w - 1) * itemsPerWeek
        let end = min(start + itemsPerWeek, allTerms.count)
        guard start < end else { return [] }
        return Array(allTerms[start..<end])
    }

    func nextWeek(from current: Int, termCount: Int) -> Int {
        let tw = totalWeeks(termCount: termCount)
        if tw <= 1 { return 1 }
        return (current % tw) + 1
    }
}
