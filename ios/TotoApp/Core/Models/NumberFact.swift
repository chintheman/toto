import Foundation

struct NumberFact: Codable, Identifiable, Equatable {
    let id: Int
    let numberValue: Int
    let headline: String
    let body: String
    let category: Category
    let priority: Int
    let source: String?

    enum Category: String, Codable, CaseIterable {
        case math, culture, superstition
        case popCulture = "pop_culture"
        case singapore
    }

    enum CodingKeys: String, CodingKey {
        case id
        case numberValue = "number_value"
        case headline, body, category, priority, source
    }
}
