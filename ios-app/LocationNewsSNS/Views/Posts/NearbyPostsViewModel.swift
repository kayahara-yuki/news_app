import SwiftUI
import CoreLocation
import Combine

// MARK: - 近くの投稿ViewModel

@MainActor
class NearbyPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = true // 初期状態をtrueに変更（アプリ起動時のロード中状態）
    @Published var errorMessage: String?

    private let dependencies = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()

    // パフォーマンス最適化: 最後のフェッチ位置を記録
    private var lastFetchLocation: CLLocation?
    private let minimumFetchDistance: Double = 500 // 500m以上移動したらフェッチ

    init() {
        setupBindings()
        setupNotificationObservers()
    }

    deinit {
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupBindings() {
        // パフォーマンス最適化: PostServiceから直接監視するのではなく、
        // 位置更新時のみ明示的にフェッチする方式に変更（二重Publisher構造を解消）

        // LocationServiceの位置情報を監視して自動更新
        // パフォーマンス最適化: debounce時間を10秒に延長
        if let locationService = dependencies.locationService as? LocationService {
            locationService.$currentLocation
                .compactMap { $0 }
                .debounce(for: .seconds(10), scheduler: DispatchQueue.main)
                .sink { [weak self] location in
                    Task {
                        await self?.fetchNearbyPostsIfNeeded(location)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func setupNotificationObservers() {
        // 投稿更新の通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePostUpdated(_:)),
            name: .postUpdated,
            object: nil
        )
    }

    @objc private func handlePostUpdated(_ notification: Notification) {
        guard let postId = notification.userInfo?["postId"] as? UUID,
              let likeCount = notification.userInfo?["likeCount"] as? Int else {
            return
        }

        // posts配列内の該当する投稿を更新
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            let originalPost = posts[index]
            let updatedPost = Post(
                id: originalPost.id,
                user: originalPost.user,
                content: originalPost.content,
                url: originalPost.url,
                latitude: originalPost.latitude,
                longitude: originalPost.longitude,
                address: originalPost.address,
                category: originalPost.category,
                visibility: originalPost.visibility,
                isUrgent: originalPost.isUrgent,
                isVerified: originalPost.isVerified,
                likeCount: likeCount,
                commentCount: originalPost.commentCount,
                shareCount: originalPost.shareCount,
                createdAt: originalPost.createdAt,
                updatedAt: originalPost.updatedAt,
                audioURL: originalPost.audioURL,
                isStatusPost: originalPost.isStatusPost,
                expiresAt: originalPost.expiresAt
            )

            posts[index] = updatedPost
        }
    }

    // MARK: - Fetch Methods

    func fetchNearbyPosts() {
        guard let location = dependencies.locationService.currentLocation else {
            // 位置情報がない場合はデフォルト位置（東京駅）を使用
            Task {
                await fetchNearbyPostsForCoordinate(
                    latitude: 35.6762,
                    longitude: 139.6503,
                    radius: 5000 // 5km
                )
            }
            return
        }

        Task {
            await fetchNearbyPostsForLocation(location)
        }
    }

    func refreshPosts() async {
        isLoading = true
        errorMessage = nil

        guard let location = dependencies.locationService.currentLocation else {
            await fetchNearbyPostsForCoordinate(
                latitude: 35.6762,
                longitude: 139.6503,
                radius: 5000
            )
            isLoading = false
            return
        }

        await fetchNearbyPostsForLocation(location)
        isLoading = false
    }

    // パフォーマンス最適化: 距離条件付きフェッチ
    private func fetchNearbyPostsIfNeeded(_ location: CLLocation) async {
        // 最後のフェッチ位置がない場合は必ずフェッチ
        guard let lastLocation = lastFetchLocation else {
            lastFetchLocation = location
            await fetchNearbyPostsForLocation(location)
            return
        }

        // 最後のフェッチ位置から500m以上移動した場合のみフェッチ
        let distance = location.distance(from: lastLocation)
        if distance >= minimumFetchDistance {
            lastFetchLocation = location
            await fetchNearbyPostsForLocation(location)
        }
    }

    private func fetchNearbyPostsForLocation(_ location: CLLocation) async {
        await fetchNearbyPostsForCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: 5000 // 5km
        )
    }

    func fetchNearbyPostsForCoordinate(
        latitude: Double,
        longitude: Double,
        radius: Double
    ) async {
        print("🌟 [NearbyPostsViewModel] fetchNearbyPostsForCoordinate開始")
        print("📍 [NearbyPostsViewModel] パラメータ: lat=\(latitude), lng=\(longitude), radius=\(radius)m")

        do {
            isLoading = true
            errorMessage = nil

            print("📡 [NearbyPostsViewModel] PostService呼び出し中...")
            await dependencies.postService.fetchNearbyPosts(
                latitude: latitude,
                longitude: longitude,
                radius: radius
            )

            // 距離を計算して設定（バックグラウンドスレッドで実行）
            let userLocation = CLLocation(latitude: latitude, longitude: longitude)
            if let postService = dependencies.postService as? PostService {
                let nearbyPosts = postService.nearbyPosts

                print("📊 [NearbyPostsViewModel] PostServiceから取得: \(nearbyPosts.count)件")

                if nearbyPosts.isEmpty {
                    print("⚠️ [NearbyPostsViewModel] 警告: PostServiceから0件の投稿")
                }

                // 距離計算をバックグラウンドで実行
                let postsWithDistance = await Task.detached {
                    nearbyPosts.map { post in
                        var updatedPost = post
                        if let postLocation = post.location {
                            let distance = userLocation.distance(from: postLocation)
                            updatedPost.distance = distance
                        }
                        return updatedPost
                    }
                }.value

                // メインスレッドで結果を設定
                posts = postsWithDistance
                print("✅ [NearbyPostsViewModel] posts配列更新完了: \(posts.count)件")

                if !posts.isEmpty {
                    print("✅ [NearbyPostsViewModel] 最初の投稿: id=\(posts[0].id), content=\(posts[0].content.prefix(30))...")
                }
            } else {
                print("❌ [NearbyPostsViewModel] PostServiceのキャストに失敗")
                AppLogger.error("PostServiceのキャストに失敗")
            }

            isLoading = false
        } catch {
            print("❌ [NearbyPostsViewModel] エラー発生: \(error)")
            print("❌ [NearbyPostsViewModel] エラー詳細: \(error.localizedDescription)")
            AppLogger.error("エラー: \(error.localizedDescription)")
            errorMessage = "投稿の取得に失敗しました: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Filter Methods

    func filterByCategory(_ category: PostCategory) {
        if let postService = dependencies.postService as? PostService {
            posts = postService.nearbyPosts.filter { $0.category == category }
        }
    }

    func filterByEmergency() {
        if let postService = dependencies.postService as? PostService {
            posts = postService.nearbyPosts.filter { $0.isEmergency }
        }
    }

    func clearFilters() {
        if let postService = dependencies.postService as? PostService {
            posts = postService.nearbyPosts
        }
    }
}
