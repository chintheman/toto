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
    /// TODO: replace with the real `toto-data` project URL + anon key once
    /// that Supabase project is created (see ios/README.md).
    private static let dataProjectURL = URL(string: "https://YOUR-TOTO-DATA-PROJECT.supabase.co")!
    private static let dataProjectAnonKey = "YOUR-TOTO-DATA-ANON-KEY"

    static let data = SupabaseClient(
        supabaseURL: dataProjectURL,
        supabaseKey: dataProjectAnonKey
    )
}
