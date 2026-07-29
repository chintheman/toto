import Foundation

struct AppearanceInsight: Identifiable {
    let symbol: String
    let text: String
    /// Non-nil only for the "last seen in Draw #N" insight, so it can push
    /// to that draw's own page instead of sitting as inert text.
    var linkedDraw: Draw? = nil
    var id: String { text }
}

/// Appearance statistics for a single number, computed from its draw
/// history. Surfaced as an expandable panel on the Number Reel
/// (`NumberReelView`) — kept from the pre-redesign `NumberDetailView`,
/// whose plain-list screen this whole feature has otherwise superseded,
/// since project notes flagged these insights as a valued addition worth
/// preserving rather than dropping outright.
struct NumberStats {
    let appearances: Int
    let totalDraws: Int
    let lastDrawNumber: Int?
    let lastDrawDate: Date?
    /// The actual last-seen Draw, so "last seen in Draw #N" can link to it —
    /// lastDrawNumber/lastDrawDate alone weren't enough to navigate anywhere.
    let lastDraw: Draw?
    let droughtDraws: Int?
    let longestStreak: Int
    let monCount: Int
    let thuCount: Int

    static func build(appearances draws: [Draw], total: Int, latest: Int?) -> NumberStats {
        let last = draws.max(by: { $0.drawNumber < $1.drawNumber })

        // Longest run of consecutive draw numbers (draw numbers are sequential).
        let ascending = draws.map(\.drawNumber).sorted()
        var longest = ascending.isEmpty ? 0 : 1
        var run = longest
        if ascending.count > 1 {
            for i in 1..<ascending.count {
                run = ascending[i] == ascending[i - 1] + 1 ? run + 1 : 1
                longest = max(longest, run)
            }
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var mon = 0, thu = 0
        for draw in draws {
            switch calendar.component(.weekday, from: draw.drawDate) {
            case 2: mon += 1
            case 5: thu += 1
            default: break
            }
        }

        return NumberStats(
            appearances: draws.count,
            totalDraws: total,
            lastDrawNumber: last?.drawNumber,
            lastDrawDate: last?.drawDate,
            lastDraw: last,
            // Only report a drought when we actually know the current latest
            // draw; without it, default to no drought insight rather than a
            // misleading "appeared in the most recent draw".
            droughtDraws: latest.flatMap { current in last.map { max(0, current - $0.drawNumber) } },
            longestStreak: longest,
            monCount: mon,
            thuCount: thu
        )
    }

    /// Builds a VARIED set of draw-history facts: only the ones that are
    /// actually notable for this number surface, so different numbers show
    /// different mixes rather than an identical five-line template. The core
    /// count always shows; everything else is threshold-gated. Framing keeps
    /// reinforcing that any streak or drought is chance, not a signal.
    func insights() -> [AppearanceInsight] {
        var out: [AppearanceInsight] = []

        // Each draw exposes 7 numbers (6 winning + 1 additional), and
        // `appearances` counts a draw when the number is any of those 7, so
        // the expected rate is 7/49 per draw, not 6/49. Anything else labels
        // almost every number "hot", the exact fallacy this app debunks.
        let avg = Double(totalDraws) * 7.0 / 49.0
        let ratio = avg > 0 ? Double(appearances) / avg : 1
        let qualifier: String
        if ratio > 1.08 { qualifier = "a little more than pure chance predicts" }
        else if ratio < 0.92 { qualifier = "a little less than pure chance predicts" }
        else { qualifier = "right about what pure chance predicts" }
        out.append(AppearanceInsight(symbol: "chart.bar.fill",
            text: "Appeared \(appearances) times in \(totalDraws.formatted()) draws, \(qualifier)."))

        // Drought: only when it's just appeared, or the gap is genuinely long.
        if let droughtDraws {
            if droughtDraws == 0 {
                out.append(AppearanceInsight(symbol: "checkmark.circle.fill",
                    text: "Turned up in the most recent draw."))
            } else if droughtDraws >= 8 {
                out.append(AppearanceInsight(symbol: "hourglass",
                    text: "Quiet lately: no show in the last \(droughtDraws) draws, which says nothing about the next one."))
            }
        }

        // Streak: only a genuinely eye-catching run.
        if longestStreak >= 3 {
            out.append(AppearanceInsight(symbol: "flame.fill",
                text: "Once hit \(longestStreak) draws in a row, the kind of run randomness throws up all the time."))
        }

        // Day skew: only when it actually leans one way.
        let dayTotal = monCount + thuCount
        if dayTotal > 0 {
            let diff = abs(monCount - thuCount)
            if Double(diff) / Double(dayTotal) > 0.15 {
                let leans = thuCount > monCount ? "Thursday" : "Monday"
                out.append(AppearanceInsight(symbol: "calendar.badge.clock",
                    text: "Leans \(leans) so far: \(thuCount) on Thursdays, \(monCount) on Mondays. Coincidence, not a pattern."))
            }
        }

        // Last-seen date: only when it hasn't just appeared (otherwise redundant).
        if let lastDrawDate, let lastDrawNumber, let lastDraw, (droughtDraws ?? 1) > 0 {
            out.append(AppearanceInsight(symbol: "calendar",
                text: "Last seen \(lastDrawDate.formatted(date: .abbreviated, time: .omitted)), in Draw #\(lastDrawNumber.formatted(.number.grouping(.never))).",
                linkedDraw: lastDraw))
        }

        return out
    }
}
