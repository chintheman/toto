import Foundation
import Supabase

struct FactsRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient? = nil) {
        self.client = client ?? SupabaseClients.data
    }

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

    /// Fetch facts for multiple numbers in a single query using `.in()`.
    /// Returns a dictionary keyed by number value.
    func multiFacts(forNumbers numbers: [Int]) async throws -> [Int: [NumberFact]] {
        let facts: [NumberFact] = try await client
            .from("number_facts")
            .select()
            .in("number_value", values: numbers)
            .eq("is_active", value: true)
            .order("priority", ascending: false)
            .execute()
            .value
        return Dictionary(grouping: facts, by: { $0.numberValue })
    }
}
