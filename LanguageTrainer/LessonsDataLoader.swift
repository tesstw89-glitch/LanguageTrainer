import Foundation
import CryptoKit

enum LessonsDataLoader {

    // MARK: - Cache

    private static var lessonItemCache: [AppLanguage: [LessonItem]] = [:]
    private static var sentenceTermCache: [AppLanguage: [TermPair]] = [:]

    /// Set true temporarily if you want to see what JSON files are actually in the app bundle.
    private static let debugBundle = false

    static func clearCache() {
        lessonItemCache.removeAll()
        sentenceTermCache.removeAll()
        print("🧹 LessonsDataLoader cache cleared")
    }

    // MARK: - New main loader

    static func lessonItems(for language: AppLanguage) -> [LessonItem] {
        if let cached = lessonItemCache[language] {
            return cached
        }

        let resourceName: String = (language == .french) ? "FrenchLessons" : "SpanishLessons"
        let loaded = loadLessonItems(fromResource: resourceName, language: language)

        // ✅ Don’t cache failures/empties (prevents “stuck at 0” during dev)
        if !loaded.isEmpty {
            lessonItemCache[language] = loaded
        } else {
            print("⚠️ Loaded 0 lesson items for \(language.rawValue) — not caching")
        }

        return loaded
    }

    // MARK: - Compatibility helper for existing views

    static func lessons(for language: AppLanguage) -> [TermPair] {
        if let cached = sentenceTermCache[language] {
            return cached
        }

        let sentenceTerms = lessonItems(for: language).map { $0.asTermPair }

        if !sentenceTerms.isEmpty {
            sentenceTermCache[language] = sentenceTerms
        }

        return sentenceTerms
    }

    // MARK: - Loader

    private static func loadLessonItems(fromResource name: String, language: AppLanguage) -> [LessonItem] {

        if debugBundle {
            dumpBundleJSONFiles()
        }

        // ✅ Accept both .json and .JSON (case matters in bundles)
        guard let url =
                Bundle.main.url(forResource: name, withExtension: "json") ??
                Bundle.main.url(forResource: name, withExtension: "JSON")
        else {
            print("❌ Missing \(name).json in bundle")
            print("   👉 Check: Target Membership + Build Phases > Copy Bundle Resources")
            return []
        }

        do {
            let rawData = try Data(contentsOf: url)

            // Force-clean invalid UTF-8 bytes
            let cleanedString = String(decoding: rawData, as: UTF8.self)

            guard let cleanedData = cleanedString.data(using: .utf8) else {
                print("❌ Failed to re-encode cleaned JSON")
                return []
            }

            let decoded = try JSONDecoder().decode([RawLesson].self, from: cleanedData)
            print("✅ Loaded \(decoded.count) lesson items from \(url.lastPathComponent)")

            return decoded.map { rawLesson in

                let lessonID = stableID(
                    prefix: "LESSON",
                    language: language,
                    foreign: rawLesson.foreign,
                    english: rawLesson.english
                )

                let lemmaPairs = rawLesson.lemmas.map { rawLemma in
                    TermPair(
                        id: stableID(
                            prefix: "LEMMA",
                            language: language,
                            foreign: rawLemma.foreign,
                            english: rawLemma.english
                        ),
                        foreign: rawLemma.foreign,
                        english: rawLemma.english
                    )
                }

                return LessonItem(
                    id: lessonID,
                    foreign: rawLesson.foreign,
                    english: rawLesson.english,
                    lemmas: lemmaPairs
                )
            }

        } catch {
            print("❌ Lessons JSON decode failed:", error)
            return []
        }
    }

    // MARK: - Stable IDs

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

    // MARK: - Debug

    private static func dumpBundleJSONFiles() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        print("📦 JSON files in bundle:", urls.map { $0.lastPathComponent }.sorted())
    }

    // MARK: - Raw JSON structures

    private struct RawLesson: Decodable {
        let foreign: String
        let english: String
        let lemmas: [RawTerm]

        private struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
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

            lemmas = try Self.decodeRawTermsIfPresent(
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

        private static func decodeRawTermsIfPresent(
            from c: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> [RawTerm] {
            for k in keys {
                if let key = AnyKey(stringValue: k),
                   let value = try c.decodeIfPresent([RawTerm].self, forKey: key) {
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
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
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
