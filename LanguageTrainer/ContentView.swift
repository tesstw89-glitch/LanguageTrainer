import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var didPrintFrenchVoices = false

    private let itemsPerWeek: Int = 200

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
                allTerms: allSentenceTerms(for: lang),
                itemsPerWeek: itemsPerWeek
            )

        // MARK: - Lemma / chunk exercises only

        case .match(let lang, let week):
            MatchView(
                language: lang,
                allTerms: lemmaTerms(for: lang, week: week)
            )

        case .listenMatch(let lang, let week):
            ListenMatchView(
                language: lang,
                allTerms: lemmaTerms(for: lang, week: week)
            )

        case .matchWrite(let lang, let week):
            MatchWriteView(
                language: lang,
                allTerms: lemmaTerms(for: lang, week: week)
            )

        case .write(let lang, let week):
            WriteView(
                language: lang,
                terms: lemmaTerms(for: lang, week: week)
            )

        case .listenWrite(let lang, let week):
            ListenWriteView(
                language: lang,
                terms: lemmaTerms(for: lang, week: week),
                totalQsOverride: 12
            )

        // MARK: - Full sentence exercises only

        case .dragAndFill(let lang, let week):
            DragFillView(
                language: lang,
                terms: sentenceTerms(for: lang, week: week)
            )

        case .speak(let lang, let week):
            SpeakView(
                language: lang,
                terms: sentenceTerms(for: lang, week: week)
            )

        // MARK: - Full Study Flow uses both

        case .fullStudyFlow(let lang, let week):
            FullStudyFlowView(
                language: lang,
                sentenceTerms: sentenceTerms(for: lang, week: week),
                lemmaTerms: lemmaTerms(for: lang, week: week)
            )

        // MARK: - Lesson routes

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

    // MARK: - Data helpers

    private func allLessonItems(for language: AppLanguage) -> [LessonItem] {
        LessonsDataLoader.lessonItems(for: language)
    }

    private func allSentenceTerms(for language: AppLanguage) -> [TermPair] {
        LessonsDataLoader.lessons(for: language)
    }

    private func sentenceTerms(for language: AppLanguage, week: Int) -> [TermPair] {
        let lessons = allLessonItems(for: language)

        return WeekEngine(itemsPerWeek: itemsPerWeek)
            .lessonSentences(forWeek: week, allLessons: lessons)
    }

    private func lemmaTerms(for language: AppLanguage, week: Int) -> [TermPair] {
        let lessons = allLessonItems(for: language)

        return WeekEngine(itemsPerWeek: itemsPerWeek)
            .lemmaTerms(forWeek: week, allLessons: lessons)
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

    private let itemsPerWeek: Int = 200

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

    private var termsForLanguage: [TermPair] {
        LessonsDataLoader.lessons(for: language)
    }

    var body: some View {
        WeeksView(
            language: language,
            terms: termsForLanguage,
            currentWeek: currentWeekBinding,
            itemsPerWeek: itemsPerWeek
        )
    }
}

// MARK: - Start New Week jump with separate current week per language

private struct StartNewWeekJump: View {
    let lang: AppLanguage
    @Binding var path: NavigationPath

    @AppStorage("currentWeek_french") private var currentWeekFrench: Int = 1
    @AppStorage("currentWeek_spanish") private var currentWeekSpanish: Int = 1

    private let itemsPerWeek: Int = 200

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
                let allLessons = LessonsDataLoader.lessonItems(for: lang)
                let engine = WeekEngine(itemsPerWeek: itemsPerWeek)

                currentWeek = engine.nextWeek(
                    from: currentWeek,
                    termCount: allLessons.count
                )

                path.removeLast(path.count)
                path.append(AppRoute.exerciseHome(lang))
            }
    }
}

#Preview {
    ContentView()
}
