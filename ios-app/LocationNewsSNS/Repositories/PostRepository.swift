import Foundation
import Supabase
import CoreLocation

// MARK: - Post Repository Protocol

protocol PostRepositoryProtocol {
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async throws -> [Post]
    func getPost(id: UUID) async throws -> Post
    func createPost(_ request: CreatePostRequest) async throws -> Post
    func updatePost(_ post: Post) async throws -> Post
    func deletePost(id: UUID) async throws
    func likePost(id: UUID) async throws
    func unlikePost(id: UUID) async throws
    func sharePost(id: UUID) async throws
    func reportPost(id: UUID, reason: String) async throws
    func getUserPosts(userID: UUID, limit: Int, offset: Int) async throws -> [Post]
    func getPostsByCategory(category: PostCategory, limit: Int, offset: Int) async throws -> [Post]
    func searchPosts(query: String, limit: Int, offset: Int) async throws -> [Post]
    func hasUserLikedPost(id: UUID, userID: UUID) async throws -> Bool
    func getPostLikes(id: UUID, limit: Int, offset: Int) async throws -> [UserProfile]
    func getPostComments(id: UUID, limit: Int, offset: Int) async throws -> [Comment]
    func addComment(postID: UUID, content: String, userID: UUID) async throws -> Comment
}

// MARK: - Post Repository Implementation

class PostRepository: PostRepositoryProtocol {
    private let supabase = SupabaseConfig.shared.client

    // パフォーマンス最適化: キャッシュ層
    private let nearbyPostsCache = NSCache<NSString, CachedPosts>()
    private let cacheTTL: TimeInterval = 300 // 5分

