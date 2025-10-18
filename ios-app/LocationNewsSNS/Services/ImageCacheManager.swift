import Foundation
import UIKit

/// 画像キャッシュマネージャー
/// LRU（Least Recently Used）キャッシュでメモリ効率を最適化
class ImageCacheManager {
    static let shared = ImageCacheManager()

    // MARK: - Properties

    private let cache = NSCache<NSString, UIImage>()

    // MARK: - Configuration

    private init() {
        configureCache()
    }

    private func configureCache() {
        // メモリ制限: 50MB（約50枚の高解像度画像）
        cache.totalCostLimit = 50 * 1024 * 1024

        // アイテム数制限: 100枚
        cache.countLimit = 100

        // メモリ警告時に自動削除
        cache.evictsObjectsWithDiscardedContent = true

        // メモリ警告の通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Public Methods

    /// 画像をキャッシュに保存
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    /// キャッシュから画像を取得
    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    /// 特定のキーの画像を削除
    func removeImage(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// キャッシュを全てクリア
    @objc func clearCache() {
        cache.removeAllObjects()
        AppLogger.debug("画像キャッシュをクリアしました")
    }

    // MARK: - Deinit

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - URLSession Image Cache Extension

extension URLSession {
    /// 画像を非同期でダウンロードし、キャッシュに保存
    func cachedImage(from url: URL) async throws -> UIImage {
        let cacheKey = url.absoluteString

        // キャッシュチェック
        if let cachedImage = ImageCacheManager.shared.image(forKey: cacheKey) {
            AppLogger.debug("画像キャッシュヒット: \(url.lastPathComponent)")
            return cachedImage
        }

        // ダウンロード
        AppLogger.debug("画像ダウンロード開始: \(url.lastPathComponent)")
        let (data, _) = try await self.data(from: url)

        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        // キャッシュに保存
        ImageCacheManager.shared.setImage(image, forKey: cacheKey)

        return image
    }
}
