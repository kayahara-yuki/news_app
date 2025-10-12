import Foundation
import Supabase
import Combine
import CoreLocation

// MARK: - 投稿のリアルタイム監視・更新マネージャー

@MainActor
class RealtimePostManager: ObservableObject {
    @Published var realtimePosts: [Post] = []
    @Published var latestUpdates: [PostUpdate] = []
    @Published var isSubscribed = false
    
    private let realtimeService: RealtimeService
    private let postRepository: any PostRepositoryProtocol
    private let locationService: any LocationServiceProtocol

    var postChannel: RealtimeChannel?
    private var cancellables = Set<AnyCancellable>()
    private let updateBufferSize = 50

    // 監視設定
    private var monitoringRadius: Double = 5000 // 5km
    private var monitoringCenter: CLLocationCoordinate2D?

    init(
        realtimeService: RealtimeService,
        postRepository: any PostRepositoryProtocol,
        locationService: any LocationServiceProtocol
    ) {
        self.realtimeService = realtimeService
        self.postRepository = postRepository
        self.locationService = locationService

        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // データベース変更通知を監視
        NotificationCenter.default.publisher(for: .databaseChangeNotification)
            .sink { [weak self] notification in
                self?.handleDatabaseChange(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Subscription Management
    
    /// 近くの投稿のリアルタイム監視を開始
    func startMonitoringNearbyPosts(
        center: CLLocationCoordinate2D,
        radius: Double = 5000
    ) {
        guard !isSubscribed else { return }
        
        monitoringCenter = center
        monitoringRadius = radius
        
        // Supabase Realtimeチャンネルを設定
        let channelName = "posts:nearby:\(center.latitude),\(center.longitude)"
        
        postChannel = realtimeService.subscribeToChannel(
            channelName,
            table: "posts"
        )
        
        // 追加のイベントリスナーを設定
        setupPostChannelListeners()
        
        isSubscribed = true
        
        // 初期データを取得
        Task {
            await fetchInitialPosts()
        }
    }
    
    /// 監視を停止
    func stopMonitoring() {
        guard isSubscribed, let channelName = postChannel?.topic else { return }
        
        realtimeService.unsubscribeFromChannel(channelName)
        postChannel = nil
        isSubscribed = false
        realtimePosts.removeAll()
        latestUpdates.removeAll()
    }
    
    // MARK: - Channel Setup
    
    private func setupPostChannelListeners() {
        // TODO: Supabase Realtime API の型定義が必要
        // リアルタイムイベント処理は一旦無効化
    }
    
    // MARK: - Event Handlers
    // TODO: Supabase Realtime API の型定義が必要
    // 以下のハンドラは一旦コメントアウト

    /*
    private func handleNewPost(_ change: PostgresChange) {
        guard let record = change.record,
              let post = decodePost(from: record),
              isPostInMonitoringArea(post) else { return }

        // 新しい投稿を追加
        realtimePosts.insert(post, at: 0)

        // 更新履歴に追加
        addUpdate(PostUpdate(
            type: .new,
            post: post,
            timestamp: Date()
        ))

        // 通知を送信
        sendNewPostNotification(post)
    }

    private func handlePostUpdate(_ change: PostgresChange) {
        guard let record = change.record,
              let updatedPost = decodePost(from: record) else { return }

        // 既存の投稿を更新
        if let index = realtimePosts.firstIndex(where: { $0.id == updatedPost.id }) {
            realtimePosts[index] = updatedPost

            // 更新履歴に追加
            addUpdate(PostUpdate(
                type: .updated,
                post: updatedPost,
                timestamp: Date()
            ))
        }
    }

    private func handlePostDelete(_ change: PostgresChange) {
        guard let oldRecord = change.oldRecord,
              let postID = oldRecord["id"] as? String,
              let uuid = UUID(uuidString: postID) else { return }

        // 投稿を削除
        realtimePosts.removeAll { $0.id == uuid }

        // 更新履歴に追加
        addUpdate(PostUpdate(
            type: .deleted,
            postID: uuid,
            timestamp: Date()
        ))
    }
    */
    
    private func handleDatabaseChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let table = userInfo["table"] as? String,
              table == "posts" else { return }
        
        // 必要に応じて追加の処理
    }
    
    // MARK: - Location Updates
    
    private func updateMonitoringLocation(_ newCenter: CLLocationCoordinate2D) {
        // 位置が大きく変わった場合は再購読
        if let currentCenter = monitoringCenter {
            let distance = CLLocation(
                latitude: currentCenter.latitude,
                longitude: currentCenter.longitude
            ).distance(from: CLLocation(
                latitude: newCenter.latitude,
                longitude: newCenter.longitude
            ))
            
            if distance > monitoringRadius / 2 {
                // 監視範囲を更新
                stopMonitoring()
                startMonitoringNearbyPosts(center: newCenter, radius: monitoringRadius)
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchInitialPosts() async {
        guard let center = monitoringCenter else { return }
        
        do {
            let posts = try await postRepository.fetchNearbyPosts(
                latitude: center.latitude,
                longitude: center.longitude,
                radius: monitoringRadius
            )
            
            realtimePosts = posts
        } catch {
            print("Failed to fetch initial posts: \(error)")
        }
    }
    
    // MARK: - Utilities
    
    private func isPostInMonitoringArea(_ post: Post) -> Bool {
        guard let center = monitoringCenter,
              let lat = post.latitude,
              let lng = post.longitude else { return false }

        let postLocation = CLLocation(latitude: lat, longitude: lng)
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return postLocation.distance(from: centerLocation) <= monitoringRadius
    }
    
    private func decodePost(from record: [String: Any]) -> Post? {
        do {
            let data = try JSONSerialization.data(withJSONObject: record)
            let post = try JSONDecoder().decode(Post.self, from: data)
            return post
        } catch {
            print("Failed to decode post: \(error)")
            return nil
        }
    }
    
    private func addUpdate(_ update: PostUpdate) {
        latestUpdates.insert(update, at: 0)
        
        // バッファサイズを超えたら古い更新を削除
        if latestUpdates.count > updateBufferSize {
            latestUpdates.removeLast(latestUpdates.count - updateBufferSize)
        }
    }
    
    private func sendNewPostNotification(_ post: Post) {
        // 新しい投稿の通知を送信
        let notification = Notification(
            name: .newPostReceived,
            object: nil,
            userInfo: ["post": post]
        )
        NotificationCenter.default.post(notification)
    }
}

// MARK: - Supporting Types

struct PostUpdate: Identifiable {
    let id = UUID()
    let type: UpdateType
    let post: Post?
    let postID: UUID?
    let timestamp: Date
    
    enum UpdateType {
        case new
        case updated
        case deleted
    }
    
    init(type: UpdateType, post: Post? = nil, postID: UUID? = nil, timestamp: Date) {
        self.type = type
        self.post = post
        self.postID = postID ?? post?.id
        self.timestamp = timestamp
    }
}

// MARK: - Notification Names
// Note: newPostReceivedはAppConfiguration.swiftで定義されています

extension Notification.Name {
    static let postUpdated = Notification.Name("postUpdated")
    static let postDeleted = Notification.Name("postDeleted")
}