    nonisolated func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double = 10000) async throws -> [Post] {
        AppLogger.debug("fetchNearbyPosts - lat: \(latitude), lng: \(longitude), radius: \(radius)m")

        // キャッシュキーの生成（位置情報を100m単位で丸める）
        let roundedLat = round(latitude * 1000) / 1000 // 約100m精度
        let roundedLng = round(longitude * 1000) / 1000
        let cacheKey = "nearby_\(roundedLat)_\(roundedLng)_\(Int(radius))" as NSString

        // キャッシュチェック
        if let cached = nearbyPostsCache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            AppLogger.debug("キャッシュヒット: \(cached.posts.count) 件")
            return cached.posts
        }

        AppLogger.debug("キャッシュミス - API呼び出し")

        // PostGIS nearby_posts_with_user RPC関数を使用した近隣検索
        // デフォルト半径: 10km (10000m) - パフォーマンス最適化のため制限
        // radiusはすでにメートル単位で渡されているので、そのまま使用
        let radiusMeters = Int(radius)

        // RPC関数はINTEGER型を期待。単純なCodable structを使用
        struct RPCParams: Codable {
            var lat: Double
            var lng: Double
            var radius_meters: Int
            var max_results: Int
        }

        let params = RPCParams(
            lat: latitude,
            lng: longitude,
            radius_meters: radiusMeters,
            max_results: 50
        )

        AppLogger.debug("RPC呼び出し - params: \(params)")

        let response: [NearbyPostResponse] = try await supabase
            .rpc("nearby_posts_with_user", params: params)
            .execute()
            .value

        AppLogger.debug("RPC レスポンス: \(response.count) 件")
        let posts = try response.map { try $0.toPost() }
        AppLogger.debug("Post変換完了: \(posts.count) 件")

        // キャッシュに保存
        let cachedPosts = CachedPosts(posts: posts, timestamp: Date())
        nearbyPostsCache.setObject(cachedPosts, forKey: cacheKey)

        return posts
    }
    
    func getPost(id: UUID) async throws -> Post {
        let response: PostResponse = try await supabase
            .from("posts")
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified, role, privacy_settings, email, bio, location, created_at, updated_at)
            """)
            .eq("id", value: id)
            .single()
            .execute()
            .value

        return try response.toPost()
    }
    
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        let postRequest = PostRequest(from: request)

        let response: PostResponse = try await supabase
            .from("posts")
            .insert(postRequest)
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified, role, privacy_settings, email, bio, location, created_at, updated_at)
            """)
            .single()
            .execute()
            .value

        // TODO: メディアファイル処理は実装時に追加
        // 画像データはUIImage形式で保持されているため、
        // アップロード処理が必要です

        return try response.toPost()
    }
    
    func updatePost(_ post: Post) async throws -> Post {
        let postRequest = PostRequest(from: post)
        
        let response: PostResponse = try await supabase
            .from("posts")
            .update(postRequest)
            .eq("id", value: post.id)
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified),
                post_media(id, media_type, file_url, thumbnail_url)
            """)
            .single()
            .execute()
            .value
        
        return try response.toPost()
    }
    
    func deletePost(id: UUID) async throws {
        try await supabase
            .from("posts")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func likePost(id: UUID) async throws {
        // TODO: 現在のユーザーIDを取得
        let userID = UUID() // 仮のID

        let likeRequest = PostLikeRequest(
            postID: id,
            userID: userID
        )

        try await supabase
            .from("likes")
            .insert(likeRequest)
            .execute()

        // いいね数を更新
        try await supabase
            .from("posts")
            .update(["like_count": "like_count + 1"])
            .eq("id", value: id)
            .execute()
    }
    
    func unlikePost(id: UUID) async throws {
        // TODO: 現在のユーザーIDを取得
        let userID = UUID() // 仮のID

        try await supabase
            .from("likes")
            .delete()
            .eq("post_id", value: id)
            .eq("user_id", value: userID)
            .execute()

        // いいね数を更新
        try await supabase
            .from("posts")
            .update(["like_count": "like_count - 1"])
            .eq("id", value: id)
            .execute()
    }
    
    func sharePost(id: UUID) async throws {
        try await supabase
            .from("posts")
            .update(["share_count": "share_count + 1"])
            .eq("id", value: id)
            .execute()
    }
    
    func reportPost(id: UUID, reason: String) async throws {
        // TODO: 現在のユーザーIDを取得
        let userID = UUID() // 仮のID
        
        let reportRequest = PostReportRequest(
            postID: id,
            userID: userID,
            reason: reason,
            reportedAt: Date()
        )
        
        try await supabase
            .from("post_reports")
            .insert(reportRequest)
            .execute()
    }
    
    func getUserPosts(userID: UUID, limit: Int, offset: Int) async throws -> [Post] {
        let response: [PostResponse] = try await supabase
            .from("posts")
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified),
                post_media(id, media_type, file_url, thumbnail_url)
            """)
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return try response.map { try $0.toPost() }
    }
    
    func getPostsByCategory(category: PostCategory, limit: Int, offset: Int) async throws -> [Post] {
        let response: [PostResponse] = try await supabase
            .from("posts")
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified),
                post_media(id, media_type, file_url, thumbnail_url)
            """)
            .eq("category", value: category.rawValue)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return try response.map { try $0.toPost() }
    }
    
    func searchPosts(query: String, limit: Int, offset: Int) async throws -> [Post] {
        let response: [PostResponse] = try await supabase
            .from("posts")
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified),
                post_media(id, media_type, file_url, thumbnail_url)
            """)
            .textSearch("content", query: query)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return try response.map { try $0.toPost() }
    }
    
    func hasUserLikedPost(id: UUID, userID: UUID) async throws -> Bool {
        let response: [PostLikeResponse] = try await supabase
            .from("likes")
            .select("id")
            .eq("post_id", value: id)
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value

        return !response.isEmpty
    }
    
    func getPostLikes(id: UUID, limit: Int, offset: Int) async throws -> [UserProfile] {
        let response: [PostLikeResponse] = try await supabase
            .from("likes")
            .select("users!likes_user_id_fkey(*)")
            .eq("post_id", value: id)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return try response.compactMap { try $0.user?.toUserProfile() }
    }
    
    func getPostComments(id: UUID, limit: Int, offset: Int) async throws -> [Comment] {
        let response: [CommentResponse] = try await supabase
            .from("comments")
            .select("""
                *,
                users!comments_user_id_fkey(id, username, display_name, avatar_url, is_verified, role, privacy_settings, email, bio, location, created_at, updated_at)
            """)
            .eq("post_id", value: id)
            .order("created_at", ascending: true)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return try response.map { try $0.toComment() }
    }
    
    func addComment(postID: UUID, content: String, userID: UUID) async throws -> Comment {
        let commentRequest = CommentRequest(
            postID: postID,
            userID: userID,
            content: content
        )

        let response: CommentResponse = try await supabase
            .from("comments")
            .insert(commentRequest)
            .select("""
                *,
                users!comments_user_id_fkey(id, username, display_name, avatar_url, is_verified, role, privacy_settings, email, bio, location, created_at, updated_at)
            """)
            .single()
            .execute()
            .value

        // コメント数を更新
        try await supabase
            .from("posts")
            .update(["comment_count": "comment_count + 1"])
            .eq("id", value: postID)
            .execute()

        return try response.toComment()
    }
    
    // MARK: - Private Methods
    
    // TODO: メディアアップロード機能実装時に有効化
    // private func addMediaToPost(postID: UUID, mediaURLs: [String]) async throws {
    //     let mediaRequests = mediaURLs.map { url in
    //         PostMediaRequest(
    //             postID: postID,
    //             mediaType: getMediaType(from: url),
    //             fileURL: url,
    //             thumbnailURL: nil
    //         )
    //     }
    //
    //     try await supabase
    //         .from("post_media")
    //         .insert(mediaRequests)
    //         .execute()
    // }
    
    private func getMediaType(from url: String) -> String {
        let lowercaseURL = url.lowercased()
        
        if lowercaseURL.contains(".jpg") || lowercaseURL.contains(".jpeg") || 
           lowercaseURL.contains(".png") || lowercaseURL.contains(".gif") {
            return "image"
        } else if lowercaseURL.contains(".mp4") || lowercaseURL.contains(".mov") || 
                  lowercaseURL.contains(".avi") {
            return "video"
        } else if lowercaseURL.contains(".mp3") || lowercaseURL.contains(".wav") || 
                  lowercaseURL.contains(".aac") {
            return "audio"
        } else {
            return "document"
        }
    }
}

