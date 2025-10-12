import Foundation
import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import Combine

// MARK: - PhotosKitメディア選択サービス

@MainActor
class ImagePickerService: NSObject, ObservableObject {
    @Published var selectedMedia: [SelectedMediaItem] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var albums: [MediaAlbum] = []
    @Published var recentPhotos: [PHAsset] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let imageManager = PHImageManager.default()
    private let maxSelectionCount = 10
    
    override init() {
        super.init()
        checkPhotoLibraryPermission()
        setupPhotoLibraryObserver()
    }
    
    // MARK: - Permission Management
    
    /// フォトライブラリの許可状態をチェック
    func checkPhotoLibraryPermission() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    /// フォトライブラリのアクセス許可を要求
    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
            if status == .authorized || status == .limited {
                loadRecentPhotos()
                loadAlbums()
            }
        }
    }
    
    // MARK: - Photo Library Observer
    
    private func setupPhotoLibraryObserver() {
        PHPhotoLibrary.shared().register(self)
    }
    
    // MARK: - Media Loading
    
    /// 最近の写真を読み込み
    func loadRecentPhotos(count: Int = 100) {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        
        isLoading = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = count
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        recentPhotos = assets
        isLoading = false
    }
    
    /// アルバム一覧を読み込み
    func loadAlbums() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        
        var albumList: [MediaAlbum] = []
        
        // スマートアルバム
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        
        smartAlbums.enumerateObjects { collection, _, _ in
            let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
            if assetCount > 0 {
                albumList.append(MediaAlbum(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "不明なアルバム",
                    assetCount: assetCount,
                    collection: collection
                ))
            }
        }
        
        // ユーザー作成アルバム
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        
        userAlbums.enumerateObjects { collection, _, _ in
            let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
            if assetCount > 0 {
                albumList.append(MediaAlbum(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "不明なアルバム",
                    assetCount: assetCount,
                    collection: collection
                ))
            }
        }
        
        albums = albumList.sorted { $0.assetCount > $1.assetCount }
    }
    
    /// 特定のアルバムから写真を読み込み
    func loadPhotos(from album: MediaAlbum) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        return assets
    }
    
    // MARK: - Media Selection
    
    /// メディアを選択
    func selectMedia(_ asset: PHAsset) {
        // 最大選択数チェック
        guard selectedMedia.count < maxSelectionCount else { return }
        
        // 既に選択済みかチェック
        guard !selectedMedia.contains(where: { $0.asset.localIdentifier == asset.localIdentifier }) else { return }
        
        let selectedItem = SelectedMediaItem(
            id: UUID(),
            asset: asset,
            type: asset.mediaType == .image ? .image : .video,
            selectedAt: Date()
        )
        
        selectedMedia.append(selectedItem)
    }
    
    /// メディアの選択を解除
    func deselectMedia(_ asset: PHAsset) {
        selectedMedia.removeAll { $0.asset.localIdentifier == asset.localIdentifier }
    }
    
    /// 選択済みメディアをクリア
    func clearSelection() {
        selectedMedia.removeAll()
    }
    
    /// 選択中かチェック
    func isSelected(_ asset: PHAsset) -> Bool {
        return selectedMedia.contains { $0.asset.localIdentifier == asset.localIdentifier }
    }
    
    // MARK: - Media Processing
    
    /// 選択されたメディアをUIImageまたはURLに変換
    func processSelectedMedia() async -> [ProcessedMediaItem] {
        var processedItems: [ProcessedMediaItem] = []
        
        for selectedItem in selectedMedia {
            do {
                let processedItem = try await processAsset(selectedItem.asset)
                processedItems.append(processedItem)
            } catch {
                print("メディア処理エラー: \(error)")
            }
        }
        
        return processedItems
    }
    
    private func processAsset(_ asset: PHAsset) async throws -> ProcessedMediaItem {
        switch asset.mediaType {
        case .image:
            let image = try await requestImage(for: asset)
            return ProcessedMediaItem(
                id: UUID(),
                type: .image(image),
                originalAsset: asset
            )
            
        case .video:
            let url = try await requestVideoURL(for: asset)
            return ProcessedMediaItem(
                id: UUID(),
                type: .video(url),
                originalAsset: asset
            )
            
        default:
            throw ImagePickerError.unsupportedMediaType
        }
    }
    
    // MARK: - Image Request
    
    /// PHAssetからUIImageを取得
    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize = PHImageManagerMaximumSize,
        quality: PHImageRequestOptionsDeliveryMode = .highQualityFormat
    ) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = quality
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ImagePickerError.imageRequestFailed)
                }
            }
        }
    }
    
    /// サムネイル画像を取得
    func requestThumbnail(
        for asset: PHAsset,
        size: CGSize = CGSize(width: 200, height: 200)
    ) async throws -> UIImage {
        return try await requestImage(
            for: asset,
            targetSize: size,
            quality: .fastFormat
        )
    }
    
    // MARK: - Video Request
    
    /// PHAssetから動画URLを取得
    func requestVideoURL(for asset: PHAsset) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            imageManager.requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(throwing: ImagePickerError.videoRequestFailed)
                }
            }
        }
    }
    
    // MARK: - Metadata Extraction
    
    /// アセットのメタデータを取得
    func getAssetMetadata(_ asset: PHAsset) -> AssetMetadata {
        return AssetMetadata(
            localIdentifier: asset.localIdentifier,
            mediaType: asset.mediaType,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            location: asset.location,
            duration: asset.duration,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            isFavorite: asset.isFavorite,
            isHidden: asset.isHidden
        )
    }
    
    // MARK: - Camera Integration
    
    /// カメラで撮影された画像を処理
    func handleCameraImage(_ image: UIImage) {
        // カメラで撮影された画像を一時的なアセットとして追加
        let tempAsset = createTemporaryAsset(from: image)
        selectMedia(tempAsset)
    }
    
    /// カメラで撮影された動画を処理
    func handleCameraVideo(at url: URL) {
        // 動画をフォトライブラリに保存
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.loadRecentPhotos(count: 1)
                }
            } else if let error = error {
                print("動画保存エラー: \(error)")
            }
        }
    }
    
    private func createTemporaryAsset(from image: UIImage) -> PHAsset {
        // 実際の実装では、一時的なPHAssetを作成するか
        // 別の方法でカメラ画像を管理する
        // ここではプレースホルダーとして空のPHAssetを返す
        // TODO: 適切な実装が必要
        return PHAsset()
    }
    
    // MARK: - Search and Filter
    
    /// 日付範囲でフィルタ
    func filterAssets(from startDate: Date, to endDate: Date) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        return assets
    }
    
    /// メディアタイプでフィルタ
    func filterAssets(by mediaType: PHAssetMediaType) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        return assets
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension ImagePickerService: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            // フォトライブラリの変更に応じて更新
            self.loadRecentPhotos()
            self.loadAlbums()
        }
    }
}

