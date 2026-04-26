import SwiftUI

struct ChooseWeekView: View {
    let language: AppLanguage
    let allTerms: [TermPair]
    let itemsPerWeek: Int

    @AppStorage("currentWeek_french") private var currentWeekFrench: Int = 1
    @AppStorage("currentWeek_spanish") private var currentWeekSpanish: Int = 1

    private var currentWeek: Binding<Int> {
        Binding(
            get: {
                language == .french ? currentWeekFrench : currentWeekSpanish
            },
            set: { newValue in
                if language == .french {
                    currentWeekFrench = newValue
                } else {
                    currentWeekSpanish = newValue
                }
            }
        )
    }

    private var engine: WeekEngine { WeekEngine(itemsPerWeek: itemsPerWeek) }
    private var totalWeeks: Int { engine.totalWeeks(termCount: allTerms.count) }

    @State private var selectedWeeks: Set<Int> = []

    private var sortedSelectedWeeks: [Int] {
        selectedWeeks.sorted()
    }

    private var selectedTerms: [TermPair] {
        sortedSelectedWeeks.flatMap { week in
            engine.terms(forWeek: week, allTerms: allTerms)
        }
    }

    private var selectedWeeksLabel: String {
        if sortedSelectedWeeks.isEmpty { return "None" }
        return sortedSelectedWeeks.map { "Week \($0)" }.joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Choose your weeks!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .padding(.top, 10)

                Text("Tap as many weeks as you want")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Select current week") {
                        let cw = engine.clampWeek(currentWeek.wrappedValue, termCount: allTerms.count)
                        selectedWeeks = [cw]
                    }

                    Button("Clear all") {
                        selectedWeeks.removeAll()
                    }

                    Button("Select all") {
                        selectedWeeks = Set(1...max(1, totalWeeks))
                    }
                }
                .buttonStyle(.bordered)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 10)], spacing: 10) {
                    ForEach(1...max(1, totalWeeks), id: \.self) { week in
                        Button {
                            if selectedWeeks.contains(week) {
                                selectedWeeks.remove(week)
                            } else {
                                selectedWeeks.insert(week)
                            }
                        } label: {
                            Text("Week \(week)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedWeeks.contains(week)
                                    ? Color.blue
                                    : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    selectedWeeks.contains(week)
                                    ? .white
                                    : .primary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)

                VStack(spacing: 6) {
                    Text("Selected: \(selectedWeeksLabel)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text("Terms in selected weeks: \(selectedTerms.count)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 10) {
                    NavigationLink("Match") {
                        MatchView(language: language, allTerms: selectedTerms)
                    }
                    NavigationLink("Drag & Fill") {
                        DragFillView(language: language, terms: selectedTerms)
                    }
                    NavigationLink("Speak") {
                        SpeakView(language: language, terms: selectedTerms)
                    }
                    NavigationLink("Listen & Match") {
                        ListenMatchView(language: language, allTerms: selectedTerms)
                    }
                    NavigationLink("Write") {
                        WriteView(language: language, terms: selectedTerms)
                    }
                    NavigationLink("Match & Write") {
                        MatchWriteView(language: language, allTerms: selectedTerms)
                    }
                    NavigationLink("Full Study Flow") {
                        FullStudyFlowView(language: language, terms: selectedTerms)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .disabled(selectedTerms.isEmpty)

                Button {
                    if let firstSelected = sortedSelectedWeeks.first {
                        currentWeek.wrappedValue = firstSelected
                    }
                } label: {
                    Text("Set first selected week as current week")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .buttonStyle(.bordered)
                .disabled(sortedSelectedWeeks.isEmpty)
                .padding(.top, 6)

                Spacer(minLength: 20)
            }
        }
        .navigationTitle("Choose weeks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let cw = engine.clampWeek(currentWeek.wrappedValue, termCount: allTerms.count)
            currentWeek.wrappedValue = cw

            if selectedWeeks.isEmpty {
                selectedWeeks = [cw]
            }
        }
    }
}
