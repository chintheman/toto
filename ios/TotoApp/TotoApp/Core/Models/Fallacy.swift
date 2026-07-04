import Foundation

struct Fallacy: Codable, Identifiable, Hashable {
    var id: String { slug }
    let slug: String
    let title: String
    let mythStatement: String
    let verdictLabel: String
    let explanationBody: String
    let statCallout: String?
    let emoji: String?
    let displayOrder: Int
    let inOnboardingCarousel: Bool

    enum CodingKeys: String, CodingKey {
        case slug, title
        case mythStatement = "myth_statement"
        case verdictLabel = "verdict_label"
        case explanationBody = "explanation_body"
        case statCallout = "stat_callout"
        case emoji
        case displayOrder = "display_order"
        case inOnboardingCarousel = "in_onboarding_carousel"
    }
}
