import XCTest
@testable import TotoApp

final class ReelDestinationTests: XCTestCase {
    // MARK: - .shuffled

    func testShuffled_startsAtTheRequestedNumber() {
        for _ in 0..<20 {
            let destination = ReelDestination.shuffled(category: .prime, startingAt: 17)
            XCTAssertEqual(destination.startIndex, 0)
            XCTAssertEqual(destination.sequence.first, 17)
        }
    }

    /// The sequence must be exactly that category's numbers, each once —
    /// shuffling must never drop, duplicate, or invent a number.
    func testShuffled_sequenceIsExactlyTheCategorysNumbers() {
        let destination = ReelDestination.shuffled(category: .prime, startingAt: 17)
        XCTAssertEqual(Set(destination.sequence), Set(NumberCategory.prime.numbers))
        XCTAssertEqual(destination.sequence.count, NumberCategory.prime.numbers.count)
    }

    func testShuffled_preservesTheRequestedCategory() {
        let destination = ReelDestination.shuffled(category: .fibonacci, startingAt: 8)
        XCTAssertEqual(destination.category, .fibonacci)
    }

    /// Not a guarantee of the RNG, but astronomically likely across enough
    /// tries — catches an accidental "shuffle" that's actually a no-op.
    func testShuffled_ordersDiffersAcrossVisits() {
        let sequences = (0..<10).map { _ in ReelDestination.shuffled(category: .allNumbers, startingAt: 1).sequence }
        XCTAssertTrue(Set(sequences).count > 1, "10 shuffles of 49 numbers were all identical")
    }

    // MARK: - .sequential

    func testSequential_isTheFullOrderedRange() {
        let destination = ReelDestination.sequential(startingAt: 23)
        XCTAssertEqual(destination.sequence, Array(1...49))
        XCTAssertEqual(destination.category, .allNumbers)
    }

    func testSequential_startIndexMatchesTheRequestedNumber() {
        let destination = ReelDestination.sequential(startingAt: 23)
        XCTAssertEqual(destination.startIndex, 22) // 23 is at index 22 in 1...49
        XCTAssertEqual(destination.sequence[destination.startIndex], 23)
    }
}
