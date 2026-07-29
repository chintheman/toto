import XCTest
@testable import TotoApp

final class NumberStatsTests: XCTestCase {
    // MARK: - Fixtures

    /// NumberStats has no Codable/custom init besides the `build(...)`
    /// factory, so its memberwise init is available directly — no need to
    /// round-trip through Draw/JSON just to test `insights()`'s branching.
    private func makeStats(
        appearances: Int,
        totalDraws: Int = 1_202,
        lastDrawNumber: Int? = 4108,
        lastDrawDate: Date? = nil,
        lastDraw: Draw? = nil,
        droughtDraws: Int? = 1,
        longestStreak: Int = 1,
        monCount: Int = 0,
        thuCount: Int = 0
    ) -> NumberStats {
        NumberStats(
            appearances: appearances,
            totalDraws: totalDraws,
            lastDrawNumber: lastDrawNumber,
            lastDrawDate: lastDrawDate,
            lastDraw: lastDraw,
            droughtDraws: droughtDraws,
            longestStreak: longestStreak,
            monCount: monCount,
            thuCount: thuCount
        )
    }

    /// Draw requires a full JSON round-trip (its only initializer is
    /// `init(from decoder:)`) — only `.build()`'s tests need a real one.
    private func makeDraw(id: Int, drawNumber: Int, dateString: String) -> Draw {
        let json = """
        {
            "id": \(id),
            "draw_number": \(drawNumber),
            "draw_date": "\(dateString)",
            "winning_numbers": [1, 2, 3, 4, 5, 6],
            "additional_number": 7,
            "jackpot_amount": 1000000,
            "jackpot_won": false,
            "source_url": "https://example.com"
        }
        """
        return try! JSONDecoder().decode(Draw.self, from: Data(json.utf8))
    }

    // MARK: - insights(): appearance-rate qualifier

    func testInsights_appearanceRate_aboveExpected() {
        // Expected rate is 7/49 per draw (7 numbers drawn per draw: 6 + 1
        // additional) — 1202 draws * 7/49 ≈ 172 expected; 200 is ~16% over.
        let stats = makeStats(appearances: 200, totalDraws: 1_202)
        let text = stats.insights().first?.text ?? ""
        XCTAssertTrue(text.contains("a little more than pure chance predicts"), text)
    }

    func testInsights_appearanceRate_belowExpected() {
        let stats = makeStats(appearances: 140, totalDraws: 1_202)
        let text = stats.insights().first?.text ?? ""
        XCTAssertTrue(text.contains("a little less than pure chance predicts"), text)
    }

    func testInsights_appearanceRate_aboutRight() {
        let stats = makeStats(appearances: 172, totalDraws: 1_202)
        let text = stats.insights().first?.text ?? ""
        XCTAssertTrue(text.contains("right about what pure chance predicts"), text)
    }

    // MARK: - insights(): drought

    func testInsights_drought_zero_showsJustAppeared() {
        let stats = makeStats(appearances: 172, droughtDraws: 0)
        XCTAssertTrue(stats.insights().contains { $0.text == "Turned up in the most recent draw." })
    }

    func testInsights_drought_longGap_showsQuietLately() {
        let stats = makeStats(appearances: 172, droughtDraws: 8)
        XCTAssertTrue(stats.insights().contains { $0.symbol == "hourglass" })
    }

    func testInsights_drought_shortGap_showsNoDroughtInsight() {
        // Between 1 and 7 draws since last seen: neither "just appeared"
        // nor "quiet lately" is notable enough to surface.
        let stats = makeStats(appearances: 172, droughtDraws: 4)
        XCTAssertFalse(stats.insights().contains { $0.symbol == "hourglass" })
        XCTAssertFalse(stats.insights().contains { $0.text == "Turned up in the most recent draw." })
    }

    // MARK: - insights(): streak

    func testInsights_streak_belowThreshold_noInsight() {
        let stats = makeStats(appearances: 172, longestStreak: 2)
        XCTAssertFalse(stats.insights().contains { $0.symbol == "flame.fill" })
    }

    func testInsights_streak_atThreshold_showsInsight() {
        let stats = makeStats(appearances: 172, longestStreak: 3)
        XCTAssertTrue(stats.insights().contains { $0.symbol == "flame.fill" })
    }

