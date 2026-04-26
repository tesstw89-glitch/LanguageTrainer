import SwiftUI

struct WeeksView: View {
    let language: AppLanguage
    let terms: [TermPair]
    @Binding var currentWeek: Int
    let itemsPerWeek: Int

    private var engine: WeekEngine {
        WeekEngine(itemsPerWeek: itemsPerWeek)
    }

    private var totalWeeks: Int {
        engine.totalWeeks(termCount: terms.count)
    }

    private var safeCurrentWeek: Int {
        engine.clampWeek(currentWeek, termCount: terms.count)
    }

    var body: some View {
        List {
            currentWeekSection
            weeksSection
        }
        .navigationTitle("Weeks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            currentWeek = safeCurrentWeek
        }
    }

    // MARK: - Sections

    private var currentWeekSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current week: \(safeCurrentWeek)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Text("\(terms.count) items total")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var weeksSection: some View {
        Section {
            ForEach(1...max(1, totalWeeks), id: \.self) { week in
                Button {
                    currentWeek = week
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Week \(week)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))

                            Text(rangeText(for: week))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if week == safeCurrentWeek {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func rangeText(for week: Int) -> String {
        guard !terms.isEmpty else {
            return "No items"
        }

        let startIndex = (week - 1) * itemsPerWeek
        let endIndex = min(startIndex + itemsPerWeek, terms.count)

        guard startIndex < terms.count else {
            return "No items"
        }

        return "Items \(startIndex + 1)–\(endIndex)"
    }
}
