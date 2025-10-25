import SwiftUI
import SafariServices

// MARK: - Safari View (SFSafariViewController Wrapper)

/// SFSafariViewControllerをSwiftUIで使用するためのラッパー
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false

        let vc = SFSafariViewController(url: url, configuration: configuration)
        vc.dismissButtonStyle = .close
        vc.preferredControlTintColor = .systemBlue
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // SFSafariViewControllerは内部状態を管理するため、更新は不要
    }
}

// MARK: - Identifiable URL

/// URLをシート表示用にIdentifiableに適合させるためのラッパー構造体
/// - Note: sheet(item:)で使用するために必要
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL

    init(_ url: URL) {
        self.url = url
    }
}

// MARK: - Safari Sheet Modifier

/// アプリ内ブラウザ(SFSafariViewController)でURLを開くためのViewModifier
struct SafariSheetModifier: ViewModifier {
    @State private var identifiableURL: IdentifiableURL?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                // HTTP/HTTPSスキーム以外は、標準の動作（ブラウザで開く等）にフォールバック
                if url.scheme == "https" || url.scheme == "http" {
                    identifiableURL = IdentifiableURL(url)
                    return .handled
                } else {
                    return .systemAction
                }
            })
            .sheet(item: $identifiableURL) { identifiableURL in
                SafariView(url: identifiableURL.url)
                    .ignoresSafeArea()
            }
    }
}

// MARK: - View Extension

extension View {
    /// ViewにSafariシート表示機能を追加する
    /// アプリ内で開かれるURLをSFSafariViewControllerで表示するようにする
    func safariSheet() -> some View {
        modifier(SafariSheetModifier())
    }
}
