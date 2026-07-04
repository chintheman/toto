import Foundation
import Supabase

struct DrawsRepository {
    private let client = SupabaseClients.data

    func latestDraw() async throws -> Draw? {
        let draws: [Draw] = try await client
            .from("draws")
            .select()
            .order("draw_number", ascending: false)
            .limit(1)
            .execute()
            .value
        return draws.first
    }

    func history(limit: Int = 50, before drawNumber: Int? = nil) async throws -> [Draw] {
        var query = client.from("draws").select()
        if let drawNumber {
            query = query.lt("draw_number", value: drawNumber)
        }
        let draws: [Draw] = try await query
            .order("draw_number", ascending: false)
            .limit(limit)
            .execute()
            .value
        return draws
    }

    func prizeGroups(forDrawId drawId: Int) async throws -> [PrizeGroup] {
        try await client
            .from("draw_prize_groups")
            .select()
            .eq("draw_id", value: drawId)
            .order("group_number", ascending: true)
            .execute()
            .value
    }

    func upcomingDraw() async throws -> UpcomingDraw? {
        let rows: [UpcomingDraw] = try await client
            .from("upcoming_draw")
            .select()
            .order("draw_date", ascending: true)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Every draw a given number has appeared in (winning numbers OR
    /// additional number), used by NumberDetailView's "recent appearances".
    func draws(containingNumber number: Int, limit: Int = 10) async throws -> [Draw] {
        try await client
            .from("draws")
            .select()
            .contains("winning_numbers", value: [number])
            .order("draw_number", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}
