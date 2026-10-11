import Foundation
import Supabase

/// The single Supabase client the whole app shares.
/// The anon key is safe to ship in the app; row-level security protects the data.
let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey,
    options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
)