// MARK: - Data Transfer Objects

struct PostRequest: Encodable {
    let id: UUID?
    let userID: UUID?
    let content: String
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let category: String
    let visibility: String
    let isUrgent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case content
        case url
        case latitude
        case longitude
        case address
        case category
        case visibility
        case isUrgent = "is_urgent"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(userID, forKey: .userID)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encode(category, forKey: .category)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(isUrgent, forKey: .isUrgent)
    }
    
    init(from request: CreatePostRequest) {
        self.id = nil
        self.userID = nil // TODO: 現在のユーザーIDを設定
        self.content = request.content
        self.url = nil // CreatePostRequestにはurl不要
        self.latitude = request.latitude
        self.longitude = request.longitude
        self.address = request.locationName

        // categoryはCreatePostRequestに存在しないため、デフォルト値を使用
        self.category = "social"
        self.visibility = request.visibility.rawValue
        self.isUrgent = request.emergencyLevel != nil
    }
    
    init(from post: Post) {
        self.id = post.id
        self.userID = post.user.id
        self.content = post.content
        self.url = post.url
        self.latitude = post.latitude
        self.longitude = post.longitude
        self.address = post.address
        self.category = post.category.rawValue
        self.visibility = post.visibility.rawValue
        self.isUrgent = post.isUrgent
    }
}

struct PostResponse: Decodable {
    let id: UUID
    let userID: UUID
    let content: String
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let category: String
    let visibility: String
    let isUrgent: Bool
    let isVerified: Bool
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let createdAt: String
    let updatedAt: String
    let user: UserResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
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
        case user = "users"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decode(UUID.self, forKey: .userID)
        content = try container.decode(String.self, forKey: .content)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        category = try container.decode(String.self, forKey: .category)
        visibility = try container.decode(String.self, forKey: .visibility)
        isUrgent = try container.decode(Bool.self, forKey: .isUrgent)
        isVerified = try container.decode(Bool.self, forKey: .isVerified)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        shareCount = try container.decode(Int.self, forKey: .shareCount)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        user = try container.decodeIfPresent(UserResponse.self, forKey: .user)
    }
    
    func toPost() throws -> Post {
        let dateFormatter = ISO8601DateFormatter()

        guard let createdDate = dateFormatter.date(from: createdAt),
              let updatedDate = dateFormatter.date(from: updatedAt) else {
            throw RepositoryError.invalidDateFormat
        }

        guard let userResponse = user else {
            throw RepositoryError.decodingError
        }

        let userProfile = try userResponse.toUserProfile()

        return Post(
            id: id,
            user: userProfile,
            content: content,
            url: url,
            latitude: latitude,
            longitude: longitude,
            address: address,
            category: PostCategory(rawValue: category) ?? .other,
            visibility: PostVisibility(rawValue: visibility) ?? .public,
            isUrgent: isUrgent,
            isVerified: isVerified,
            likeCount: likeCount,
            commentCount: commentCount,
            shareCount: shareCount,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

struct PostMediaRequest: Codable {
    let postID: UUID
    let mediaType: String
    let fileURL: String
    let thumbnailURL: String?
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case mediaType = "media_type"
        case fileURL = "file_url"
        case thumbnailURL = "thumbnail_url"
    }
}

struct PostMediaResponse: Codable {
    let id: UUID
    let postID: UUID
    let mediaType: String
    let fileURL: String
    let thumbnailURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case mediaType = "media_type"
        case fileURL = "file_url"
        case thumbnailURL = "thumbnail_url"
    }
}

