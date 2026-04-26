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

struct LessonItem: Identifiable, Hashable, Codable {

    let id: UUID
    let foreign: String
    let english: String
    let lemmas: [TermPair]

    init(
        id: UUID = UUID(),
        foreign: String,
        english: String,
        lemmas: [TermPair] = []
    ) {
        self.id = id
        self.foreign = foreign
        self.english = english
        self.lemmas = lemmas
    }

    var asTermPair: TermPair {
        TermPair(
            id: id,
            foreign: foreign,
            english: english
        )
    }
}
