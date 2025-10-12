import Foundation
import CoreLocation
import CryptoKit
import Combine

/// 位置情報プライバシー管理サービス
@MainActor
class LocationPrivacyService: ObservableObject {
    @Published var privacySettings: PrivacySettings
    @Published var isEmergencyMode = false
    
    private let userDefaults = UserDefaults.standard
    private let privacyKey = "LocationPrivacySettings"
    
    init(privacySettings: PrivacySettings = UserProfile.defaultPrivacySettings()) {
        self.privacySettings = privacySettings
        self.privacySettings = loadPrivacySettings() ?? privacySettings
    }
    
    // MARK: - プライバシー設定の管理
    
    /// プライバシー設定を保存
    func savePrivacySettings() {
        do {
            let data = try JSONEncoder().encode(privacySettings)
            userDefaults.set(data, forKey: privacyKey)
        } catch {
            print("プライバシー設定の保存エラー: \(error)")
        }
    }
    
    /// プライバシー設定を読み込み
    private func loadPrivacySettings() -> PrivacySettings? {
        guard let data = userDefaults.data(forKey: privacyKey) else { return nil }
        
        do {
            return try JSONDecoder().decode(PrivacySettings.self, from: data)
        } catch {
            print("プライバシー設定の読み込みエラー: \(error)")
            return nil
        }
    }
    
    /// 位置情報精度を更新
    func updateLocationPrecision(_ precision: LocationPrecision) {
        privacySettings = PrivacySettings(
            locationSharing: privacySettings.locationSharing,
            locationPrecision: precision.rawValue,
            profileVisibility: privacySettings.profileVisibility,
            emergencyOverride: privacySettings.emergencyOverride
        )
        savePrivacySettings()
    }

    /// 位置情報共有設定を更新
    func updateLocationSharing(_ enabled: Bool) {
        privacySettings = PrivacySettings(
            locationSharing: enabled,
            locationPrecision: privacySettings.locationPrecision,
            profileVisibility: privacySettings.profileVisibility,
            emergencyOverride: privacySettings.emergencyOverride
        )
        savePrivacySettings()
    }
    
    // MARK: - 位置情報の加工
    
    /// プライバシー設定に基づいて位置情報を加工
    func processLocation(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard privacySettings.locationSharing else {
            // 位置情報共有が無効の場合はデフォルト位置を返す
            return CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503) // 東京駅
        }

        // 緊急モードの場合は正確な位置を返す
        if isEmergencyMode && privacySettings.emergencyOverride {
            return coordinate
        }

