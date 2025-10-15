import Foundation
import SwiftUI
import Combine

/// 認証画面用のViewModel
@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var username: String = ""
    @Published var displayName: String = ""

    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var alertTitle: String = ""

    private let authService: any AuthServiceProtocol

    var isLoading: Bool {
        authService.isLoading
    }

    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    init(authService: any AuthServiceProtocol) {
        self.authService = authService
    }

    // MARK: - バリデーション

    var isLoginFormValid: Bool {
        isValidEmail(email) && password.count >= 6
    }

    var isSignUpFormValid: Bool {
        isValidEmail(email) &&
        password.count >= 6 &&
        password == confirmPassword &&
        username.count >= 3
    }

    var isForgotPasswordFormValid: Bool {
        isValidEmail(email)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // MARK: - 認証アクション

    func signIn() async {
        guard isLoginFormValid else {
            showError(title: "入力エラー", message: "メールアドレスとパスワードを正しく入力してください。")
            return
        }

        await authService.signIn(email: email, password: password)

        if let error = authService.errorMessage {
            showError(title: "ログインエラー", message: error)
        }
    }

    func signUp() async {
        guard isSignUpFormValid else {
            showError(title: "入力エラー", message: "すべてのフィールドを正しく入力してください。")
            return
        }

        await authService.signUp(
            email: email,
            password: password,
            username: username,
            displayName: displayName.isEmpty ? nil : displayName
        )

        if let error = authService.errorMessage {
            showError(title: "サインアップエラー", message: error)
        } else {
            showSuccess(title: "登録完了", message: "アカウントが作成されました。")
        }
    }

    func resetPassword() async {
        guard isForgotPasswordFormValid else {
            showError(title: "入力エラー", message: "有効なメールアドレスを入力してください。")
            return
        }

        await authService.resetPassword(email: email)

        if let error = authService.errorMessage {
            showError(title: "エラー", message: error)
        } else {
            showSuccess(title: "メール送信完了", message: "パスワードリセット用のメールを送信しました。")
        }
    }

    func signInWithApple() async {
        // Apple Sign-in の実装（将来的に）
        showError(title: "未実装", message: "Apple Sign-inは現在実装中です。")
    }

    // MARK: - ヘルパーメソッド

    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private func showSuccess(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        username = ""
        displayName = ""
    }
}
