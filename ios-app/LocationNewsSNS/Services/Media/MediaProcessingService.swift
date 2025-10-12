import Foundation
import UIKit
import AVFoundation
import VideoToolbox
import ImageIO
import CoreImage
import Combine

// MARK: - メディア処理・最適化サービス

@MainActor
class MediaProcessingService: ObservableObject {
    @Published var processingProgress: [String: Double] = [:]
    @Published var isProcessing = false
    
    private let ciContext = CIContext()
    private var processingTasks: [String: Task<Void, Error>] = [:]
    
    // 設定
    private let imageCompressionQuality: CGFloat = 0.8
    private let maxImageDimension: CGFloat = 1920
    private let videoCompressionPreset = AVAssetExportPresetMediumQuality
    
    init() {}
    
    // MARK: - Image Processing
    
    /// 画像を最適化
    func optimizeImage(
        _ image: UIImage,
        maxDimension: CGFloat = 1920,
        compressionQuality: CGFloat = 0.8
    ) async throws -> UIImage {
        let processingId = UUID().uuidString
        updateProgress(processingId, progress: 0.1)
        
        // リサイズ
        let resizedImage = await resizeImage(image, maxDimension: maxDimension)
        updateProgress(processingId, progress: 0.5)
        
        // メタデータを削除
        let optimizedImage = removeImageMetadata(resizedImage)
        updateProgress(processingId, progress: 0.8)
        
        // 品質調整
        let finalImage = await adjustImageQuality(optimizedImage, quality: compressionQuality)
        updateProgress(processingId, progress: 1.0)
        
        return finalImage
    }
    
