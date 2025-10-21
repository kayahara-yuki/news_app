import Foundation

// MARK: - コメントデータモデル

struct Comment: Identifiable, Codable {
    let id: UUID
    let postID: UUID
    let user: UserProfile
    let content: String
    let parentCommentID: UUID? // 返信の場合
    let likeCount: Int
    let createdAt: Date
    let updatedAt: Date

    // 計算プロパティ（DBには存在しない）
    var repliesCount: Int = 0  // デフォルト値、後で取得して更新可能
    var isLikedByCurrentUser: Bool = false  // デフォルト値、後で取得して更新可能

    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case user
        case content
        case parentCommentID = "parent_comment_id"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // 通常のイニシャライザ（コードから直接生成する場合）
    init(
        id: UUID,
        postID: UUID,
        user: UserProfile,
        content: String,
        parentCommentID: UUID? = nil,
        likeCount: Int = 0,
        repliesCount: Int = 0,
        isLikedByCurrentUser: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.postID = postID
        self.user = user
        self.content = content
        self.parentCommentID = parentCommentID
        self.likeCount = likeCount
        self.repliesCount = repliesCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 返信かどうか
    var isReply: Bool {
        return parentCommentID != nil
    }
    
    // 時間表示用のフォーマット
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - コメント作成リクエスト

struct CreateCommentRequest: Codable {
    let postID: UUID
    let content: String
    let parentCommentID: UUID?
    
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case content
        case parentCommentID = "parent_comment_id"
    }
    
    init(postID: UUID, content: String, parentCommentID: UUID? = nil) {
        self.postID = postID
        self.content = content
        self.parentCommentID = parentCommentID
    }
}

// MARK: - フォロー関係データモデル

struct Follow: Identifiable, Codable {
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

// MARK: - ソーシャル統計情報

struct SocialStats: Codable {
    let userID: UUID
    let followersCount: Int
    let followingCount: Int
    let postsCount: Int
    let totalLikesReceived: Int
    let totalCommentsReceived: Int
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case postsCount = "posts_count"
        case totalLikesReceived = "total_likes_received"
        case totalCommentsReceived = "total_comments_received"
    }
}

// MARK: - フォローリクエスト

struct FollowRequest: Codable {
    let targetUserID: UUID
    
    enum CodingKeys: String, CodingKey {
        case targetUserID = "target_user_id"
    }
}

// MARK: - いいねデータモデル

struct Like: Identifiable, Codable {
    let id: UUID
    let userID: UUID
    let postID: UUID?
    let commentID: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case postID = "post_id"
        case commentID = "comment_id"
        case createdAt = "created_at"
    }
    
    var targetType: LikeTargetType {
        if postID != nil {
            return .post
        } else if commentID != nil {
            return .comment
        } else {
            return .unknown
        }
    }
}

enum LikeTargetType {
    case post
    case comment
    case unknown
}

// MARK: - 活動フィードデータモデル

struct ActivityFeedItem: Identifiable, Codable {
    let id: UUID
    let actorUser: UserProfile
    let activityType: ActivityType
    let targetPost: Post?
    let targetComment: Comment?
    let targetUser: UserProfile?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case actorUser = "actor_user"
        case activityType = "activity_type"
        case targetPost = "target_post"
        case targetComment = "target_comment"
        case targetUser = "target_user"
        case createdAt = "created_at"
    }
    
    var displayText: String {
        let actorName = actorUser.displayName ?? actorUser.username
        
        switch activityType {
        case .like:
            return "\(actorName)さんがあなたの投稿にいいねしました"
        case .comment:
            return "\(actorName)さんがあなたの投稿にコメントしました"
        case .follow:
            return "\(actorName)さんがあなたをフォローしました"
        case .mention:
            return "\(actorName)さんがあなたをメンションしました"
        case .reply:
            return "\(actorName)さんがあなたのコメントに返信しました"
        }
    }
    
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

enum ActivityType: String, Codable, CaseIterable {
    case like = "like"
    case comment = "comment"
    case follow = "follow"
    case mention = "mention"
    case reply = "reply"
    
    var displayName: String {
        switch self {
        case .like: return "いいね"
        case .comment: return "コメント"
        case .follow: return "フォロー"
        case .mention: return "メンション"
        case .reply: return "返信"
        }
    }
    
    var iconName: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .follow: return "person.badge.plus.fill"
        case .mention: return "at.badge.plus"
        case .reply: return "arrowshape.turn.up.left.fill"
        }
    }
}

// MARK: - ユーザー検索結果

struct UserSearchResult: Identifiable, Codable {
    let user: UserProfile
    let isFollowing: Bool
    let isFollowedBy: Bool
    let mutualFollowersCount: Int
    let lastActiveAt: Date?
    
    var id: UUID { user.id }
    
    enum CodingKeys: String, CodingKey {
        case user
        case isFollowing = "is_following"
        case isFollowedBy = "is_followed_by"
        case mutualFollowersCount = "mutual_followers_count"
        case lastActiveAt = "last_active_at"
    }
    
    var relationshipText: String {
        if isFollowing && isFollowedBy {
            return "相互フォロー"
        } else if isFollowing {
            return "フォロー中"
        } else if isFollowedBy {
            return "フォロワー"
        } else if mutualFollowersCount > 0 {
            return "\(mutualFollowersCount)人の共通フォロワー"
        } else {
            return ""
        }
    }
}