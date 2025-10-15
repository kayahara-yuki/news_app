import SwiftUI

/// パスワードリセット画面
struct ForgotPasswordView: View {
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    init(authService: any AuthServiceProtocol) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.red.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // タイトル
                    VStack(spacing: 15) {
                        Image(systemName: "lock.rotation")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .padding(.top, 50)

                        Text("パスワードリセット")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("登録したメールアドレスを入力してください\nパスワードリセット用のリンクをお送りします")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)

                    // フォーム
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

                        // 送信ボタン
                        Button(action: {
                            Task {
                                await viewModel.resetPassword()
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "envelope.fill")
                                    Text("リセットメールを送信")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(viewModel.isForgotPasswordFormValid ? Color.white : Color.white.opacity(0.5))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.isForgotPasswordFormValid || viewModel.isLoading)
                        .padding(.top, 10)

                        // 説明テキスト
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.white)
                                Text("メールが届かない場合は、迷惑メールフォルダをご確認ください。")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.white)
                                Text("リンクは24時間有効です。")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)

                        // ログインに戻る
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("ログイン画面に戻る")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                }
            }
        }
        .navigationTitle("パスワードリセット")
        .navigationBarTitleDisplayMode(.inline)
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {
                if viewModel.alertTitle == "メール送信完了" {
                    dismiss()
                }
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ForgotPasswordView(authService: DependencyContainer.shared.authService)
    }
}
