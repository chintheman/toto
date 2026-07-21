import Foundation

struct Fallacy: Codable, Identifiable, Hashable {
    var id: String { slug }
    let slug: String
    let title: String
    let mythStatement: String
    let truthLabel: String?
    let verdictLabel: String
    let explanationBody: String
    let statCallout: String?
    let emoji: String?
    let category: String?
    let categoryKey: String?
    let displayOrder: Int
    let inOnboardingCarousel: Bool

    var style: CategoryStyle { CategoryStyle.forKey(categoryKey) }

    /// The green "THE TRUTH" headline. Carousel rows carry a dedicated
    /// truth_label; older Learn-only rows fall back to their verdict.
    var truthHeadline: String { truthLabel ?? verdictLabel }

    enum CodingKeys: String, CodingKey {
        case slug, title
        case mythStatement = "myth_statement"
        case truthLabel = "truth_label"
        case verdictLabel = "verdict_label"
        case explanationBody = "explanation_body"
        case statCallout = "stat_callout"
        case emoji
        case category
        case categoryKey = "category_key"
        case displayOrder = "display_order"
        case inOnboardingCarousel = "in_onboarding_carousel"
    }
}
