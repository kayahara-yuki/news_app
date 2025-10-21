import Foundation
import Supabase
import CoreLocation

// MARK: - User Repository Protocol

protocol UserRepositoryProtocol {
    func getUser(id: UUID) async throws -> UserProfile
    func getUserByUsername(_ username: String) async throws -> UserProfile?
    func getUserByEmail(_ email: String) async throws -> UserProfile?
    func createUser(_ profile: UserProfile) async throws -> UserProfile
    func updateUser(_ profile: UserProfile) async throws -> UserProfile
    func deleteUser(id: UUID) async throws
    func followUser(userID: UUID, targetUserID: UUID) async throws
    func unfollowUser(userID: UUID, targetUserID: UUID) async throws
    func getFollowers(userID: UUID, limit: Int, offset: Int) async throws -> [UserProfile]
    func getFollowing(userID: UUID, limit: Int, offset: Int) async throws -> [UserProfile]
    func isFollowing(userID: UUID, targetUserID: UUID) async throws -> Bool
    func searchUsers(query: String, limit: Int) async throws -> [UserProfile]
    func updatePrivacySettings(userID: UUID, settings: PrivacySettings) async throws
    func reportUser(userID: UUID, targetUserID: UUID, reason: String) async throws
}

// MARK: - User Repository Implementation

class UserRepository: UserRepositoryProtocol {
    private let supabase = SupabaseConfig.shared.client

    // パフォーマンス最適化: ユーザー情報キャッシュ
    private let userCache = NSCache<NSString, CachedUser>()
    private let cacheTTL: TimeInterval = 600 // 10分

    func getUser(id: UUID) async throws -> UserProfile {
        let cacheKey = "user_\(id.uuidString)" as NSString

        // キャッシュチェック
        if let cached = userCache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.user
        }

        // API呼び出し
        let response: UserResponse = try await supabase
            .from("users")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value

        let user = try response.toUserProfile()

        // キャッシュに保存
        let cachedUser = CachedUser(user: user, timestamp: Date())
        userCache.setObject(cachedUser, forKey: cacheKey)

