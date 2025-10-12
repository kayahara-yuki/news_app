import Foundation
import UserNotifications
import CoreLocation
import Combine
import AudioToolbox
import Supabase

// MARK: - 緊急通知専用サービス

@MainActor
class EmergencyNotificationService: ObservableObject {
    @Published var activeEmergencyAlerts: [EmergencyAlert] = []
    @Published var emergencyNotificationSettings: EmergencyNotificationSettings = .default
    
    private let pushNotificationService: PushNotificationService
    private let locationService: LocationService
    private let realtimeService: RealtimeService
    
    private var cancellables = Set<AnyCancellable>()
    private var emergencyChannel: RealtimeChannel?
    
    // 緊急レベル別の設定
    private let criticalRadius: Double = 5000 // 5km
    private let warningRadius: Double = 10000 // 10km
    private let infoRadius: Double = 20000 // 20km
    
    init(
        pushNotificationService: PushNotificationService,
        locationService: LocationService,
        realtimeService: RealtimeService
    ) {
        self.pushNotificationService = pushNotificationService
        self.locationService = locationService
        self.realtimeService = realtimeService
        
        setupEmergencyChannel()
        setupBindings()
        loadSettings()
    }
    
    // MARK: - Setup
    
    private func setupEmergencyChannel() {
        emergencyChannel = realtimeService.subscribeToChannel(
            "emergency_alerts",
            table: "emergency_events"
        )
        
        // TODO: Supabase Realtime V2 APIに移行が必要
        /*
        if let channel = emergencyChannel {
            // 新しい緊急事態
            channel.onPostgresChanges(
                event: .insert,
                table: "emergency_events"
            ) { [weak self] change in
                self?.handleNewEmergencyEvent(change)
            }

            // 緊急事態の更新
            channel.onPostgresChanges(
                event: .update,
                table: "emergency_events"
            ) { [weak self] change in
                self?.handleEmergencyEventUpdate(change)
            }

            // 緊急ブロードキャスト
            channel.onBroadcast(event: "emergency_alert") { [weak self] message in
                self?.handleEmergencyBroadcast(message)
            }

            // SOSシグナル
            channel.onBroadcast(event: "sos_signal") { [weak self] message in
                self?.handleSOSSignal(message)
            }
        }
        */
    }
    
