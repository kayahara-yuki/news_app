import Foundation
import CoreData
import Combine
import CoreLocation

// MARK: - ローカルストレージマネージャー

@MainActor
class LocalStorageManager: ObservableObject {
    static let shared = LocalStorageManager()
    
    @Published var isOnline = true
    @Published var syncStatus: SyncStatus = .idle
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LocationNewsSNS")
        container.loadPersistentStores { _, error in
            if let error = error {
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - 初期化
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - ネットワーク監視
    
    private func setupNetworkMonitoring() {
        // ネットワーク状態の監視実装
        // 実際の実装では Network framework を使用
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkNetworkStatus()
            }
            .store(in: &cancellables)
    }
    
    private func checkNetworkStatus() {
        // 実際のネットワーク状態チェック
        // 今回は仮実装
        let wasOnline = isOnline
        
        // TODO: 実際のネットワーク状態を確認
        // isOnline = NetworkMonitor.shared.isConnected
        
        if wasOnline != isOnline {
            handleNetworkStatusChange()
        }
    }
    
    private func handleNetworkStatusChange() {
        if isOnline {
            Task {
                await syncPendingData()
            }
        } else {
            syncStatus = .offline
        }
    }
    
    // MARK: - データ保存
    
    func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - データ同期
    
    func syncPendingData() async {
        guard isOnline else { return }
        
        syncStatus = .syncing
        
        do {
            // 未同期の投稿を同期
            await syncPendingPosts()
            
            // 未同期のユーザーアクションを同期
            await syncPendingActions()
            
            syncStatus = .synced

        } catch {
            syncStatus = .failed
        }
    }
    
    private func syncPendingPosts() async {
        let pendingPosts = fetchPendingPosts()
        
        for pendingPost in pendingPosts {
            do {
                // オンラインでの投稿作成を試行
                try await uploadPendingPost(pendingPost)
                
                // 成功したらローカルから削除
                context.delete(pendingPost)
                
            } catch {
                // エラーの場合はそのまま残す
            }
        }
        
        try? saveContext()
    }
    
    private func syncPendingActions() async {
        let pendingActions = fetchPendingActions()
        
        for action in pendingActions {
            do {
                try await executePendingAction(action)
                context.delete(action)
            } catch {
            }
        }
        
        try? saveContext()
    }
    
    // MARK: - 投稿のオフライン対応
    
    func savePostForOfflineAccess(_ post: Post) throws {
        let cachedPost = CachedPost(context: context)
        cachedPost.configure(from: post)
        try saveContext()
    }
    
    func savePendingPost(_ request: CreatePostRequest) throws {
        let pendingPost = PendingPost(context: context)
        pendingPost.configure(from: request)
        try saveContext()
    }
    
    func fetchCachedPosts(near location: CLLocationCoordinate2D, radius: Double) -> [Post] {
        let request: NSFetchRequest<CachedPost> = CachedPost.fetchRequest()
        
        // 位置に基づくフィルタリング
        let latMin = location.latitude - (radius / 111000) // 約1度 = 111km
        let latMax = location.latitude + (radius / 111000)
        let lngMin = location.longitude - (radius / (111000 * cos(location.latitude * .pi / 180)))
        let lngMax = location.longitude + (radius / (111000 * cos(location.latitude * .pi / 180)))
        
        request.predicate = NSPredicate(
            format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f",
            latMin, latMax, lngMin, lngMax
        )
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let cachedPosts = try context.fetch(request)
            return cachedPosts.compactMap { $0.toPost() }
        } catch {
            return []
        }
    }
    
    // MARK: - ユーザーアクションのオフライン対応
    
    func savePendingLike(postID: UUID, isLike: Bool) throws {
        let pendingAction = PendingAction(context: context)
        pendingAction.actionType = isLike ? "like" : "unlike"
        pendingAction.postID = postID
        pendingAction.createdAt = Date()
        try saveContext()
    }
    
    func savePendingComment(postID: UUID, content: String) throws {
        let pendingAction = PendingAction(context: context)
        pendingAction.actionType = "comment"
        pendingAction.postID = postID
        pendingAction.content = content
        pendingAction.createdAt = Date()
        try saveContext()
    }
    
    // MARK: - Private Methods
    
    private func fetchPendingPosts() -> [PendingPost] {
        let request: NSFetchRequest<PendingPost> = PendingPost.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    private func fetchPendingActions() -> [PendingAction] {
        let request: NSFetchRequest<PendingAction> = PendingAction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    private func uploadPendingPost(_ pendingPost: PendingPost) async throws {
        guard let createRequest = pendingPost.toCreatePostRequest() else {
            throw LocalStorageError.invalidData
        }
        
        // PostRepositoryを使用して実際にアップロード
        let postRepository = PostRepository()
        _ = try await postRepository.createPost(createRequest)
    }
    
    private func executePendingAction(_ action: PendingAction) async throws {
        let postRepository = PostRepository()
        
        switch action.actionType {
        case "like":
            if let postID = action.postID {
                try await postRepository.likePost(id: postID)
            }
        case "unlike":
            if let postID = action.postID {
                try await postRepository.unlikePost(id: postID)
            }
        case "comment":
            if let postID = action.postID, let content = action.content {
                try await postRepository.addComment(postID: postID, content: content, userID: UUID()) // TODO: 現在のユーザーID
            }
        default:
            throw LocalStorageError.unsupportedAction
        }
    }
}

// MARK: - 同期ステータス

enum SyncStatus {
    case idle
    case syncing
    case synced
    case failed
    case offline
    
    var displayText: String {
        switch self {
        case .idle: return "待機中"
        case .syncing: return "同期中..."
        case .synced: return "同期済み"
        case .failed: return "同期失敗"
        case .offline: return "オフライン"
        }
    }
}

// MARK: - エラー定義

enum LocalStorageError: Error, LocalizedError {
    case invalidData
    case unsupportedAction
    case coreDataError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "無効なデータです"
        case .unsupportedAction:
            return "サポートされていないアクションです"
        case .coreDataError(let error):
            return "Core Dataエラー: \(error.localizedDescription)"
        }
    }
}

// MARK: - CLLocationCoordinate2D Extension

extension CLLocationCoordinate2D {
    static func from(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}