        return user
    }
    
    func getUserByUsername(_ username: String) async throws -> UserProfile? {
        let cacheKey = "user_username_\(username)" as NSString

        // キャッシュチェック
        if let cached = userCache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.user
        }

        // API呼び出し
        let response: [UserResponse] = try await supabase
            .from("users")
            .select()
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value

        guard let user = try response.first?.toUserProfile() else {
            return nil
        }

        // キャッシュに保存
        let cachedUser = CachedUser(user: user, timestamp: Date())
        userCache.setObject(cachedUser, forKey: cacheKey)

        return user
    }
    
    func getUserByEmail(_ email: String) async throws -> UserProfile? {
        let cacheKey = "user_email_\(email)" as NSString

        // キャッシュチェック
        if let cached = userCache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.user
        }

        // API呼び出し
        let response: [UserResponse] = try await supabase
            .from("users")
            .select()
            .eq("email", value: email)
            .limit(1)
            .execute()
            .value

        guard let user = try response.first?.toUserProfile() else {
            return nil
        }

        // キャッシュに保存
        let cachedUser = CachedUser(user: user, timestamp: Date())
        userCache.setObject(cachedUser, forKey: cacheKey)

        return user
    }
    
    func createUser(_ profile: UserProfile) async throws -> UserProfile {
        let userRequest = UserRequest(from: profile)
        
        let response: UserResponse = try await supabase
            .from("users")
            .insert(userRequest)
            .select()
            .single()
            .execute()
            .value
        
        return try response.toUserProfile()
    }
    
    func updateUser(_ profile: UserProfile) async throws -> UserProfile {
        let userRequest = UserRequest(from: profile)
        
        let response: UserResponse = try await supabase
            .from("users")
            .update(userRequest)
            .eq("id", value: profile.id)
            .select()
            .single()
            .execute()
            .value
        
        return try response.toUserProfile()
    }
    
    func deleteUser(id: UUID) async throws {
        try await supabase
            .from("users")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func followUser(userID: UUID, targetUserID: UUID) async throws {
        let followRequest = FollowRequest(
            targetUserID: targetUserID
        )
        
        try await supabase
            .from("user_follows")
            .insert(followRequest)
            .execute()
    }
    
    func unfollowUser(userID: UUID, targetUserID: UUID) async throws {
        try await supabase
            .from("user_follows")
            .delete()
            .eq("follower_id", value: userID)
            .eq("following_id", value: targetUserID)
            .execute()
    }
    
    func getFollowers(userID: UUID, limit: Int, offset: Int) async throws -> [UserProfile] {
        let response: [FollowResponse] = try await supabase
            .from("user_follows")
            .select("follower_id, users!user_follows_follower_id_fkey(*)")
            .eq("following_id", value: userID)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return try response.compactMap { try $0.follower?.toUserProfile() }
    }
    
    func getFollowing(userID: UUID, limit: Int, offset: Int) async throws -> [UserProfile] {
        let response: [FollowResponse] = try await supabase
            .from("user_follows")
            .select("following_id, users!user_follows_following_id_fkey(*)")
            .eq("follower_id", value: userID)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return try response.compactMap { try $0.following?.toUserProfile() }
    }
    
    func isFollowing(userID: UUID, targetUserID: UUID) async throws -> Bool {
        let response: [FollowResponse] = try await supabase
            .from("user_follows")
            .select("id")
            .eq("follower_id", value: userID)
            .eq("following_id", value: targetUserID)
            .limit(1)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    func searchUsers(query: String, limit: Int) async throws -> [UserProfile] {
        let response: [UserResponse] = try await supabase
            .from("users")
            .select()
            .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
            .limit(limit)
            .execute()
            .value
        
        return try response.map { try $0.toUserProfile() }
    }
    
    func updatePrivacySettings(userID: UUID, settings: PrivacySettings) async throws {
        let settingsData = try JSONEncoder().encode(settings)
        let settingsString = String(data: settingsData, encoding: .utf8) ?? "{}"

        try await supabase
            .from("users")
            .update(["privacy_settings": settingsString])
            .eq("id", value: userID)
            .execute()
    }
    
    func reportUser(userID: UUID, targetUserID: UUID, reason: String) async throws {
        let reportRequest = UserReportRequest(
            reporterID: userID,
            targetUserID: targetUserID,
            reason: reason,
            reportedAt: Date()
        )
        
        try await supabase
            .from("user_reports")
            .insert(reportRequest)
            .execute()
    }
}

// MARK: - Data Transfer Objects

struct UserRequest: Codable {
    let id: UUID
    let email: String
    let username: String
    let displayName: String?
    let bio: String?
    let avatarURL: String?
    let coverURL: String?
    let location: String?
    let locationPrecision: String
    let isVerified: Bool
    let isOfficial: Bool
    let role: String
    let privacySettings: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case coverURL = "cover_url"
        case location
        case locationPrecision = "location_precision"
        case isVerified = "is_verified"
        case isOfficial = "is_official"
        case role
        case privacySettings = "privacy_settings"
    }
    
    init(from profile: UserProfile) {
        self.id = profile.id
        self.email = profile.email
        self.username = profile.username
        self.displayName = profile.displayName
        self.bio = profile.bio
        self.avatarURL = profile.avatarURL
        self.coverURL = nil // coverURLはUserProfileから削除された
        self.location = profile.location
        self.locationPrecision = profile.privacySettings?.locationPrecision ?? "city"
        self.isVerified = profile.isVerified
        self.isOfficial = profile.isOfficial
        self.role = profile.role.rawValue

        // プライバシー設定をエンコード
        if let settings = profile.privacySettings {
            do {
                let data = try JSONEncoder().encode(settings)
                self.privacySettings = String(data: data, encoding: .utf8).flatMap { ["data": $0] }
            } catch {
                self.privacySettings = nil
            }
        } else {
            self.privacySettings = nil
        }
    }
}

