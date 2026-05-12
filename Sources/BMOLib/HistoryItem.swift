import Foundation

struct HistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLang: Language
    let targetLang: Language
    let date: Date

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLang: Language,
        targetLang: Language,
        date: Date = Date()
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.date = date
    }
}
