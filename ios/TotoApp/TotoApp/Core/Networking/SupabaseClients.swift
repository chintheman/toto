import Foundation
import Supabase

/// Only ONE Supabase project is ever configured here: `toto-data`, the
/// public-readable project (draws, facts, fallacies). Its anon key is safe
/// to ship in this binary because RLS grants it SELECT-only, and it has no
/// visibility into `toto-recommendation` (the private project holding the
/// paid recommendation engine's algorithm and heuristic data).
///
/// `toto-recommendation` is deliberately NOT configured here — Phase 3 will
/// add a call to its Edge Function endpoint directly (with a StoreKit
/// transaction as a bearer credential), not a second SupabaseClient with a
/// key baked into this app.
enum SupabaseClients {
    private static let dataProjectURL = URL(string: "https://vpopzwluqosebiistdmd.supabase.co")!
    // This is the "publishable" key (Supabase's newer key format, sb_publishable_...) --
    // functionally equivalent to the legacy "anon" key for RLS purposes, and
    // just as safe to ship in this binary (see doc comment above).
    private static let dataProjectAnonKey = "sb_publishable_5efrIi-5CPxz-cbz9HI1cA_3pGMCnlv"

    static let data = SupabaseClient(
        supabaseURL: dataProjectURL,
        supabaseKey: dataProjectAnonKey
    )
}
