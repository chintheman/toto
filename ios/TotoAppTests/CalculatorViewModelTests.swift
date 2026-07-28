import XCTest
@testable import TotoApp

final class CalculatorViewModelTests: XCTestCase {
    /// A live jackpot that doesn't round to any preset's $0.1M bucket:
    /// "Today" plus all 8 presets should appear, nothing deduped.
    func testChipsIncludeLiveAndAllPresetsWhenNoOverlap() {
        let chips = CalculatorViewModel.jackpotChips(currentJackpot: 5_900_838)
        XCTAssertEqual(chips.count, 1 + JackpotPreset.millionsValues.count)
        XCTAssertEqual(chips.first?.selection, .live)
    }

    /// A live jackpot landing exactly on a preset (e.g. today's estimate is
    /// $1,000,000, same as the $1M preset) must not show the same figure
    /// twice in the row.
    func testDuplicatePresetIsDroppedWhenLiveJackpotMatchesIt() {
        let chips = CalculatorViewModel.jackpotChips(currentJackpot: 1_000_000)
        XCTAssertEqual(chips.count, JackpotPreset.millionsValues.count) // 1 live + 7 presets, not 1 + 8
        XCTAssertTrue(chips.contains { $0.selection == .live })
        XCTAssertFalse(chips.contains { $0.selection == .preset(1_000_000) })
    }

    /// No live jackpot yet (still loading, or a won jackpot with no
    /// upcoming estimate): chips are the 8 presets only, no "Today" entry.
    func testChipsArePresetsOnlyWhenNoLiveJackpotYet() {
        let chips = CalculatorViewModel.jackpotChips(currentJackpot: nil)
        XCTAssertEqual(chips.count, JackpotPreset.millionsValues.count)
        XCTAssertFalse(chips.contains { $0.selection == .live })
    }
}