// MARK: - Supporting Types

struct MediaAlbum: Identifiable {
    let id: String
    let title: String
    let assetCount: Int
    let collection: PHAssetCollection
}

struct SelectedMediaItem: Identifiable {
    let id: UUID
    let asset: PHAsset
    let type: MediaType
    let selectedAt: Date
}

struct ProcessedMediaItem: Identifiable {
    let id: UUID
    let type: ProcessedMediaType
    let originalAsset: PHAsset
}

enum ProcessedMediaType {
    case image(UIImage)
    case video(URL)
}

struct AssetMetadata {
    let localIdentifier: String
    let mediaType: PHAssetMediaType
    let creationDate: Date?
    let modificationDate: Date?
    let location: CLLocation?
    let duration: TimeInterval
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let isHidden: Bool
}

enum ImagePickerError: Error, LocalizedError {
    case permissionDenied
    case imageRequestFailed
    case videoRequestFailed
    case unsupportedMediaType
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "フォトライブラリへのアクセスが許可されていません"
        case .imageRequestFailed:
            return "画像の読み込みに失敗しました"
        case .videoRequestFailed:
            return "動画の読み込みに失敗しました"
        case .unsupportedMediaType:
            return "サポートされていないメディアタイプです"
        case .processingFailed:
            return "メディアの処理に失敗しました"
        }
    }
}