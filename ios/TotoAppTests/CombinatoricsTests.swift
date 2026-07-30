import XCTest
@testable import TotoApp

final class CombinatoricsTests: XCTestCase {
    /// The exact values every bet type's cost and every prize-tier
    /// probability in the app ultimately derives from — pinned directly
    /// rather than only indirectly via BetType.cost/EVMath, so a
    /// regression here is caught at its actual source.
    func testKnownValues() {
        XCTAssertEqual(Combinatorics.nCr(49, 6), 13_983_816, accuracy: 1)
        XCTAssertEqual(Combinatorics.nCr(6, 6), 1)
        XCTAssertEqual(Combinatorics.nCr(7, 6), 7)
        XCTAssertEqual(Combinatorics.nCr(8, 6), 28)
        XCTAssertEqual(Combinatorics.nCr(9, 6), 84)
        XCTAssertEqual(Combinatorics.nCr(10, 6), 210)
    }

    /// C(n, r) == C(n, n-r) — the implementation deliberately exploits this
    /// (`min(r, n-r)`) to keep the running product smaller, so this is
    /// also a check that optimization didn't break correctness.
    func testSymmetry() {
        XCTAssertEqual(Combinatorics.nCr(49, 6), Combinatorics.nCr(49, 43))
        XCTAssertEqual(Combinatorics.nCr(10, 3), Combinatorics.nCr(10, 7))
    }

    func testEdgeCases() {
        XCTAssertEqual(Combinatorics.nCr(5, 0), 1) // choosing none is 1 way
        XCTAssertEqual(Combinatorics.nCr(5, 5), 1) // choosing all is 1 way
        XCTAssertEqual(Combinatorics.nCr(5, 6), 0) // can't choose more than n
        XCTAssertEqual(Combinatorics.nCr(5, -1), 0) // negative r is invalid
    }
}
