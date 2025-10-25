import Foundation
import SwiftUI
import Combine

/// アプリ全体の設定を管理するクラス
class AppConfiguration: ObservableObject {
    static let shared = AppConfiguration()
    
    // MARK: - アプリ情報
    let appName = "地図SNS"
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - 機能フラグ
    @Published var isEmergencyModeEnabled = false
    @Published var isOfflineModeEnabled = false
    @Published var isDarkModeForced = false
    
    // MARK: - アプリ設定
    @Published var maxPostsToLoad = 50
    @Published var nearbyPostsRadius: Double = 1000 // メートル
    @Published var autoRefreshInterval: TimeInterval = 30 // 秒
    
    // MARK: - デバッグ設定
    #if DEBUG
    @Published var isDebugModeEnabled = true
    @Published var showPerformanceMetrics = false
    @Published var useTestData = false
    #else
    @Published var isDebugModeEnabled = false
    @Published var showPerformanceMetrics = false
    @Published var useTestData = false
    #endif
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSettings()
    }
    
    // MARK: - 設定の保存・読み込み
    
    private func loadSettings() {
        isEmergencyModeEnabled = userDefaults.bool(forKey: "isEmergencyModeEnabled")
        isOfflineModeEnabled = userDefaults.bool(forKey: "isOfflineModeEnabled")
        isDarkModeForced = userDefaults.bool(forKey: "isDarkModeForced")
        maxPostsToLoad = userDefaults.object(forKey: "maxPostsToLoad") as? Int ?? 50
        nearbyPostsRadius = userDefaults.object(forKey: "nearbyPostsRadius") as? Double ?? 1000
        autoRefreshInterval = userDefaults.object(forKey: "autoRefreshInterval") as? TimeInterval ?? 30
    }
    
    func saveSettings() {
        userDefaults.set(isEmergencyModeEnabled, forKey: "isEmergencyModeEnabled")
        userDefaults.set(isOfflineModeEnabled, forKey: "isOfflineModeEnabled")
        userDefaults.set(isDarkModeForced, forKey: "isDarkModeForced")
        userDefaults.set(maxPostsToLoad, forKey: "maxPostsToLoad")
        userDefaults.set(nearbyPostsRadius, forKey: "nearbyPostsRadius")
        userDefaults.set(autoRefreshInterval, forKey: "autoRefreshInterval")
    }
    
    // MARK: - 緊急モード
    
    func activateEmergencyMode() {
        isEmergencyModeEnabled = true
        saveSettings()
        
        // 緊急モード時の設定調整
        autoRefreshInterval = 10 // より頻繁な更新
        nearbyPostsRadius = 5000 // より広い範囲
        
        NotificationCenter.default.post(name: .emergencyModeActivated, object: nil)
    }
    
    func deactivateEmergencyMode() {
        isEmergencyModeEnabled = false
        saveSettings()
        
        // 通常モードの設定に復帰
        autoRefreshInterval = 30
        nearbyPostsRadius = 1000
        
        NotificationCenter.default.post(name: .emergencyModeDeactivated, object: nil)
    }
    
    // MARK: - パフォーマンス設定
    
    func optimizeForLowPerformance() {
        maxPostsToLoad = 20
        autoRefreshInterval = 60
        saveSettings()
    }
    
    func optimizeForHighPerformance() {
        maxPostsToLoad = 100
        autoRefreshInterval = 15
        saveSettings()
    }
    
    // MARK: - デバッグ機能
    
    #if DEBUG
    func enableTestMode() {
        useTestData = true
        showPerformanceMetrics = true
    }

    func disableTestMode() {
        useTestData = false
        showPerformanceMetrics = false
    }
    #endif
}

// MARK: - 通知名の定義

extension Notification.Name {
    static let emergencyModeActivated = Notification.Name("emergencyModeActivated")
    static let emergencyModeDeactivated = Notification.Name("emergencyModeDeactivated")
    static let appConfigurationChanged = Notification.Name("appConfigurationChanged")

    // 投稿関連の通知
    static let newPostCreated = Notification.Name("newPostCreated")
    static let newPostReceived = Notification.Name("newPostReceived")
}

// MARK: - 環境変数

enum AppEnvironment {
    case development
    case staging
    case production
    
    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
    
    var apiBaseURL: String {
        switch self {
        case .development:
            return "https://your-project.supabase.co"
        case .staging:
            return "https://your-staging-project.supabase.co"
        case .production:
            return "https://your-production-project.supabase.co"
        }
    }
    
    var logLevel: LogLevel {
        switch self {
        case .development:
            return .debug
        case .staging:
            return .info
        case .production:
            return .error
        }
    }
}

enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

// MARK: - App Theme Configuration

struct AppTheme {
    static let primaryColor = Color.blue
    static let secondaryColor = Color.orange
    static let backgroundColor = Color(.systemBackground)
    static let surfaceColor = Color(.secondarySystemBackground)
    
    // Liquid Glass エフェクト用の色
    static let glassBackground = Color.clear
    static let glassBorder = Color.white.opacity(0.2)
    static let glassShadow = Color.black.opacity(0.1)
    
    // カテゴリ別の色
    static let newsColor = Color.orange
    static let emergencyColor = Color.red
    static let communityColor = Color.green
    static let trafficColor = Color.blue
    
    // グラデーション
    static let primaryGradient = LinearGradient(
        colors: [primaryColor, secondaryColor],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let emergencyGradient = LinearGradient(
        colors: [Color.red, Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}