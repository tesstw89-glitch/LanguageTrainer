import Foundation

struct CorrelationCandidate: Hashable {
    let phrase: String
    let matchCount: Int
}

enum CorrelationEngine {
    static let minimumMatches = 8

    private static let maximumInternalTokenSpan = 6
    private static let maximumRandomWeight = 40

    private static var candidateCache: [AppLanguage: [CorrelationCandidate]] = [:]

    private static let frenchCliticPrefixes: Set<String> = [
        "j", "m", "t", "s", "n", "l", "d", "c", "qu"
    ]

    static func clearCache() {
        candidateCache.removeAll()
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
        var counts: [String: Int] = [:]

        for term in terms {
            let sentenceTokens = tokens(for: term.foreign, language: language)
            guard sentenceTokens.count >= 2 else { continue }

            var seenInSentence = Set<String>()

            for start in sentenceTokens.indices {
                let maximumLength = min(
                    maximumInternalTokenSpan,
                    sentenceTokens.count - start
                )

                guard maximumLength >= 2 else { continue }

                for length in 2...maximumLength {
                    let slice = Array(sentenceTokens[start..<(start + length)])
                    let phrase = render(slice)
                    let displayedWordCount = phrase.split(whereSeparator: { $0.isWhitespace }).count

                    guard displayedWordCount == 2 || displayedWordCount == 3 else {
                        continue
                    }

                    guard !exclusions.contains(phrase) else {
                        continue
                    }

                    seenInSentence.insert(phrase)
                }
            }

            for phrase in seenInSentence {
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

    // MARK: - Exact candidate exclusions

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
