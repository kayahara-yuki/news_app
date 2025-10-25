import Foundation
import Supabase

// MARK: - User関連のデータモデル

/// ユーザープロフィール
struct UserProfile: Codable, Identifiable {
    let id: UUID
    let email: String
    let username: String
    let displayName: String?
    let bio: String?
    let avatarURL: String?
    let location: String?
    let isVerified: Bool
    let role: UserRole
    let privacySettings: PrivacySettings?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case location
        case isVerified = "is_verified"
        case role
        case privacySettings = "privacy_settings"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // 通常のイニシャライザ（コードから直接生成する場合）
    init(
        id: UUID,
        email: String,
        username: String,
        displayName: String? = nil,
        bio: String? = nil,
        avatarURL: String? = nil,
        location: String? = nil,
        isVerified: Bool = false,
        role: UserRole = .user,
        privacySettings: PrivacySettings? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.avatarURL = avatarURL
        self.location = location
        self.isVerified = isVerified
        self.role = role
        self.privacySettings = privacySettings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // カスタムデコーダー - ISO8601形式の日付文字列をパース
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        isVerified = try container.decode(Bool.self, forKey: .isVerified)
        role = try container.decode(UserRole.self, forKey: .role)
        privacySettings = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacySettings)

        // 日付文字列をパース（複数のフォーマットに対応）
        createdAt = try Self.decodeDate(from: container, forKey: .createdAt)
        updatedAt = try Self.decodeDate(from: container, forKey: .updatedAt)
    }

    // 柔軟な日付デコード処理
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date {
        // まず文字列としてデコードを試みる
        if let dateString = try? container.decode(String.self, forKey: key) {
            // ISO8601形式でパース（複数のバリエーションに対応）
            let formatters: [ISO8601DateFormatter] = [
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return formatter
                }(),
                {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime]
                    return formatter
                }(),
                {
                    let formatter = ISO8601DateFormatter()
                    return formatter
                }()
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            // DateFormatterでもう一度試す（PostgreSQLのタイムスタンプフォーマット対応）
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            // マイクロ秒なしのフォーマットも試す
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            // さらに別のフォーマットも試す
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
            if let date = dateFormatter.date(from: dateString) {
                return date
            }

        }

        // Doubleとしてデコードを試みる（タイムスタンプ）
        if let timestamp = try? container.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestamp)
        }

        // どちらも失敗した場合は現在時刻を返す（エラーを避けるため）
        return Date()
    }
}

/// ユーザーロール
enum UserRole: String, Codable, CaseIterable {
    case user = "user"
    case moderator = "moderator"
    case admin = "admin"
    case official = "official" // 公式機関
}

/// プライバシー設定
struct PrivacySettings: Codable {
    let locationSharing: Bool
    let locationPrecision: String?
    let profileVisibility: String
    let emergencyOverride: Bool

    enum CodingKeys: String, CodingKey {
        case locationSharing = "locationSharing"
        case locationPrecision = "locationPrecision"
        case profileVisibility = "profileVisibility"
        case emergencyOverride = "emergencyOverride"
    }

    static let `default` = PrivacySettings(
        locationSharing: true,
        locationPrecision: "city",
        profileVisibility: "public",
        emergencyOverride: true
    )
}

/// 位置情報の精度設定
enum LocationPrecision: String, Codable, CaseIterable {
    case exact = "exact"           // 正確な位置
    case approximate = "approximate" // 大まかな位置（100m程度の誤差）
    case areaOnly = "area_only"     // エリアのみ（1km四方）
}

/// プロフィールの公開設定
enum ProfileVisibility: String, Codable, CaseIterable {
    case publicProfile = "public"    // 全体公開
    case followers = "followers"     // フォロワーのみ
    case privateProfile = "private"  // 非公開
}

/// データ保持設定
struct DataRetentionSettings: Codable {
    let autoDeletePosts: Bool      // 投稿の自動削除
    let retentionDays: Int         // 保持期間（日数）
    let deleteLocationHistory: Bool // 位置履歴の削除
    
    enum CodingKeys: String, CodingKey {
        case autoDeletePosts = "auto_delete_posts"
        case retentionDays = "retention_days"
        case deleteLocationHistory = "delete_location_history"
    }
}

/// フォロー関係
struct UserFollow: Codable, Identifiable {
    let id: UUID
    let followerID: UUID
    let followingID: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerID = "follower_id"
        case followingID = "following_id"
        case createdAt = "created_at"
    }
}

// MARK: - UserProfile Extensions

extension UserProfile {
    /// デフォルトのプライバシー設定
    static func defaultPrivacySettings() -> PrivacySettings {
        return PrivacySettings.default
    }
    
    /// 表示用の名前を取得
    var displayNameOrUsername: String {
        return displayName ?? username
    }
    
    /// 公式アカウントかどうか
    var isOfficial: Bool {
        return role == .official || role == .admin
    }
    
    /// モデレーター権限があるかどうか
    var hasModeratorPrivileges: Bool {
        return role == .moderator || role == .admin
    }
}