struct UserResponse: Codable {
    let id: UUID
    let email: String
    let username: String
    let displayName: String?
    let bio: String?
    let avatarURL: String?
    let coverURL: String?
    let location: String?
    let locationPrecision: String?
    let isVerified: Bool
    let isOfficial: Bool?
    let role: String
    let privacySettings: [String: String]?
    let createdAt: String
    let updatedAt: String
    let lastActiveAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case coverURL = "cover_url"
        case location
        case locationPrecision = "location_precision"
        case isVerified = "is_verified"
        case isOfficial = "is_official"
        case role
        case privacySettings = "privacy_settings"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastActiveAt = "last_active_at"
    }
    
    func toUserProfile() throws -> UserProfile {
        // 柔軟な日付パース処理（失敗時は現在時刻を返す）
        func parseDate(_ dateString: String, fieldName: String) -> Date {
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
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd HH:mm:ss.SSSSSSZ",
                "yyyy-MM-dd HH:mm:ss.SSSSSS",
                "yyyy-MM-dd HH:mm:ssZ",
                "yyyy-MM-dd HH:mm:ss"
            ]

            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }

            return Date()
        }

        let createdDate = parseDate(createdAt, fieldName: "createdAt")
        let updatedDate = parseDate(updatedAt, fieldName: "updatedAt")
        let lastActiveDate = lastActiveAt.map { parseDate($0, fieldName: "lastActiveAt") }

        // プライバシー設定をデコード
        var privacySettings: PrivacySettings?
        if let settingsDict = self.privacySettings, let jsonString = settingsDict["data"] {
            do {
                let data = Data(jsonString.utf8)
                privacySettings = try JSONDecoder().decode(PrivacySettings.self, from: data)
            } catch {
                privacySettings = PrivacySettings.default
            }
        } else {
            privacySettings = PrivacySettings.default
        }

        return UserProfile(
            id: id,
            email: email,
            username: username,
            displayName: displayName,
            bio: bio,
            avatarURL: avatarURL,
            location: location,
            isVerified: isVerified,
            role: UserRole(rawValue: role) ?? .user,
            privacySettings: privacySettings,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

// Note: FollowRequestは Models/Comment.swift で定義されています

struct FollowResponse: Codable {
    let id: UUID?
    let followerID: UUID?
    let followingID: UUID?
    let follower: UserResponse?
    let following: UserResponse?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerID = "follower_id"
        case followingID = "following_id"
        case follower
        case following
        case createdAt = "created_at"
    }
}

struct UserReportRequest: Codable {
    let reporterID: UUID
    let targetUserID: UUID
    let reason: String
    let reportedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case targetUserID = "target_user_id"
        case reason
        case reportedAt = "reported_at"
    }
}

// MARK: - Helper Types

struct AnyEncodable: Encodable {
    private let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let stringValue as String:
            try container.encode(stringValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyEncodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyEncodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyDecodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyDecodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: Error, LocalizedError {
    case invalidDateFormat
    case encodingError
    case decodingError
    case networkError(String)
    case notFound
    case unauthorized
    case forbidden
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidDateFormat:
            return "日付フォーマットが無効です"
        case .encodingError:
            return "データのエンコードに失敗しました"
        case .decodingError:
            return "データのデコードに失敗しました"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .notFound:
            return "データが見つかりません"
        case .unauthorized:
            return "認証が必要です"
        case .forbidden:
            return "アクセス権限がありません"
        case .unknownError:
            return "不明なエラーが発生しました"
        }
    }
}

// MARK: - Cache Models

/// キャッシュされたユーザー情報
class CachedUser {
    let user: UserProfile
    let timestamp: Date

    init(user: UserProfile, timestamp: Date) {
        self.user = user
        self.timestamp = timestamp
    }
}