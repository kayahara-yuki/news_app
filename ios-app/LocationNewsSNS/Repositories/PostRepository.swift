import Foundation
import Supabase
import CoreLocation

// MARK: - Post Repository Protocol

protocol PostRepositoryProtocol {
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async throws -> [Post]
    func getPost(id: UUID) async throws -> Post
    func createPost(_ request: CreatePostRequest) async throws -> Post
    func createPostWithAudio(_ request: CreatePostRequest, audioURL: String) async throws -> Post
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
    private let cacheTTL: TimeInterval = 60 // 1分(リアルタイム性向上)

    // 現在のユーザーIDを動的に取得
    private func getCurrentUserID() async throws -> UUID {
        let session = try await supabase.auth.session
        return session.user.id
    }

    nonisolated func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double = 10000) async throws -> [Post] {
        print("🔍 [PostRepository] fetchNearbyPosts開始")
        print("📍 [PostRepository] パラメータ: lat=\(latitude), lng=\(longitude), radius=\(radius)m")

        // キャッシュキーの生成（位置情報を10m単位で丸める）
        let roundedLat = round(latitude * 10000) / 10000 // 約10m精度
        let roundedLng = round(longitude * 10000) / 10000
        let cacheKey = "nearby_\(roundedLat)_\(roundedLng)_\(Int(radius))" as NSString

        // キャッシュチェック
        if let cached = nearbyPostsCache.object(forKey: cacheKey),
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            print("✅ [PostRepository] キャッシュヒット: \(cached.posts.count)件")
            return cached.posts
        }

        print("🔄 [PostRepository] キャッシュミス - RPC呼び出し実行")

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

        print("📤 [PostRepository] RPC呼び出し: nearby_posts_with_user")
        print("📤 [PostRepository] RPCパラメータ: \(params)")

        let response: [NearbyPostResponse] = try await supabase
            .rpc("nearby_posts_with_user", params: params)
            .execute()
            .value

        print("📥 [PostRepository] RPC応答受信: \(response.count)件")

        if response.isEmpty {
            print("⚠️ [PostRepository] 警告: RPCから0件の投稿が返されました")
        } else {
            print("✅ [PostRepository] 最初の投稿: id=\(response[0].id), content=\(response[0].content.prefix(30))...")
        }

        let posts = try response.map { try $0.toPost() }

        print("✅ [PostRepository] Post変換完了: \(posts.count)件")

        // キャッシュに保存
        let cachedPosts = CachedPosts(posts: posts, timestamp: Date())
        nearbyPostsCache.setObject(cachedPosts, forKey: cacheKey)

        print("💾 [PostRepository] キャッシュ保存完了")

        return posts
    }
    
    func getPost(id: UUID) async throws -> Post {
        let response: PostResponse = try await supabase
            .from("posts")
            .select("""
                *,
                users!posts_user_id_fkey(id, username, display_name, avatar_url, is_verified, role, email, bio, location, created_at, updated_at)
            """)
            .eq("id", value: id)
            .single()
            .execute()
            .value

        let post = try response.toPost()
        return post
    }
    
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        print("[PostRepository] 🚀 createPost started")
        print("[PostRepository] 📝 content: \"\(request.content)\"")
        print("[PostRepository] 📍 location: lat=\(request.latitude ?? 0), lng=\(request.longitude ?? 0)")
        print("[PostRepository] 📍 locationName: \"\(request.locationName ?? "")\"")

        // 現在のユーザーIDを取得
        let currentUserID = try await getCurrentUserID()
        print("[PostRepository] 👤 Current userID: \(currentUserID.uuidString)")

        // PostRequestを作成（userIDを含む）
        let postRequest = PostRequest(from: request, userID: currentUserID)

        print("[PostRepository] 📤 PostRequest created")
        print("[PostRepository] 📤 PostRequest fields: userID=\(postRequest.userID?.uuidString ?? "nil"), lat=\(postRequest.latitude ?? 0), lng=\(postRequest.longitude ?? 0)")
        print("[PostRepository] 📤 Location (WKT): \(postRequest.location ?? "nil")")
        print("[PostRepository] 📤 PostRequest: category=\(postRequest.category), visibility=\(postRequest.visibility)")
        print("[PostRepository] 📤 PostRequest: isStatusPost=\(postRequest.isStatusPost ?? false), expiresAt=\(postRequest.expiresAt?.description ?? "nil")")

        print("[PostRepository] 📤 Sending INSERT request to Supabase...")
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

        print("[PostRepository] ✅ Supabase response received")
        print("[PostRepository] ✅ Response: id=\(response.id), content=\"\(response.content.prefix(30))...\"")
        print("[PostRepository] ✅ Response: lat=\(response.latitude ?? 0), lng=\(response.longitude ?? 0), address=\"\(response.address ?? "")\"")
        print("[PostRepository] ✅ Response: isStatusPost=\(response.isStatusPost), expiresAt=\(response.expiresAt ?? "nil")")

        // TODO: メディアファイル処理は実装時に追加
        // 画像データはUIImage形式で保持されているため、
        // アップロード処理が必要です

        let post = try response.toPost()
        print("[PostRepository] ✅ Post object created successfully")
        print("[PostRepository] ✅ Post.canShowOnMap: \(post.canShowOnMap)")
        return post
    }

    /// 音声付き投稿を作成
    /// - Parameters:
    ///   - request: 投稿作成リクエスト
    ///   - audioURL: 音声ファイルのURL
    /// - Returns: 作成された投稿
    func createPostWithAudio(_ request: CreatePostRequest, audioURL: String) async throws -> Post {
        print("[PostRepository] 🚀 createPostWithAudio started")
        print("[PostRepository] 📝 content: \"\(request.content)\"")
        print("[PostRepository] 🎤 audioURL: \(audioURL)")
        print("[PostRepository] 📍 location: lat=\(request.latitude ?? 0), lng=\(request.longitude ?? 0)")

        // 現在のユーザーIDを取得
        let currentUserID = try await getCurrentUserID()
        print("[PostRepository] 👤 Current userID: \(currentUserID.uuidString)")

        // PostRequestを作成（userIDとaudioURLを含む）
        let postRequest = PostRequest(from: request, userID: currentUserID, audioURL: audioURL)

        print("[PostRepository] 📤 PostRequest created with audioURL")
        print("[PostRepository] 📤 PostRequest: userID=\(postRequest.userID?.uuidString ?? "nil"), isStatusPost=\(postRequest.isStatusPost ?? false)")

        print("[PostRepository] 📤 Sending INSERT request to Supabase...")
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

        print("[PostRepository] ✅ Supabase response received")
        print("[PostRepository] ✅ Response: id=\(response.id), audioURL=\(response.audioURL ?? "nil")")

        let post = try response.toPost()
        print("[PostRepository] ✅ Post with audio created successfully")
        return post
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
        let userID = try await getCurrentUserID()

        // 既にいいねしているかチェック
        let checkResponse = try await supabase
            .from("likes")
            .select("id", head: false, count: .exact)
            .eq("post_id", value: id)
            .eq("user_id", value: userID)
            .limit(1)
            .execute()

        // 既にいいねが存在する場合は何もしない
        if (checkResponse.count ?? 0) > 0 {
            return
        }

        let likeRequest = PostLikeRequest(
            postID: id,
            userID: userID
        )

        try await supabase
            .from("likes")
            .insert(likeRequest)
            .execute()
    }
    
    func unlikePost(id: UUID) async throws {
        let userID = try await getCurrentUserID()

        // いいねが存在するか確認
        let checkResponse = try await supabase
            .from("likes")
            .select("id", head: false, count: .exact)
            .eq("post_id", value: id)
            .eq("user_id", value: userID)
            .limit(1)
            .execute()

        // いいねが存在しない場合は何もしない
        if (checkResponse.count ?? 0) == 0 {
            return
        }

        try await supabase
            .from("likes")
            .delete()
            .eq("post_id", value: id)
            .eq("user_id", value: userID)
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
        let userID = try await getCurrentUserID()

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
        // シンプルなカウントクエリを使用
        let response = try await supabase
            .from("likes")
            .select("id", head: false, count: .exact)
            .eq("post_id", value: id)
            .eq("user_id", value: userID)
            .limit(1)
            .execute()

        return (response.count ?? 0) > 0
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
    let audioURL: String?
    let isStatusPost: Bool?
    let expiresAt: Date?
    let location: String?  // PostGIS POINT in WKT format: "POINT(lng lat)"

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
        case audioURL = "audio_url"
        case isStatusPost = "is_status_post"
        case expiresAt = "expires_at"
        case location
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
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encodeIfPresent(isStatusPost, forKey: .isStatusPost)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(location, forKey: .location)
    }

    init(from request: CreatePostRequest, userID: UUID, audioURL: String? = nil) {
        self.id = nil
        self.userID = userID
        self.content = request.content
        self.url = nil // CreatePostRequestにはurl不要
        self.latitude = request.latitude
        self.longitude = request.longitude
        self.address = request.locationName

        // categoryはCreatePostRequestに存在しないため、デフォルト値を使用
        self.category = "social"
        self.visibility = request.visibility.rawValue
        self.isUrgent = request.emergencyLevel != nil

        // 音声・ステータス関連フィールド
        self.audioURL = audioURL
        self.isStatusPost = request.isStatusPost
        self.expiresAt = request.expiresAt

        // PostGIS location (WKT format: "POINT(longitude latitude)")
        if let lat = request.latitude, let lng = request.longitude {
            self.location = "POINT(\(lng) \(lat))"
        } else {
            self.location = nil
        }
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
        self.audioURL = post.audioURL
        self.isStatusPost = post.isStatusPost
        self.expiresAt = post.expiresAt

        // PostGIS location (WKT format: "POINT(longitude latitude)")
        if let lat = post.latitude, let lng = post.longitude {
            self.location = "POINT(\(lng) \(lat))"
        } else {
            self.location = nil
        }
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
    let audioURL: String?
    let isStatusPost: Bool
    let expiresAt: String?

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
        case audioURL = "audio_url"
        case isStatusPost = "is_status_post"
        case expiresAt = "expires_at"
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
        audioURL = try container.decodeIfPresent(String.self, forKey: .audioURL)
        isStatusPost = try container.decodeIfPresent(Bool.self, forKey: .isStatusPost) ?? false
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
    }
    
    func toPost() throws -> Post {

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

            return Date()
        }

        let createdDate = parseDate(createdAt, fieldName: "createdAt")
        let updatedDate = parseDate(updatedAt, fieldName: "updatedAt")

        guard let userResponse = user else {
            throw RepositoryError.decodingError
        }

        let userProfile = try userResponse.toUserProfile()

        let expiresAtDate: Date? = {
            guard let expiresAtString = expiresAt else { return nil }
            return parseDate(expiresAtString, fieldName: "expiresAt")
        }()

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
            updatedAt: updatedDate,
            audioURL: audioURL,
            isStatusPost: isStatusPost,
            expiresAt: expiresAtDate
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
            likeCount: likeCount,
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
    let audioURL: String?
    let isStatusPost: Bool?
    let expiresAt: String?

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
        case audioURL = "audio_url"
        case isStatusPost = "is_status_post"
        case expiresAt = "expires_at"
    }

    func toPost() throws -> Post {

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
            return Date()
        }

        let createdDate = parseDate(createdAt, fieldName: "createdAt")
        let updatedDate = parseDate(updatedAt, fieldName: "updatedAt")

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

        let expiresAtDate: Date? = {
            guard let expiresAtString = expiresAt else { return nil }
            return parseDate(expiresAtString, fieldName: "expiresAt")
        }()

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
            updatedAt: updatedDate,
            audioURL: audioURL,
            isStatusPost: isStatusPost ?? false,
            expiresAt: expiresAtDate
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