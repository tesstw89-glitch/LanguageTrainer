import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var didPrintFrenchVoices = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Image("homescreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 14) {
                        NavigationLink(value: AppRoute.exerciseHome(.french)) {
                            langButton("French", color: .blue)
                        }

                        NavigationLink(value: AppRoute.exerciseHome(.spanish)) {
                            langButton("Spanish", color: .red)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 350)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
            .onAppear {
                if !didPrintFrenchVoices {
                    didPrintFrenchVoices = true
                    printFrenchVoices()
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {

        case .exerciseHome(let lang):
            ExerciseHomeView(language: lang, path: $path)

        case .chooseWeek(let lang):
            ChooseWeekView(
                language: lang,
                allTerms: LanguageDataLoader.terms(for: lang),
                itemsPerWeek: 200
            )

        case .match(let lang, let week):
            let all = LanguageDataLoader.terms(for: lang)
            let terms = WeekEngine(itemsPerWeek: 200).terms(forWeek: week, allTerms: all)
            MatchView(language: lang, allTerms: terms)

        case .dragAndFill(let lang, let week):
            let all = LanguageDataLoader.terms(for: lang)
            let terms = WeekEngine(itemsPerWeek: 200).terms(forWeek: week, allTerms: all)
            DragFillView(language: lang, terms: terms)

        case .speak(let lang, let week):
            let all = LanguageDataLoader.terms(for: lang)
            let terms = WeekEngine(itemsPerWeek: 200).terms(forWeek: week, allTerms: all)
            SpeakView(language: lang, terms: terms)

        case .listenMatch(let lang, let week):
            let all = LanguageDataLoader.terms(for: lang)
            let terms = WeekEngine(itemsPerWeek: 200).terms(forWeek: week, allTerms: all)
            ListenMatchView(language: lang, allTerms: terms)

        case .write(let lang, let week):
            let all = LanguageDataLoader.terms(for: lang)
            let terms = WeekEngine(itemsPerWeek: 200).terms(forWeek: week, allTerms: all)
            WriteView(language: lang, terms: terms)

        case .matchWrite(let lang, let week):
            let all = LanguageDataLoader.terms(for: lang)
            let terms = WeekEngine(itemsPerWeek: 200).terms(forWeek: week, allTerms: all)
            MatchWriteView(language: lang, allTerms: terms)

        case .fullStudyFlow(let lang, let week):
            let all = LanguageDataLoader.terms(for: lang)
            let terms = WeekEngine(itemsPerWeek: 200).terms(forWeek: week, allTerms: all)
            FullStudyFlowView(language: lang, terms: terms)
            
        case .listenWrite(let lang, let week):
            let all = LessonsDataLoader.lessons(for: lang)
            let sentences = WeekEngine(itemsPerWeek: 30).terms(forWeek: week, allTerms: all)
            ListenWriteView(language: lang, terms: sentences, totalQsOverride: 12)
            
        case .lessonsHome(let lang):
            LessonsHomeView(language: lang)

        case .lessonUnit(let lang, let unit):
            LessonUnitView(language: lang, unit: unit)

        case .lessonFlow(let lang, let unit, let lesson):
            LessonFlowView(language: lang, unit: unit, lesson: lesson)

        case .weeks(let lang):
            WeeksViewShell(language: lang)

        case .startNewWeek(let lang):
            StartNewWeekJump(lang: lang, path: $path)
        }
    }

    private func langButton(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 220, height: 56)
            .background(color.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Weeks shell with separate current week per language
private struct WeeksViewShell: View {
    let language: AppLanguage

    @AppStorage("currentWeek_french") private var currentWeekFrench: Int = 1
    @AppStorage("currentWeek_spanish") private var currentWeekSpanish: Int = 1

    private var currentWeekBinding: Binding<Int> {
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

    var body: some View {
        WeeksView(
            language: language,
            allTerms: LanguageDataLoader.terms(for: language),
            currentWeek: currentWeekBinding,
            itemsPerWeek: 200
        )
    }
}

// MARK: - Start New Week jump with separate current week per language
private struct StartNewWeekJump: View {
    let lang: AppLanguage
    @Binding var path: NavigationPath

    @AppStorage("currentWeek_french") private var currentWeekFrench: Int = 1
    @AppStorage("currentWeek_spanish") private var currentWeekSpanish: Int = 1

    private var currentWeek: Int {
        get {
            lang == .french ? currentWeekFrench : currentWeekSpanish
        }
        nonmutating set {
            if lang == .french {
                currentWeekFrench = newValue
            } else {
                currentWeekSpanish = newValue
            }
        }
    }

    var body: some View {
        Color.clear
            .onAppear {
                let all = LanguageDataLoader.terms(for: lang)
                let engine = WeekEngine(itemsPerWeek: 200)
                currentWeek = engine.nextWeek(from: currentWeek, termCount: all.count)

                path.removeLast(path.count)
                path.append(AppRoute.exerciseHome(lang))
            }
    }
}

#Preview {
    ContentView()
}
