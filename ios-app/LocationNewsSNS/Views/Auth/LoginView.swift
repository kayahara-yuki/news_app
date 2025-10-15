import SwiftUI

/// ログイン画面
struct LoginView: View {
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    init(authService: any AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 25) {
                        // ロゴ・タイトル
                        VStack(spacing: 10) {
                            Image(systemName: "map.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white)
                                .padding(.top, 50)

                            Text("ロケーションニュース")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("地域のニュースをシェアしよう")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.bottom, 30)

                        // ログインフォーム
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

                            // パスワード
                            VStack(alignment: .leading, spacing: 8) {
                                Text("パスワード")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                SecureField("パスワード", text: $viewModel.password)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.password)
                            }

                            // パスワード忘れた
                            HStack {
                                Spacer()
                                NavigationLink(destination: ForgotPasswordView(authService: DependencyContainer.shared.authService)) {
                                    Text("パスワードを忘れた場合")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                            }

                            // ログインボタン
                            Button(action: {
                                Task {
                                    await viewModel.signIn()
                                }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("ログイン")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(viewModel.isLoginFormValid ? Color.white : Color.white.opacity(0.5))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                            .disabled(!viewModel.isLoginFormValid || viewModel.isLoading)
                            .padding(.top, 10)

                            // アカウント作成リンク
                            HStack {
                                Text("アカウントをお持ちでない場合")
                                    .foregroundColor(.white)
                                NavigationLink(destination: SignUpView(authService: DependencyContainer.shared.authService)) {
                                    Text("新規登録")
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
            .navigationBarHidden(true)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {}
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

// MARK: - カスタムテキストフィールドスタイル

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(10)
            .foregroundColor(.primary)
    }
}

// MARK: - Preview

#Preview {
    LoginView(authService: DependencyContainer.shared.authService)
}
