import Foundation
import Supabase
import Combine
import CoreLocation

// MARK: - Supabase Realtime基本サービス

@MainActor
class RealtimeService: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus: RealtimeConnectionStatus = .disconnected
    @Published var activeSubscriptions: [String: RealtimeChannel] = [:]
    
    private let supabase = SupabaseConfig.shared.client
    private var cancellables = Set<AnyCancellable>()
    private let reconnectDelay: TimeInterval = 5.0
    
    init() {
        setupConnectionMonitoring()
    }
    
    // MARK: - Connection Management
    
    private func setupConnectionMonitoring() {
        // 接続状態の監視
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkConnectionStatus()
            }
            .store(in: &cancellables)
    }
    
    private func checkConnectionStatus() {
        // 接続状態をチェック
        if activeSubscriptions.isEmpty {
            connectionStatus = .disconnected
            isConnected = false
        } else {
            connectionStatus = .connected
            isConnected = true
        }
    }
    
    // MARK: - Channel Subscription
    
    /// チャンネルを購読
    func subscribeToChannel(
        _ channelName: String,
        table: String? = nil,
        filter: String? = nil
    ) -> RealtimeChannel {
        // 既存のサブスクリプションがある場合は返す
        if let existingChannel = activeSubscriptions[channelName] {
            return existingChannel
        }
        
        // 新しいチャンネルを作成
        let channel = supabase.realtime.channel(channelName)

        // TODO: Supabase Realtime API の型定義が必要
        // リアルタイムイベント処理は一旦無効化

        // チャンネルを購読
        channel.subscribe { [weak self] status, error in
            if let error = error {
                print("Subscription error: \(error)")
            }
            self?.handleSubscriptionStatus(status, channelName: channelName)
        }

        // アクティブなサブスクリプションに追加
        activeSubscriptions[channelName] = channel

        return channel
    }
    
    /// チャンネルの購読を解除
    func unsubscribeFromChannel(_ channelName: String) {
        guard let channel = activeSubscriptions[channelName] else { return }
        
        Task {
            await channel.unsubscribe()
            activeSubscriptions.removeValue(forKey: channelName)
            checkConnectionStatus()
        }
    }
    
    /// すべてのチャンネルの購読を解除
    func unsubscribeAll() {
        Task {
            for (_, channel) in activeSubscriptions {
                await channel.unsubscribe()
            }
            activeSubscriptions.removeAll()
            checkConnectionStatus()
        }
    }
    
    // MARK: - Event Handling
    // TODO: Supabase Realtime API の型定義が必要

    /*
    private func handleDatabaseChange(_ change: PostgresChange, table: String) {
        print("Database change detected in table \(table):")
        print("Event: \(change.event)")
        
        // 変更イベントを通知
        NotificationCenter.default.post(
            name: .databaseChangeNotification,
            object: nil,
            userInfo: [
                "table": table,
                "event": change.event,
                "record": change.record,
                "oldRecord": change.oldRecord
            ]
        )
    }
    */

    private func handleSubscriptionStatus(_ status: RealtimeSubscribeStates, channelName: String) {
        print("Realtime channel \(channelName) status: \(status)")
        
        switch status {
        case .subscribed:
            connectionStatus = .connected
            isConnected = true
            
        case .timedOut, .channelError:
            connectionStatus = .disconnected
            isConnected = false
            activeSubscriptions.removeValue(forKey: channelName)
            
        case .channelError:
            connectionStatus = .error
            attemptReconnection(channelName: channelName)
            
        default:
            break
        }
    }
    
    // MARK: - Reconnection
    
    private func attemptReconnection(channelName: String) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
            
            if let channel = activeSubscriptions[channelName] {
                print("Attempting to reconnect channel: \(channelName)")
                
                // 再購読を試みる
                channel.subscribe { [weak self] status, error in
                    if let error = error {
                        print("Resubscription error: \(error)")
                    }
                    self?.handleSubscriptionStatus(status, channelName: channelName)
                }
            }
        }
    }
    
    // MARK: - Presence
    
    /// プレゼンス機能を有効化（位置情報共有など）
    func enablePresence(
        on channel: RealtimeChannel,
        userID: UUID,
        metadata: [String: Any] = [:]
    ) {
        Task {
            var presence: [String: String] = ["user_id": userID.uuidString]
            // metadataをString型に変換
            metadata.forEach { key, value in
                presence[key] = String(describing: value)
            }

            await channel.track(presence)
        }
    }
    
    /// プレゼンス情報を更新
    func updatePresence(
        on channel: RealtimeChannel,
        location: CLLocationCoordinate2D? = nil,
        status: String? = nil
    ) {
        Task {
            var updates: [String: Any] = [:]
            
            if let location = location {
                updates["latitude"] = location.latitude
                updates["longitude"] = location.longitude
                updates["last_updated"] = Date().iso8601String
            }
            
            if let status = status {
                updates["status"] = status
            }
            
            if !updates.isEmpty {
                await channel.track(updates)
            }
        }
    }
    
    // MARK: - Broadcast
    
    /// メッセージをブロードキャスト
    func broadcast(
        on channel: RealtimeChannel,
        event: String,
        payload: [String: Any]
    ) {
        Task {
            await channel.send(
                type: .broadcast,
                event: event,
                payload: payload
            )
        }
    }
    
    /// 位置情報をブロードキャスト
    func broadcastLocation(
        on channel: RealtimeChannel,
        coordinate: CLLocationCoordinate2D,
        accuracy: Double,
        additionalInfo: [String: Any] = [:]
    ) {
        var payload: [String: Any] = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "accuracy": accuracy,
            "timestamp": Date().iso8601String
        ]
        
        additionalInfo.forEach { payload[$0.key] = $0.value }
        
        broadcast(on: channel, event: "location_update", payload: payload)
    }
}

// MARK: - Supporting Types

enum RealtimeConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error
    
    var displayText: String {
        switch self {
        case .disconnected: return "切断"
        case .connecting: return "接続中..."
        case .connected: return "接続済み"
        case .error: return "エラー"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let databaseChangeNotification = Notification.Name("databaseChangeNotification")
    static let realtimeConnectionStatusChanged = Notification.Name("realtimeConnectionStatusChanged")
}

// MARK: - PostgresChange Event Extension

extension PostgresChangeEvent {
    static var all: PostgresChangeEvent {
        return .insert
    }
}