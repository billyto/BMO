import Foundation
import NaturalLanguage

/// Grammatical word class (part of speech) shown as a hint next to a short
/// translation, e.g. "verb" for løbe → run.
enum WordClass: String, Codable, Sendable, CaseIterable {
    case noun
    case verb
    case adjective
    case adverb
    case pronoun
    case preposition
    case conjunction
    case interjection
    case number

    /// Lowercase label for the UI chip and the Anki tag.
    var label: String { rawValue }

    fileprivate init?(_ tag: NLTag) {
        switch tag {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .adverb: self = .adverb
        case .pronoun: self = .pronoun
        case .preposition: self = .preposition
        case .conjunction: self = .conjunction
        case .interjection: self = .interjection
        case .number: self = .number
        default: return nil
        }
    }
}

/// Tags the word class of short translations with Apple's on-device
/// NaturalLanguage tagger: free, offline and instant.
///
/// NLTagger has no lexical-class model for Danish (every Danish word comes
/// back as `OtherWord`), so this always tags the English side of the pair.
/// A word normally keeps its class across the translation (løbe → run is a
/// verb on both sides), so the English class stands in for the Danish one.
enum WordClassTagger {
    /// Longest input (in words) that gets a hint. A class means nothing for
    /// a sentence, and a short phrase like "to run" or "the house" still has
    /// one clear head word.
    static let maxWords = 3

    /// Tags whose words don't decide the class of a short phrase: the "to" in
    /// "to run", the "the" in "the house".
    private static let functionTags: Set<NLTag> = [.determiner, .particle, .classifier]

    /// The class of the English side of a DA↔EN translation, or nil when
    /// there's no English side, it's longer than `maxWords`, or its words
    /// don't agree on a single class (e.g. "run fast").
    static func wordClass(source: String, translated: String, from: Language, to: Language) -> WordClass? {
        let english: String
        if from == .english {
            english = source
        } else if to == .english {
            english = translated
        } else {
            return nil
        }
        return wordClass(english: english)
    }

    static func wordClass(english text: String) -> WordClass? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = trimmed
        tagger.setLanguage(.english, range: trimmed.startIndex..<trimmed.endIndex)

        var tags: [NLTag] = []
        tagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .omitOther]
        ) { tag, _ in
            tags.append(tag ?? .otherWord)
            return tags.count <= maxWords
        }
        guard !tags.isEmpty, tags.count <= maxWords else { return nil }

        // "to run" → [verb], "the house" → [noun]. A lone function word
        // ("the") has nothing left, so keep it and let it map (or not).
        let contentTags = tags.filter { !functionTags.contains($0) }
        let deciding = contentTags.isEmpty ? tags : contentTags
        let classes = deciding.compactMap(WordClass.init)
        guard classes.count == deciding.count, let first = classes.first,
              classes.allSatisfy({ $0 == first }) else {
            return nil
        }
        return first
    }
}

// MARK: - Danish word classes (Wiktionary)

/// Looks up every word class a Danish word can have. Protocol so tests and
/// #Preview never hit the network (same DI shape as PhoneticsRunner).
protocol DanishWordClassLookup: Sendable {
    /// Word classes in the order the source lists them; empty when the word
    /// isn't found.
    func wordClasses(for word: String) async throws -> [WordClass]
}