        switch privacySettings.locationPrecision {
        case "exact":
            return coordinate
        case "approximate":
            return addNoise(to: coordinate, radius: 100) // 100m以内のノイズ
        case "area_only":
            return roundToArea(location: coordinate, gridSize: 1000) // 1km四方に丸める
        default:
            return addNoise(to: coordinate, radius: 100) // デフォルトはapproximate
        }
    }
    
    /// 位置情報にノイズを追加
    private func addNoise(to location: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
        let randomAngle = Double.random(in: 0...(2 * .pi))
        let randomDistance = Double.random(in: 0...radius)
        
        let deltaLat = randomDistance * cos(randomAngle) / 111000
        let deltaLng = randomDistance * sin(randomAngle) / (111000 * cos(location.latitude * .pi / 180))
        
        return CLLocationCoordinate2D(
            latitude: location.latitude + deltaLat,
            longitude: location.longitude + deltaLng
        )
    }
    
    /// 位置情報を指定されたグリッドサイズに丸める
    private func roundToArea(location: CLLocationCoordinate2D, gridSize: Double) -> CLLocationCoordinate2D {
        let gridSizeDegrees = gridSize / 111000 // 約1度 = 111km
        
        let roundedLat = round(location.latitude / gridSizeDegrees) * gridSizeDegrees
        let roundedLng = round(location.longitude / gridSizeDegrees) * gridSizeDegrees
        
        return CLLocationCoordinate2D(latitude: roundedLat, longitude: roundedLng)
    }
    
    // MARK: - 位置情報の暗号化
    
    /// 位置情報を暗号化
    func encryptLocation(latitude: Double, longitude: Double) throws -> Data {
        let locationData = LocationData(
            latitude: latitude,
            longitude: longitude,
            accuracy: 0,
            timestamp: Date(),
            source: .manual
        )
        
        let jsonData = try JSONEncoder().encode(locationData)
        let key = getEncryptionKey()
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        
        return sealedBox.combined!
    }
    
    /// 暗号化された位置情報を復号化
    func decryptLocation(encryptedData: Data) throws -> (latitude: Double, longitude: Double) {
        let key = getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        let locationData = try JSONDecoder().decode(LocationData.self, from: decryptedData)
        return (locationData.latitude, locationData.longitude)
    }
    
    /// 暗号化キーを取得（実際の実装ではKeychainに保存）
    private func getEncryptionKey() -> SymmetricKey {
        // 注意: 実際の実装ではKeychainから安全に取得する
        let keyData = "LocationEncryptionKey2025".data(using: .utf8)!
        return SymmetricKey(data: SHA256.hash(data: keyData))
    }
    
    // MARK: - 緊急モード
    
    /// 緊急モードを有効化
    func activateEmergencyMode() {
        isEmergencyMode = true
        
        // 緊急モード時は一時的に位置情報の精度を最高に設定
        if privacySettings.emergencyOverride {
            updateLocationPrecision(.exact)
        }
        
        print("緊急モードが有効化されました")
    }
    
    /// 緊急モードを無効化
    func deactivateEmergencyMode() {
        isEmergencyMode = false
        
        // 通常のプライバシー設定に戻す
        // Note: ユーザーの元の設定を復元する実装が必要
        
        print("緊急モードが無効化されました")
    }
    
    // MARK: - データ保持管理

    /// 古い位置データを削除
    func cleanupOldLocationData() async {
        // データ保持設定はPrivacySettingsから削除されたため、デフォルト30日で実装
        let retentionDays = 30
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()

        // 実際の実装では、データベースから古いレコードを削除
        print("位置データのクリーンアップ: \(cutoffDate)以前のデータを削除")
    }

    /// 位置履歴を削除
    func deleteLocationHistory() async {
        // 実際の実装では、すべての位置履歴を削除
        print("位置履歴を削除しました")
    }
    
    // MARK: - プライバシー分析
    
    /// 位置情報の露出度を分析
    func analyzeLocationExposure(for posts: [Post]) -> LocationExposureAnalysis {
        let exactLocationPosts = posts.filter { post in
            // 実際の実装では、投稿時の精度設定を確認
            return true // プレースホルダー
        }
        
        let approximateLocationPosts = posts.filter { post in
            // 実際の実装では、投稿時の精度設定を確認
            return true // プレースホルダー
        }
        
        return LocationExposureAnalysis(
            totalPosts: posts.count,
            exactLocationPosts: exactLocationPosts.count,
            approximateLocationPosts: approximateLocationPosts.count,
            areaOnlyPosts: posts.count - exactLocationPosts.count - approximateLocationPosts.count,
            exposureScore: calculateExposureScore(posts: posts)
        )
    }
    
    /// 露出度スコアを計算
    private func calculateExposureScore(posts: [Post]) -> Double {
        // 実際の実装では、投稿の頻度、精度、時間的パターンを分析
        return Double.random(in: 0...100) // プレースホルダー
    }
}

// MARK: - Supporting Types

/// 位置情報露出度分析結果
struct LocationExposureAnalysis {
    let totalPosts: Int
    let exactLocationPosts: Int
    let approximateLocationPosts: Int
    let areaOnlyPosts: Int
    let exposureScore: Double // 0-100のスコア
    
    /// 露出度レベル
    var exposureLevel: ExposureLevel {
        switch exposureScore {
        case 0..<30:
            return .low
        case 30..<70:
            return .medium
        default:
            return .high
        }
    }
}

/// 露出度レベル
enum ExposureLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "プライバシーが適切に保護されています"
        case .medium: return "一部の情報が推測される可能性があります"
        case .high: return "位置情報の露出度が高い状態です"
        }
    }
}