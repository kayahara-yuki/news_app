import Foundation
import UIKit

/// URLCacheベースの画像キャッシュ設定
class ImageCache {
    static let shared = ImageCache()

    private init() {
        configureURLCache()
    }

    /// URLCacheを設定して画像キャッシングを有効化
    private func configureURLCache() {
        // メモリキャッシュ: 50MB
        // ディスクキャッシュ: 100MB
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 100 * 1024 * 1024

        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "image_cache"
        )

        URLCache.shared = cache
    }

    /// キャッシュをクリア
    func clearCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    /// 特定のURLのキャッシュを削除
    func removeCachedResponse(for url: URL) {
        let request = URLRequest(url: url)
        URLCache.shared.removeCachedResponse(for: request)
    }

    /// キャッシュサイズ情報を取得
    func getCacheInfo() -> (currentMemoryUsage: Int, currentDiskUsage: Int) {
        return (
            currentMemoryUsage: URLCache.shared.currentMemoryUsage,
            currentDiskUsage: URLCache.shared.currentDiskUsage
        )
    }
}