/// English Wiktionary's REST definition endpoint, which groups a word's
/// entries by language and gives each a part of speech. Only the single
/// Danish word is sent — never the rest of the user's text.
struct WiktionaryWordClassLookup: DanishWordClassLookup {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func wordClasses(for word: String) async throws -> [WordClass] {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])),
              let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)") else {
            return []
        }
        var request = URLRequest(url: url)
        // Wikimedia asks API clients to identify themselves; generic on purpose.
        request.setValue("Sig/1.0 (macOS translator)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        let (data, response) = try await session.data(for: request)
        // 404 = no entry for this word, not an error worth surfacing.
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return Self.parse(data)
    }

    /// Pulls the Danish ("da") entries' parts of speech out of the response,
    /// mapped to `WordClass` and de-duplicated in order.
    static func parse(_ data: Data) -> [WordClass] {
        struct Entry: Decodable { let partOfSpeech: String }
        guard let byLanguage = try? JSONDecoder().decode([String: [Entry]].self, from: data),
              let danish = byLanguage["da"] else {
            return []
        }
        var result: [WordClass] = []
        for entry in danish {
            guard let wordClass = wordClass(wiktionary: entry.partOfSpeech),
                  !result.contains(wordClass) else { continue }
            result.append(wordClass)
        }
        return result
    }

    static func wordClass(wiktionary partOfSpeech: String) -> WordClass? {
        switch partOfSpeech.lowercased() {
        case "noun", "proper noun": return .noun
        case "verb": return .verb
        case "adjective": return .adjective
        case "adverb": return .adverb
        case "pronoun": return .pronoun
        case "preposition": return .preposition
        case "conjunction": return .conjunction
        case "interjection": return .interjection
        case "numeral", "number": return .number
        default: return nil
        }
    }
}

/// Danish side of the word-class hint. Only single words (plus "at løbe" /
/// "en hund" forms) are looked up: Wiktionary has no sentence context, so
/// it can only list what a word *can* be, which means nothing for a phrase.
final class DanishWordClassService: Sendable {
    private let lookup: DanishWordClassLookup
    private let cache = WordClassCache()

    init(lookup: DanishWordClassLookup = WiktionaryWordClassLookup()) {
        self.lookup = lookup
    }

    /// Word classes for `danish`, or empty when it isn't a single word, has
    /// no entry, or the lookup fails (offline, timeout).
    func wordClasses(for danish: String) async -> [WordClass] {
        guard let query = Self.query(for: danish) else { return [] }
        if let cached = await cache.value(for: query.word) {
            return query.narrow(cached)
        }
        do {
            var classes = try await lookup.wordClasses(for: query.word)
            // Sentence-initial capitals ("Hus") have no entry; proper nouns do.
            if classes.isEmpty, query.word != query.word.lowercased() {
                classes = try await lookup.wordClasses(for: query.word.lowercased())
            }
            // Only real answers are cached: a failure (offline, timeout,
            // cancellation) throws past this, so the word is retried later.
            await cache.set(classes, for: query.word)
            return query.narrow(classes)
        } catch {
            return []
        }
    }

    struct Query: Equatable {
        let word: String
        /// Set by an "at"/"en"/"et" prefix, which already says what the word is.
        let implied: WordClass?

        /// "at løb" can only be the verb reading, "et løb" only the noun —
        /// when the prefix's class is among the word's, that's the answer.
        func narrow(_ classes: [WordClass]) -> [WordClass] {
            guard let implied, classes.contains(implied) else { return classes }
            return [implied]
        }
    }

    static func query(for text: String) -> Query? {
        let words = text
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        switch words.count {
        case 1:
            return Query(word: words[0], implied: nil)
        case 2:
            switch words[0].lowercased() {
            case "at": return Query(word: words[1], implied: .verb)
            case "en", "et": return Query(word: words[1], implied: .noun)
            default: return nil
            }
        default:
            return nil
        }
    }
}

/// Session-only cache so re-translating, swapping or restoring the same word
/// doesn't hit Wiktionary again.
private actor WordClassCache {
    private var storage: [String: [WordClass]] = [:]

    func value(for word: String) -> [WordClass]? { storage[word] }
    func set(_ classes: [WordClass], for word: String) { storage[word] = classes }
}

/// For #Preview: answers without the network.
struct MockDanishWordClassLookup: DanishWordClassLookup {
    func wordClasses(for word: String) async throws -> [WordClass] { [.adjective, .verb] }
}
