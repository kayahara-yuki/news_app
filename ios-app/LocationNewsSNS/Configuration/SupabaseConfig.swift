import Foundation
import Supabase

/// Supabaseの設定を管理するクラス
class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    // MARK: - Supabase設定
    // 注意: 本番環境では環境変数やplistファイルから読み込むこと
    private let supabaseURL = "https://ikjxfoyfeliiovbwelyx.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTI5NDUsImV4cCI6MjA3NTU4ODk0NX0.E61qFPidet3gHJpqaBLeih2atXqx5LDc9zv5onEeM30"
    
    /// Supabaseクライアントのインスタンス
    lazy var client: SupabaseClient = {
        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }
        
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey
        )
    }()
    
    private init() {}
}

/// Supabaseクライアントへの便利なアクセス
extension SupabaseClient {
    static var shared: SupabaseClient {
        return SupabaseConfig.shared.client
    }
}