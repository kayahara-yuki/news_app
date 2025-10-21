import Foundation
import Supabase
import AuthenticationServices
import Combine

/// 認証サービス
@MainActor
class AuthService: ObservableObject, AuthServiceProtocol {
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = true  // 初期化時はローディング状態
    @Published var errorMessage: String?

    private let supabase = SupabaseConfig.shared.client
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 認証状態の監視
        observeAuthStateChanges()

        // 既存のセッションをチェック
        Task {
            await checkExistingSession()
        }
    }
    
    // MARK: - 認証状態の監視
    
    private func observeAuthStateChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    handleAuthStateChange(event: event, session: session)
                }
            }
        }
    }
    
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) {
        Task { @MainActor in
            switch event {
            case .signedIn:
                if let session = session {
                    await handleSignIn(session: session)
                }
            case .signedOut:
                await handleSignOut()
            case .tokenRefreshed:
                break
            case .userUpdated:
                if let session = session {
                    await fetchUserProfile(userID: session.user.id)
                }
            default:
                break
            }
        }
    }
    
    
    // MARK: - セッション管理
    
    private func checkExistingSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.session
            await handleSignIn(session: session)
        } catch {
            print("❌ [ERROR] AuthService - 既存セッションの確認エラー: \(error)")
            await handleSignOut()
        }
    }
    
    private func handleSignIn(session: Session) async {
        await fetchUserProfile(userID: session.user.id)
        isAuthenticated = true
        errorMessage = nil
    }
    
    private func handleSignOut() async {
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }
    
    // MARK: - 認証メソッド
    
    /// メールとパスワードでサインイン
    func signIn(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            // 認証状態の変更は observeAuthStateChanges で自動処理される
            print("サインイン成功: \(response.user.email ?? "")")
            
        } catch {
            print("サインインエラー: \(error)")
            errorMessage = "サインインに失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// メールとパスワードでサインアップ
    func signUp(email: String, password: String, username: String, displayName: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            // プロフィール作成
            await createUserProfile(
                userID: response.user.id,
                email: email,
                username: username,
                displayName: displayName
            )
            
            print("サインアップ成功: \(email)")
            
        } catch {
            print("サインアップエラー: \(error)")
            errorMessage = "サインアップに失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// Apple Sign-in
    func signInWithApple() async {
        isLoading = true
        defer { isLoading = false }
        
        // Apple Sign-inの実装
        // Note: ASAuthorizationAppleIDCredentialを使用した実装が必要
        
        print("Apple Sign-in is not implemented yet")
        errorMessage = "Apple Sign-inは未実装です"
    }
    
    /// サインアウト
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await supabase.auth.signOut()
            print("サインアウト成功")
        } catch {
            print("サインアウトエラー: \(error)")
            errorMessage = "サインアウトに失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// パスワードリセット
    func resetPassword(email: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            print("パスワードリセットメール送信成功")
        } catch {
            print("パスワードリセットエラー: \(error)")
            errorMessage = "パスワードリセットに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - ユーザープロフィール管理
    
    private func fetchUserProfile(userID: UUID) async {
        // ユーザープロフィール取得は後で実装
        print("ユーザープロフィール取得: \(userID)")
        // 仮のユーザーデータ
        currentUser = UserProfile(
            id: userID,
            email: "user@example.com",
            username: "user",
            displayName: "Test User",
            bio: nil,
            avatarURL: nil,
            location: nil,
            isVerified: false,
            role: .user,
            privacySettings: PrivacySettings.default,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createUserProfile(userID: UUID, email: String, username: String, displayName: String?) async {
        // プロフィール作成は後で実装
        print("プロフィール作成: \(email)")

        let profile = UserProfile(
            id: userID,
            email: email,
            username: username,
            displayName: displayName,
            bio: nil,
            avatarURL: nil,
            location: nil,
            isVerified: false,
            role: .user,
            privacySettings: PrivacySettings.default,
            createdAt: Date(),
            updatedAt: Date()
        )

        currentUser = profile
    }
    
    /// プロフィール更新
    func updateProfile(displayName: String?, bio: String?, location: String?) async {
        guard let currentUser = currentUser else { return }

        isLoading = true
        defer { isLoading = false }

        // プロフィール更新は後で実装
        print("プロフィール更新: \(displayName ?? "")")

        // TODO: Supabase APIで更新

        // ローカルのユーザー情報を更新
        let updatedUser = UserProfile(
            id: currentUser.id,
            email: currentUser.email,
            username: currentUser.username,
            displayName: displayName,
            bio: bio,
            avatarURL: currentUser.avatarURL,
            location: location,
            isVerified: currentUser.isVerified,
            role: currentUser.role,
            privacySettings: currentUser.privacySettings,
            createdAt: currentUser.createdAt,
            updatedAt: Date()
        )

        self.currentUser = updatedUser
    }
}

// MARK: - Date Extension

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}