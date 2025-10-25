import Foundation
import Supabase
import UIKit
import AVFoundation
import Combine

// MARK: - Supabase Storageメディアアップロードサービス

@MainActor
class MediaUploadService: ObservableObject {
    @Published var uploadProgress: [String: Double] = [:]
    @Published var uploadStatus: [String: UploadStatus] = [:]
    @Published var isUploading = false
    
    private let supabase = SupabaseConfig.shared.client
    private let storage: SupabaseStorageClient
    private let bucketName = "media-files"
    private let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
    private let allowedImageTypes = ["image/jpeg", "image/png", "image/heic", "image/webp"]
    private let allowedVideoTypes = ["video/mp4", "video/mov", "video/quicktime"]
    
    private var uploadTasks: [String: Task<MediaFile, Error>] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.storage = supabase.storage
        setupStorage()
    }
    
    // MARK: - Storage Setup
    
    private func setupStorage() {
        Task {
            await createBucketIfNeeded()
        }
    }
    
    private func createBucketIfNeeded() async {
        do {
            // バケットが存在するかチェック
            let buckets = try await storage.listBuckets()
            
            if !buckets.contains(where: { $0.name == bucketName }) {
                // バケットを作成
                try await storage.createBucket(
                    bucketName,
                    options: BucketOptions(
                        public: false,
                        fileSizeLimit: String(maxFileSize),
                        allowedMimeTypes: allowedImageTypes + allowedVideoTypes
                    )
                )
            }
        } catch {
        }
    }
    
    // MARK: - Image Upload
    
    /// 画像をアップロード
    func uploadImage(
        _ image: UIImage,
        fileName: String? = nil,
        quality: CGFloat = 0.8
    ) async throws -> MediaFile {
        let uploadId = UUID().uuidString
        let finalFileName = fileName ?? generateFileName(extension: "jpg")
        
        // 画像を圧縮
        guard let imageData = compressImage(image, quality: quality) else {
            throw MediaUploadError.compressionFailed
        }
        
        // アップロード開始
        updateUploadStatus(uploadId, status: .uploading)
        
        do {
            let fileURL = try await uploadData(
                imageData,
                fileName: finalFileName,
                contentType: "image/jpeg",
                uploadId: uploadId
            )
            
            let mediaFile = MediaFile(
                id: UUID(),
                type: .image,
                url: fileURL,
                thumbnailURL: fileURL // 画像の場合は同じURL
            )
            
            updateUploadStatus(uploadId, status: .completed)
            return mediaFile
            
        } catch {
            updateUploadStatus(uploadId, status: .failed(error))
            throw error
        }
    }
    
    /// 複数画像を並列アップロード
    func uploadImages(
        _ images: [UIImage],
        quality: CGFloat = 0.8
    ) async throws -> [MediaFile] {
        return try await withThrowingTaskGroup(of: MediaFile.self) { group in
            var results: [MediaFile] = []
            
            for (index, image) in images.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { throw MediaUploadError.cancelled }
                    let fileName = self.generateFileName(extension: "jpg", index: index)
                    return try await self.uploadImage(image, fileName: fileName, quality: quality)
                }
            }
            
            for try await mediaFile in group {
                results.append(mediaFile)
            }
            
            return results
        }
    }
    
    // MARK: - Video Upload
    
    /// 動画をアップロード
    func uploadVideo(
        from url: URL,
        fileName: String? = nil
    ) async throws -> MediaFile {
        let uploadId = UUID().uuidString
        let finalFileName = fileName ?? generateFileName(extension: "mp4")
        
        // 動画データを読み込み
        guard let videoData = try? Data(contentsOf: url) else {
            throw MediaUploadError.invalidFile
        }
        
        // ファイルサイズチェック
        if Int64(videoData.count) > maxFileSize {
            throw MediaUploadError.fileTooLarge
        }
        
        // 動画のメタデータを取得
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        var width: Int = 0
        var height: Int = 0
        
        if let videoTrack = tracks.first {
            let size = try await videoTrack.load(.naturalSize)
            width = Int(size.width)
            height = Int(size.height)
        }
        
        // アップロード開始
        updateUploadStatus(uploadId, status: .uploading)
        
        do {
            let fileURL = try await uploadData(
                videoData,
                fileName: finalFileName,
                contentType: "video/mp4",
                uploadId: uploadId
            )
            
            // サムネイルを生成してアップロード
            let thumbnailURL = try await generateAndUploadThumbnail(
                for: asset,
                fileName: finalFileName
            )
            
            let mediaFile = MediaFile(
                id: UUID(),
                type: .video,
                url: fileURL,
                thumbnailURL: thumbnailURL
            )
            
            updateUploadStatus(uploadId, status: .completed)
            return mediaFile
            
        } catch {
            updateUploadStatus(uploadId, status: .failed(error))
            throw error
        }
    }
    
    // MARK: - Core Upload Methods
    
    private func uploadData(
        _ data: Data,
        fileName: String,
        contentType: String,
        uploadId: String
    ) async throws -> String {
        let filePath = "\(getCurrentUserID())/\(Date().timeIntervalSince1970)/\(fileName)"
        
        // プログレス追跡付きアップロード
        let fileOptions = FileOptions(
            cacheControl: "3600",
            contentType: contentType
        )
        
        try await storage.from(bucketName).upload(
            path: filePath,
            file: data,
            options: fileOptions
        )
        
        // 公開URLを取得
        let publicURL = try storage.from(bucketName).getPublicURL(path: filePath)
        return publicURL.absoluteString
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateAndUploadThumbnail(
        for asset: AVAsset,
        fileName: String
    ) async throws -> String {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        let cgImage = try await imageGenerator.image(at: time).image
        let thumbnailImage = UIImage(cgImage: cgImage)
        
        // サムネイル用のファイル名
        let thumbnailFileName = fileName.replacingOccurrences(of: ".mp4", with: "_thumb.jpg")
        
        // サムネイルをアップロード
        return try await uploadImage(thumbnailImage, fileName: thumbnailFileName).url
    }
    
    // MARK: - Image Compression
    
    private func compressImage(_ image: UIImage, quality: CGFloat) -> Data? {
        // 最大サイズを設定（例：1920x1080）
        let maxSize = CGSize(width: 1920, height: 1080)
        let resizedImage = resizeImage(image, targetSize: maxSize)
        
        return resizedImage.jpegData(compressionQuality: quality)
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        // 小さい方の比率を使用（アスペクト比を保持）
        let ratio = min(widthRatio, heightRatio)
        
        // すでに小さい場合はそのまま返す
        if ratio >= 1.0 {
            return image
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    // MARK: - Upload Management
    
    func cancelUpload(_ uploadId: String) {
        uploadTasks[uploadId]?.cancel()
        uploadTasks.removeValue(forKey: uploadId)
        uploadProgress.removeValue(forKey: uploadId)
        updateUploadStatus(uploadId, status: .cancelled)
    }
    
    func cancelAllUploads() {
        for (uploadId, task) in uploadTasks {
            task.cancel()
            updateUploadStatus(uploadId, status: .cancelled)
        }
        uploadTasks.removeAll()
        uploadProgress.removeAll()
        isUploading = false
    }
    
    private func updateUploadStatus(_ uploadId: String, status: UploadStatus) {
        uploadStatus[uploadId] = status
        
        // アップロード中のタスクがあるかチェック
        let hasActiveUploads = uploadStatus.values.contains { status in
            if case .uploading = status { return true }
            return false
        }
        
        isUploading = hasActiveUploads
    }
    
    // MARK: - File Validation
    
    func validateFile(_ data: Data, mimeType: String) throws {
        // ファイルサイズチェック
        if Int64(data.count) > maxFileSize {
            throw MediaUploadError.fileTooLarge
        }
        
        // MIMEタイプチェック
        let allowedTypes = allowedImageTypes + allowedVideoTypes
        if !allowedTypes.contains(mimeType) {
            throw MediaUploadError.unsupportedFileType
        }
    }
    
    // MARK: - File Management
    
    /// ファイルを削除
    func deleteFile(at path: String) async throws {
        try await storage.from(bucketName).remove(paths: [path])
    }
    
    /// 古いファイルをクリーンアップ
    func cleanupOldFiles(olderThan days: Int = 30) async {
        do {
            let userPath = getCurrentUserID()
            let files = try await storage.from(bucketName).list(path: userPath)
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            
            let oldFiles = files.filter { file in
                if let createdAt = file.createdAt {
                    return createdAt < cutoffDate
                }
                return false
            }
            
            if !oldFiles.isEmpty {
                let pathsToDelete = oldFiles.map { "\(userPath)/\($0.name)" }
                try await storage.from(bucketName).remove(paths: pathsToDelete)
            }

        } catch {
        }
    }
    
    // MARK: - Utilities
    
    nonisolated private func generateFileName(extension ext: String, index: Int? = nil) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        
        if let index = index {
            return "\(timestamp)_\(index)_\(random).\(ext)"
        } else {
            return "\(timestamp)_\(random).\(ext)"
        }
    }
    
    private func getCurrentUserID() -> String {
        // TODO: 実際の実装では認証サービスから取得
        return "user_123"
    }
    
    // MARK: - Batch Operations
    
    /// 複数メディアファイルを並列アップロード
    func uploadMedia(_ mediaItems: [MediaItem]) async throws -> [MediaFile] {
        return try await withThrowingTaskGroup(of: MediaFile.self) { group in
            var results: [MediaFile] = []
            
            for mediaItem in mediaItems {
                group.addTask { [weak self] in
                    guard let self = self else { throw MediaUploadError.cancelled }
                    
                    switch mediaItem {
                    case .image(let image):
                        return try await self.uploadImage(image)
                    case .video(let url):
                        return try await self.uploadVideo(from: url)
                    }
                }
            }
            
            for try await mediaFile in group {
                results.append(mediaFile)
            }

            return results
        }
    }
}

// MARK: - Supporting Types

enum UploadStatus {
    case waiting
    case uploading
    case completed
    case failed(Error)
    case cancelled
    
    var displayText: String {
        switch self {
        case .waiting: return "待機中"
        case .uploading: return "アップロード中"
        case .completed: return "完了"
        case .failed: return "失敗"
        case .cancelled: return "キャンセル"
        }
    }
}

enum MediaUploadError: Error, LocalizedError {
    case invalidFile
    case fileTooLarge
    case unsupportedFileType
    case compressionFailed
    case networkError
    case cancelled
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "無効なファイルです"
        case .fileTooLarge:
            return "ファイルサイズが大きすぎます（最大50MB）"
        case .unsupportedFileType:
            return "サポートされていないファイル形式です"
        case .compressionFailed:
            return "画像の圧縮に失敗しました"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .cancelled:
            return "アップロードがキャンセルされました"
        case .quotaExceeded:
            return "ストレージ容量を超過しています"
        }
    }
}

enum MediaItem {
    case image(UIImage)
    case video(URL)
    
    var type: MediaType {
        switch self {
        case .image: return .image
        case .video: return .video
        }
    }
}

// MARK: - Extensions

extension FileOptions {
    init(cacheControl: String, contentType: String) {
        self.init()
        self.cacheControl = cacheControl
        self.contentType = contentType
    }
}