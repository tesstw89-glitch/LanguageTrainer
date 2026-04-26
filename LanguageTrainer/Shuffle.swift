import Foundation

extension Array {
    /// In-place Fisher–Yates shuffle
    mutating func fisherYatesShuffle() {
        guard count > 1 else { return }
        // i from last index down to 1
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i)
            if i != j { swapAt(i, j) }
        }
    }

    /// Returns a Fisher–Yates shuffled copy
    func fisherYatesShuffled() -> [Element] {
        var copy = self
        copy.fisherYatesShuffle()
        return copy
    }
}
