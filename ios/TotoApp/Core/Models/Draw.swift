import Foundation

// MARK: - Flexible decoding helpers
//
// PostgREST (Supabase) serializes Postgres `numeric` columns as quoted
// STRINGS ("1187340.00") and `date` columns as date-only strings
// ("2026-07-16"), neither of which a plain `Double`/`Date` decode accepts.
// These helpers accept the wire format AND the ISO8601 form our on-disk
// Home cache writes, so the same models round-trip through both.

enum FlexibleDate {
    private static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso = ISO8601DateFormatter()

    static func parse(_ string: String) -> Date? {
        if string.contains("T") {
            return isoWithFractional.date(from: string) ?? iso.date(from: string)
        }
        // Anchor a bare calendar date at noon UTC so the displayed day is
        // stable in every viewer timezone (never rolls to the previous day).
        return dateOnly.date(from: string)?.addingTimeInterval(12 * 3600)
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let value = try? decode(Double.self, forKey: key) { return value }
        let string = try decode(String.self, forKey: key)
        guard let value = Double(string) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not a number: \(string)")
        }
        return value
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        guard let string = try decodeIfPresent(String.self, forKey: key) else { return nil }
        return Double(string)
    }

    func decodeFlexibleDate(forKey key: Key) throws -> Date {
        let string = try decode(String.self, forKey: key)
        guard let date = FlexibleDate.parse(string) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Unrecognized date: \(string)")
        }
        return date
    }
}

// MARK: - Models

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
        drawDate = try container.decodeFlexibleDate(forKey: .drawDate)
        winningNumbers = try container.decode([Int].self, forKey: .winningNumbers)
        additionalNumber = try container.decode(Int.self, forKey: .additionalNumber)
        jackpotAmount = try container.decodeFlexibleDouble(forKey: .jackpotAmount)
        jackpotWon = try container.decode(Bool.self, forKey: .jackpotWon)
        snowballAmount = try container.decodeFlexibleDoubleIfPresent(forKey: .snowballAmount)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl) ?? ""
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        drawId = try container.decode(Int.self, forKey: .drawId)
        groupNumber = try container.decode(Int.self, forKey: .groupNumber)
        prizeType = (try? container.decode(PrizeType.self, forKey: .prizeType)) ?? .pariMutuel
        prizePerWinner = try container.decodeFlexibleDouble(forKey: .prizePerWinner)
        winnerCount = try container.decode(Int.self, forKey: .winnerCount)
    }
}

struct UpcomingDraw: Codable, Equatable {
    let drawNumber: Int
    let drawDate: Date
    /// Nil when the upcoming jackpot hasn't been published yet. A row can
    /// exist (with a known date) before the estimate is known, so this must
    /// tolerate null instead of failing the whole fetch.
    let estimatedJackpot: Double?
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
        drawDate = try container.decodeFlexibleDate(forKey: .drawDate)
        estimatedJackpot = try container.decodeFlexibleDoubleIfPresent(forKey: .estimatedJackpot)
        isSnowball = try container.decode(Bool.self, forKey: .isSnowball)
    }
}
