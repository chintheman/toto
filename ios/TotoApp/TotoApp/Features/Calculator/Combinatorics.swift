import Foundation

/// `nCr` as Double (not Int) because these numbers get large — C(49,9) is
/// in the trillions — but we only ever need them as ratios, so Double's
/// ~15-17 significant digits is more than enough precision.
enum Combinatorics {
    static func nCr(_ n: Int, _ r: Int) -> Double {
        guard r >= 0, r <= n else { return 0 }
        let r = min(r, n - r) // symmetry, keeps the running product smaller
        var result = 1.0
        for i in 0..<r {
            result *= Double(n - i) / Double(i + 1)
        }
        return result
    }
}
