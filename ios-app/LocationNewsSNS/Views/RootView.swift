import SwiftUI

/// アプリのルートビュー
/// 認証状態に応じてLoginViewまたはContentViewを表示
struct RootView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isLoading {
                // ローディング中
                LoadingView()
            } else if authService.isAuthenticated {
                // 認証済み - メインコンテンツを表示
                ContentView()
            } else {
                // 未認証 - ログイン画面を表示
                LoginView(authService: authService)
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}

/// ローディング画面
struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "map.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("読み込み中...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview

#Preview("認証済み") {
    RootView()
        .environmentObject({
            let service = AuthService()
            // プレビュー用に認証済み状態をシミュレート
            return service
        }())
}

#Preview("未認証") {
    RootView()
        .environmentObject(AuthService())
}

#Preview("ローディング") {
    LoadingView()
}
