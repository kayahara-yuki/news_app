import SwiftUI

/// サインアップ（新規登録）画面
struct SignUpView: View {
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    init(authService: any AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 25) {
                    // タイトル
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .padding(.top, 30)

                        Text("新規登録")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("アカウントを作成してください")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 20)

                    // サインアップフォーム
                    VStack(spacing: 20) {
                        // メールアドレス
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メールアドレス")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            TextField("example@email.com", text: $viewModel.email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                        }

                        // ユーザー名
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ユーザー名（3文字以上）")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            TextField("username", text: $viewModel.username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.username)
                                .autocapitalization(.none)
                        }

                        // 表示名（オプション）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("表示名（オプション）")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            TextField("表示名", text: $viewModel.displayName)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.name)
                        }

                        // パスワード
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード（6文字以上）")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            SecureField("パスワード", text: $viewModel.password)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.newPassword)
                        }

                        // パスワード確認
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード（確認）")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            SecureField("パスワード再入力", text: $viewModel.confirmPassword)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.newPassword)

                            // パスワード一致確認
                            if !viewModel.password.isEmpty && !viewModel.confirmPassword.isEmpty {
                                HStack(spacing: 5) {
                                    Image(systemName: viewModel.password == viewModel.confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    Text(viewModel.password == viewModel.confirmPassword ? "パスワードが一致しています" : "パスワードが一致しません")
                                        .font(.caption)
                                }
                                .foregroundColor(viewModel.password == viewModel.confirmPassword ? .green : .red)
                            }
                        }

                        // 登録ボタン
                        Button(action: {
                            Task {
                                await viewModel.signUp()
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("アカウントを作成")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(viewModel.isSignUpFormValid ? Color.white : Color.white.opacity(0.5))
                            .foregroundColor(.purple)
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.isSignUpFormValid || viewModel.isLoading)
                        .padding(.top, 10)

                        // 利用規約
                        Text("登録することで、利用規約とプライバシーポリシーに同意したものとみなされます。")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)

                        // ログインリンク
                        HStack {
                            Text("既にアカウントをお持ちの場合")
                                .foregroundColor(.white)
                            Button(action: {
                                dismiss()
                            }) {
                                Text("ログイン")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .font(.subheadline)
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                }
            }
        }
        .navigationTitle("新規登録")
        .navigationBarTitleDisplayMode(.inline)
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {
                if viewModel.isAuthenticated {
                    dismiss()
                }
            }
        } message: {
            Text(viewModel.alertMessage)
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SignUpView(authService: DependencyContainer.shared.authService)
    }
}