    /// 画像をリサイズ
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) async -> UIImage {
        return await Task.detached {
            let size = image.size
            
            // 既に小さい場合はそのまま返す
            if max(size.width, size.height) <= maxDimension {
                return image
            }
            
            let aspectRatio = size.width / size.height
            let newSize: CGSize
            
            if size.width > size.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
            
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }.value
    }
    
    /// 画像のメタデータを削除
    private func removeImageMetadata(_ image: UIImage) -> UIImage {
        guard let imageData = image.jpegData(compressionQuality: 1.0),
              let dataProvider = CGDataProvider(data: imageData as CFData),
              let cgImage = CGImage(
                jpegDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// 画像品質を調整
    private func adjustImageQuality(_ image: UIImage, quality: CGFloat) async -> UIImage {
        return await Task.detached {
            guard let data = image.jpegData(compressionQuality: quality),
                  let compressedImage = UIImage(data: data) else {
                return image
            }
            return compressedImage
        }.value
    }
    
    // MARK: - Video Processing
    
    /// 動画を最適化
    func optimizeVideo(
        from inputURL: URL,
        outputURL: URL,
        preset: String = AVAssetExportPresetMediumQuality
    ) async throws {
        let processingId = UUID().uuidString
        updateProgress(processingId, progress: 0.1)
        
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw MediaProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // プログレス監視
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.updateProgress(processingId, progress: Double(exportSession.progress))
            }
        }
        
        await exportSession.export()
        progressTimer.invalidate()
        
        updateProgress(processingId, progress: 1.0)
        
        if exportSession.status != .completed {
            if let error = exportSession.error {
                throw error
            } else {
                throw MediaProcessingError.videoExportFailed
            }
        }
    }
    
    /// 動画のサムネイルを生成
    func generateVideoThumbnail(
        from url: URL,
        at time: CMTime = CMTime(seconds: 1.0, preferredTimescale: 600)
    ) async throws -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try await imageGenerator.image(at: time).image
        return UIImage(cgImage: cgImage)
    }
    
    /// 動画の複数サムネイルを生成
    func generateVideoThumbnails(
        from url: URL,
        count: Int = 5
    ) async throws -> [UIImage] {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        var thumbnails: [UIImage] = []
        let timeInterval = duration.seconds / Double(count)
        
        for i in 0..<count {
            let time = CMTime(seconds: timeInterval * Double(i), preferredTimescale: 600)
            let cgImage = try await imageGenerator.image(at: time).image
            thumbnails.append(UIImage(cgImage: cgImage))
        }
        
        return thumbnails
    }
    
    // MARK: - Image Filters
    
    /// 画像にフィルターを適用
    func applyFilter(to image: UIImage, filterName: String) async throws -> UIImage {
        return try await Task.detached { [weak self] in
            guard let self = self,
                  let ciImage = CIImage(image: image),
                  let filter = CIFilter(name: filterName) else {
                throw MediaProcessingError.filterApplicationFailed
            }
            
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            
            guard let outputImage = filter.outputImage,
                  let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent) else {
                throw MediaProcessingError.filterApplicationFailed
            }
            
            return UIImage(cgImage: cgImage)
        }.value
    }
    
    /// 画像の自動補正
    func autoEnhanceImage(_ image: UIImage) async throws -> UIImage {
        return try await Task.detached { [weak self] in
            guard let self = self,
                  let ciImage = CIImage(image: image) else {
                throw MediaProcessingError.imageProcessingFailed
            }
            
            // 自動調整フィルターのチェーン
            let filters = ciImage.autoAdjustmentFilters()
            
            var processedImage = ciImage
            for filter in filters {
                filter.setValue(processedImage, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    processedImage = output
                }
            }
            
            guard let cgImage = self.ciContext.createCGImage(processedImage, from: processedImage.extent) else {
                throw MediaProcessingError.imageProcessingFailed
            }
            
            return UIImage(cgImage: cgImage)
        }.value
    }
    
    // MARK: - Batch Processing
    
    /// 複数画像を並列処理
    func batchProcessImages(
        _ images: [UIImage],
        operations: [ImageOperation] = [.optimize]
    ) async throws -> [UIImage] {
        return try await withThrowingTaskGroup(of: (Int, UIImage).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { throw MediaProcessingError.processingCancelled }
                    
                    var processedImage = image
                    
                    for operation in operations {
                        switch operation {
                        case .optimize:
                            processedImage = try await self.optimizeImage(processedImage)
                        case .resize(let maxDimension):
                            processedImage = await self.resizeImage(processedImage, maxDimension: maxDimension)
                        case .filter(let filterName):
                            processedImage = try await self.applyFilter(to: processedImage, filterName: filterName)
                        case .autoEnhance:
                            processedImage = try await self.autoEnhanceImage(processedImage)
                        }
                    }
                    
                    return (index, processedImage)
                }
            }
            
            var results: [(Int, UIImage)] = []
            for try await result in group {
                results.append(result)
            }
            
            // 元の順序を保持
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    // MARK: - Media Validation
    
    /// 画像を検証
    func validateImage(_ image: UIImage) -> ImageValidationResult {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var warnings: [String] = []
        var isValid = true
        
        // サイズチェック
        if max(size.width, size.height) > 4000 {
            warnings.append("画像サイズが大きすぎます（推奨: 最大4000px）")
        }
        
        // アスペクト比チェック
        if aspectRatio > 3.0 || aspectRatio < 0.33 {
            warnings.append("アスペクト比が極端です")
        }
        
        // データサイズチェック
        if let data = image.jpegData(compressionQuality: 1.0),
           data.count > 10 * 1024 * 1024 { // 10MB
            warnings.append("ファイルサイズが大きすぎます")
            isValid = false
        }
        
        return ImageValidationResult(
            isValid: isValid,
            warnings: warnings,
            recommendedActions: generateRecommendations(for: warnings)
        )
    }
    
    /// 動画を検証
    func validateVideo(at url: URL) async -> VideoValidationResult {
        let asset = AVAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            
            var warnings: [String] = []
            var isValid = true
            
            // 長さチェック
            if duration.seconds > 300 { // 5分
                warnings.append("動画が長すぎます（推奨: 最大5分）")
            }
            
            // 解像度チェック
            if let videoTrack = tracks.first {
                let size = try await videoTrack.load(.naturalSize)
                if max(size.width, size.height) > 1920 {
                    warnings.append("解像度が高すぎます（推奨: 最大1920px）")
                }
            }
            
            // ファイルサイズチェック
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            if fileSize > 100 * 1024 * 1024 { // 100MB
                warnings.append("ファイルサイズが大きすぎます")
                isValid = false
            }
            
            return VideoValidationResult(
                isValid: isValid,
                warnings: warnings,
                duration: duration.seconds,
                fileSize: fileSize,
                recommendedActions: generateRecommendations(for: warnings)
            )
            
        } catch {
            return VideoValidationResult(
                isValid: false,
                warnings: ["動画の解析に失敗しました"],
                duration: 0,
                fileSize: 0,
                recommendedActions: ["有効な動画ファイルを選択してください"]
            )
        }
    }
    
    // MARK: - Progress Management
    
    private func updateProgress(_ taskId: String, progress: Double) {
        processingProgress[taskId] = progress
        
        // 全体の処理状況を更新
        let hasActiveProcessing = processingProgress.values.contains { $0 < 1.0 }
        isProcessing = hasActiveProcessing
        
        // 完了したタスクを削除
        if progress >= 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.processingProgress.removeValue(forKey: taskId)
            }
        }
    }
    
    func cancelProcessing(_ taskId: String) {
        processingTasks[taskId]?.cancel()
        processingTasks.removeValue(forKey: taskId)
        processingProgress.removeValue(forKey: taskId)
    }
    
    func cancelAllProcessing() {
        for (_, task) in processingTasks {
            task.cancel()
        }
        processingTasks.removeAll()
        processingProgress.removeAll()
        isProcessing = false
    }
    
    // MARK: - Utilities
    
    private func generateRecommendations(for warnings: [String]) -> [String] {
        var recommendations: [String] = []
        
        for warning in warnings {
            switch warning {
            case let w where w.contains("サイズが大きすぎます"):
                recommendations.append("画像を圧縮してください")
            case let w where w.contains("解像度が高すぎます"):
                recommendations.append("解像度を下げてください")
            case let w where w.contains("長すぎます"):
                recommendations.append("動画を短く編集してください")
            case let w where w.contains("アスペクト比"):
                recommendations.append("適切なアスペクト比に調整してください")
            default:
                recommendations.append("メディアファイルを最適化してください")
            }
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

enum ImageOperation {
    case optimize
    case resize(maxDimension: CGFloat)
    case filter(String)
    case autoEnhance
}

struct ImageValidationResult {
    let isValid: Bool
    let warnings: [String]
    let recommendedActions: [String]
}

struct VideoValidationResult {
    let isValid: Bool
    let warnings: [String]
    let duration: Double
    let fileSize: Int64
    let recommendedActions: [String]
}

enum MediaProcessingError: Error, LocalizedError {
    case imageProcessingFailed
    case videoExportFailed
    case filterApplicationFailed
    case exportSessionCreationFailed
    case processingCancelled
    case invalidInput
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "画像の処理に失敗しました"
        case .videoExportFailed:
            return "動画のエクスポートに失敗しました"
        case .filterApplicationFailed:
            return "フィルターの適用に失敗しました"
        case .exportSessionCreationFailed:
            return "エクスポートセッションの作成に失敗しました"
        case .processingCancelled:
            return "処理がキャンセルされました"
        case .invalidInput:
            return "無効な入力です"
        }
    }
}