import SwiftUI
import Foundation

struct ExerciseHomeView: View {
    let language: AppLanguage
    @Binding var path: NavigationPath

    @AppStorage("currentWeek_french") private var currentWeekFrench: Int = 1
    @AppStorage("currentWeek_spanish") private var currentWeekSpanish: Int = 1
    @AppStorage("lastRandomWeek_french") private var lastRandomWeekFrench: Int = 0
    @AppStorage("lastRandomWeek_spanish") private var lastRandomWeekSpanish: Int = 0
    @AppStorage("lastCorrelation_french") private var lastCorrelationFrench: String = ""
    @AppStorage("lastCorrelation_spanish") private var lastCorrelationSpanish: String = ""

    @State private var pendingExerciseTitle: String? = nil
    @State private var showingStarredTerms = false
    @State private var showingCorrelationUnavailable = false

    private var currentWeek: Int {
        get { language == .french ? currentWeekFrench : currentWeekSpanish }
        nonmutating set {
            if language == .french { currentWeekFrench = newValue }
            else { currentWeekSpanish = newValue }
        }
    }

    private var lastRandomWeek: Int {
        get { language == .french ? lastRandomWeekFrench : lastRandomWeekSpanish }
        nonmutating set {
            if language == .french { lastRandomWeekFrench = newValue }
            else { lastRandomWeekSpanish = newValue }
        }
    }

    private var lastCorrelation: String {
        get { language == .french ? lastCorrelationFrench : lastCorrelationSpanish }
        nonmutating set {
            if language == .french { lastCorrelationFrench = newValue }
            else { lastCorrelationSpanish = newValue }
        }
    }

    private let itemsPerWeek: Int = 200

    struct PlacedButton: Identifiable {
        let id = UUID()
        let title: String
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
    }

    private let topButtons: [PlacedButton] = [
        .init(title: "Full Study Flow",  x: -66, y: -150, rotation: -1.0),
        .init(title: "Listen & Match",   x: -70, y: -85,  rotation:  1.2),
        .init(title: "Match",            x:  70, y: -85,  rotation: -0.6),
        .init(title: "Drag & Fill",      x: -50, y: -20,  rotation:  0.8),
        .init(title: "Write",            x:  60, y: -20,  rotation: -1.1),
        .init(title: "Speak",            x: -64, y:  50,  rotation:  0.5),
        .init(title: "Match & Write",    x:  70, y:  50,  rotation: -0.7),
        .init(title: "Listen & Write",   x:  90, y: -150, rotation:  0.4)
    ]

    private let bottomButtons: [PlacedButton] = [
        .init(title: "Start a new week",    x:   6, y: -170, rotation:  0.9),
        .init(title: "Weeks",               x: -80, y: -115, rotation: -0.6),
        .init(title: "Choose your weeks!",  x:  72, y: -115, rotation:  0.8),
        .init(title: "Known terms",         x:  82, y:  -60, rotation: -0.7),
        .init(title: "Starred terms",       x: -70, y:  -60, rotation:  0.6),
        .init(title: "Discarded 🗑️",        x: -60, y:   -5, rotation: -0.4),
        .init(title: "Added terms",         x:  90, y:   -5, rotation:  0.7),
        .init(title: "Export All Terms",    x:  -8, y:   50, rotation: -0.8)
    ]

