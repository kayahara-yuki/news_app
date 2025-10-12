import Foundation
import Supabase

/// Supabaseの設定を管理するクラス
class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    // MARK: - Supabase設定
    // 注意: 本番環境では環境変数やplistファイルから読み込むこと
    private let supabaseURL = "https://your-project-id.supabase.co"
    private let supabaseAnonKey = "your-anon-key-here"
    
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