import SwiftUI
import Foundation

struct ExerciseHomeView: View {
    let language: AppLanguage
    @Binding var path: NavigationPath

    @AppStorage("currentWeek_french") private var currentWeekFrench: Int = 1
    @AppStorage("currentWeek_spanish") private var currentWeekSpanish: Int = 1
    @AppStorage("lastRandomWeek_french") private var lastRandomWeekFrench: Int = 0
    @AppStorage("lastRandomWeek_spanish") private var lastRandomWeekSpanish: Int = 0

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
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let termCount = mainTermCount()
            guard termCount > 0 else { return }

            currentWeek = WeekEngine(itemsPerWeek: itemsPerWeek)
                .clampWeek(currentWeek, termCount: termCount)
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
                placedButtons(topButtons, anchor: topAnchor)
                placedButtons(bottomButtons, anchor: bottomAnchor)
            }
        }
    }

    private func placedButtons(_ items: [PlacedButton], anchor: CGPoint) -> some View {
        ZStack {
            ForEach(items) { item in
                HiggledyButton(title: item.title) {
                    handleTap(title: item.title)
                }
                .rotationEffect(Angle.degrees(item.rotation))
                .position(x: anchor.x + item.x, y: anchor.y + item.y)
            }
        }
    }

    private func startRandomStudy() {
        let termCount = mainTermCount()
        guard termCount > 0 else { return }

        let engine = WeekEngine(itemsPerWeek: itemsPerWeek)
        let totalWeeks = engine.totalWeeks(termCount: termCount)

        let candidateWeeks = (1...totalWeeks).filter { week in
            totalWeeks == 1 || week != lastRandomWeek
        }

        guard let randomWeek = candidateWeeks.randomElement() else { return }
        lastRandomWeek = randomWeek

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

        print("🎲 Random study: \(language.rawValue), week \(randomWeek) of \(totalWeeks), \(randomExercise)")
        path.append(randomExercise)
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

    private func handleTap(title: String) {
        switch title {
        case "Match":
            path.append(AppRoute.match(language, week: currentWeek))

        case "Drag & Fill":
            path.append(AppRoute.dragAndFill(language, week: currentWeek))

        case "Choose your weeks!":
            path.append(AppRoute.chooseWeek(language))

        case "Weeks":
            path.append(AppRoute.weeks(language))

        case "Start a new week":
            path.append(AppRoute.startNewWeek(language))

        case "Full Study Flow":
            path.append(AppRoute.fullStudyFlow(language, week: currentWeek))

        case "Listen & Match":
            path.append(AppRoute.listenMatch(language, week: currentWeek))

        case "Write":
            path.append(AppRoute.write(language, week: currentWeek))

        case "Speak":
            path.append(AppRoute.speak(language, week: currentWeek))

        case "Match & Write":
            path.append(AppRoute.matchWrite(language, week: currentWeek))

        case "Listen & Write":
            path.append(AppRoute.listenWrite(language, week: currentWeek))

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