    private func setupBindings() {
        // 位置情報の変更を監視
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.checkNearbyEmergencies(userLocation: location)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Emergency Event Handling
    
    // TODO: Realtime V2 API移行後に有効化
    /*
    private func handleNewEmergencyEvent(_ change: PostgresChange) {
        guard let record = change.record,
              let emergencyEvent = decodeEmergencyEvent(from: record) else { return }
        
        // 現在位置からの距離を計算
        guard let currentLocation = locationService.currentLocation else { return }
        
        let eventLocation = CLLocation(
            latitude: emergencyEvent.affectedArea.first?.latitude ?? 0,
            longitude: emergencyEvent.affectedArea.first?.longitude ?? 0
        )
        
        let distance = currentLocation.distance(from: eventLocation)
        
        // 距離と緊急度に基づいて通知を送信
        if shouldNotifyForEmergency(event: emergencyEvent, distance: distance) {
            sendEmergencyAlert(event: emergencyEvent, distance: distance)
        }
    }
    


    private func handleEmergencyEventUpdate(_ change: PostgresChange) {
        guard let record = change.record,
              let updatedEvent = decodeEmergencyEvent(from: record) else { return }

        // TODO: EmergencyStatusに.resolvedを追加後に有効化
        // ステータスが解決済みに変わった場合は通知を送信
        if updatedEvent.status == .resolved {
            sendEmergencyResolvedNotification(event: updatedEvent)
        }
    }
    */
    
    private func handleEmergencyBroadcast(_ message: [String: Any]) {
        guard let payload = message["payload"] as? [String: Any] else { return }
        
        let alert = EmergencyAlert(
            id: UUID(),
            type: payload["type"] as? String ?? "unknown",
            title: payload["title"] as? String ?? "緊急事態",
            message: payload["message"] as? String ?? "",
            severity: EmergencySeverity(rawValue: payload["severity"] as? String ?? "warning") ?? .warning,
            location: extractLocation(from: payload),
            timestamp: Date(),
            isRead: false
        )
        
        activeEmergencyAlerts.insert(alert, at: 0)
        
        // 即座に緊急通知を送信
        sendImmediateEmergencyAlert(alert: alert)
    }
    
    private func handleSOSSignal(_ message: [String: Any]) {
        guard let payload = message["payload"] as? [String: Any],
              let userID = payload["user_id"] as? String,
              let latitude = payload["latitude"] as? Double,
              let longitude = payload["longitude"] as? Double else { return }
        
        let sosAlert = EmergencyAlert(
            id: UUID(),
            type: "sos",
            title: "SOS信号",
            message: "近くでSOS信号が発信されました",
            severity: .critical,
            location: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            timestamp: Date(),
            isRead: false,
            sourceUserID: UUID(uuidString: userID)
        )
        
        activeEmergencyAlerts.insert(sosAlert, at: 0)
        
        // 最高優先度で通知
        sendSOSAlert(alert: sosAlert)
    }
    
    // MARK: - Notification Sending
    
    private func sendEmergencyAlert(event: EmergencyEvent, distance: Double) {
        let title = getEmergencyTitle(for: event.eventType, severity: event.severity)
        let body = getEmergencyBody(for: event, distance: distance)
        
        let userInfo: [AnyHashable: Any] = [
            "type": "emergency_event",
            "event_id": event.id.uuidString,
            "event_type": event.eventType.rawValue,
            "severity": event.severity.rawValue,
            "distance": distance
        ]
        
        // 緊急度に応じて通知レベルを調整
        switch event.severity {
        case .critical:
            pushNotificationService.sendCriticalAlert(
                title: title,
                body: body,
                userInfo: userInfo
            )
        case .warning:
            pushNotificationService.sendLocalNotification(
                title: title,
                body: body,
                category: "EMERGENCY_CATEGORY",
                userInfo: userInfo,
                sound: .defaultCritical
            )
        case .info:
            pushNotificationService.sendLocalNotification(
                title: title,
                body: body,
                category: "EMERGENCY_CATEGORY",
                userInfo: userInfo
            )
        }
        
        // バイブレーション（緊急度に応じて）
        if event.severity == .critical {
            triggerEmergencyVibration()
        }
    }
    
    private func sendImmediateEmergencyAlert(alert: EmergencyAlert) {
        let userInfo: [AnyHashable: Any] = [
            "type": "emergency_alert",
            "alert_id": alert.id.uuidString,
            "alert_type": alert.type,
            "severity": alert.severity.rawValue
        ]
        
        switch alert.severity {
        case .critical:
            pushNotificationService.sendCriticalAlert(
                title: alert.title,
                body: alert.message,
                userInfo: userInfo
            )
        case .warning:
            pushNotificationService.sendLocalNotification(
                title: alert.title,
                body: alert.message,
                category: "EMERGENCY_CATEGORY",
                userInfo: userInfo,
                sound: .defaultCritical
            )
        case .info:
            pushNotificationService.sendLocalNotification(
                title: alert.title,
                body: alert.message,
                category: "EMERGENCY_CATEGORY",
                userInfo: userInfo
            )
        }
    }
    
    private func sendSOSAlert(alert: EmergencyAlert) {
        let title = "🆘 SOS信号"
        let body = "近くでSOS信号が発信されました。緊急事態の可能性があります。"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "sos_signal",
            "alert_id": alert.id.uuidString,
            "source_user_id": alert.sourceUserID?.uuidString ?? "",
            "latitude": alert.location?.latitude ?? 0,
            "longitude": alert.location?.longitude ?? 0
        ]
        
        // 最高優先度のクリティカルアラート
        pushNotificationService.sendCriticalAlert(
            title: title,
            body: body,
            userInfo: userInfo
        )
        
        // 連続バイブレーション
        triggerSOSVibration()
    }
    
    private func sendEmergencyResolvedNotification(event: EmergencyEvent) {
        let title = "緊急事態解決"
        let body = "\(event.eventType.displayName)の緊急事態が解決されました"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "emergency_resolved",
            "event_id": event.id.uuidString,
            "event_type": event.eventType.rawValue
        ]
        
