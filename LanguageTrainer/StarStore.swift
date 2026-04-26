import Foundation
import SwiftUI

@MainActor
final class StarStore: ObservableObject {
    @Published private(set) var starredIDs: Set<UUID> = []

    private let key = "starred_term_ids_v1"

    init() {
        load()
    }

    func isStarred(_ id: UUID) -> Bool {
        starredIDs.contains(id)
    }

    func toggle(_ id: UUID) {
        if starredIDs.contains(id) {
            starredIDs.remove(id)
        } else {
            starredIDs.insert(id)
        }
        save()
    }

    func set(_ id: UUID, starred: Bool) {
        if starred { starredIDs.insert(id) } else { starredIDs.remove(id) }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let arr = try? JSONDecoder().decode([UUID].self, from: data) {
            self.starredIDs = Set(arr)
        }
    }

    private func save() {
        let arr = Array(starredIDs)
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
