import Foundation

struct TermPair: Identifiable, Hashable, Codable {

    let id: UUID
    let foreign: String
    let english: String

    init(
        id: UUID = UUID(),
        foreign: String,
        english: String
    ) {
        self.id = id
        self.foreign = foreign
        self.english = english
    }
}
