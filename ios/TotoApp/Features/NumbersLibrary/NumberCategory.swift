import SwiftUI

/// A browsable slice of the 1–49 number space for the Numbers hub. Purely
/// math-derived (Prime/Even/Odd/Perfect Squares/Fibonacci) except
/// `culturallySignificant`, which is a curated list — deliberately no
/// frequency-based categories (Hot/Cold/Overdue), since those would
/// contradict the gambler's-fallacy myths busted in Learn.
enum NumberCategory: String, CaseIterable, Identifiable, Equatable, Hashable {
    case random, allNumbers, prime, even, odd, perfectSquares, fibonacci, culturallySignificant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .random: return "Random"
        case .allNumbers: return "All Numbers"
        case .prime: return "Prime"
        case .even: return "Even"
        case .odd: return "Odd"
        case .perfectSquares: return "Perfect Squares"
        case .fibonacci: return "Fibonacci"
        case .culturallySignificant: return "Culturally Significant"
        }
    }

    /// The name shown in the reel's breadcrumb ("Prime Numbers · 7 of 15").
    var breadcrumbTitle: String {
        switch self {
        case .random, .allNumbers: return title
        default: return "\(title) Numbers"
        }
    }

    var tileSubtitle: String {
        switch self {
        case .random: return "Surprise me"
        case .allNumbers: return "1 to 49"
        default: return "\(numbers.count) numbers"
        }
    }

    /// Tile fill, matching the design's per-category palette. Random and
    /// Culturally Significant are two-stop gradients; the rest are flat
    /// (per design note: a liquid-glass bubble treatment was tried on the
    /// number balls themselves and reverted for hurting legibility, but
    /// these full tiles aren't balls, so a gradient reads fine here).
    var tileGradient: [Color] {
        switch self {
        case .random: return [Color(hex: 0xFF3B30), Color(hex: 0xAF52DE)]
        case .allNumbers: return [Color(hex: 0x1C1C1E)]
        case .culturallySignificant: return [Color(hex: 0xFFD60A), Color(hex: 0xFF9500)]
        case .prime: return [Color(hex: 0x30B0C7)]
        case .even: return [Color(hex: 0x34C759)]
        case .odd: return [Color(hex: 0xFF9500)]
        case .perfectSquares: return [Color(hex: 0xAF52DE)]
        case .fibonacci: return [Color(hex: 0xFF3B30)]
        }
    }

    /// The numbers (1...49) belonging to this category, in canonical
    /// (ascending) order. `random`'s hub tile and reel behavior come from
    /// shuffling this same full range fresh on every visit, not from a
    /// distinct number set — shuffling happens at the call site (see
    /// `NumbersHubView`/`NumberReelView`), not here, so this stays a pure,
    /// deterministic lookup.
    var numbers: [Int] {
        switch self {
        case .random, .allNumbers: return Array(1...49)
        case .prime: return (1...49).filter(Self.isPrime)
        case .even: return (1...49).filter { $0.isMultiple(of: 2) }
        case .odd: return (1...49).filter { !$0.isMultiple(of: 2) }
        case .perfectSquares: return (1...49).filter { n in
            let root = Int(Double(n).squareRoot().rounded())
            return root * root == n
        }
        case .fibonacci: return Self.fibonacciNumbers
        case .culturallySignificant: return Self.culturallySignificantNumbers
        }
    }

    private static func isPrime(_ n: Int) -> Bool {
        guard n >= 2 else { return false }
        if n == 2 { return true }
        if n.isMultiple(of: 2) { return false }
        var divisor = 3
        while divisor * divisor <= n {
            if n.isMultiple(of: divisor) { return false }
            divisor += 2
        }
        return true
    }

    private static let fibonacciNumbers: [Int] = {
        var values: [Int] = [1, 2]
        while true {
            let next = values[values.count - 1] + values[values.count - 2]
            guard next <= 49 else { break }
            values.append(next)
        }
        return values
    }()

    // Numbers carrying real cross-cultural numerological weight: 4
    // (unlucky, Chinese/Japanese — Mandarin homophone with "death"), 7
    // (lucky, Western), 8 (lucky, Chinese — homophone with "prosperity"),
    // 9 (lucky, Chinese — homophone with "long-lasting"), 13 (unlucky,
    // Western).
    private static let culturallySignificantNumbers: [Int] = [4, 7, 8, 9, 13]
}
