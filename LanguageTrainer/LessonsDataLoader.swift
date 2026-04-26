import Foundation
import CryptoKit

enum LessonsDataLoader {

    private static var cache: [AppLanguage: [TermPair]] = [:]

    /// Set true temporarily if you want to see what JSON files are actually in the app bundle.
    private static let debugBundle = false

    static func clearCache() {
        cache.removeAll()
        print("🧹 LessonsDataLoader cache cleared")
    }

    static func lessons(for language: AppLanguage) -> [TermPair] {
        if let cached = cache[language] { return cached }

        let resourceName: String = (language == .french) ? "FrenchLessons" : "SpanishLessons"
        let loaded = load(fromResource: resourceName, language: language)

        // ✅ Don’t cache failures/empties (prevents “stuck at 0” during dev)
        if !loaded.isEmpty {
            cache[language] = loaded
        } else {
            print("⚠️ Loaded 0 lessons for \(language.rawValue) — not caching")
        }

        return loaded
    }

    // MARK: - Loader
    private static func load(fromResource name: String, language: AppLanguage) -> [TermPair] {

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

            let decoded = try JSONDecoder().decode([RawTerm].self, from: cleanedData)
            print("✅ Loaded \(decoded.count) lessons from \(url.lastPathComponent)")

            return decoded.map {
                TermPair(
                    id: stableID(language: language, foreign: $0.foreign, english: $0.english),
                    foreign: $0.foreign,
                    english: $0.english
                )
            }

        } catch {
            print("❌ Lessons JSON decode failed:", error)
            return []
        }
    }

    private static func stableID(language: AppLanguage, foreign: String, english: String) -> UUID {
        let raw = "LESSON|\(language.rawValue)|\(foreign)|\(english)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let bytes = Array(digest.prefix(16))

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func dumpBundleJSONFiles() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        print("📦 JSON files in bundle:", urls.map { $0.lastPathComponent }.sorted())
    }

    // MARK: - Raw JSON structure (supports Foreign/English OR foreign/english)
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

            func decodeString(_ keys: [String]) throws -> String {
                for k in keys {
                    if let key = AnyKey(stringValue: k),
                       let value = try c.decodeIfPresent(String.self, forKey: key) {
                        return value
                    }
                }
                throw DecodingError.keyNotFound(
                    AnyKey(stringValue: keys.first ?? "unknown")!,
                    .init(codingPath: decoder.codingPath, debugDescription: "Missing keys \(keys)")
                )
            }

            foreign = try decodeString(["Foreign", "foreign"])
            english = try decodeString(["English", "english"])
        }
    }
}
