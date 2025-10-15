import SwiftUI
import CoreLocation
import Combine

// MARK: - 近くの投稿ViewModel

@MainActor
class NearbyPostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dependencies = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()

    // パフォーマンス最適化: 最後のフェッチ位置を記録
    private var lastFetchLocation: CLLocation?
    private let minimumFetchDistance: Double = 500 // 500m以上移動したらフェッチ

    init() {
        setupBindings()
    }

    deinit {
        cancellables.removeAll()
        AppLogger.debug("deinit called")
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

    // MARK: - Fetch Methods

    func fetchNearbyPosts() {
        AppLogger.debug("fetchNearbyPosts() called")
        guard let location = dependencies.locationService.currentLocation else {
            AppLogger.info("位置情報がない - デフォルト位置（東京駅）を使用")
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

        AppLogger.debug("位置情報あり: lat=\(location.coordinate.latitude), lng=\(location.coordinate.longitude)")
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
            AppLogger.debug("移動距離: \(Int(distance))m - データフェッチを実行")
            lastFetchLocation = location
            await fetchNearbyPostsForLocation(location)
        } else {
            AppLogger.debug("移動距離: \(Int(distance))m - フェッチをスキップ（最小距離: \(Int(minimumFetchDistance))m）")
        }
    }

    private func fetchNearbyPostsForLocation(_ location: CLLocation) async {
        await fetchNearbyPostsForCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: 5000 // 5km
        )
    }

    private func fetchNearbyPostsForCoordinate(
        latitude: Double,
        longitude: Double,
        radius: Double
    ) async {
        AppLogger.debug("fetchNearbyPostsForCoordinate - lat: \(latitude), lng: \(longitude), radius: \(radius)m")
        do {
            isLoading = true
            errorMessage = nil

            await dependencies.postService.fetchNearbyPosts(
                latitude: latitude,
                longitude: longitude,
                radius: radius
            )

            AppLogger.debug("データ取得完了")

            // 距離を計算して設定
            let userLocation = CLLocation(latitude: latitude, longitude: longitude)
            if let postService = dependencies.postService as? PostService {
                AppLogger.debug("PostServiceから取得した投稿数: \(postService.nearbyPosts.count)")
                posts = postService.nearbyPosts.map { post in
                    var updatedPost = post
                    if let postLocation = post.location {
                        let distance = userLocation.distance(from: postLocation)
                        updatedPost.distance = distance
                    }
                    return updatedPost
                }
                AppLogger.debug("ViewModelに設定した投稿数: \(posts.count)")
            } else {
                AppLogger.error("PostServiceのキャストに失敗")
            }

            isLoading = false
        } catch {
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
