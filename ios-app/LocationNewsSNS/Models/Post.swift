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
    let isEmergency: Bool
    let emergencyLevel: EmergencyLevel?
    let trustScore: Double
    let mediaFiles: [MediaFile]
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let createdAt: Date
    let updatedAt: Date

    // カルーセル表示用のプロパティ
    var userName: String? { user.displayName ?? user.username }
    var mediaUrls: [String]? { mediaFiles.isEmpty ? nil : mediaFiles.map { $0.url } }
    var distance: Double? = nil // 現在位置からの距離（メートル）

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
        case isEmergency = "is_emergency"
        case emergencyLevel = "emergency_level"
        case trustScore = "trust_score"
        case mediaFiles = "media_files"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 投稿カテゴリ
enum PostCategory: String, Codable, CaseIterable {
    case news = "news"                 // ニュース
    case traffic = "traffic"           // 交通情報
    case weather = "weather"           // 天気・気象
    case crime = "crime"               // 犯罪・治安
    case emergency = "emergency"       // 緊急情報
    case community = "community"       // 地域情報
    case business = "business"         // 店舗・ビジネス
    case sports = "sports"             // スポーツ
    case entertainment = "entertainment" // エンターテイメント
    case other = "other"               // その他
    
    /// カテゴリの表示名
    var displayName: String {
        switch self {
        case .news: return "ニュース"
        case .traffic: return "交通情報"
        case .weather: return "天気・気象"
        case .crime: return "犯罪・治安"
        case .emergency: return "緊急情報"
        case .community: return "地域情報"
        case .business: return "店舗・ビジネス"
        case .sports: return "スポーツ"
        case .entertainment: return "エンターテイメント"
        case .other: return "その他"
        }
    }
    
    /// カテゴリのアイコン
    var iconName: String {
        switch self {
        case .news: return "newspaper"
        case .traffic: return "car"
        case .weather: return "cloud.sun"
        case .crime: return "shield.lefthalf.filled"
        case .emergency: return "exclamationmark.triangle"
        case .community: return "building.2"
        case .business: return "storefront"
        case .sports: return "sportscourt"
        case .entertainment: return "party.popper"
        case .other: return "ellipsis.circle"
        }
    }
}

/// 投稿の公開範囲
enum PostVisibility: String, Codable, CaseIterable {
    case `public` = "public"    // 全体公開
    case followers = "followers"  // フォロワーのみ
    case area = "area"           // 地域限定
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

    /// 緊急投稿かどうか
    var isUrgent: Bool {
        return isEmergency || category == .emergency
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

    /// 検証済み投稿かどうか（信頼スコアが0.7以上）
    var isVerified: Bool {
        return trustScore >= 0.7
    }
}