import Foundation
import SwiftUI
import CryptoKit

struct CorrelationCandidate: Hashable {
    let phrase: String
    let matchCount: Int
}

enum CorrelationRoute: Hashable {
    case dragAndFill(AppLanguage, phrase: String)
    case listenWrite(AppLanguage, phrase: String)
}

enum CorrelationEngine {
    static let minimumMatches = 8

    private static let maximumInternalTokenSpan = 6
    private static let maximumRandomWeight = 40

    private static var candidateCache: [AppLanguage: [CorrelationCandidate]] = [:]

    private static let frenchCliticPrefixes: Set<String> = [
        "j", "m", "t", "s", "n", "l", "d", "c", "qu"
    ]

    static func allSentenceTerms(for language: AppLanguage) -> [TermPair] {
        CorrelationSentenceLoader.terms(for: language)
    }

    static func clearCache() {
        candidateCache.removeAll()
        CorrelationSentenceLoader.clearCache()
    }

    static func randomCorrelation(
        for language: AppLanguage,
        terms: [TermPair],
        excluding previousPhrase: String? = nil
    ) -> CorrelationCandidate? {
        let allCandidates = candidates(for: language, terms: terms)
        guard !allCandidates.isEmpty else { return nil }

        let previousKey = previousPhrase.map {
            normalisedCandidate($0, language: language)
        }

        let filtered = allCandidates.filter { candidate in
            guard let previousKey, allCandidates.count > 1 else { return true }
            return normalisedCandidate(candidate.phrase, language: language) != previousKey
        }

        let pool = filtered.isEmpty ? allCandidates : filtered
        let totalWeight = pool.reduce(0) { partial, candidate in
            partial + min(candidate.matchCount, maximumRandomWeight)
        }

        guard totalWeight > 0 else { return pool.randomElement() }

        var ticket = Int.random(in: 0..<totalWeight)

        for candidate in pool {
            ticket -= min(candidate.matchCount, maximumRandomWeight)
            if ticket < 0 {
                return candidate
            }
        }

        return pool.last
    }

    static func matchingTerms(
        for phrase: String,
        language: AppLanguage,
        terms: [TermPair]
    ) -> [TermPair] {
        let target = tokens(for: phrase, language: language)
        guard !target.isEmpty else { return [] }

        return terms.filter { term in
            containsSequence(
                haystack: tokens(for: term.foreign, language: language),
                needle: target
            )
        }
    }

    static func candidates(
        for language: AppLanguage,
        terms: [TermPair]
    ) -> [CorrelationCandidate] {
        if let cached = candidateCache[language] {
            return cached
        }

        let exclusions = exclusionSet(for: language)
        let meaningfulCandidates = meaningfulCandidateSet(
            for: language,
            exclusions: exclusions
        )

        guard !meaningfulCandidates.isEmpty else {
            candidateCache[language] = []
            return []
        }

        var counts: [String: Int] = [:]

        for term in terms {
            let sentenceTokens = tokens(for: term.foreign, language: language)
            guard sentenceTokens.count >= 2 else { continue }

            let sentenceCandidates = candidatePhrases(
                from: sentenceTokens,
                exclusions: exclusions
            )

            for phrase in sentenceCandidates where meaningfulCandidates.contains(phrase) {
                counts[phrase, default: 0] += 1
            }
        }

        let result = counts
            .compactMap { phrase, count -> CorrelationCandidate? in
                guard count >= minimumMatches else { return nil }
                return CorrelationCandidate(phrase: phrase, matchCount: count)
            }
            .sorted {
                if $0.matchCount == $1.matchCount {
                    return $0.phrase < $1.phrase
                }
                return $0.matchCount > $1.matchCount
            }

        candidateCache[language] = result
        print("🔗 Correlations: \(result.count) candidates for \(language.rawValue)")
        return result
    }

    // MARK: - Candidate gates

    private static func meaningfulCandidateSet(
        for language: AppLanguage,
        exclusions: Set<String>
    ) -> Set<String> {
        var result = Set<String>()

        // Candidate phrases must come from the user's curated lemma/chunk material.
        // We also allow 2–3-word sub-chunks of a longer curated lemma so useful
        // recurring pieces can still correlate with inflected sentence forms.
        for lemma in LanguageDataLoader.lemmas(for: language) {
            let lemmaTokens = tokens(for: lemma.foreign, language: language)
            result.formUnion(
                candidatePhrases(
                    from: lemmaTokens,
                    exclusions: exclusions
                )
            )
        }

        return result
    }

    private static func candidatePhrases(
        from sourceTokens: [String],
        exclusions: Set<String>
    ) -> Set<String> {
        guard sourceTokens.count >= 2 else { return [] }

        var result = Set<String>()

        for start in sourceTokens.indices {
            let maximumLength = min(
                maximumInternalTokenSpan,
                sourceTokens.count - start
            )

            guard maximumLength >= 2 else { continue }

            for length in 2...maximumLength {
                let slice = Array(sourceTokens[start..<(start + length)])
                let phrase = render(slice)
                let displayedWordCount = phrase.split(whereSeparator: { $0.isWhitespace }).count

                guard displayedWordCount == 2 || displayedWordCount == 3 else {
                    continue
                }

                // Exact candidate exclusion only. A longer correlation is still allowed
                // even if it happens to contain a shorter excluded sequence.
                guard !exclusions.contains(phrase) else {
                    continue
                }

                result.insert(phrase)
            }
        }

        return result
    }

