import Foundation
import UIKit

// MARK: - 投稿作成・編集リクエスト

/// 投稿作成リクエスト
struct CreatePostRequest: Codable {
    let content: String
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let visibility: PostVisibility
    let allowComments: Bool
    let emergencyLevel: EmergencyLevel?
    let tags: [String]?
    let images: [UIImage] // エンコードされない
    
    enum CodingKeys: String, CodingKey {
        case content
        case latitude
        case longitude
        case locationName = "location_name"
        case visibility
        case allowComments = "allow_comments"
        case emergencyLevel = "emergency_level"
        case tags
    }
    
    init(content: String, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, visibility: PostVisibility = .public, allowComments: Bool = true, emergencyLevel: EmergencyLevel? = nil, tags: [String]? = nil, images: [UIImage] = []) {
        self.content = content
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.visibility = visibility
        self.allowComments = allowComments
        self.emergencyLevel = emergencyLevel
        self.tags = tags
        self.images = images
    }
    
    // Codable conformance for properties other than images
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(locationName, forKey: .locationName)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(allowComments, forKey: .allowComments)
        try container.encodeIfPresent(emergencyLevel, forKey: .emergencyLevel)
        try container.encodeIfPresent(tags, forKey: .tags)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        visibility = try container.decode(PostVisibility.self, forKey: .visibility)
        allowComments = try container.decode(Bool.self, forKey: .allowComments)
        emergencyLevel = try container.decodeIfPresent(EmergencyLevel.self, forKey: .emergencyLevel)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        images = [] // デコード時は空配列
    }
}

/// 投稿更新リクエスト
struct UpdatePostRequest: Codable {
    let postID: UUID
    let content: String
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let visibility: PostVisibility
    let allowComments: Bool
    let emergencyLevel: EmergencyLevel?
    let tags: [String]?
    let newImages: [UIImage] // エンコードされない
    let existingMediaFiles: [MediaFile]
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case content
        case latitude
        case longitude
        case locationName = "location_name"
        case visibility
        case allowComments = "allow_comments"
        case emergencyLevel = "emergency_level"
        case tags
        case existingMediaFiles = "existing_media_files"
    }
    
    init(postID: UUID, content: String, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, visibility: PostVisibility = .public, allowComments: Bool = true, emergencyLevel: EmergencyLevel? = nil, tags: [String]? = nil, newImages: [UIImage] = [], existingMediaFiles: [MediaFile] = []) {
        self.postID = postID
        self.content = content
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.visibility = visibility
        self.allowComments = allowComments
        self.emergencyLevel = emergencyLevel
        self.tags = tags
        self.newImages = newImages
        self.existingMediaFiles = existingMediaFiles
    }
    
    // Codable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postID, forKey: .postID)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(locationName, forKey: .locationName)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(allowComments, forKey: .allowComments)
        try container.encodeIfPresent(emergencyLevel, forKey: .emergencyLevel)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(existingMediaFiles, forKey: .existingMediaFiles)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postID = try container.decode(UUID.self, forKey: .postID)
        content = try container.decode(String.self, forKey: .content)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        visibility = try container.decode(PostVisibility.self, forKey: .visibility)
        allowComments = try container.decode(Bool.self, forKey: .allowComments)
        emergencyLevel = try container.decodeIfPresent(EmergencyLevel.self, forKey: .emergencyLevel)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        existingMediaFiles = try container.decode([MediaFile].self, forKey: .existingMediaFiles)
        newImages = [] // デコード時は空配列
    }
}

// MARK: - 投稿検索・フィルター

/// 投稿検索リクエスト
struct PostSearchRequest: Codable {
    let query: String?
    let latitude: Double?
    let longitude: Double?
    let radius: Double? // メートル単位
    let category: PostCategory?
    let emergencyLevel: EmergencyLevel?
    let tags: [String]?
    let userID: UUID?
    let startDate: Date?
    let endDate: Date?
    let limit: Int
    let offset: Int
    
    enum CodingKeys: String, CodingKey {
        case query
        case latitude
        case longitude
        case radius
        case category
        case emergencyLevel = "emergency_level"
        case tags
        case userID = "user_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case limit
        case offset
    }
    
    init(query: String? = nil, latitude: Double? = nil, longitude: Double? = nil, radius: Double? = nil, category: PostCategory? = nil, emergencyLevel: EmergencyLevel? = nil, tags: [String]? = nil, userID: UUID? = nil, startDate: Date? = nil, endDate: Date? = nil, limit: Int = 20, offset: Int = 0) {
        self.query = query
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.category = category
        self.emergencyLevel = emergencyLevel
        self.tags = tags
        self.userID = userID
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
        self.offset = offset
    }
}

