import Foundation

/// Reads Supabase settings that Config/Secrets.xcconfig injects into Info.plist.
enum AppConfig {
    static let supabaseURL: URL = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String,
              !host.isEmpty, host != "your-project-ref.supabase.co",
              let url = URL(string: "https://\(host)")
        else {
            fatalError("Set SUPABASE_HOST in Config/Secrets.xcconfig")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty, key != "your-anon-public-key"
        else {
            fatalError("Set SUPABASE_ANON_KEY in Config/Secrets.xcconfig")
        }
        return key
    }()
}
