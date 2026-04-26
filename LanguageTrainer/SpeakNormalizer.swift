import Foundation

enum SpeakNormalizer {

    // MARK: - Stop words (ignored in the success % denominator)
    static let stopWords: Set<String> = [
        "je","j","tu","il","elle","on","nous","vous","ils","elles",
        "le","la","les","un","une","des","du","de","d",
        "ce","cet","cette","ces",
        "et","ou","mais","que","qui",
        "ne","n","pas","y","en",
        "mon","ton","son","notre","votre","leur","leurs",
        "au","aux"
    ]

    // MARK: - Number map (basic; extend anytime)
    static let numberMap: [String: String] = [
        "zero":"0",
        "un":"1", "une":"1",
        "deux":"2",
        "trois":"3",
        "quatre":"4",
        "cinq":"5",
        "six":"6",
        "sept":"7",
        "huit":"8",
        "neuf":"9",
        "dix":"10",
        "onze":"11",
        "douze":"12",
        "treize":"13",
        "quatorze":"14",
        "quinze":"15",
        "seize":"16",
        "vingt":"20",
        "trente":"30",
        "quarante":"40",
        "cinquante":"50",
        "soixante":"60",
        "cent":"100"
    ]

    // MARK: - Homophone groups (canonical -> variants)
    // Keep these as single-token variants for iOS STT reliability.
    static let homophones: [String: [String]] = [
        "a":   ["a", "à"],
        "un":  ["un", "en", "an"],
        "au":  ["au", "aux"],
        "ces": ["ces", "c est", "c'est", "sais", "sait", "ses"],
        "ca":  ["ça", "sa"],
        "cent":["cent", "sens", "sent"],
        "sang":["sang", "sans"],
        "on":  ["on", "ont"],
        "ou":  ["ou", "où"],
        "peu": ["peu", "peux", "peut"],
        "quand": ["quand", "quant", "qu en", "qu'en"],
        "si":  ["si", "six"],
        "son": ["son", "sont"],
        "sou": ["sou", "sous"],
        "ta":  ["ta", "t a", "t'a", "tas", "t as", "t'as"],
        "tes": ["tes", "t es", "t'es"],
        "tu":  ["tu", "tue"],
        "vin": ["vin", "vain", "vingt"],
        "vers":["vers", "vert"]
    ]

    // Precomputed lookup: variant -> canonical
    private static let variantToCanonical: [String: String] = {
        var map: [String: String] = [:]
        for (canon, vars) in homophones {
            for v in vars { map[v] = canon }
        }
        return map
    }()

    // MARK: - Public API

    /// Normalizes a token (one word) into a canonical match key.
    /// Keeps 1:1 mapping with the visible word index (important for highlighting).
    static func canonicalToken(_ raw: String) -> String {
        var w = raw.lowercased()

        // strip accents
        w = w.folding(options: .diacriticInsensitive, locale: .current)

        // normalize apostrophes then REMOVE them (so "c'est" -> "cest")
        w = w.replacingOccurrences(of: "’", with: "'")
        w = w.replacingOccurrences(of: "'", with: "")

        // remove punctuation inside token, keep digits/letters
        w = w.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)

        // numbers ("deux" -> "2")
        if let num = numberMap[w] { w = num }

        // homophones
        if let canon = variantToCanonical[w] { w = canon }

        // very light plural trim (optional)
        if w.count > 3, (w.hasSuffix("s") || w.hasSuffix("x")) {
            w.removeLast()
        }

        return w
    }

    /// Tokenizes transcript into canonical tokens (set works well for “heard somewhere” matching).
    static func transcriptTokenSet(_ transcript: String) -> Set<String> {
        let cleaned = transcript
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "[.,!?/()«»…:;]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        let canonical = parts
            .map { canonicalToken($0) }
            .filter { !$0.isEmpty }

        return Set(canonical)
    }

    /// Builds canonical tokens aligned to displayed word indices.
    static func sentenceCanonicalTokensAlignedToWords(_ sentence: String) -> [String] {
        let words = sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return words.map { canonicalToken($0) }
    }

    /// Indices of “important words” (used for success ratio)
    static func importantIndices(for canonicalTokens: [String]) -> [Int] {
        canonicalTokens.enumerated().compactMap { idx, tok in
            guard !tok.isEmpty else { return nil }
            return stopWords.contains(tok) ? nil : idx
        }
    }
}
