import Foundation
import CoreLocation

// MARK: - News Story Model (Google News RSS)

/// Google News RSSから取得するニュースストーリー
struct NewsStory: Identifiable, Equatable {
    let id: String // <guid>
    let title: String // <title>
    let link: String // <link>
    let pubDate: Date? // <pubDate>
    let description: String? // <description>
    let source: String? // <source>

    // ジオコーディング結果（ローカルで追加）
    var coordinate: CLLocationCoordinate2D?
    var distance: Double? // メートル単位

    // MARK: - Equatable

    static func == (lhs: NewsStory, rhs: NewsStory) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - RSS Feed Response Models

/// RSSフィード全体
struct RSSFeed {
    let title: String
    let link: String
    let language: String?
    let lastBuildDate: Date?
    var items: [NewsStory] // ソート可能にするためvarに変更
}
