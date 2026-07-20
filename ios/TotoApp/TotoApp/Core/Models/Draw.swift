import Foundation

// MARK: - Date Formatter

extension DateFormatter {
    static let totoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - Draw

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        drawNumber = try container.decode(Int.self, forKey: .drawNumber)

        // Supabase REST API returns date columns as "yyyy-MM-dd" strings.
        // The SDK's default decoder may not handle this format, so we
        // decode it manually.
        let dateString = try container.decode(String.self, forKey: .drawDate)
        guard let date = DateFormatter.totoDate.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .drawDate,
                in: container,
                debugDescription: "Expected yyyy-MM-dd format, got '\(dateString)'"
            )
        }
        drawDate = date

        winningNumbers = try container.decode([Int].self, forKey: .winningNumbers)
        additionalNumber = try container.decode(Int.self, forKey: .additionalNumber)
        jackpotAmount = try container.decode(Double.self, forKey: .jackpotAmount)
        jackpotWon = try container.decode(Bool.self, forKey: .jackpotWon)
        snowballAmount = try container.decodeIfPresent(Double.self, forKey: .snowballAmount)
        sourceUrl = try container.decode(String.self, forKey: .sourceUrl)
    }
}

// MARK: - PrizeGroup

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

// MARK: - UpcomingDraw

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        drawNumber = try container.decode(Int.self, forKey: .drawNumber)

        let dateString = try container.decode(String.self, forKey: .drawDate)
        guard let date = DateFormatter.totoDate.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .drawDate,
                in: container,
                debugDescription: "Expected yyyy-MM-dd format, got '\(dateString)'"
            )
        }
        drawDate = date

        estimatedJackpot = try container.decode(Double.self, forKey: .estimatedJackpot)
        isSnowball = try container.decode(Bool.self, forKey: .isSnowball)
    }
}
