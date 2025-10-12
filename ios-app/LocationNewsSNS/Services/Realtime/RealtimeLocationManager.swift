import Foundation
import Supabase
import Combine
import CoreLocation
import MapKit

// MARK: - 位置情報ベースのリアルタイム更新マネージャー

@MainActor
class RealtimeLocationManager: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    // TODO: EmergencyAlert型の重複を解決する必要があります
    // @Published var emergencyAlerts: [EmergencyAlert] = []
    @Published var locationHeatmap: LocationHeatmap?
    @Published var isLocationSharingActive = false
    
    private let realtimeService: RealtimeService
    private let locationService: LocationService
    private let locationPrivacyService: LocationPrivacyService
    
    private var locationChannel: RealtimeChannel?
    private var emergencyChannel: RealtimeChannel?
    private var cancellables = Set<AnyCancellable>()
    
    // 設定
    private let nearbyUserRadius: Double = 1000 // 1km
    private let locationUpdateInterval: TimeInterval = 30 // 30秒
    private var locationUpdateTimer: Timer?
    
    init(
        realtimeService: RealtimeService,
        locationService: LocationService,
        locationPrivacyService: LocationPrivacyService
    ) {
        self.realtimeService = realtimeService
        self.locationService = locationService
        self.locationPrivacyService = locationPrivacyService
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // 位置情報の更新を監視
        locationService.$currentLocation
            .compactMap { $0 }
            .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
        
        // 緊急モードの変更を監視
        locationPrivacyService.$isEmergencyMode
            .sink { [weak self] isEmergency in
                if isEmergency {
                    self?.startEmergencyLocationSharing()
                } else {
                    self?.stopEmergencyLocationSharing()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Location Sharing
    
    /// 位置情報共有を開始
    func startLocationSharing(userID: UUID) {
        guard !isLocationSharingActive else { return }
        
        // プライバシー設定を確認
        guard locationPrivacyService.privacySettings.locationSharing else {
            print("Location sharing is disabled in privacy settings")
            return
        }
        
        // リアルタイムチャンネルを設定
        let channelName = "location:sharing"
        locationChannel = realtimeService.subscribeToChannel(channelName)
        
        // プレゼンスを有効化
        if let channel = locationChannel {
            realtimeService.enablePresence(
                on: channel,
                userID: userID,
                metadata: ["sharing_mode": "standard"]
            )
            
            // プレゼンスイベントを監視
            setupPresenceListeners(on: channel)
        }
        
        // 定期的な位置情報更新を開始
        startLocationUpdateTimer()
        
        isLocationSharingActive = true
    }
    
    /// 位置情報共有を停止
    func stopLocationSharing() {
        guard isLocationSharingActive else { return }
        
        if let channelName = locationChannel?.topic {
            realtimeService.unsubscribeFromChannel(channelName)
        }
        
        locationChannel = nil
        stopLocationUpdateTimer()
        nearbyUsers.removeAll()
        isLocationSharingActive = false
    }
    
    // MARK: - Emergency Mode
    
    private func startEmergencyLocationSharing() {
        guard let userID = getCurrentUserID() else { return }
        
        // 緊急チャンネルを設定
        let channelName = "emergency:location"
        emergencyChannel = realtimeService.subscribeToChannel(channelName)
        
        if let channel = emergencyChannel {
            // 高頻度で位置情報を送信
            realtimeService.enablePresence(
                on: channel,
                userID: userID,
                metadata: ["emergency": true, "timestamp": Date().iso8601String]
            )
            
            // 緊急アラートを監視
            setupEmergencyListeners(on: channel)
        }
        
        // 位置情報の更新頻度を上げる
        stopLocationUpdateTimer()
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.broadcastCurrentLocation()
        }
    }
    
    private func stopEmergencyLocationSharing() {
        if let channelName = emergencyChannel?.topic {
            realtimeService.unsubscribeFromChannel(channelName)
        }

        emergencyChannel = nil
        // TODO: emergencyAlerts再有効化後にコメント解除
        // emergencyAlerts.removeAll()

        // 通常の更新頻度に戻す
        if isLocationSharingActive {
            startLocationUpdateTimer()
        }
    }
    
    // MARK: - Channel Listeners

    private func setupPresenceListeners(on channel: RealtimeChannel) {
        // TODO: Supabase Realtime API更新に伴い、Presence APIの使用方法を見直す必要があります
        // 古いAPIメソッド (onPresenceSync, onPresenceJoin, onPresenceLeave, onBroadcast) は利用不可
        /*
        // ユーザーの参加
        channel.onPresenceSync { [weak self] in
            self?.updateNearbyUsers(from: channel)
        }

        // ユーザーの位置更新
        channel.onPresenceJoin { [weak self] joins in
            self?.handleUserJoin(joins)
        }

        // ユーザーの離脱
        channel.onPresenceLeave { [weak self] leaves in
            self?.handleUserLeave(leaves)
        }

        // 位置情報ブロードキャスト
        channel.onBroadcast(event: "location_update") { [weak self] message in
            self?.handleLocationBroadcast(message)
        }
        */
    }

    private func setupEmergencyListeners(on channel: RealtimeChannel) {
        // TODO: Supabase Realtime API更新に伴い、Broadcast APIの使用方法を見直す必要があります
        /*
        // 緊急アラート
        channel.onBroadcast(event: "emergency_alert") { [weak self] message in
            self?.handleEmergencyAlert(message)
        }

        // SOSシグナル
        channel.onBroadcast(event: "sos_signal") { [weak self] message in
            self?.handleSOSSignal(message)
        }
        */
    }
    
    // MARK: - Event Handlers
    
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isLocationSharingActive || locationPrivacyService.isEmergencyMode else { return }
        
        // プライバシー設定に基づいて位置を調整
        let adjustedCoordinate = locationPrivacyService.processLocation(location.coordinate)
        
        // プレゼンスを更新
        if let channel = locationChannel ?? emergencyChannel {
            realtimeService.updatePresence(
                on: channel,
                location: adjustedCoordinate
            )
        }
    }
    
    private func handleUserJoin(_ joins: [PresenceJoin]) {
        for join in joins {
            if let userID = join.presence["user_id"] as? String,
               let latitude = join.presence["latitude"] as? Double,
               let longitude = join.presence["longitude"] as? Double {
                
                let nearbyUser = NearbyUser(
                    userID: UUID(uuidString: userID) ?? UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    lastUpdated: Date()
                )
                
                // 距離を確認して追加
                if isUserNearby(nearbyUser) {
                    nearbyUsers.append(nearbyUser)
                }
            }
        }
    }
    
    private func handleUserLeave(_ leaves: [PresenceLeave]) {
        for leave in leaves {
            if let userID = leave.presence["user_id"] as? String {
                nearbyUsers.removeAll { $0.userID.uuidString == userID }
            }
        }
    }
    
    private func handleLocationBroadcast(_ message: [String: Any]) {
        guard let payload = message["payload"] as? [String: Any],
              let userID = payload["user_id"] as? String,
              let latitude = payload["latitude"] as? Double,
              let longitude = payload["longitude"] as? Double else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // 既存のユーザーを更新または新規追加
        if let index = nearbyUsers.firstIndex(where: { $0.userID.uuidString == userID }) {
            nearbyUsers[index].coordinate = coordinate
            nearbyUsers[index].lastUpdated = Date()
        } else {
            let nearbyUser = NearbyUser(
                userID: UUID(uuidString: userID) ?? UUID(),
                coordinate: coordinate,
                lastUpdated: Date()
            )
            
            if isUserNearby(nearbyUser) {
                nearbyUsers.append(nearbyUser)
            }
        }
    }
    
    private func handleEmergencyAlert(_ message: [String: Any]) {
        // TODO: Realtime API更新後に実装
        /*
        guard let payload = message["payload"] as? [String: Any],
              let userID = payload["user_id"] as? String,
              let latitude = payload["latitude"] as? Double,
              let longitude = payload["longitude"] as? Double,
              let alertType = payload["type"] as? String else { return }

        let alert = EmergencyAlert(
            id: UUID(),
            userID: UUID(uuidString: userID) ?? UUID(),
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            type: alertType,
            message: payload["message"] as? String,
            timestamp: Date()
        )

        emergencyAlerts.insert(alert, at: 0)

        // 通知を送信
        sendEmergencyNotification(alert)
        */
    }

    private func handleSOSSignal(_ message: [String: Any]) {
        // TODO: Realtime API更新後に実装
        /*
        guard let payload = message["payload"] as? [String: Any] else { return }

        // SOS信号の処理
        print("SOS signal received: \(payload)")
        */
    }
    
    // MARK: - Location Broadcasting
    
    private func broadcastCurrentLocation() {
        guard let location = locationService.currentLocation,
              let channel = locationChannel ?? emergencyChannel,
              let userID = getCurrentUserID() else { return }
        
        // プライバシー設定に基づいて位置を調整
        let adjustedCoordinate = locationPrivacyService.processLocation(location.coordinate)
        
        var additionalInfo: [String: Any] = ["user_id": userID.uuidString]
        
        if locationPrivacyService.isEmergencyMode {
            additionalInfo["emergency"] = true
        }
        
        realtimeService.broadcastLocation(
            on: channel,
            coordinate: adjustedCoordinate,
            accuracy: location.horizontalAccuracy,
            additionalInfo: additionalInfo
        )
    }
    
    // MARK: - Utilities
    
    private func updateNearbyUsers(from channel: RealtimeChannel) {
        Task {
            let presences = await channel.presenceState()
            
            nearbyUsers = presences.compactMap { _, presence in
                guard let userID = presence["user_id"] as? String,
                      let latitude = presence["latitude"] as? Double,
                      let longitude = presence["longitude"] as? Double else { return nil }
                
                let nearbyUser = NearbyUser(
                    userID: UUID(uuidString: userID) ?? UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    lastUpdated: Date()
                )
                
                return isUserNearby(nearbyUser) ? nearbyUser : nil
            }
        }
    }
    
    private func isUserNearby(_ user: NearbyUser) -> Bool {
        guard let currentLocation = locationService.currentLocation else { return false }
        
        let userLocation = CLLocation(
            latitude: user.coordinate.latitude,
            longitude: user.coordinate.longitude
        )
        
        return currentLocation.distance(from: userLocation) <= nearbyUserRadius
    }
    
    private func startLocationUpdateTimer() {
        locationUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: locationUpdateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.broadcastCurrentLocation()
        }
    }
    
    private func stopLocationUpdateTimer() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func getCurrentUserID() -> UUID? {
        // TODO: 実際の実装では認証サービスから取得
        return UUID()
    }

    // TODO: EmergencyAlert型の重複解決後に有効化
    /*
    private func sendEmergencyNotification(_ alert: EmergencyAlert) {
        NotificationCenter.default.post(
            name: .emergencyAlertReceived,
            object: nil,
            userInfo: ["alert": alert]
        )
    }
    */
    
    // MARK: - Heatmap Generation
    
    func generateLocationHeatmap(for region: MKCoordinateRegion) {
        // 近くのユーザーの密度からヒートマップを生成
        let heatmap = LocationHeatmap(
            region: region,
            dataPoints: nearbyUsers.map { user in
                HeatmapDataPoint(
                    coordinate: user.coordinate,
                    intensity: 1.0,
                    radius: 100
                )
            }
        )
        
        locationHeatmap = heatmap
    }
}

// MARK: - Supporting Types

struct NearbyUser: Identifiable {
    let id = UUID()
    let userID: UUID
    var coordinate: CLLocationCoordinate2D
    var lastUpdated: Date
    var distance: Double?
}

// Note: EmergencyAlert is defined in EmergencyRepository.swift and EmergencyNotificationService.swift

struct LocationHeatmap {
    let region: MKCoordinateRegion
    let dataPoints: [HeatmapDataPoint]
}

struct HeatmapDataPoint {
    let coordinate: CLLocationCoordinate2D
    let intensity: Double
    let radius: Double
}

// MARK: - Notification Names

extension Notification.Name {
    static let emergencyAlertReceived = Notification.Name("emergencyAlertReceived")
    static let nearbyUsersUpdated = Notification.Name("nearbyUsersUpdated")
}

// MARK: - Presence Types

struct PresenceJoin {
    let key: String
    let presence: [String: Any]
}

struct PresenceLeave {
    let key: String
    let presence: [String: Any]
}