    private static func exclusionSet(for language: AppLanguage) -> Set<String> {
        let raw: String

        switch language {
        case .french:
            raw = CorrelationExclusions.french
        case .spanish:
            raw = CorrelationExclusions.spanish
        }

        return Set(
            raw
                .split(whereSeparator: { $0.isNewline })
                .map { normalisedCandidate(String($0), language: language) }
                .filter { !$0.isEmpty }
        )
    }

    private static func normalisedCandidate(
        _ text: String,
        language: AppLanguage
    ) -> String {
        render(tokens(for: text, language: language))
    }

    // MARK: - Tokenisation

    private static func tokens(
        for text: String,
        language: AppLanguage
    ) -> [String] {
        let normalised = text
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "´", with: "'")

        let allowed = CharacterSet.letters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "'-"))

        let basic = normalised
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }

        guard language == .french else {
            return basic
        }

        return basic.flatMap(splitFrenchToken)
    }

    private static func splitFrenchToken(_ token: String) -> [String] {
        guard let apostropheIndex = token.firstIndex(of: "'") else {
            return [token]
        }

        let prefix = String(token[..<apostropheIndex])
        let restStart = token.index(after: apostropheIndex)
        let remainder = String(token[restStart...])

        guard frenchCliticPrefixes.contains(prefix), !remainder.isEmpty else {
            return [token]
        }

        return ["\(prefix)'"] + splitFrenchToken(remainder)
    }

    private static func render(_ tokens: [String]) -> String {
        var output = ""

        for token in tokens {
            guard !token.isEmpty else { continue }

            if output.isEmpty {
                output = token
            } else if output.last == "'" {
                output += token
            } else {
                output += " \(token)"
            }
        }

        return output
    }

    private static func containsSequence(
        haystack: [String],
        needle: [String]
    ) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else {
            return false
        }

        let finalStart = haystack.count - needle.count

        for start in 0...finalStart {
            if Array(haystack[start..<(start + needle.count)]) == needle {
                return true
            }
        }

        return false
    }
}

struct CorrelationExerciseDestination: View {
    let route: CorrelationRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .dragAndFill(let language, let phrase):
            DragFillView(
                language: language,
                terms: correlationTerms(language: language, phrase: phrase)
            )
            .safeAreaInset(edge: .top, spacing: 0) {
                CorrelationBanner(phrase: phrase)
            }

        case .listenWrite(let language, let phrase):
            ListenWriteView(
                language: language,
                terms: correlationTerms(language: language, phrase: phrase),
                totalQsOverride: 12
            )
            .safeAreaInset(edge: .top, spacing: 0) {
                CorrelationBanner(phrase: phrase)
            }
        }
    }

    private func correlationTerms(
        language: AppLanguage,
        phrase: String
    ) -> [TermPair] {
        CorrelationEngine.matchingTerms(
            for: phrase,
            language: language,
            terms: CorrelationEngine.allSentenceTerms(for: language)
        )
    }
}

private struct CorrelationBanner: View {
    let phrase: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "link")
                .font(.system(size: 13, weight: .bold))

            Text("Correlation: \(phrase)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}

private enum CorrelationSentenceLoader {
    private static var cache: [AppLanguage: [TermPair]] = [:]

    static func clearCache() {
        cache.removeAll()
    }

    static func terms(for language: AppLanguage) -> [TermPair] {
        if let cached = cache[language] {
            return cached
        }

        let resourceName = language == .french ? "french_terms" : "spanish_terms"

        guard let url =
                Bundle.main.url(forResource: resourceName, withExtension: "json") ??
                Bundle.main.url(forResource: resourceName, withExtension: "JSON")
        else {
            print("❌ Missing \(resourceName).json for correlations")
            return []
        }

        do {
            let rawData = try Data(contentsOf: url)
            let cleanedString = String(decoding: rawData, as: UTF8.self)

            guard let cleanedData = cleanedString.data(using: .utf8) else {
                return []
            }

            let decoded = try JSONDecoder().decode([RawEntry].self, from: cleanedData)

            let loaded = decoded.compactMap { raw -> TermPair? in
                let foreign = clean(raw.foreign)
                let english = clean(raw.english)
                let context: String? = {
                    guard let rawContext = raw.context else { return nil }
                    let cleanedContext = clean(rawContext)
                    return cleanedContext.isEmpty ? nil : cleanedContext
                }()

                guard !foreign.isEmpty, !english.isEmpty else { return nil }

                return TermPair(
                    id: stableID(
                        prefix: "SENTENCE",
                        language: language,
                        foreign: foreign,
                        english: english
                    ),
                    foreign: foreign,
                    english: english,
                    context: context
                )
            }

            if !loaded.isEmpty {
                cache[language] = loaded
            }

            return loaded
        } catch {
            print("❌ Correlation JSON decode failed for \(resourceName).json:", error)
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
        let context: String?

        private struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }

            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            init?(intValue: Int) {
                nil
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

            context = try Self.decodeOptionalString(
                from: container,
                keys: ["context", "Context"]
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

        private static func decodeOptionalString(
            from container: KeyedDecodingContainer<AnyKey>,
            keys: [String]
        ) throws -> String? {
            for keyName in keys {
                if let key = AnyKey(stringValue: keyName),
                   let value = try container.decodeIfPresent(String.self, forKey: key) {
                    return value
                }
            }

            return nil
        }
    }
}
