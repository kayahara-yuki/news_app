import Foundation
import UserNotifications
import UIKit
import Combine

// MARK: - APNsプッシュ通知サービス

@MainActor
class PushNotificationService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: Data?
    @Published var notificationSettings: UNNotificationSettings?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // 通知カテゴリー
    private let emergencyCategory = "EMERGENCY_CATEGORY"
    private let postCategory = "POST_CATEGORY"
    private let locationCategory = "LOCATION_CATEGORY"
    
    override init() {
        super.init()
        setupNotificationCategories()
        checkAuthorizationStatus()
        notificationCenter.delegate = self
    }
    
    // MARK: - Authorization
    
    /// プッシュ通知の許可を要求
    func requestAuthorization() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .provisional, .criticalAlert]
            )
            
            await MainActor.run {
                self.isAuthorized = granted
                self.authorizationStatus = granted ? .authorized : .denied
            }
            
            if granted {
                await registerForRemoteNotifications()
                await updateNotificationSettings()
            }
            
        } catch {
            print("通知許可要求エラー: \(error)")
        }
    }
    
    /// リモート通知の登録
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }
    
    /// 現在の認証状態を確認
    func checkAuthorizationStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            await MainActor.run {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized || 
                                  settings.authorizationStatus == .provisional
                self.notificationSettings = settings
            }
        }
    }
    
    private func updateNotificationSettings() async {
        let settings = await notificationCenter.notificationSettings()
        await MainActor.run {
            self.notificationSettings = settings
        }
    }
    
    // MARK: - Device Token Management
    
    /// デバイストークンを設定
    func setDeviceToken(_ token: Data) {
        deviceToken = token
        
        // サーバーにデバイストークンを送信
        Task {
            await uploadDeviceToken(token)
        }
    }
    
    /// デバイストークン登録失敗
    func handleRegistrationError(_ error: Error) {
        print("デバイストークン登録エラー: \(error)")
    }
    
    private func uploadDeviceToken(_ token: Data) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        // TODO: Supabaseにデバイストークンを送信
        print("デバイストークンをサーバーに送信: \(tokenString)")
        
        // 実際の実装ではSupabaseのユーザープロフィールテーブルに保存
        /*
        do {
            try await supabase
                .from("user_profiles")
                .update(["device_token": tokenString])
                .eq("id", getCurrentUserID())
                .execute()
        } catch {
            print("デバイストークン送信エラー: \(error)")
        }
        */
    }
    
    // MARK: - Local Notifications
    
    /// ローカル通知を送信
    func sendLocalNotification(
        title: String,
        body: String,
        category: String = "",
        userInfo: [AnyHashable: Any] = [:],
        delay: TimeInterval = 0,
        sound: UNNotificationSound = .default
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.userInfo = userInfo
        
        if !category.isEmpty {
            content.categoryIdentifier = category
        }
        
        // バッジ数を増加
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        let trigger: UNNotificationTrigger
        if delay > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        }
        
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("ローカル通知送信エラー: \(error)")
            }
        }
    }
    
    /// 緊急通知を送信（クリティカルアラート）
    func sendCriticalAlert(
        title: String,
        body: String,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = emergencyCategory
        content.userInfo = userInfo
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // クリティカルアラート音
        content.sound = UNNotificationSound.defaultCritical
        content.interruptionLevel = .critical
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let identifier = "emergency_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("緊急通知送信エラー: \(error)")
            }
        }
    }
    
    // MARK: - Notification Categories
    
    private func setupNotificationCategories() {
        // 緊急通知カテゴリー
        let emergencyActions = [
            UNNotificationAction(
                identifier: "VIEW_EMERGENCY",
                title: "詳細を見る",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "SHARE_LOCATION",
                title: "位置情報を共有",
                options: [.authenticationRequired]
            )
        ]
        
        let emergencyCategory = UNNotificationCategory(
            identifier: self.emergencyCategory,
            actions: emergencyActions,
            intentIdentifiers: [],
            options: [] // .criticalAlert is deprecated
        )
        
        // 投稿通知カテゴリー
        let postActions = [
            UNNotificationAction(
                identifier: "LIKE_POST",
                title: "いいね",
                options: []
            ),
            UNNotificationAction(
                identifier: "VIEW_POST",
                title: "見る",
                options: [.foreground]
            )
        ]
        
        let postCategory = UNNotificationCategory(
            identifier: self.postCategory,
            actions: postActions,
            intentIdentifiers: [],
            options: []
        )
        
        // 位置情報通知カテゴリー
        let locationActions = [
            UNNotificationAction(
                identifier: "VIEW_LOCATION",
                title: "地図で見る",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "SHARE_MY_LOCATION",
                title: "自分の位置を共有",
                options: [.authenticationRequired]
            )
        ]
        
        let locationCategory = UNNotificationCategory(
            identifier: self.locationCategory,
            actions: locationActions,
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            emergencyCategory,
            postCategory,
            locationCategory
        ])
    }
    
    // MARK: - Badge Management
    
    /// バッジ数をクリア
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    /// バッジ数を設定
    func setBadgeCount(_ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }
    
    // MARK: - Notification Management
    
    /// 保留中の通知を取得
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    /// 配信済み通知を取得
    func getDeliveredNotifications() async -> [UNNotification] {
        return await notificationCenter.deliveredNotifications()
    }
    
    /// 特定の通知をキャンセル
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// すべての保留中通知をキャンセル
    func cancelAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    /// 配信済み通知をクリア
    func clearDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    
    /// 通知が表示される前に呼ばれる
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // アプリがフォアグラウンドでも通知を表示
        completionHandler([.banner, .badge, .sound])
    }
    
    /// 通知をタップしたときに呼ばれる
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // アクションに応じて処理
        switch actionIdentifier {
        case "VIEW_EMERGENCY":
            handleEmergencyView(userInfo: userInfo)
        case "SHARE_LOCATION":
            handleLocationSharing(userInfo: userInfo)
        case "LIKE_POST":
            handlePostLike(userInfo: userInfo)
        case "VIEW_POST":
            handlePostView(userInfo: userInfo)
        case "VIEW_LOCATION":
            handleLocationView(userInfo: userInfo)
        case "SHARE_MY_LOCATION":
            handleMyLocationSharing(userInfo: userInfo)
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - Action Handlers
    
    private func handleEmergencyView(userInfo: [AnyHashable: Any]) {
        // 緊急情報の詳細画面に遷移
        NotificationCenter.default.post(
            name: .showEmergencyDetails,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handleLocationSharing(userInfo: [AnyHashable: Any]) {
        // 位置情報共有の開始
        NotificationCenter.default.post(
            name: .startLocationSharing,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handlePostLike(userInfo: [AnyHashable: Any]) {
        // 投稿にいいね
        if let postID = userInfo["post_id"] as? String {
            NotificationCenter.default.post(
                name: .likePostFromNotification,
                object: nil,
                userInfo: ["post_id": postID]
            )
        }
    }
    
    private func handlePostView(userInfo: [AnyHashable: Any]) {
        // 投稿詳細画面に遷移
        NotificationCenter.default.post(
            name: .showPostDetails,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handleLocationView(userInfo: [AnyHashable: Any]) {
        // 地図画面に遷移
        NotificationCenter.default.post(
            name: .showLocationOnMap,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handleMyLocationSharing(userInfo: [AnyHashable: Any]) {
        // 自分の位置情報を共有
        NotificationCenter.default.post(
            name: .shareMyLocation,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        // デフォルトアクション（通知タップ）
        NotificationCenter.default.post(
            name: .notificationTapped,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showEmergencyDetails = Notification.Name("showEmergencyDetails")
    static let startLocationSharing = Notification.Name("startLocationSharing")
    static let likePostFromNotification = Notification.Name("likePostFromNotification")
    static let showPostDetails = Notification.Name("showPostDetails")
    static let showLocationOnMap = Notification.Name("showLocationOnMap")
    static let shareMyLocation = Notification.Name("shareMyLocation")
    static let notificationTapped = Notification.Name("notificationTapped")
}

// MARK: - Supporting Types

enum NotificationCategory: String, CaseIterable {
    case emergency = "EMERGENCY_CATEGORY"
    case post = "POST_CATEGORY"
    case location = "LOCATION_CATEGORY"
    
    var displayName: String {
        switch self {
        case .emergency: return "緊急通知"
        case .post: return "投稿通知"
        case .location: return "位置情報通知"
        }
    }
}