    var body: some View {
        ZStack {
            background
            headerArea
            buttonsLayer
            randomStudyButton

            if let pendingExerciseTitle {
                weekChoiceOverlay(for: pendingExerciseTitle)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CorrelationRoute.self) { route in
            CorrelationExerciseDestination(route: route)
        }
        .onAppear {
            let termCount = mainTermCount()
            guard termCount > 0 else { return }

            currentWeek = WeekEngine(itemsPerWeek: itemsPerWeek)
                .clampWeek(currentWeek, termCount: termCount)
        }
        .sheet(isPresented: $showingStarredTerms) {
            StarredTermsView(
                language: language,
                allTerms: LanguageDataLoader.terms(for: language)
            )
        }
        .alert("Correlations", isPresented: $showingCorrelationUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("I couldn't find a correlation with at least \(CorrelationEngine.minimumMatches) matching sentences.")
        }
    }

    private var background: some View {
        Image("exercisehome")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    private var headerArea: some View {
        VStack(spacing: 10) {
            Text(language.rawValue)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 52)

            Spacer()
        }
    }

    private var randomStudyButton: some View {
        VStack {
            HStack {
                Spacer()

                Button(action: startRandomStudy) {
                    Image("dice")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .contentShape(Rectangle())
                        .shadow(radius: 5, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Random study")
                .accessibilityHint("Chooses a random week and a random exercise")
            }
            .padding(.top, 42)
            .padding(.trailing, 18)

            Spacer()
        }
    }

    private var buttonsLayer: some View {
        GeometryReader { geo in
            let topAnchor = CGPoint(x: geo.size.width / 2, y: 290)
            let bottomAnchor = CGPoint(x: geo.size.width / 2, y: 660)

            ZStack {
                placedButtons(topButtons, anchor: topAnchor, showsWeekChoice: true)
                placedButtons(bottomButtons, anchor: bottomAnchor, showsWeekChoice: false)
            }
        }
    }

    private func placedButtons(
        _ items: [PlacedButton],
        anchor: CGPoint,
        showsWeekChoice: Bool
    ) -> some View {
        ZStack {
            ForEach(items) { item in
                HiggledyButton(title: item.title) {
                    if showsWeekChoice {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            pendingExerciseTitle = item.title
                        }
                    } else {
                        handleTap(title: item.title)
                    }
                }
                .rotationEffect(Angle.degrees(item.rotation))
                .position(x: anchor.x + item.x, y: anchor.y + item.y)
            }
        }
    }

    // MARK: - Week / source choice overlay

    private func weekChoiceOverlay(for exerciseTitle: String) -> some View {
        let hasCorrelations = supportsCorrelations(exerciseTitle)

        return ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissWeekChoice()
                }

            VStack(spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exerciseTitle)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)

                        Text(hasCorrelations ? "Choose a source" : "Which week?")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        dismissWeekChoice()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    openExercise(exerciseTitle, week: currentWeek)
                } label: {
                    weekChoiceButton(
                        title: "Study week",
                        subtitle: "Week \(currentWeek)"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    guard let randomWeek = chooseRandomWeek() else { return }
                    openExercise(exerciseTitle, week: randomWeek)
                } label: {
                    weekChoiceButton(
                        title: "Random week",
                        subtitle: "Surprise me"
                    )
                }
                .buttonStyle(.plain)

                if hasCorrelations {
                    Button {
                        openCorrelationExercise(exerciseTitle)
                    } label: {
                        weekChoiceButton(
                            title: "Correlations",
                            subtitle: "Same 2–3 words across every sentence"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(Color.white.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.green.opacity(0.70), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
            .padding(.horizontal, 28)
        }
        .zIndex(100)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func weekChoiceButton(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.green.opacity(0.65), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
    }

    private func dismissWeekChoice() {
        withAnimation(.easeInOut(duration: 0.16)) {
            pendingExerciseTitle = nil
        }
    }

    private func supportsCorrelations(_ exerciseTitle: String) -> Bool {
        exerciseTitle == "Drag & Fill" || exerciseTitle == "Listen & Write"
    }

    private func openCorrelationExercise(_ exerciseTitle: String) {
        let allTerms = CorrelationEngine.allSentenceTerms(for: language)
        let previous = lastCorrelation.isEmpty ? nil : lastCorrelation

        guard let candidate = CorrelationEngine.randomCorrelation(
            for: language,
            terms: allTerms,
            excluding: previous
        ) else {
            showingCorrelationUnavailable = true
            return
        }

        lastCorrelation = candidate.phrase
        pendingExerciseTitle = nil

        print(
            "🔗 Correlation study: \(language.rawValue), \(candidate.phrase), \(candidate.matchCount) sentences"
        )

        switch exerciseTitle {
        case "Drag & Fill":
            path.append(
                CorrelationRoute.dragAndFill(
                    language,
                    phrase: candidate.phrase
                )
            )

        case "Listen & Write":
            path.append(
                CorrelationRoute.listenWrite(
                    language,
                    phrase: candidate.phrase
                )
            )

        default:
            break
        }
    }

    // MARK: - Random study

    private func startRandomStudy() {
        guard let randomWeek = chooseRandomWeek() else { return }

        let exerciseRoutes: [AppRoute] = [
            .listenMatch(language, week: randomWeek),
            .match(language, week: randomWeek),
            .dragAndFill(language, week: randomWeek),
            .write(language, week: randomWeek),
            .speak(language, week: randomWeek),
            .matchWrite(language, week: randomWeek),
            .listenWrite(language, week: randomWeek)
        ]

        guard let randomExercise = exerciseRoutes.randomElement() else { return }

        print("🎲 Random study: \(language.rawValue), week \(randomWeek), \(randomExercise)")
        path.append(randomExercise)
    }

    private func chooseRandomWeek() -> Int? {
        let termCount = mainTermCount()
        guard termCount > 0 else { return nil }

        let engine = WeekEngine(itemsPerWeek: itemsPerWeek)
        let totalWeeks = engine.totalWeeks(termCount: termCount)

        let candidateWeeks = (1...totalWeeks).filter { week in
            totalWeeks == 1 || week != lastRandomWeek
        }

        guard let randomWeek = candidateWeeks.randomElement() else { return nil }
        lastRandomWeek = randomWeek

        return randomWeek
    }

    private func mainTermCount() -> Int {
        let resourceName = language == .french ? "french_terms" : "spanish_terms"

        guard let url =
                Bundle.main.url(forResource: resourceName, withExtension: "json") ??
                Bundle.main.url(forResource: resourceName, withExtension: "JSON")
        else {
            print("❌ Missing \(resourceName).json in bundle")
            return 0
        }

        do {
            let rawData = try Data(contentsOf: url)
            let cleanedString = String(decoding: rawData, as: UTF8.self)

            guard let cleanedData = cleanedString.data(using: .utf8),
                  let entries = try JSONSerialization.jsonObject(with: cleanedData) as? [[String: Any]]
            else {
                return 0
            }

            return entries.count
        } catch {
            print("❌ Couldn't count terms in \(resourceName).json:", error)
            return 0
        }
    }

    // MARK: - Exercise routing

    private func openExercise(_ title: String, week: Int) {
        guard let route = exerciseRoute(for: title, week: week) else { return }
        pendingExerciseTitle = nil
        path.append(route)
    }

    private func exerciseRoute(for title: String, week: Int) -> AppRoute? {
        switch title {
        case "Full Study Flow":
            return .fullStudyFlow(language, week: week)

        case "Listen & Match":
            return .listenMatch(language, week: week)

        case "Match":
            return .match(language, week: week)

        case "Drag & Fill":
            return .dragAndFill(language, week: week)

        case "Write":
            return .write(language, week: week)

        case "Speak":
            return .speak(language, week: week)

        case "Match & Write":
            return .matchWrite(language, week: week)

        case "Listen & Write":
            return .listenWrite(language, week: week)

        default:
            return nil
        }
    }

    // MARK: - Bottom buttons

    private func handleTap(title: String) {
        switch title {
        case "Choose your weeks!":
            path.append(AppRoute.chooseWeek(language))

        case "Weeks":
            path.append(AppRoute.weeks(language))

        case "Start a new week":
            path.append(AppRoute.startNewWeek(language))

        case "Starred terms":
            showingStarredTerms = true

        default:
            break
        }
    }
}

// ✅ If you already have this somewhere else, delete this duplicate.
struct HiggledyButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.green, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}