    // MARK: - insights(): day-of-week skew

    func testInsights_daySkew_belowThreshold_noInsight() {
        // 55/45 split: 10% difference, under the 15% threshold.
        let stats = makeStats(appearances: 172, monCount: 55, thuCount: 45)
        XCTAssertFalse(stats.insights().contains { $0.symbol == "calendar.badge.clock" })
    }

    func testInsights_daySkew_aboveThreshold_showsInsight() {
        // 60/40 split: 20% difference, over the 15% threshold.
        let stats = makeStats(appearances: 172, monCount: 60, thuCount: 40)
        XCTAssertTrue(stats.insights().contains { $0.symbol == "calendar.badge.clock" })
    }

    // MARK: - insights(): last-seen linking

    func testInsights_lastSeen_omittedWhenJustAppeared() {
        // droughtDraws == 0 already covers "just appeared" via its own
        // insight — repeating it as "last seen today" would be redundant.
        let draw = makeDraw(id: 1, drawNumber: 4108, dateString: "2026-07-27")
        let stats = makeStats(appearances: 172, lastDrawDate: draw.drawDate, lastDraw: draw, droughtDraws: 0)
        XCTAssertFalse(stats.insights().contains { $0.linkedDraw != nil })
    }

    func testInsights_lastSeen_includedAndLinksTheDraw() {
        let draw = makeDraw(id: 1, drawNumber: 4108, dateString: "2026-07-27")
        let stats = makeStats(appearances: 172, lastDrawDate: draw.drawDate, lastDraw: draw, droughtDraws: 4)
        let insight = stats.insights().first { $0.linkedDraw != nil }
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.linkedDraw, draw)
        XCTAssertTrue(insight?.text.contains("4108") ?? false)
    }

    // MARK: - build()

    /// build() must count only the given draws, preserve the total, and
    /// compute drought as (latest draw number − this number's last draw).
    func testBuild_basicAggregation() {
        let draws = [
            makeDraw(id: 1, drawNumber: 4100, dateString: "2026-07-06"),
            makeDraw(id: 2, drawNumber: 4104, dateString: "2026-07-13"),
        ]
        let stats = NumberStats.build(appearances: draws, total: 1_202, latest: 4108)
        XCTAssertEqual(stats.appearances, 2)
        XCTAssertEqual(stats.totalDraws, 1_202)
        XCTAssertEqual(stats.lastDrawNumber, 4104)
        XCTAssertEqual(stats.droughtDraws, 4) // 4108 - 4104
    }

    /// No known "latest" draw (e.g. still loading) must not fabricate a
    /// drought value — better no insight than a misleading one.
    func testBuild_noLatestDraw_droughtIsNil() {
        let draws = [makeDraw(id: 1, drawNumber: 4104, dateString: "2026-07-13")]
        let stats = NumberStats.build(appearances: draws, total: 1_202, latest: nil)
        XCTAssertNil(stats.droughtDraws)
    }

    /// Three consecutive draw numbers (however many other numbers-in-
    /// between exist in reality) form a streak of 3, not 2 or 1 — this is
    /// the run-length logic over sorted draw numbers.
    func testBuild_longestStreak_consecutiveDrawNumbers() {
        let draws = [
            makeDraw(id: 1, drawNumber: 4100, dateString: "2026-06-29"),
            makeDraw(id: 2, drawNumber: 4101, dateString: "2026-07-02"),
            makeDraw(id: 3, drawNumber: 4102, dateString: "2026-07-06"),
            makeDraw(id: 4, drawNumber: 4105, dateString: "2026-07-16"), // breaks the run
        ]
        let stats = NumberStats.build(appearances: draws, total: 1_202, latest: 4108)
        XCTAssertEqual(stats.longestStreak, 3)
    }

    func testBuild_noAppearances_zeroedOutSafely() {
        let stats = NumberStats.build(appearances: [], total: 1_202, latest: 4108)
        XCTAssertEqual(stats.appearances, 0)
        XCTAssertEqual(stats.longestStreak, 0)
        XCTAssertNil(stats.lastDrawNumber)
        XCTAssertNil(stats.droughtDraws) // no last draw to measure a gap from
    }
}
