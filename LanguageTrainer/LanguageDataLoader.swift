import Foundation
import CryptoKit

enum LanguageDataLoader {

    // MARK: - Cache

    private static var termCache: [AppLanguage: [TermPair]] = [:]
    private static var termItemCache: [AppLanguage: [LessonItem]] = [:]
    private static var lemmaCache: [AppLanguage: [TermPair]] = [:]

    private static var lessonCache: [AppLanguage: [TermPair]] = [:]

    // MARK: - Clear cache

    static func clearCache() {
        termCache.removeAll()
        termItemCache.removeAll()
        lemmaCache.removeAll()
        lessonCache.removeAll()
        print("🧹 LanguageDataLoader cache cleared")
    }

    // MARK: - Main terms from french_terms / spanish_terms

    /// Full sentence rows from french_terms.json / spanish_terms.json.
    /// Use this for DragFill / Speak / sentence-based games.
    static func terms(for language: AppLanguage) -> [TermPair] {
        if let cached = termCache[language] {
            return cached
        }

        let items = termItems(for: language)
        let terms = items.map { $0.asTermPair }

        termCache[language] = terms
        return terms
    }

    /// Full rows WITH their lemmas preserved.
    /// Use this when WeekEngine needs to extract lemmas by week.
    static func termItems(for language: AppLanguage) -> [LessonItem] {
        if let cached = termItemCache[language] {
            return cached
        }

        let resourceName: String
        switch language {
        case .french:
            resourceName = "french_terms"
        case .spanish:
            resourceName = "spanish_terms"
        }

        let loaded = loadTermItems(fromResource: resourceName, language: language)

        if !loaded.isEmpty {
            termItemCache[language] = loaded
        } else {
            print("⚠️ Loaded 0 term items for \(language.rawValue)")
        }

        return loaded
    }

    /// All lemmas flattened from french_terms.json / spanish_terms.json.
    /// Use this for Match / ListenMatch / MatchWrite / Write if you are NOT using weeks.
    static func lemmas(for language: AppLanguage) -> [TermPair] {
        if let cached = lemmaCache[language] {
            return cached
        }

        let flattened = termItems(for: language)
            .flatMap { $0.lemmas }

        let deduped = dedupedTerms(flattened)

        lemmaCache[language] = deduped
        return deduped
    }

    // MARK: - Hidden old Lessons feature

    /// Old lesson sentence files.
    /// Keep this only for the hidden Lessons feature, if anything still uses it.
    static func lessons(for language: AppLanguage) -> [TermPair] {
        if let cached = lessonCache[language] {
            return cached
        }

        let resourceName: String
        switch language {
        case .french:
            resourceName = "french_lessons"
        case .spanish:
            resourceName = "spanish_lessons"
        }

        let loaded = loadSimpleTerms(fromResource: resourceName, language: language)
        lessonCache[language] = loaded
        return loaded
    }

    // MARK: - Main loader with lemmas

