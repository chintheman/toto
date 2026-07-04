import Foundation
import Supabase

struct FactsRepository {
    private let client = SupabaseClients.data

    func allFacts(forNumber number: Int) async throws -> [NumberFact] {
        try await client
            .from("number_facts")
            .select()
            .eq("number_value", value: number)
            .eq("is_active", value: true)
            .order("priority", ascending: false)
            .execute()
            .value
    }

    /// The curated top facts for a number, used for draw-day surfacing (2-3
    /// facts per drawn number) rather than dumping all ~20 at once.
    func topFacts(forNumber number: Int, limit: Int = 3) async throws -> [NumberFact] {
        try await client
            .from("number_facts")
            .select()
            .eq("number_value", value: number)
            .eq("is_active", value: true)
            .order("priority", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}
