import Foundation
import Supabase

struct FactsRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClients.data) {
        self.client = client
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

    /// Top facts for a whole set of numbers in ONE round trip
    /// (design-changes §2 perf: `.in("number_value", numbers)` instead of
    /// 7 serial queries). Returns facts grouped by number, best-priority
    /// first within each group.
    func topFacts(forNumbers numbers: [Int], limitPerNumber: Int = 2) async throws -> [Int: [NumberFact]] {
        guard !numbers.isEmpty else { return [:] }
        let facts: [NumberFact] = try await client
            .from("number_facts")
            .select()
            .in("number_value", values: numbers)
            .eq("is_active", value: true)
            .order("priority", ascending: false)
            .execute()
            .value
        var grouped: [Int: [NumberFact]] = [:]
        for fact in facts where (grouped[fact.numberValue]?.count ?? 0) < limitPerNumber {
            grouped[fact.numberValue, default: []].append(fact)
        }
        return grouped
    }
}
