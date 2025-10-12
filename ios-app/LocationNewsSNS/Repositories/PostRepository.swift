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
    
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async throws -> [Post] {
        // PostGISを使用した近隣検索
        // TODO: RPC関数を使用するためには、Supabaseで nearby_posts 関数を作成する必要があります
        // 現時点では通常のクエリで代替します
        let response: [PostResponse] = try await supabase
            .from("posts")
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified),
                post_media(id, media_type, file_url, thumbnail_url)
            """)
            .order("created_at", ascending: false)
            .execute()
            .value

        return try response.map { try $0.toPost() }
    }
    
    func getPost(id: UUID) async throws -> Post {
        let response: PostResponse = try await supabase
            .from("posts")
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified),
                post_media(id, media_type, file_url, thumbnail_url)
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
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified),
                post_media(id, media_type, file_url, thumbnail_url)
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
            userID: userID,
            reactionType: "like"
        )
        
        try await supabase
            .from("post_likes")
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
            .from("post_likes")
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
            .from("post_likes")
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
            .from("post_likes")
            .select("users!post_likes_user_id_fkey(*)")
            .eq("post_id", value: id)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        return try response.compactMap { try $0.user?.toUserProfile() }
    }
    
    func getPostComments(id: UUID, limit: Int, offset: Int) async throws -> [Comment] {
        let response: [CommentResponse] = try await supabase
            .from("post_comments")
            .select("""
                *,
                users!post_comments_user_id_fkey(id, username, display_name, avatar_url, is_verified)
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
            .from("post_comments")
            .insert(commentRequest)
            .select("""
                *,
                users!post_comments_user_id_fkey(id, username, display_name, avatar_url, is_verified)
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
    let location: String? // PostGISのGEOGRAPHY型
    let address: [String: AnyEncodable]?
    let category: String
    let visibility: String
    let isEmergency: Bool
    let emergencyLevel: String?
    let trustScore: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case content
        case url
        case location
        case address
        case category
        case visibility
        case isEmergency = "is_emergency"
        case emergencyLevel = "emergency_level"
        case trustScore = "trust_score"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(userID, forKey: .userID)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(location, forKey: .location)

        if let address = address {
            let addressDict = address.mapValues { $0 }
            try container.encode(addressDict, forKey: .address)
        }

        try container.encode(category, forKey: .category)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(isEmergency, forKey: .isEmergency)
        try container.encodeIfPresent(emergencyLevel, forKey: .emergencyLevel)
        try container.encode(trustScore, forKey: .trustScore)
    }
    
    init(from request: CreatePostRequest) {
        self.id = nil
        self.userID = nil // TODO: 現在のユーザーIDを設定
        self.content = request.content
        self.url = nil // CreatePostRequestにはurl不要

        // PostGIS用の位置情報フォーマット
        if let lat = request.latitude, let lng = request.longitude {
            self.location = "POINT(\(lng) \(lat))"
        } else {
            self.location = nil
        }

        // 住所情報をJSONBフォーマットに変換
        if let locationName = request.locationName {
            self.address = ["formatted": AnyEncodable(locationName)]
        } else {
            self.address = nil
        }

        // categoryはCreatePostRequestに存在しないため、デフォルト値を使用
        self.category = "community"
        self.visibility = request.visibility.rawValue
        self.isEmergency = request.emergencyLevel != nil
        self.emergencyLevel = request.emergencyLevel?.rawValue
        self.trustScore = 0.5 // デフォルト値
    }
    
    init(from post: Post) {
        self.id = post.id
        self.userID = post.user.id
        self.content = post.content
        self.url = post.url
        
        // PostGIS用の位置情報フォーマット
        if let lat = post.latitude, let lng = post.longitude {
            self.location = "POINT(\(lng) \(lat))"
        } else {
            self.location = nil
        }
        
        // 住所情報をJSONBフォーマットに変換
        if let address = post.address {
            self.address = ["formatted": AnyEncodable(address)]
        } else {
            self.address = nil
        }
        
        self.category = post.category.rawValue
        self.visibility = post.visibility.rawValue
        self.isEmergency = post.isEmergency
        self.emergencyLevel = post.emergencyLevel?.rawValue
        self.trustScore = post.trustScore
    }
}

struct PostResponse: Decodable {
    let id: UUID
    let userID: UUID
    let content: String
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let address: [String: AnyDecodable]?
    let category: String
    let visibility: String
    let isEmergency: Bool
    let emergencyLevel: String?
    let trustScore: Double
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let createdAt: String
    let updatedAt: String
    let user: UserResponse?
    let postMedia: [PostMediaResponse]?

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
        case isEmergency = "is_emergency"
        case emergencyLevel = "emergency_level"
        case trustScore = "trust_score"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user = "users"
        case postMedia = "post_media"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decode(UUID.self, forKey: .userID)
        content = try container.decode(String.self, forKey: .content)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        address = try container.decodeIfPresent([String: AnyDecodable].self, forKey: .address)
        category = try container.decode(String.self, forKey: .category)
        visibility = try container.decode(String.self, forKey: .visibility)
        isEmergency = try container.decode(Bool.self, forKey: .isEmergency)
        emergencyLevel = try container.decodeIfPresent(String.self, forKey: .emergencyLevel)
        trustScore = try container.decode(Double.self, forKey: .trustScore)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
        shareCount = try container.decode(Int.self, forKey: .shareCount)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        user = try container.decodeIfPresent(UserResponse.self, forKey: .user)
        postMedia = try container.decodeIfPresent([PostMediaResponse].self, forKey: .postMedia)
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
        
        // 住所情報をデコード
        let formattedAddress = address?["formatted"]?.value as? String
        
        // メディア情報をデコード
        let mediaFiles = postMedia?.compactMap { media in
            MediaFile(
                id: media.id,
                type: MediaType(rawValue: media.mediaType) ?? .image,
                url: media.fileURL,
                thumbnailURL: media.thumbnailURL
            )
        } ?? []
        
        return Post(
            id: id,
            user: userProfile,
            content: content,
            url: url,
            latitude: latitude,
            longitude: longitude,
            address: formattedAddress,
            category: PostCategory(rawValue: category) ?? .community,
            visibility: PostVisibility(rawValue: visibility) ?? .public,
            isEmergency: isEmergency,
            emergencyLevel: emergencyLevel.flatMap { EmergencyLevel(rawValue: $0) },
            trustScore: trustScore,
            mediaFiles: mediaFiles,
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
    let reactionType: String
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case reactionType = "reaction_type"
    }
}

struct PostLikeResponse: Codable {
    let id: UUID
    let postID: UUID
    let userID: UUID
    let reactionType: String
    let createdAt: String
    let user: UserResponse?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case userID = "user_id"
        case reactionType = "reaction_type"
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

// MARK: - Comment Model
// Note: Commentモデルは Models/Comment.swift で定義されています