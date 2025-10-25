import Foundation
import UserNotifications
import CoreLocation
import Combine

// MARK: - 通知管理・スケジューリングマネージャー

@MainActor
class NotificationManager: ObservableObject {
    @Published var notificationSettings: NotificationSettings = .default
    @Published var isNotificationEnabled = true
    @Published var scheduledNotifications: [ScheduledNotification] = []
    
    private let pushNotificationService: PushNotificationService
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    
    // 通知タイプ別の設定
    private var notificationTypes: [NotificationType: Bool] = [:]
    
    init(
        pushNotificationService: PushNotificationService,
        locationService: LocationService
    ) {
        self.pushNotificationService = pushNotificationService
        self.locationService = locationService
        
        loadNotificationSettings()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // 位置情報の変更を監視
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
        
        // プッシュ通知サービスの状態変更を監視
        pushNotificationService.$isAuthorized
            .sink { [weak self] isAuthorized in
                self?.isNotificationEnabled = isAuthorized
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Sending
    
    /// 新しい投稿の通知
    func sendNewPostNotification(
        post: Post,
        distance: Double
    ) {
        guard isNotificationEnabled,
              notificationSettings.enablePostNotifications,
              distance <= notificationSettings.postNotificationRadius else { return }
        
        let title = "新しい投稿"
        let body = "\(post.user.displayName ?? post.user.username)さんが近くに投稿しました"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "new_post",
            "post_id": post.id.uuidString,
            "user_id": post.user.id.uuidString,
            "distance": distance
        ]
        
        pushNotificationService.sendLocalNotification(
            title: title,
            body: body,
            category: "POST_CATEGORY",
            userInfo: userInfo
        )
    }
    
    /// 緊急事態の通知
    func sendEmergencyNotification(
        event: EmergencyEvent,
        distance: Double
    ) {
        guard isNotificationEnabled,
              notificationSettings.enableEmergencyNotifications else { return }
        
        let title = "⚠️ 緊急事態発生"
        let body = "\(event.eventType.displayName)が発生しています（\(String(format: "%.1f", distance/1000))km先）"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "emergency",
            "event_id": event.id.uuidString,
            "event_type": event.eventType.rawValue,
            "distance": distance
        ]
        
        // 緊急度に応じてクリティカルアラートを使用
        if event.severity == .critical {
            pushNotificationService.sendCriticalAlert(
                title: title,
                body: body,
                userInfo: userInfo
            )
        } else {
            pushNotificationService.sendLocalNotification(
                title: title,
                body: body,
                category: "EMERGENCY_CATEGORY",
                userInfo: userInfo,
                sound: .defaultCritical
            )
        }
    }
    
    /// 位置情報共有の通知
    func sendLocationSharingNotification(
        fromUser: UserProfile,
        location: CLLocationCoordinate2D
    ) {
        guard isNotificationEnabled,
              notificationSettings.enableLocationNotifications else { return }
        
        let title = "位置情報が共有されました"
        let body = "\(fromUser.displayName ?? fromUser.username)さんが位置情報を共有しました"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "location_sharing",
            "user_id": fromUser.id.uuidString,
            "latitude": location.latitude,
            "longitude": location.longitude
        ]
        