/// 位置ベース投稿取得リクエスト
struct LocationBasedPostsRequest: Codable {
    let latitude: Double
    let longitude: Double
    let radius: Double // メートル単位
    let limit: Int
    let offset: Int
    let includeEmergencyOnly: Bool
    
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case radius
        case limit
        case offset
        case includeEmergencyOnly = "include_emergency_only"
    }
    
    init(latitude: Double, longitude: Double, radius: Double = 1000, limit: Int = 20, offset: Int = 0, includeEmergencyOnly: Bool = false) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.limit = limit
        self.offset = offset
        self.includeEmergencyOnly = includeEmergencyOnly
    }
}

// MARK: - 投稿インタラクション

/// いいねリクエスト
struct LikePostRequest: Codable {
    let postID: UUID
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
    }
}

/// シェアリクエスト
struct SharePostRequest: Codable {
    let postID: UUID
    let shareType: ShareType
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case shareType = "share_type"
        case message
    }
}

enum ShareType: String, Codable, CaseIterable {
    case repost = "repost"
    case quote = "quote"
    case external = "external"
    
    var displayName: String {
        switch self {
        case .repost:
            return "リポスト"
        case .quote:
            return "引用投稿"
        case .external:
            return "外部シェア"
        }
    }
}

/// 投稿報告リクエスト
struct ReportPostRequest: Codable {
    let postID: UUID
    let reason: ReportReason
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case reason
        case description
    }
}

enum ReportReason: String, Codable, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case misinformation = "misinformation"
    case inappropriate = "inappropriate"
    case violence = "violence"
    case hateSpeech = "hate_speech"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .spam:
            return "スパム"
        case .harassment:
            return "ハラスメント"
        case .misinformation:
            return "誤情報"
        case .inappropriate:
            return "不適切な内容"
        case .violence:
            return "暴力的な内容"
        case .hateSpeech:
            return "ヘイトスピーチ"
        case .other:
            return "その他"
        }
    }
    
    var description: String {
        switch self {
        case .spam:
            return "宣伝や無関係な内容の投稿"
        case .harassment:
            return "特定の人物への嫌がらせ"
        case .misinformation:
            return "事実と異なる情報の拡散"
        case .inappropriate:
            return "不適切または有害な内容"
        case .violence:
            return "暴力を助長する内容"
        case .hateSpeech:
            return "差別的な発言や表現"
        case .other:
            return "上記以外の問題"
        }
    }
}

// MARK: - 投稿下書き

/// 下書き保存リクエスト
struct SaveDraftRequest: Codable {
    let content: String
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let visibility: PostVisibility
    let allowComments: Bool
    let emergencyLevel: EmergencyLevel?
    let tags: [String]?
    let images: [UIImage] // エンコードされない
    
    enum CodingKeys: String, CodingKey {
        case content
        case latitude
        case longitude
        case locationName = "location_name"
        case visibility
        case allowComments = "allow_comments"
        case emergencyLevel = "emergency_level"
        case tags
    }
    
    init(content: String, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, visibility: PostVisibility = .public, allowComments: Bool = true, emergencyLevel: EmergencyLevel? = nil, tags: [String]? = nil, images: [UIImage] = []) {
        self.content = content
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.visibility = visibility
        self.allowComments = allowComments
        self.emergencyLevel = emergencyLevel
        self.tags = tags
        self.images = images
    }
    
    // Codable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(locationName, forKey: .locationName)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(allowComments, forKey: .allowComments)
        try container.encodeIfPresent(emergencyLevel, forKey: .emergencyLevel)
        try container.encodeIfPresent(tags, forKey: .tags)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        visibility = try container.decode(PostVisibility.self, forKey: .visibility)
        allowComments = try container.decode(Bool.self, forKey: .allowComments)
        emergencyLevel = try container.decodeIfPresent(EmergencyLevel.self, forKey: .emergencyLevel)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        images = [] // デコード時は空配列
    }
}

/// 下書きデータモデル
struct PostDraft: Identifiable, Codable {
    let id: UUID
    let content: String
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let visibility: PostVisibility
    let allowComments: Bool
    let emergencyLevel: EmergencyLevel?
    let tags: [String]?
    let mediaFiles: [MediaFile]?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case latitude
        case longitude
        case locationName = "location_name"
        case visibility
        case allowComments = "allow_comments"
        case emergencyLevel = "emergency_level"
        case tags
        case mediaFiles = "media_files"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var preview: String {
        let maxLength = 50
        if content.count <= maxLength {
            return content
        } else {
            return String(content.prefix(maxLength)) + "..."
        }
    }
    
    var hasMedia: Bool {
        return mediaFiles?.isEmpty == false
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
    
    var hasTags: Bool {
        return tags?.isEmpty == false
    }
}