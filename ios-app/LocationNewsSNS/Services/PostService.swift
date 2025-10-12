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
            print("投稿取得エラー: \(error)")
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
            
        } catch {
            print("いいね取り消しエラー: \(error)")
            await MainActor.run {
                self.errorMessage = "いいねの取り消しに失敗しました: \(error.localizedDescription)"
            }
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
    
    private func updateLocalPostLikeCount(postID: UUID, increment: Bool) {
        // nearbyPostsを更新
        if let index = nearbyPosts.firstIndex(where: { $0.id == postID }) {
            let updatedPost = nearbyPosts[index]
            let newLikeCount = increment ? updatedPost.likeCount + 1 : max(0, updatedPost.likeCount - 1)
            
            // Postは値型なので、新しいインスタンスを作成
            let newPost = Post(
                id: updatedPost.id,
                user: updatedPost.user,
                content: updatedPost.content,
                url: updatedPost.url,
                latitude: updatedPost.latitude,
                longitude: updatedPost.longitude,
                address: updatedPost.address,
                category: updatedPost.category,
                visibility: updatedPost.visibility,
                isEmergency: updatedPost.isEmergency,
                emergencyLevel: updatedPost.emergencyLevel,
                trustScore: updatedPost.trustScore,
                mediaFiles: updatedPost.mediaFiles,
                likeCount: newLikeCount,
                commentCount: updatedPost.commentCount,
                shareCount: updatedPost.shareCount,
                createdAt: updatedPost.createdAt,
                updatedAt: updatedPost.updatedAt
            )
            
            nearbyPosts[index] = newPost
        }
        
        // postsも更新
        if let index = posts.firstIndex(where: { $0.id == postID }) {
            let updatedPost = posts[index]
            let newLikeCount = increment ? updatedPost.likeCount + 1 : max(0, updatedPost.likeCount - 1)
            
            let newPost = Post(
                id: updatedPost.id,
                user: updatedPost.user,
                content: updatedPost.content,
                url: updatedPost.url,
                latitude: updatedPost.latitude,
                longitude: updatedPost.longitude,
                address: updatedPost.address,
                category: updatedPost.category,
                visibility: updatedPost.visibility,
                isEmergency: updatedPost.isEmergency,
                emergencyLevel: updatedPost.emergencyLevel,
                trustScore: updatedPost.trustScore,
                mediaFiles: updatedPost.mediaFiles,
                likeCount: newLikeCount,
                commentCount: updatedPost.commentCount,
                shareCount: updatedPost.shareCount,
                createdAt: updatedPost.createdAt,
                updatedAt: updatedPost.updatedAt
            )

            posts[index] = newPost
        }
    }
}