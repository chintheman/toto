import Foundation

/// Ports the SGT draw-schedule logic from the research site
/// (site/src/useNextDraw.ts): draws are Monday & Thursday at 18:30 SGT
/// (UTC+8). This is a fallback/local estimate for the countdown display —
/// the authoritative source is always `upcoming_draw` from Supabase, which
/// reflects the actual scraped draw date. This local calculation exists so
/// Home has something sensible to show even before that data loads.
enum NextDrawSchedule {
    private static let sgtTimeZone = TimeZone(identifier: "Asia/Singapore")!
    private static let drawWeekdays: Set<Int> = [2, 5] // Calendar.weekday: Sun=1 ... so Mon=2, Thu=5
    private static let drawHour = 18
    private static let drawMinute = 30

    static func nextDrawDate(from now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sgtTimeZone

        for dayOffset in 0...7 {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: candidateDay)
            guard drawWeekdays.contains(weekday) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            components.hour = drawHour
            components.minute = drawMinute
            components.second = 0
            guard let candidateDrawTime = calendar.date(from: components) else { continue }

            if candidateDrawTime > now {
                return candidateDrawTime
            }
        }
        // Should be unreachable given the 7-day search window, but keep a
        // safe fallback rather than force-unwrapping.
        return now.addingTimeInterval(3 * 24 * 3600)
    }
}
