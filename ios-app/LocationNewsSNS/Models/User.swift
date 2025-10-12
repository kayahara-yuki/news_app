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
    let locationPrecision: String
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