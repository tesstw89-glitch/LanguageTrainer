import Foundation
import SwiftUI

struct TermPair: Identifiable, Hashable, Codable {

    let id: UUID
    let foreign: String
    let english: String
    let context: String?

    init(
        id: UUID = UUID(),
        foreign: String,
        english: String,
        context: String? = nil
    ) {
        self.id = id
        self.foreign = foreign
        self.english = english
        self.context = context
    }
}

struct LessonItem: Identifiable, Hashable, Codable {

    let id: UUID
    let foreign: String
    let english: String
    let lemmas: [TermPair]
    let context: String?

    init(
        id: UUID = UUID(),
        foreign: String,
        english: String,
        lemmas: [TermPair] = [],
        context: String? = nil
    ) {
        self.id = id
        self.foreign = foreign
        self.english = english
        self.lemmas = lemmas
        self.context = context
    }

    var asTermPair: TermPair {
        TermPair(
            id: id,
            foreign: foreign,
            english: english,
            context: context
        )
    }
}

struct ContextHelpButton: View {
    let context: String?

    @State private var isShowingContext = false

    private var cleanedContext: String? {
        guard let context else { return nil }

        let cleaned = context.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    var body: some View {
        if let cleanedContext {
            Button {
                isShowingContext = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(10)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show context")
            .alert("Context", isPresented: $isShowingContext) {
                Button("Close", role: .cancel) { }
            } message: {
                Text(cleanedContext)
            }
        }
    }
}