struct PostLikeRequest: Codable {
    let postID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
    }
}

struct PostLikeResponse: Codable {
    let id: UUID
    let postID: UUID
    let userID: UUID
    let createdAt: String
    let user: UserResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case userID = "user_id"
        case createdAt = "created_at"
        case user = "users"
    }
}

struct PostReportRequest: Codable {
    let postID: UUID
    let userID: UUID
    let reason: String
    let reportedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case reason
        case reportedAt = "reported_at"
    }
}

struct CommentRequest: Codable {
    let postID: UUID
    let userID: UUID
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case content
    }
}

struct CommentResponse: Codable {
    let id: UUID
    let postID: UUID
    let userID: UUID
    let content: String
    let likeCount: Int
    let createdAt: String
    let updatedAt: String
    let user: UserResponse?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case userID = "user_id"
        case content
        case likeCount = "like_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user = "users"
    }
    
    func toComment() throws -> Comment {
        let dateFormatter = ISO8601DateFormatter()

        guard let createdDate = dateFormatter.date(from: createdAt),
              let updatedDate = dateFormatter.date(from: updatedAt) else {
            throw RepositoryError.invalidDateFormat
        }

        guard let userResponse = user else {
            throw RepositoryError.decodingError
        }

        let userProfile = try userResponse.toUserProfile()

        return Comment(
            id: id,
            postID: postID,
            user: userProfile,
            content: content,
            parentCommentID: nil, // TODO: 返信機能実装時に対応
            likesCount: likeCount,
            repliesCount: 0, // TODO: 返信機能実装時に対応
            isLikedByCurrentUser: false, // TODO: いいね状態取得機能実装時に対応
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

// MARK: - Nearby Post Response (for RPC function)

struct NearbyPostResponse: Decodable {
    let id: UUID
    let userID: UUID
    let username: String
    let displayName: String?
    let avatarURL: String?
    let isVerified: Bool
    let userRole: String
    let content: String
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let category: String
    let visibility: String
    let isUrgent: Bool
    let postIsVerified: Bool
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let createdAt: String
    let updatedAt: String
    let distanceMeters: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case isVerified = "is_verified"
        case userRole = "user_role"
        case content
        case url
        case latitude
        case longitude
        case address
        case category
        case visibility
        case isUrgent = "is_urgent"
        case postIsVerified = "post_is_verified"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case distanceMeters = "distance_meters"
    }

    func toPost() throws -> Post {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let createdDate = dateFormatter.date(from: createdAt),
              let updatedDate = dateFormatter.date(from: updatedAt) else {
            AppLogger.error("日付パースエラー - createdAt: \(createdAt), updatedAt: \(updatedAt)")
            throw RepositoryError.invalidDateFormat
        }

        let userProfile = UserProfile(
            id: userID,
            email: "", // RPC関数からはemailは返されない
            username: username,
            displayName: displayName,
            bio: nil,
            avatarURL: avatarURL,
            location: nil,
            isVerified: isVerified,
            role: UserRole(rawValue: userRole) ?? .user,
            privacySettings: nil,
            createdAt: Date(), // RPC関数からは返されない
            updatedAt: Date()  // RPC関数からは返されない
        )

        return Post(
            id: id,
            user: userProfile,
            content: content,
            url: url,
            latitude: latitude,
            longitude: longitude,
            address: address,
            category: PostCategory(rawValue: category) ?? .other,
            visibility: PostVisibility(rawValue: visibility) ?? .public,
            isUrgent: isUrgent,
            isVerified: postIsVerified,
            likeCount: likeCount,
            commentCount: commentCount,
            shareCount: shareCount,
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}

// MARK: - Cache Models

/// キャッシュされた投稿データ
class CachedPosts {
    let posts: [Post]
    let timestamp: Date

    init(posts: [Post], timestamp: Date) {
        self.posts = posts
        self.timestamp = timestamp
    }
}

// MARK: - Comment Model
// Note: Commentモデルは Models/Comment.swift で定義されています