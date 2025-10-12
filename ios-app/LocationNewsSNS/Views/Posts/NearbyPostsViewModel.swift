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

    init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // PostServiceの投稿リストを監視（PostServiceが具体的な実装であることを確認）
        if let postService = dependencies.postService as? PostService {
            postService.$nearbyPosts
                .receive(on: DispatchQueue.main)
                .sink { [weak self] posts in
                    self?.posts = posts
                }
                .store(in: &cancellables)
        }

        // LocationServiceの位置情報を監視して自動更新
        if let locationService = dependencies.locationService as? LocationService {
            locationService.$currentLocation
                .compactMap { $0 }
                .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
                .sink { [weak self] location in
                    Task {
                        await self?.fetchNearbyPostsForLocation(location)
                    }
                }
                .store(in: &cancellables)
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
        do {
            isLoading = true
            errorMessage = nil

            await dependencies.postService.fetchNearbyPosts(
                latitude: latitude,
                longitude: longitude,
                radius: radius
            )

            // 距離を計算して設定
            let userLocation = CLLocation(latitude: latitude, longitude: longitude)
            if let postService = dependencies.postService as? PostService {
                posts = postService.nearbyPosts.map { post in
                    var updatedPost = post
                    if let postLocation = post.location {
                        let distance = userLocation.distance(from: postLocation)
                        updatedPost.distance = distance
                    }
                    return updatedPost
                }
            }

            isLoading = false
        } catch {
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
