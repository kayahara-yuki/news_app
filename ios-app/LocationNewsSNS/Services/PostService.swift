import Foundation
import Supabase
import CoreLocation
import Combine

/// 投稿管理サービス
@MainActor
class PostService: ObservableObject, PostServiceProtocol {
    @Published var posts: [Post] = []
    @Published var nearbyPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let postRepository: PostRepositoryProtocol
    private var realtimePostManager: RealtimePostManager?
    private var cancellables = Set<AnyCancellable>()
    
    init(postRepository: PostRepositoryProtocol = PostRepository()) {
        self.postRepository = postRepository
        setupRealtimeSubscription()
    }

    deinit {
        cancellables.removeAll()
        // Main Actor分離されたメソッドを非同期で呼び出し
        if let manager = realtimePostManager {
            Task { @MainActor in
                manager.stopMonitoring()
            }
        }
    }
    
    // MARK: - リアルタイム更新
    
    private func setupRealtimeSubscription() {
        // リアルタイム機能の初期化
        let dependencies = DependencyContainer.shared
        
        realtimePostManager = RealtimePostManager(
            realtimeService: RealtimeService(),
            postRepository: PostRepository(),
            locationService: dependencies.locationService
        )
        
        // リアルタイム投稿の変更を監視
        realtimePostManager?.$realtimePosts
            .sink { [weak self] posts in
                self?.handleRealtimePostUpdate(posts)
            }
            .store(in: &cancellables)
        
        // 新しい投稿の通知を監視
        NotificationCenter.default.publisher(for: .newPostReceived)
            .sink { [weak self] notification in
                if let post = notification.userInfo?["post"] as? Post {
                    self?.handleNewPost(post)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleRealtimePostUpdate(_ posts: [Post]) {
        // リアルタイム投稿をマージ
        nearbyPosts = posts
    }
    
    private func handleNewPost(_ post: Post) {
        // 新しい投稿をリストの先頭に追加
        nearbyPosts.insert(post, at: 0)

        // Map上にピンを表示するための通知を送信
        if post.canShowOnMap {
            NotificationCenter.default.post(
                name: .newPostCreated,
                object: nil,
                userInfo: ["post": post]
            )
        }
    }
    
    // MARK: - 投稿の取得
    
    /// 近隣の投稿を取得
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let posts = try await postRepository.fetchNearbyPosts(
                latitude: latitude,
                longitude: longitude,
                radius: radius
            )

            await MainActor.run {
                self.nearbyPosts = posts
                self.errorMessage = nil
            }

            // リアルタイム監視を開始
            realtimePostManager?.startMonitoringNearbyPosts(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                radius: radius
            )

        } catch {
            AppLogger.error("投稿取得エラー: \(error)")
            await MainActor.run {
                self.errorMessage = "投稿の取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    /// 投稿を作成
    func createPost(_ request: CreatePostRequest) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let newPost = try await postRepository.createPost(request)

            await MainActor.run {
                // ローカルリストに追加
                self.nearbyPosts.insert(newPost, at: 0)
                self.errorMessage = nil

                // Map上にピンを表示するための通知を送信
                if newPost.canShowOnMap {
                    NotificationCenter.default.post(
                        name: .newPostCreated,
                        object: nil,
                        userInfo: ["post": newPost]
                    )
                }
            }

        } catch {
            print("投稿作成エラー: \(error)")
            await MainActor.run {
                self.errorMessage = "投稿の作成に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    /// 投稿にいいねする
    func likePost(id: UUID) async {
        do {
            try await postRepository.likePost(id: id)

            await MainActor.run {
                // ローカルリストのいいね数を更新
                updateLocalPostLikeCount(postID: id, increment: true)
                self.errorMessage = nil
            }

            // いいね後、サーバーから最新データを取得して同期
            await refreshPost(id: id)

        } catch {
            print("いいねエラー: \(error)")
            await MainActor.run {
                self.errorMessage = "いいねに失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    /// 投稿のいいねを取り消す
    func unlikePost(id: UUID) async {
        do {
            try await postRepository.unlikePost(id: id)

            await MainActor.run {
                // ローカルリストのいいね数を更新
                updateLocalPostLikeCount(postID: id, increment: false)
                self.errorMessage = nil
            }

            // いいね解除後、サーバーから最新データを取得して同期
            await refreshPost(id: id)

        } catch {
            print("いいね取り消しエラー: \(error)")
            await MainActor.run {
                self.errorMessage = "いいねの取り消しに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    /// 投稿のいいね状態をチェック
    func checkLikeStatus(postID: UUID, userID: UUID) async -> Bool {
        do {
            return try await postRepository.hasUserLikedPost(id: postID, userID: userID)
        } catch {
            print("いいね状態チェックエラー: \(error)")
            return false
        }
    }

    /// 投稿を取得
    func getPost(id: UUID) async -> Post? {
        do {
            let post = try await postRepository.getPost(id: id)
            return post
        } catch {
            await MainActor.run {
                self.errorMessage = "投稿の取得に失敗しました: \(error.localizedDescription)"
            }
            return nil
        }
    }

    /// 投稿を削除
    func deletePost(id: UUID) async {
        do {
            try await postRepository.deletePost(id: id)
            
            await MainActor.run {
                // ローカルリストから削除
                self.nearbyPosts.removeAll { $0.id == id }
                self.posts.removeAll { $0.id == id }
                self.errorMessage = nil
            }
            
        } catch {
            print("投稿削除エラー: \(error)")
            await MainActor.run {
                self.errorMessage = "投稿の削除に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods

    /// サーバーから投稿の最新データを取得してローカル配列を更新
    private func refreshPost(id: UUID) async {
        do {
            let updatedPost = try await postRepository.getPost(id: id)

            await MainActor.run {
                // nearbyPosts配列を更新
                if let index = nearbyPosts.firstIndex(where: { $0.id == id }) {
                    nearbyPosts[index] = updatedPost
                }

                // posts配列を更新
                if let index = posts.firstIndex(where: { $0.id == id }) {
                    posts[index] = updatedPost
                }
            }
        } catch {
            // エラーは無視（UI更新は行わない）
        }
    }

    // パフォーマンス最適化: 重複コードを削減し、効率的な更新を実現
    private func updateLocalPostLikeCount(postID: UUID, increment: Bool) {
        // ヘルパー関数: Post配列内の特定IDの投稿のいいね数を更新
        func updatePostInArray(_ array: inout [Post], postID: UUID, increment: Bool) -> Bool {
            guard let index = array.firstIndex(where: { $0.id == postID }) else {
                return false
            }

            let updatedPost = array[index]
            let newLikeCount = increment ? updatedPost.likeCount + 1 : max(0, updatedPost.likeCount - 1)

            // Postは値型なので、新しいインスタンスを作成
            array[index] = Post(
                id: updatedPost.id,
                user: updatedPost.user,
                content: updatedPost.content,
                url: updatedPost.url,
                latitude: updatedPost.latitude,
                longitude: updatedPost.longitude,
                address: updatedPost.address,
                category: updatedPost.category,
                visibility: updatedPost.visibility,
                isUrgent: updatedPost.isUrgent,
                isVerified: updatedPost.isVerified,
                likeCount: newLikeCount,
                commentCount: updatedPost.commentCount,
                shareCount: updatedPost.shareCount,
                createdAt: updatedPost.createdAt,
                updatedAt: updatedPost.updatedAt
            )
            return true
        }

        // nearbyPostsとpostsを更新
        updatePostInArray(&nearbyPosts, postID: postID, increment: increment)
        updatePostInArray(&posts, postID: postID, increment: increment)
    }
}