import SwiftUI

struct StarButton: View {
    @EnvironmentObject private var stars: StarStore
    let id: UUID

    var body: some View {
        Button {
            stars.toggle(id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: stars.isStarred(id) ? "star.fill" : "star")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(stars.isStarred(id) ? Color.yellow : Color.gray.opacity(0.6))
                .padding(10)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct StarredTermsView: View {
    @EnvironmentObject private var stars: StarStore
    @Environment(\.dismiss) private var dismiss

    let language: AppLanguage
    let allTerms: [TermPair]

    private var allStarEligibleTerms: [TermPair] {
        var seen = Set<UUID>()
        let combined = allTerms + LanguageDataLoader.lemmas(for: language)

        return combined.filter { term in
            seen.insert(term.id).inserted
        }
    }

    private var starredTerms: [TermPair] {
        allStarEligibleTerms.filter { stars.starredIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if starredTerms.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "star")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.yellow)

                        Text("No starred terms yet")
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        Text("Star a phrase or chunk while studying and it will appear here.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(starredTerms) { term in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(term.foreign)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(.primary)

                                        Text(term.english)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    StarButton(id: term.id)
                                }
                                .padding(.vertical, 5)
                            }
                        } header: {
                            Text("\(starredTerms.count) starred")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Starred terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
