import Foundation
import CoreLocation

// MARK: - Post関連のデータモデル

/// 投稿
struct Post: Codable, Identifiable {
    let id: UUID
    let user: UserProfile
    let content: String
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let category: PostCategory
    let visibility: PostVisibility
    let isUrgent: Bool
    let isVerified: Bool
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let createdAt: Date
    let updatedAt: Date

    // 新規追加: 音声メッセージ投稿機能
    let audioURL: String?

    // 新規追加: ステータス投稿機能
    let isStatusPost: Bool
    let expiresAt: Date?

    // カルーセル表示用のプロパティ
    var userName: String? { user.displayName ?? user.username }
    var distance: Double? = nil // 現在位置からの距離（メートル）

    // MARK: - Computed Properties

    /// 投稿が期限切れかどうか
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// 残り時間（秒）
    var remainingTime: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }

    /// 残り時間のテキスト表示
    /// - Returns: 「あと2時間で削除」「あと45分で削除」「まもなく削除」「削除済み」
    var remainingTimeText: String? {
        guard let remainingTime = remainingTime else { return nil }

        // 期限切れ
        if remainingTime <= 0 {
            return "削除済み"
        }

        // 1分未満
        if remainingTime < 60 {
            return "まもなく削除"
        }

        // 1時間未満
        if remainingTime < 3600 {
            let minutes = Int(remainingTime / 60)
            return "あと\(minutes)分で削除"
        }

        // 1時間以上
        let hours = Int(remainingTime / 3600)
        return "あと\(hours)時間で削除"
    }

    /// 「まもなく削除されます」バッジを表示すべきかどうか
    /// - Returns: 残り時間が1時間未満かつ期限切れでない場合にtrue
    var shouldShowExpiringBadge: Bool {
        guard let remainingTime = remainingTime else { return false }
        return remainingTime > 0 && remainingTime < 3600
    }

    /// 投稿からステータスタイプを推測
    ///
    /// 投稿のcontentがStatusTypeのrawValueと一致する場合、該当するStatusTypeを返す
    ///
    /// - Returns: 一致するStatusType、またはnil
    var statusType: StatusType? {
        guard isStatusPost else { return nil }
        return StatusType.allCases.first { $0.rawValue == content }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case content
        case url
        case latitude
        case longitude
        case address
        case category
        case visibility
        case isUrgent = "is_urgent"
        case isVerified = "is_verified"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case audioURL = "audio_url"
        case isStatusPost = "is_status_post"
        case expiresAt = "expires_at"
    }
}

/// 投稿カテゴリ
enum PostCategory: String, Codable, CaseIterable {
    case news = "news"                 // ニュース
    case event = "event"               // イベント
    case emergency = "emergency"       // 緊急情報
    case traffic = "traffic"           // 交通情報
    case weather = "weather"           // 天気・気象
    case social = "social"             // ソーシャル
    case business = "business"         // 店舗・ビジネス
    case other = "other"               // その他
    
    /// カテゴリの表示名
    var displayName: String {
        switch self {
        case .news: return "ニュース"
        case .event: return "イベント"
        case .emergency: return "緊急情報"
        case .traffic: return "交通情報"
        case .weather: return "天気・気象"
        case .social: return "ソーシャル"
        case .business: return "店舗・ビジネス"
        case .other: return "その他"
        }
    }
    
    /// カテゴリのアイコン
    var iconName: String {
        switch self {
        case .news: return "newspaper"
        case .event: return "calendar"
        case .emergency: return "exclamationmark.triangle"
        case .traffic: return "car"
        case .weather: return "cloud.sun"
        case .social: return "person.2"
        case .business: return "storefront"
        case .other: return "ellipsis.circle"
        }
    }
}

/// 投稿の公開範囲
enum PostVisibility: String, Codable, CaseIterable {
    case `public` = "public"    // 全体公開
    case followers = "followers"  // フォロワーのみ
    case `private` = "private"   // 非公開
}

/// メディアファイル
struct MediaFile: Codable, Identifiable {
    let id: UUID
    let type: MediaType
    let url: String
    let thumbnailURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case url
        case thumbnailURL = "thumbnail_url"
    }
}

/// メディアタイプ
enum MediaType: String, Codable, CaseIterable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
}

/// リアクションタイプ
enum ReactionType: String, Codable, CaseIterable {
    case like = "like"       // いいね
    case love = "love"       // 愛
    case laugh = "laugh"     // 笑い
    case angry = "angry"     // 怒り
    case sad = "sad"         // 悲しみ
    
    /// リアクションの絵文字
    var emoji: String {
        switch self {
        case .like: return "👍"
        case .love: return "❤️"
        case .laugh: return "😂"
        case .angry: return "😠"
        case .sad: return "😢"
        }
    }
}

// MARK: - Post Extensions

extension Post {
    /// 投稿の位置情報
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 投稿の位置
    var location: CLLocation? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    /// 緊急投稿かどうか（互換性のため残す）
    var isEmergency: Bool {
        return isUrgent || category == .emergency
    }

    /// 投稿の経過時間を表示用文字列で取得
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// ニュース投稿かどうか
    var isNewsPost: Bool {
        return url != nil && category == .news
    }

    /// 位置情報が有効かどうか
    var hasValidLocation: Bool {
        guard let lat = latitude, let lng = longitude else { return false }
        return (-90...90).contains(lat) && (-180...180).contains(lng)
    }

    /// Map上に表示可能かどうか
    var canShowOnMap: Bool {
        return hasValidLocation
    }

}