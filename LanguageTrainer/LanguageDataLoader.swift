import Foundation
import CryptoKit

enum LanguageDataLoader {
    
    static func clearCache() {
        cache.removeAll()
        lessonCache.removeAll()
        print("🧹 LanguageDataLoader cache cleared")
    }
    
    private static func stableID(language: AppLanguage, foreign: String, english: String) -> UUID {
        let raw = "\(language.rawValue)|\(foreign)|\(english)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let bytes = Array(digest.prefix(16))

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: - Cache
    private static var cache: [AppLanguage: [TermPair]] = [:]

    // MARK: - Public entry point
    static func terms(for language: AppLanguage) -> [TermPair] {
        if let cached = cache[language] {
            return cached
        }

        let resourceName: String
        switch language {
        case .french:  resourceName = "french_terms"
        case .spanish: resourceName = "spanish_terms"
        }

        let loaded = loadTerms(fromResource: resourceName, language: language)
        cache[language] = loaded
        return loaded
    }
    
    // MARK: - Lessons cache
    private static var lessonCache: [AppLanguage: [TermPair]] = [:]

    static func lessons(for language: AppLanguage) -> [TermPair] {
        if let cached = lessonCache[language] {
            return cached
        }

        let resourceName: String
        switch language {
        case .french:  resourceName = "french_lessons"
        case .spanish: resourceName = "spanish_lessons"
        }

        let loaded = loadTerms(fromResource: resourceName, language: language)
        lessonCache[language] = loaded
        return loaded
    }

    // MARK: - Loader
    private static func loadTerms(fromResource name: String, language: AppLanguage) -> [TermPair] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            print("❌ Missing \(name).json in bundle")
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
            print("✅ Loaded \(decoded.count) terms from \(name).json")

            return decoded.map {
                TermPair(
                    id: stableID(language: language, foreign: $0.foreign, english: $0.english),
                    foreign: $0.foreign,
                    english: $0.english
                )
            }

        } catch {
            print("❌ JSON decode failed:", error)
            return []
        }
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
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Missing keys \(keys)"
                    )
                )
            }

            foreign = try decodeString(["Foreign", "foreign"])
            english = try decodeString(["English", "english"])
        }
        

    }
}
