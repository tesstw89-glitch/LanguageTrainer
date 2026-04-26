import Foundation

struct TokenItem: Identifiable, Hashable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }

    var dragPayload: String { id.uuidString }
}
