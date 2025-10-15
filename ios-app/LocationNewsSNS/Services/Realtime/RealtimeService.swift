import Foundation
import Supabase
import Combine
import CoreLocation

// MARK: - Supabase Realtime基本サービス

@MainActor
class RealtimeService: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus: RealtimeConnectionStatus = .disconnected
    @Published var activeSubscriptions: [String: RealtimeChannelV2] = [:]
    
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
    ) async -> RealtimeChannelV2 {
        // 既存のサブスクリプションがある場合は返す
        if let existingChannel = activeSubscriptions[channelName] {
            return existingChannel
        }

        // 新しいチャンネルを作成（RealtimeV2を使用）
        let channel = supabase.realtimeV2.channel(channelName)

        // チャンネルを購読
        do {
            try await channel.subscribeWithError()
            handleSubscriptionSuccess(channelName: channelName)
        } catch {
            print("Subscription error: \(error)")
            handleSubscriptionError(channelName: channelName, error: error)
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

    private func handleSubscriptionSuccess(channelName: String) {
        print("Realtime channel \(channelName) subscribed successfully")
        connectionStatus = .connected
        isConnected = true
    }

    private func handleSubscriptionError(channelName: String, error: Error) {
        print("Realtime channel \(channelName) subscription error: \(error)")
        connectionStatus = .error
        isConnected = false
        activeSubscriptions.removeValue(forKey: channelName)
        attemptReconnection(channelName: channelName)
    }
    
    // MARK: - Reconnection
    
    private func attemptReconnection(channelName: String) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))

            print("Attempting to reconnect channel: \(channelName)")

            // チャンネルを再作成して再購読
            let _ = await subscribeToChannel(channelName)
        }
    }
    
    // MARK: - Presence
    
    /// プレゼンス機能を有効化（位置情報共有など）
    func enablePresence(
        on channel: RealtimeChannelV2,
        userID: UUID,
        metadata: [String: Any] = [:]
    ) {
        Task {
            var presence: [String: AnyJSON] = ["user_id": .string(userID.uuidString)]
            // metadataをAnyJSON型に変換
            metadata.forEach { key, value in
                presence[key] = .string(String(describing: value))
            }

            try? await channel.track(state: presence)
        }
    }
    
    /// プレゼンス情報を更新
    func updatePresence(
        on channel: RealtimeChannelV2,
        location: CLLocationCoordinate2D? = nil,
        status: String? = nil
    ) {
        Task {
            var updates: [String: AnyJSON] = [:]

            if let location = location {
                updates["latitude"] = .double(location.latitude)
                updates["longitude"] = .double(location.longitude)
                updates["last_updated"] = .string(Date().iso8601String)
            }

            if let status = status {
                updates["status"] = .string(status)
            }

            if !updates.isEmpty {
                try? await channel.track(state: updates)
            }
        }
    }
    
    // MARK: - Broadcast
    
    /// メッセージをブロードキャスト
    func broadcast(
        on channel: RealtimeChannelV2,
        event: String,
        payload: [String: AnyJSON]
    ) {
        Task {
            try? await channel.broadcast(event: event, message: payload)
        }
    }

    /// 位置情報をブロードキャスト
    func broadcastLocation(
        on channel: RealtimeChannelV2,
        coordinate: CLLocationCoordinate2D,
        accuracy: Double,
        additionalInfo: [String: AnyJSON] = [:]
    ) {
        var payload: [String: AnyJSON] = [
            "latitude": .double(coordinate.latitude),
            "longitude": .double(coordinate.longitude),
            "accuracy": .double(accuracy),
            "timestamp": .string(Date().iso8601String)
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