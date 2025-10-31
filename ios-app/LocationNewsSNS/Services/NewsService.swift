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
        print("🔍 [NewsService] fetchNearbyNews開始 - lat=\(userLocation.latitude), lng=\(userLocation.longitude), radius=\(radiusKm)km")
        isLoading = true
        error = nil

        do {
            // 1. 逆ジオコーディング: 座標 -> 都市名
            print("🌍 [NewsService] 逆ジオコーディング開始")
            guard let cityName = await reverseGeocodeCoordinate(userLocation) else {
                print("❌ [NewsService] 逆ジオコーディング失敗")
                throw NewsServiceError.reverseGeocodingFailed
            }
            print("✅ [NewsService] 逆ジオコーディング成功 - 都市名: \(cityName)")

            // 2. Google News RSSから都市名でニュースを取得
            print("📡 [NewsService] Google News API呼び出し開始 - keyword: \(cityName)")
            let feed = try await repository.fetchNewsByKeyword(cityName)
            print("✅ [NewsService] API呼び出し成功 - 取得件数: \(feed.items.count)")

            // 3. ニュースに距離情報を追加（全て同じ都市なので距離は0）
            let newsWithDistance = feed.items.map { story -> NewsStory in
                var mutableStory = story
                mutableStory.coordinate = userLocation
                mutableStory.distance = 0 // 同じ都市のニュースなので距離0
                return mutableStory
            }

            // 4. 3日以内の記事のみにフィルタリング
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            let filteredNews = newsWithDistance.filter { story in
                guard let pubDate = story.pubDate else { return false }
                return pubDate >= threeDaysAgo
            }

            // 5. 最新順にソート（念のため二重チェック）
            let sortedNews = filteredNews.sorted { news1, news2 in
                guard let date1 = news1.pubDate, let date2 = news2.pubDate else {
                    return news1.pubDate != nil
                }
                return date1 > date2 // 降順（最新が先頭）
            }

            // 6. 全データをキャッシュして、最初の10件のみ表示
            allNewsCache = sortedNews
            currentPage = 0
            nearbyNews = Array(allNewsCache.prefix(itemsPerPage))
            print("📊 [NewsService] ニュース表示準備完了 - 表示件数: \(nearbyNews.count), 全体キャッシュ: \(allNewsCache.count)")

        } catch {
            print("❌ [NewsService] エラー発生: \(error.localizedDescription)")
            self.error = error
        }

        isLoading = false
        print("🏁 [NewsService] fetchNearbyNews完了 - 最終件数: \(nearbyNews.count)")
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
            print("💾 [NewsService] キャッシュから都市名取得: \(cached)")
            return cached
        }

        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            print("🌐 [NewsService] CLGeocoder呼び出し中...")
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            print("✅ [NewsService] CLGeocoder成功 - placemarks件数: \(placemarks.count)")

            if let placemark = placemarks.first {
                // 都市名を取得（locality優先、なければadministrativeArea）
                let cityName = placemark.locality ?? placemark.administrativeArea ?? placemark.country
                print("📍 [NewsService] Placemark情報 - locality: \(placemark.locality ?? "nil"), administrativeArea: \(placemark.administrativeArea ?? "nil"), country: \(placemark.country ?? "nil")")

                if let cityName = cityName {
                    // キャッシュに保存
                    reverseGeocodeCache[cacheKey] = cityName
                    print("✅ [NewsService] 都市名取得成功: \(cityName)")
                    return cityName
                } else {
                    print("⚠️ [NewsService] 都市名が取得できませんでした")
                }
            } else {
                print("⚠️ [NewsService] Placemarkが空です")
            }
        } catch {
            print("❌ [NewsService] 逆ジオコーディングエラー: \(error.localizedDescription)")
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