    private static func loadTermItems(fromResource name: String, language: AppLanguage) -> [LessonItem] {
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

            // Force-clean invalid UTF-8 bytes
            let cleanedString = String(decoding: rawData, as: UTF8.self)

            guard let cleanedData = cleanedString.data(using: .utf8) else {
                print("❌ Failed to re-encode cleaned JSON for \(name).json")
                return []
            }

            let decoded = try JSONDecoder().decode([RawTermWithLemmas].self, from: cleanedData)

            print("✅ Loaded \(decoded.count) term items from \(name).json")

            return decoded.compactMap { raw in
                let cleanedForeign = clean(raw.foreign)
                let cleanedEnglish = clean(raw.english)

                guard !cleanedForeign.isEmpty else { return nil }
                guard !cleanedEnglish.isEmpty else { return nil }

                let sentenceID = stableID(
                    prefix: "SENTENCE",
                    language: language,
                    foreign: cleanedForeign,
                    english: cleanedEnglish
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
                    foreign: cleanedForeign,
                    english: cleanedEnglish,
                    lemmas: lemmaPairs
                )
            }

        } catch {
            print("❌ JSON decode failed for \(name).json:", error)
            return []
        }
    }

    // MARK: - Simple loader for old lessons

    private static func loadSimpleTerms(fromResource name: String, language: AppLanguage) -> [TermPair] {
        guard let url =
                Bundle.main.url(forResource: name, withExtension: "json") ??
                Bundle.main.url(forResource: name, withExtension: "JSON")
        else {
            print("❌ Missing \(name).json in bundle")
            return []
        }

        do {
            let rawData = try Data(contentsOf: url)

            // Force-clean invalid UTF-8 bytes
            let cleanedString = String(decoding: rawData, as: UTF8.self)

            guard let cleanedData = cleanedString.data(using: .utf8) else {
                print("❌ Failed to re-encode cleaned JSON for \(name).json")
                return []
            }

            let decoded = try JSONDecoder().decode([RawSimpleTerm].self, from: cleanedData)

            print("✅ Loaded \(decoded.count) simple terms from \(name).json")

            return decoded.compactMap { raw in
                let cleanedForeign = clean(raw.foreign)
                let cleanedEnglish = clean(raw.english)

                guard !cleanedForeign.isEmpty else { return nil }
                guard !cleanedEnglish.isEmpty else { return nil }

                return TermPair(
                    id: stableID(
                        prefix: "TERM",
                        language: language,
                        foreign: cleanedForeign,
                        english: cleanedEnglish
                    ),
                    foreign: cleanedForeign,
                    english: cleanedEnglish
                )
            }

        } catch {
            print("❌ JSON decode failed for \(name).json:", error)
            return []
        }
    }

    // MARK: - Helpers

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

    private static func clean(_ text: String) -> String {
        var value = text
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "´", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value
    }

    private static func dedupedTerms(_ terms: [TermPair]) -> [TermPair] {
        var seen = Set<String>()

        return terms.filter { term in
            let key = normaliseKey(term.foreign) + "||" + normaliseKey(term.english)
            return seen.insert(key).inserted
        }
    }

    private static func normaliseKey(_ text: String) -> String {
        clean(text)
            .lowercased()
    }

    // MARK: - Raw JSON structures

    private struct RawTermWithLemmas: Decodable {
        let foreign: String
        let english: String
        let lemmas: [RawSimpleTerm]

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
            let c = try decoder.container(keyedBy: AnyKey.self)

            foreign = try Self.decodeString(
                from: c,
                keys: ["Foreign", "foreign"]
            )

            english = try Self.decodeString(
                from: c,
                keys: ["English", "english"]
            )

            lemmas = try Self.decodeTermsIfPresent(
                from: c,
                keys: ["Lemmas", "lemmas", "Chunks", "chunks"]
            )
        }

        private static func decodeString(
            from c: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> String {
            for k in keys {
                if let key = AnyKey(stringValue: k),
                   let value = try c.decodeIfPresent(String.self, forKey: key) {
                    return value
                }
            }

            throw DecodingError.keyNotFound(
                AnyKey(stringValue: keys.first ?? "unknown")!,
                .init(
                    codingPath: c.codingPath,
                    debugDescription: "Missing keys \(keys)"
                )
            )
        }

        private static func decodeTermsIfPresent(
            from c: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> [RawSimpleTerm] {
            for k in keys {
                if let key = AnyKey(stringValue: k),
                   let value = try c.decodeIfPresent([RawSimpleTerm].self, forKey: key) {
                    return value
                }
            }

            return []
        }
    }

    private struct RawSimpleTerm: Decodable {
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
            let c = try decoder.container(keyedBy: AnyKey.self)

            foreign = try Self.decodeString(
                from: c,
                keys: ["Foreign", "foreign"]
            )

            english = try Self.decodeString(
                from: c,
                keys: ["English", "english"]
            )
        }

        private static func decodeString(
            from c: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> String {
            for k in keys {
                if let key = AnyKey(stringValue: k),
                   let value = try c.decodeIfPresent(String.self, forKey: key) {
                    return value
                }
            }

            throw DecodingError.keyNotFound(
                AnyKey(stringValue: keys.first ?? "unknown")!,
                .init(
                    codingPath: c.codingPath,
                    debugDescription: "Missing keys \(keys)"
                )
            )
        }
    }
}
