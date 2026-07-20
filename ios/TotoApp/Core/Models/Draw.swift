import Foundation

struct Draw: Codable, Identifiable, Hashable {
    let id: Int
    let drawNumber: Int
    let drawDate: Date
    let winningNumbers: [Int]
    let additionalNumber: Int
    let jackpotAmount: Double
    let jackpotWon: Bool
    let snowballAmount: Double?
    let sourceUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case drawNumber = "draw_number"
        case drawDate = "draw_date"
        case winningNumbers = "winning_numbers"
        case additionalNumber = "additional_number"
        case jackpotAmount = "jackpot_amount"
        case jackpotWon = "jackpot_won"
        case snowballAmount = "snowball_amount"
        case sourceUrl = "source_url"
    }
}

struct PrizeGroup: Codable, Identifiable, Equatable {
    let id: Int
    let drawId: Int
    let groupNumber: Int
    let prizeType: PrizeType
    let prizePerWinner: Double
    let winnerCount: Int

    enum PrizeType: String, Codable {
        case pariMutuel = "pari_mutuel"
        case fixed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case drawId = "draw_id"
        case groupNumber = "group_number"
        case prizeType = "prize_type"
        case prizePerWinner = "prize_per_winner"
        case winnerCount = "winner_count"
    }
}

struct UpcomingDraw: Codable, Equatable {
    let drawNumber: Int
    let drawDate: Date
    let estimatedJackpot: Double
    let isSnowball: Bool

    enum CodingKeys: String, CodingKey {
        case drawNumber = "draw_number"
        case drawDate = "draw_date"
        case estimatedJackpot = "estimated_jackpot"
        case isSnowball = "is_snowball"
    }
}
