import SwiftUI

/// URLCacheを活用したキャッシング対応AsyncImage
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    let transaction: Transaction
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        scale: CGFloat = 1,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
                    .task {
                        await loadImage()
                    }
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
    }

    private func loadImage() async {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }

        // メモリキャッシュから画像を取得を試みる（高速）
        let cacheKey = url.absoluteString
        if let cachedImage = ImageCacheManager.shared.image(forKey: cacheKey) {
            let image = Image(uiImage: cachedImage)
            withTransaction(transaction) {
                phase = .success(image)
            }
            return
        }

        // URLCacheから画像を取得を試みる（中速）
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // レスポンスをキャッシュに保存
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                let cachedResponse = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            }

            // UIImageに変換
            if let uiImage = UIImage(data: data) {
                // メモリキャッシュに保存
                ImageCacheManager.shared.setImage(uiImage, forKey: cacheKey)

                let image = Image(uiImage: uiImage)
                withTransaction(transaction) {
                    phase = .success(image)
                }
            } else {
                phase = .failure(URLError(.cannotDecodeContentData))
            }
        } catch {
            phase = .failure(error)
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    /// シンプルな初期化子（デフォルトプレースホルダー）
    init(url: URL?, scale: CGFloat = 1) {
        self.init(
            url: url,
            scale: scale,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}

extension CachedAsyncImage where Placeholder == Color {
    /// contentのみ指定する初期化子
    init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            scale: scale,
            content: content,
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}

extension CachedAsyncImage where Content == Image {
    /// placeholderのみ指定する初期化子
    init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            scale: scale,
            content: { $0 },
            placeholder: placeholder
        )
    }
}
