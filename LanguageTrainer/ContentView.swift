import SwiftUI
import Foundation
import CryptoKit

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
        // These now come from french_terms.json / spanish_terms.json lemmas.

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
        // These now come from the main sentence rows in french_terms.json / spanish_terms.json.

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

        // MARK: - Full Study Flow uses both from terms JSON

        case .fullStudyFlow(let lang, let week):
            FullStudyFlowView(
                language: lang,
                sentenceTerms: sentenceTerms(for: lang, week: week),
                lemmaTerms: lemmaTerms(for: lang, week: week)
            )

        // MARK: - Hidden Lesson routes
        // Leave these using the lesson feature views.

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

    // MARK: - Data helpers for the normal app

    private func allMainItems(for language: AppLanguage) -> [LessonItem] {
        MainTermsDataLoader.items(for: language)
    }

    private func allSentenceTerms(for language: AppLanguage) -> [TermPair] {
        MainTermsDataLoader.sentenceTerms(for: language)
    }

    private func sentenceTerms(for language: AppLanguage, week: Int) -> [TermPair] {
        let items = allMainItems(for: language)

        return WeekEngine(itemsPerWeek: itemsPerWeek)
            .lessonSentences(forWeek: week, allLessons: items)
    }

    private func lemmaTerms(for language: AppLanguage, week: Int) -> [TermPair] {
        let items = allMainItems(for: language)

        return WeekEngine(itemsPerWeek: itemsPerWeek)
            .lemmaTerms(forWeek: week, allLessons: items)
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

// MARK: - Main terms JSON loader
// This reads french_terms.json / spanish_terms.json.
// It turns each sentence row into a LessonItem so WeekEngine can split sentences
// and extract lemmas cleanly.

private enum MainTermsDataLoader {
    private static var itemCache: [AppLanguage: [LessonItem]] = [:]
    private static var sentenceCache: [AppLanguage: [TermPair]] = [:]

    static func items(for language: AppLanguage) -> [LessonItem] {
        if let cached = itemCache[language] {
            return cached
        }

        let resourceName: String = {
            switch language {
            case .french:
                return "french_terms"
            case .spanish:
                return "spanish_terms"
            }
        }()

        let loaded = loadItems(fromResource: resourceName, language: language)

        if !loaded.isEmpty {
            itemCache[language] = loaded
        } else {
            print("⚠️ Loaded 0 main term items for \(language.rawValue) from \(resourceName).json")
        }

        return loaded
    }

    static func sentenceTerms(for language: AppLanguage) -> [TermPair] {
        if let cached = sentenceCache[language] {
            return cached
        }

        let sentences = items(for: language).map { $0.asTermPair }

        if !sentences.isEmpty {
            sentenceCache[language] = sentences
        }

        return sentences
    }

    private static func loadItems(fromResource name: String, language: AppLanguage) -> [LessonItem] {
        guard let url =
                Bundle.main.url(forResource: name, withExtension: "json") ??
                Bundle.main.url(forResource: name, withExtension: "JSON")
        else {
            print("❌ Missing \(name).json in bundle")
            print("👉 Check Target Membership and Build Phases > Copy Bundle Resources")
            return []
        }

        do {
            let rawData = try Data(contentsOf: url)
            let cleanedString = String(decoding: rawData, as: UTF8.self)

            guard let cleanedData = cleanedString.data(using: .utf8) else {
                print("❌ Failed to re-encode \(name).json")
                return []
            }

            let decoded = try JSONDecoder().decode([RawEntry].self, from: cleanedData)

            print("✅ Loaded \(decoded.count) main terms from \(url.lastPathComponent)")

            return decoded.compactMap { raw in
                let sentenceForeign = clean(raw.foreign)
                let sentenceEnglish = clean(raw.english)

                guard !sentenceForeign.isEmpty else { return nil }
                guard !sentenceEnglish.isEmpty else { return nil }

                let sentenceID = stableID(
                    prefix: "SENTENCE",
                    language: language,
                    foreign: sentenceForeign,
                    english: sentenceEnglish
                )

                let lemmaPairs: [TermPair] = raw.lemmas.compactMap { lemma in
                    let lemmaForeign = clean(lemma.foreign)
                    let lemmaEnglish = clean(lemma.english)

                    guard !lemmaForeign.isEmpty else { return nil }
                    guard !lemmaEnglish.isEmpty else { return nil }

                    return TermPair(
                        id: stableID(
                            prefix: "LEMMA",
                            language: language,
                            foreign: lemmaForeign,
                            english: lemmaEnglish
                        ),
                        foreign: lemmaForeign,
                        english: lemmaEnglish
                    )
                }

                return LessonItem(
                    id: sentenceID,
                    foreign: sentenceForeign,
                    english: sentenceEnglish,
                    lemmas: lemmaPairs
                )
            }

        } catch {
            print("❌ Main terms JSON decode failed for \(name).json:", error)
            return []
        }
    }

    private static func clean(_ text: String) -> String {
        var value = text
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value
    }

    private static func stableID(
        prefix: String,
        language: AppLanguage,
        foreign: String,
        english: String
    ) -> UUID {
        let raw = "\(prefix)|\(language.rawValue)|\(foreign)|\(english)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let bytes = Array(digest.prefix(16))

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private struct RawEntry: Decodable {
        let foreign: String
        let english: String
        let lemmas: [RawTerm]

        private struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }

            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            init?(intValue: Int) {
                return nil
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: AnyKey.self)

            foreign = try Self.decodeString(
                from: container,
                keys: ["foreign", "Foreign"]
            )

            english = try Self.decodeString(
                from: container,
                keys: ["english", "English"]
            )

            lemmas = try Self.decodeTermsIfPresent(
                from: container,
                keys: ["lemmas", "Lemmas", "chunks", "Chunks"]
            )
        }

        private static func decodeString(
            from container: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> String {
            for keyName in keys {
                if let key = AnyKey(stringValue: keyName),
                   let value = try container.decodeIfPresent(String.self, forKey: key) {
                    return value
                }
            }

            throw DecodingError.keyNotFound(
                AnyKey(stringValue: keys.first ?? "unknown")!,
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Missing keys \(keys)"
                )
            )
        }

        private static func decodeTermsIfPresent(
            from container: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> [RawTerm] {
            for keyName in keys {
                if let key = AnyKey(stringValue: keyName),
                   let value = try container.decodeIfPresent([RawTerm].self, forKey: key) {
                    return value
                }
            }

            return []
        }
    }

    private struct RawTerm: Decodable {
        let foreign: String
        let english: String

        private struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }

            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            init?(intValue: Int) {
                return nil
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: AnyKey.self)

            foreign = try Self.decodeString(
                from: container,
                keys: ["foreign", "Foreign"]
            )

            english = try Self.decodeString(
                from: container,
                keys: ["english", "English"]
            )
        }

        private static func decodeString(
            from container: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> String {
            for keyName in keys {
                if let key = AnyKey(stringValue: keyName),
                   let value = try container.decodeIfPresent(String.self, forKey: key) {
                    return value
                }
            }

            throw DecodingError.keyNotFound(
                AnyKey(stringValue: keys.first ?? "unknown")!,
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Missing keys \(keys)"
                )
            )
        }
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
        MainTermsDataLoader.sentenceTerms(for: language)
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
                let allItems = MainTermsDataLoader.items(for: lang)
                let engine = WeekEngine(itemsPerWeek: itemsPerWeek)

                currentWeek = engine.nextWeek(
                    from: currentWeek,
                    termCount: allItems.count
                )

                path.removeLast(path.count)
                path.append(AppRoute.exerciseHome(lang))
            }
    }
}

#Preview {
    ContentView()
}