        pushNotificationService.sendLocalNotification(
            title: title,
            body: body,
            category: "EMERGENCY_CATEGORY",
            userInfo: userInfo
        )
    }
    
    // MARK: - Location-based Monitoring
    
    private func checkNearbyEmergencies(userLocation: CLLocation) {
        // アクティブなアラートの距離を再計算
        for alert in activeEmergencyAlerts {
            guard let alertLocation = alert.location else { continue }
            
            let alertCLLocation = CLLocation(
                latitude: alertLocation.latitude,
                longitude: alertLocation.longitude
            )
            
            let distance = userLocation.distance(from: alertCLLocation)
            
            // 警戒範囲に入った場合の追加通知
            if distance <= getAlertRadius(for: alert.severity) && !alert.isRead {
                sendProximityAlert(for: alert, distance: distance)
            }
        }
    }
    
    private func sendProximityAlert(for alert: EmergencyAlert, distance: Double) {
        let title = "⚠️ 緊急事態に接近"
        let body = "緊急事態の現場に近づいています（\(String(format: "%.0f", distance))m先）"
        
        let userInfo: [AnyHashable: Any] = [
            "type": "proximity_alert",
            "alert_id": alert.id.uuidString,
            "distance": distance
        ]
        
        pushNotificationService.sendLocalNotification(
            title: title,
            body: body,
            category: "EMERGENCY_CATEGORY",
            userInfo: userInfo,
            sound: .defaultCritical
        )
    }
    
    // MARK: - Settings and Utilities
    
    private func shouldNotifyForEmergency(event: EmergencyEvent, distance: Double) -> Bool {
        let maxRadius = getAlertRadius(for: event.severity)
        
        // 距離チェック
        guard distance <= maxRadius else { return false }
        
        // 設定チェック
        switch event.severity {
        case .critical:
            return emergencyNotificationSettings.enableCriticalAlerts
        case .warning:
            return emergencyNotificationSettings.enableWarningAlerts
        case .info:
            return emergencyNotificationSettings.enableInfoAlerts
        }
    }
    
    private func getAlertRadius(for severity: EmergencySeverity) -> Double {
        switch severity {
        case .critical: return criticalRadius
        case .warning: return warningRadius
        case .info: return infoRadius
        }
    }
    
    private func getEmergencyTitle(for type: EmergencyEventType, severity: EmergencySeverity) -> String {
        let prefix = severity == .critical ? "🚨" : "⚠️"
        return "\(prefix) \(type.displayName)"
    }
    
    private func getEmergencyBody(for event: EmergencyEvent, distance: Double) -> String {
        let distanceText = distance < 1000 ? 
            "\(Int(distance))m先" : 
            "\(String(format: "%.1f", distance/1000))km先"
        
        return "\(event.description)（\(distanceText)）"
    }
    
    // MARK: - Vibration

    private func triggerEmergencyVibration() {
        // 緊急用の特別なバイブレーションパターン
        // 長いバイブレーション → 短い休止 → 長いバイブレーション
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    private func triggerSOSVibration() {
        // SOS用の連続バイブレーション
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
    
    // MARK: - Data Management
    
    func markAlertAsRead(_ alertID: UUID) {
        if let index = activeEmergencyAlerts.firstIndex(where: { $0.id == alertID }) {
            activeEmergencyAlerts[index].isRead = true
        }
    }
    
    func clearOldAlerts() {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        activeEmergencyAlerts.removeAll { $0.timestamp < cutoffDate }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "EmergencyNotificationSettings"),
           let settings = try? JSONDecoder().decode(EmergencyNotificationSettings.self, from: data) {
            emergencyNotificationSettings = settings
        }
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(emergencyNotificationSettings) {
            UserDefaults.standard.set(data, forKey: "EmergencyNotificationSettings")
        }
    }
    
    // MARK: - Utilities
    
    private func decodeEmergencyEvent(from record: [String: Any]) -> EmergencyEvent? {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            return try JSONDecoder().decode(EmergencyEvent.self, from: data)
        } catch {
            print("Failed to decode emergency event: \(error)")
            return nil
        }
    }
    
    private func extractLocation(from payload: [String: Any]) -> CLLocationCoordinate2D? {
        guard let latitude = payload["latitude"] as? Double,
              let longitude = payload["longitude"] as? Double else { return nil }
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Supporting Types

struct EmergencyAlert: Identifiable {
    let id: UUID
    let type: String
    let title: String
    let message: String
    let severity: EmergencySeverity
    let location: CLLocationCoordinate2D?
    let timestamp: Date
    var isRead: Bool
    let sourceUserID: UUID?
    
    init(
        id: UUID = UUID(),
        type: String,
        title: String,
        message: String,
        severity: EmergencySeverity,
        location: CLLocationCoordinate2D? = nil,
        timestamp: Date = Date(),
        isRead: Bool = false,
        sourceUserID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.severity = severity
        self.location = location
        self.timestamp = timestamp
        self.isRead = isRead
        self.sourceUserID = sourceUserID
    }
}

struct EmergencyNotificationSettings: Codable {
    var enableCriticalAlerts = true
    var enableWarningAlerts = true
    var enableInfoAlerts = true
    
    var criticalAlertRadius: Double = 5000
    var warningAlertRadius: Double = 10000
    var infoAlertRadius: Double = 20000
    
    var enableVibrationForCritical = true
    var enableVibrationForWarning = true
    
    var enableLocationBasedAlerts = true
    var enableSOSAlerts = true
    
    static let `default` = EmergencyNotificationSettings()
}