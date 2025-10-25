import Foundation
import CoreLocation
import Combine

// MARK: - News Service

@MainActor
class NewsService: ObservableObject {
    @Published var nearbyNews: [NewsStory] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var error: Error?

    private let repository: NewsRepositoryProtocol
    private let geocoder = CLGeocoder()

    // 逆ジオコーディングキャッシュ (座標 -> 都市名)
    private var reverseGeocodeCache: [String: String] = [:]

    // ページネーション管理
    private var allNewsCache: [NewsStory] = [] // 全データキャッシュ
    private var currentPage: Int = 0
    private let itemsPerPage: Int = 10

    var hasMoreNews: Bool {
        let totalLoaded = nearbyNews.count
        let totalAvailable = allNewsCache.count
        return totalLoaded < totalAvailable
    }

    init(repository: NewsRepositoryProtocol = NewsRepository()) {
        self.repository = repository
    }

    // MARK: - Fetch Nearby News

    /// 現在地の近くのニュースを取得（Google News RSS）
    func fetchNearbyNews(userLocation: CLLocationCoordinate2D, radiusKm: Double = 500) async {
        isLoading = true
        error = nil

        do {
            // 1. 逆ジオコーディング: 座標 -> 都市名
            guard let cityName = await reverseGeocodeCoordinate(userLocation) else {
                throw NewsServiceError.reverseGeocodingFailed
            }

            // 2. Google News RSSから都市名でニュースを取得
            let feed = try await repository.fetchNewsByKeyword(cityName)

            // 3. ニュースに距離情報を追加（全て同じ都市なので距離は0）
            let newsWithDistance = feed.items.map { story -> NewsStory in
                var mutableStory = story
                mutableStory.coordinate = userLocation
                mutableStory.distance = 0 // 同じ都市のニュースなので距離0
                return mutableStory
            }

            // 4. 最新順にソート（念のため二重チェック）
            let sortedNews = newsWithDistance.sorted { news1, news2 in
                guard let date1 = news1.pubDate, let date2 = news2.pubDate else {
                    return news1.pubDate != nil
                }
                return date1 > date2 // 降順（最新が先頭）
            }

            // 5. 全データをキャッシュして、最初の10件のみ表示
            allNewsCache = sortedNews
            currentPage = 0
            nearbyNews = Array(allNewsCache.prefix(itemsPerPage))

        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Pagination

    /// 次のページのニュースを読み込む
    func loadNextPage() {
        guard hasMoreNews, !isLoadingMore else {
            return
        }

        isLoadingMore = true

        // 次のページのデータを取得
        currentPage += 1
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, allNewsCache.count)

        guard startIndex < allNewsCache.count else {
            isLoadingMore = false
            return
        }

        let nextBatch = Array(allNewsCache[startIndex..<endIndex])
        nearbyNews.append(contentsOf: nextBatch)

        isLoadingMore = false
    }

    /// ページネーションをリセット
    func resetPagination() {
        allNewsCache.removeAll()
        nearbyNews.removeAll()
        currentPage = 0
    }

    // MARK: - Reverse Geocoding

    /// 座標を都市名に変換（キャッシュ対応）
    private func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)"

        // キャッシュチェック
        if let cached = reverseGeocodeCache[cacheKey] {
            return cached
        }

        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemarks = try await geocoder.reverseGeocodeLocation(location)

            if let placemark = placemarks.first {
                // 都市名を取得（locality優先、なければadministrativeArea）
                let cityName = placemark.locality ?? placemark.administrativeArea ?? placemark.country

                if let cityName = cityName {
                    // キャッシュに保存
                    reverseGeocodeCache[cacheKey] = cityName
                    return cityName
                }
            }
        } catch {
            // Reverse geocoding error
        }

        return nil
    }

    // MARK: - Clear Cache

    /// キャッシュをクリア
    func clearCache() {
        reverseGeocodeCache.removeAll()
        resetPagination()
    }
}

// MARK: - News Service Errors

enum NewsServiceError: LocalizedError {
    case reverseGeocodingFailed

    var errorDescription: String? {
        switch self {
        case .reverseGeocodingFailed:
            return "現在地の都市名を取得できませんでした"
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension NewsService {
    static func preview() -> NewsService {
        let service = NewsService()
        service.nearbyNews = [
            NewsStory(
                id: "CBMi123",
                title: "札幌で初雪観測 平年より5日早く - HTB北海道テレビ",
                link: "https://news.google.com/rss/articles/...",
                pubDate: Date(),
                description: "札幌管区気象台は24日、札幌で初雪を観測したと発表した。",
                source: "HTB北海道テレビ",
                coordinate: CLLocationCoordinate2D(latitude: 43.0642, longitude: 141.3469),
                distance: 0
            ),
            NewsStory(
                id: "CBMi456",
                title: "札幌市の公園にヒグマ2頭、緊急銃猟で駆除 - 読売新聞",
                link: "https://news.google.com/rss/articles/...",
                pubDate: Date(),
                description: "札幌市南区の公園にヒグマ2頭が出没し、駆除された。",
                source: "読売新聞",
                coordinate: CLLocationCoordinate2D(latitude: 43.0642, longitude: 141.3469),
                distance: 0
            )
        ]
        return service
    }
}
#endif
