import Foundation
import Supabase

struct FallaciesRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClients.data) {
        self.client = client
    }

    /// The mandatory onboarding carousel's content.
    func onboardingFallacies() async throws -> [Fallacy] {
        try await client
            .from("fallacies")
            .select()
            .eq("in_onboarding_carousel", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value
    }

    /// The full expanded library shown in Learn.
    func allFallacies() async throws -> [Fallacy] {
        try await client
            .from("fallacies")
            .select()
            .order("display_order", ascending: true)
            .execute()
            .value
    }
}