        pushNotificationService.sendLocalNotification(
            title: title,
            body: body,
            category: "LOCATION_CATEGORY",
            userInfo: userInfo
        )
    }
    
    /// いいねの通知
    func sendLikeNotification(
        post: Post,
        likedByUser: UserProfile
    ) {
        guard isNotificationEnabled,
              notificationSettings.enableLikeNotifications else { return }
        
        let title = "いいね！"
        let body = "\(likedByUser.displayName ?? likedByUser.username)さんがあなたの投稿にいいねしました"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "like",
            "post_id": post.id.uuidString,
            "user_id": likedByUser.id.uuidString
        ]
        
        pushNotificationService.sendLocalNotification(
            title: title,
            body: body,
            category: "POST_CATEGORY",
            userInfo: userInfo
        )
    }
    
    /// コメントの通知
    func sendCommentNotification(
        post: Post,
        comment: String,
        commentedByUser: UserProfile
    ) {
        guard isNotificationEnabled,
              notificationSettings.enableCommentNotifications else { return }
        
        let title = "新しいコメント"
        let body = "\(commentedByUser.displayName ?? commentedByUser.username)さんがコメントしました"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "comment",
            "post_id": post.id.uuidString,
            "user_id": commentedByUser.id.uuidString,
            "comment": comment
        ]
        
        pushNotificationService.sendLocalNotification(
            title: title,
            body: body,
            category: "POST_CATEGORY",
            userInfo: userInfo
        )
    }
    
    // MARK: - Scheduled Notifications
    
    /// 定期通知をスケジュール
    func schedulePeriodicNotification(
        title: String,
        body: String,
        interval: TimeInterval,
        repeats: Bool = true
    ) {
        let scheduledNotification = ScheduledNotification(
            id: UUID().uuidString,
            title: title,
            body: body,
            scheduledTime: Date().addingTimeInterval(interval),
            repeats: repeats,
            interval: interval
        )
        
        scheduledNotifications.append(scheduledNotification)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: repeats
        )
        
        let request = UNNotificationRequest(
            identifier: scheduledNotification.id,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
            }
        }
    }
    
    /// 位置ベース通知をスケジュール
    func scheduleLocationBasedNotification(
        title: String,
        body: String,
        region: CLCircularRegion,
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = false
    ) {
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNLocationNotificationTrigger(
            region: region,
            repeats: false
        )
        
        let identifier = "location_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
            }
        }
    }
    
    /// スケジュール済み通知をキャンセル
    func cancelScheduledNotification(_ notificationID: String) {
        scheduledNotifications.removeAll { $0.id == notificationID }
        pushNotificationService.cancelNotification(identifier: notificationID)
    }
    
    // MARK: - Location Updates
    
    private func handleLocationUpdate(_ location: CLLocation) {
        // 位置情報の変更に基づく通知処理
        checkNearbyEmergencies(location: location)
        checkLocationBasedReminders(location: location)
    }
    
    private func checkNearbyEmergencies(location: CLLocation) {
        // TODO: 近くの緊急事態をチェック
        // EmergencyServiceから緊急事態を取得し、距離をチェック
    }
    
    private func checkLocationBasedReminders(location: CLLocation) {
        // TODO: 位置ベースのリマインダーをチェック
    }
    
    // MARK: - Settings Management
    
    func updateNotificationSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        saveNotificationSettings()
    }
    
    func toggleNotificationType(_ type: NotificationType, enabled: Bool) {
        notificationTypes[type] = enabled
        
        switch type {
        case .post:
            notificationSettings.enablePostNotifications = enabled
        case .emergency:
            notificationSettings.enableEmergencyNotifications = enabled
        case .location:
            notificationSettings.enableLocationNotifications = enabled
        case .like:
            notificationSettings.enableLikeNotifications = enabled
        case .comment:
            notificationSettings.enableCommentNotifications = enabled
        }
        
        saveNotificationSettings()
    }
    
    private func loadNotificationSettings() {
        if let data = UserDefaults.standard.data(forKey: "NotificationSettings"),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            notificationSettings = settings
        }
    }
    
    private func saveNotificationSettings() {
        if let data = try? JSONEncoder().encode(notificationSettings) {
            UserDefaults.standard.set(data, forKey: "NotificationSettings")
        }
    }
    
    // MARK: - Quiet Hours
    
    /// サイレント時間中かチェック
    private func isInQuietHours() -> Bool {
        guard notificationSettings.enableQuietHours else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        let startHour = calendar.component(.hour, from: notificationSettings.quietHoursStart)
        let endHour = calendar.component(.hour, from: notificationSettings.quietHoursEnd)
        
        if startHour < endHour {
            return currentHour >= startHour && currentHour < endHour
        } else {
            return currentHour >= startHour || currentHour < endHour
        }
    }
    
    /// 通知送信前のフィルタリング
    private func shouldSendNotification(type: NotificationType) -> Bool {
        guard isNotificationEnabled else { return false }
        
        // サイレント時間中は緊急通知のみ
        if isInQuietHours() && type != .emergency {
            return false
        }
        
        // 通知タイプ別の設定をチェック
        return notificationTypes[type] ?? true
    }
    
    // MARK: - Analytics
    
    /// 通知の統計情報を取得
    func getNotificationAnalytics() -> NotificationAnalytics {
        let totalSent = scheduledNotifications.count
        let delivered = scheduledNotifications.filter { $0.isDelivered }.count
        let opened = scheduledNotifications.filter { $0.isOpened }.count
        
        return NotificationAnalytics(
            totalSent: totalSent,
            delivered: delivered,
            opened: opened,
            openRate: delivered > 0 ? Double(opened) / Double(delivered) : 0
        )
    }
}

// MARK: - Supporting Types

struct NotificationSettings: Codable {
    var enablePostNotifications = true
    var enableEmergencyNotifications = true
    var enableLocationNotifications = true
    var enableLikeNotifications = true
    var enableCommentNotifications = true
    
    var postNotificationRadius: Double = 5000 // 5km
    var emergencyNotificationRadius: Double = 10000 // 10km
    
    var enableQuietHours = false
    var quietHoursStart = Date()
    var quietHoursEnd = Date()
    
    var enableVibration = true
    var enableSound = true
    
    static let `default` = NotificationSettings()
}

enum NotificationType {
    case post
    case emergency
    case location
    case like
    case comment
}

struct ScheduledNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let scheduledTime: Date
    let repeats: Bool
    let interval: TimeInterval?
    var isDelivered = false
    var isOpened = false
}

struct NotificationAnalytics {
    let totalSent: Int
    let delivered: Int
    let opened: Int
    let openRate: Double
}