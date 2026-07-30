import XCTest
@testable import TotoApp

final class NumberCategoryTests: XCTestCase {
    /// Every category's `numbers` must stay within the game's actual
    /// range — a stray 0 or 50 here would silently show a ball no draw
    /// can ever produce.
    func testAllNumbersAreWithinOneToFortyNine() {
        for category in NumberCategory.allCases {
            for number in category.numbers {
                XCTAssertTrue((1...49).contains(number), "\(category): \(number) out of range")
            }
        }
    }

    /// No duplicate numbers within a single category's list.
    func testNoCategoryHasDuplicateNumbers() {
        for category in NumberCategory.allCases {
            XCTAssertEqual(category.numbers.count, Set(category.numbers).count, "\(category) has duplicates")
        }
    }

    /// Pins the exact counts the design handoff's hub tiles advertise
    /// ("15 numbers", "24 numbers", etc.) — these are hand-verifiable
    /// (15 primes, 24 even, 25 odd, 7 perfect squares, 8 Fibonacci values,
    /// 5 curated culturally-significant numbers under 49) so a regression
    /// in the math shows up as a tile subtitle silently going wrong.
    func testCategoryCountsMatchHandoffTileSubtitles() {
        XCTAssertEqual(NumberCategory.prime.numbers.count, 15)
        XCTAssertEqual(NumberCategory.even.numbers.count, 24)
        XCTAssertEqual(NumberCategory.odd.numbers.count, 25)
        XCTAssertEqual(NumberCategory.perfectSquares.numbers.count, 7)
        XCTAssertEqual(NumberCategory.fibonacci.numbers.count, 8)
        XCTAssertEqual(NumberCategory.culturallySignificant.numbers.count, 5)
        XCTAssertEqual(NumberCategory.random.numbers.count, 49)
        XCTAssertEqual(NumberCategory.allNumbers.numbers.count, 49)
    }

    /// Every number is either even or odd, never both, and together they
    /// cover the whole range — this is what NumbersHubViewModel's hero-card
    /// category tagging leans on as its guaranteed fallback.
    func testEveryNumberIsExactlyEvenOrOdd() {
        let even = Set(NumberCategory.even.numbers)
        let odd = Set(NumberCategory.odd.numbers)
        XCTAssertTrue(even.isDisjoint(with: odd))
        XCTAssertEqual(even.union(odd), Set(1...49))
    }

    func testPrimeNumbersAreExactlyCorrect() {
        let expected: Set<Int> = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]
        XCTAssertEqual(Set(NumberCategory.prime.numbers), expected)
    }

    func testPerfectSquaresAreExactlyCorrect() {
        let expected: Set<Int> = [1, 4, 9, 16, 25, 36, 49]
        XCTAssertEqual(Set(NumberCategory.perfectSquares.numbers), expected)
    }

    func testFibonacciNumbersAreExactlyCorrect() {
        let expected: Set<Int> = [1, 2, 3, 5, 8, 13, 21, 34]
        XCTAssertEqual(Set(NumberCategory.fibonacci.numbers), expected)
    }

    /// `allNumbers` and `random` both cover the full range but are
    /// conceptually different (sequential vs. shuffle-per-visit) — this
    /// just confirms their underlying number sets are identical, since any
    /// difference between them is meant to live at the call site
    /// (ReelDestination.shuffled vs. .sequential), not here.
    func testRandomAndAllNumbersCoverTheSameFullRange() {
        XCTAssertEqual(Set(NumberCategory.random.numbers), Set(1...49))
        XCTAssertEqual(Set(NumberCategory.allNumbers.numbers), Set(1...49))
    }

    func testBreadcrumbTitleFormatting() {
        XCTAssertEqual(NumberCategory.random.breadcrumbTitle, "Random")
        XCTAssertEqual(NumberCategory.allNumbers.breadcrumbTitle, "All Numbers")
        XCTAssertEqual(NumberCategory.prime.breadcrumbTitle, "Prime Numbers")
        XCTAssertEqual(NumberCategory.perfectSquares.breadcrumbTitle, "Perfect Squares Numbers")
    }

    /// The vertical swipe cycle order on the Number Reel (NumberReelView)
    /// is `NumberCategory.allCases` — pinning it explicitly here means a
    /// reordering shows up as a clear test failure, not just a surprise
    /// swipe destination on device.
    func testCategoryCycleOrderMatchesHubTileGridOrder() {
        XCTAssertEqual(NumberCategory.allCases, [
            .random, .allNumbers, .prime, .even, .odd, .perfectSquares, .fibonacci, .culturallySignificant,
        ])
    }
}
