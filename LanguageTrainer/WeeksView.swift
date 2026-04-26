import SwiftUI

struct WeeksView: View {
    let language: AppLanguage
    let allTerms: [TermPair]
    @Binding var currentWeek: Int
    let itemsPerWeek: Int

    private var engine: WeekEngine { WeekEngine(itemsPerWeek: itemsPerWeek) }
    private var totalWeeks: Int { engine.totalWeeks(termCount: allTerms.count) }

    var body: some View {
        List {
            Section {
                Text("Current week: \(engine.clampWeek(currentWeek, termCount: allTerms.count))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }

            ForEach(1...max(1, totalWeeks), id: \.self) { w in
                Button {
                    currentWeek = w
                } label: {
                    HStack {
                        Text("Week \(w)")
                        Spacer()
                        if w == engine.clampWeek(currentWeek, termCount: allTerms.count) {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                }
            }
        }
        .navigationTitle("Weeks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            currentWeek = engine.clampWeek(currentWeek, termCount: allTerms.count)
        }
    }
}
