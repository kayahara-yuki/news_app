import Foundation
import Combine
import CoreLocation

// MARK: - Auth UseCase Protocol

protocol AuthUseCaseProtocol {
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, username: String, displayName: String?) async throws
    func signOut() async throws
    func resetPassword(email: String) async throws
    func updateProfile(displayName: String?, bio: String?, location: String?) async throws
    func getCurrentUser() async throws -> UserProfile?
    func isAuthenticated() -> Bool
}

// MARK: - Auth UseCase Implementation

class AuthUseCase: AuthUseCaseProtocol {
    private let authService: any AuthServiceProtocol
    private let userRepository: any UserRepositoryProtocol
    
    init(authService: any AuthServiceProtocol, userRepository: any UserRepositoryProtocol) {
        self.authService = authService
        self.userRepository = userRepository
    }
    
    func signIn(email: String, password: String) async throws {
        // バリデーション
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
        
        guard email.contains("@") else {
            throw AuthError.invalidEmail
        }
        
        // ビジネスロジック: サインイン
        await authService.signIn(email: email, password: password)
        
        if let errorMessage = authService.errorMessage {
            throw AuthError.signInFailed(errorMessage)
        }
    }
    
    func signUp(email: String, password: String, username: String, displayName: String?) async throws {
        // バリデーション
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            throw AuthError.invalidCredentials
        }
        
        guard email.contains("@") else {
            throw AuthError.invalidEmail
        }
        
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        
        // ユーザー名の重複チェック
        let existingUser = try? await userRepository.getUserByUsername(username)
        if existingUser != nil {
            throw AuthError.usernameAlreadyExists
        }
        
        // ビジネスロジック: サインアップ
        await authService.signUp(email: email, password: password, username: username, displayName: displayName)
        
        if let errorMessage = authService.errorMessage {
            throw AuthError.signUpFailed(errorMessage)
        }
    }
    
    func signOut() async throws {
        await authService.signOut()
        
        if let errorMessage = authService.errorMessage {
            throw AuthError.signOutFailed(errorMessage)
        }
    }
    
    func resetPassword(email: String) async throws {
        guard !email.isEmpty, email.contains("@") else {
            throw AuthError.invalidEmail
        }
        
        await authService.resetPassword(email: email)
        
        if let errorMessage = authService.errorMessage {
            throw AuthError.resetPasswordFailed(errorMessage)
        }
    }
    
    func updateProfile(displayName: String?, bio: String?, location: String?) async throws {
        guard isAuthenticated() else {
            throw AuthError.notAuthenticated
        }
        
        // バリデーション
        if let bio = bio, bio.count > 500 {
            throw AuthError.bioTooLong
        }
        
        if let displayName = displayName, displayName.count > 100 {
            throw AuthError.displayNameTooLong
        }
        
        await authService.updateProfile(displayName: displayName, bio: bio, location: location)
        
        if let errorMessage = authService.errorMessage {
            throw AuthError.updateProfileFailed(errorMessage)
        }
    }
    
    func getCurrentUser() async throws -> UserProfile? {
        return authService.currentUser
    }
    
    func isAuthenticated() -> Bool {
        return authService.isAuthenticated
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case invalidEmail
    case weakPassword
    case usernameAlreadyExists
    case notAuthenticated
    case bioTooLong
    case displayNameTooLong
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case resetPasswordFailed(String)
    case updateProfileFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "メールアドレスとパスワードを入力してください"
        case .invalidEmail:
            return "有効なメールアドレスを入力してください"
        case .weakPassword:
            return "パスワードは8文字以上で入力してください"
        case .usernameAlreadyExists:
            return "このユーザー名は既に使用されています"
        case .notAuthenticated:
            return "ログインが必要です"
        case .bioTooLong:
            return "自己紹介は500文字以内で入力してください"
        case .displayNameTooLong:
            return "表示名は100文字以内で入力してください"
        case .signInFailed(let message):
            return "サインインに失敗しました: \(message)"
        case .signUpFailed(let message):
            return "サインアップに失敗しました: \(message)"
        case .signOutFailed(let message):
            return "サインアウトに失敗しました: \(message)"
        case .resetPasswordFailed(let message):
            return "パスワードリセットに失敗しました: \(message)"
        case .updateProfileFailed(let message):
            return "プロフィール更新に失敗しました: \(message)"
        }
    }
}