import Foundation
import Supabase

// MARK: - ソーシャル機能リポジトリプロトコル

protocol SocialRepositoryProtocol {
    // フォロー関連
    func followUser(userID: UUID) async throws
    func unfollowUser(userID: UUID) async throws
    func getFollowers(userID: UUID) async throws -> [UserProfile]
    func getFollowing(userID: UUID) async throws -> [UserProfile]
    func checkFollowStatus(userID: UUID) async throws -> Bool
    func getSocialStats(userID: UUID) async throws -> SocialStats
    
    // コメント関連
    func createComment(_ request: CreateCommentRequest) async throws -> Comment
    func getComments(postID: UUID, limit: Int, offset: Int) async throws -> [Comment]
    func getReplies(commentID: UUID) async throws -> [Comment]
    func likeComment(commentID: UUID) async throws
    func unlikeComment(commentID: UUID) async throws
    func deleteComment(commentID: UUID) async throws
    
    // いいね関連
    func likePost(postID: UUID) async throws
    func unlikePost(postID: UUID) async throws
    func getLikes(postID: UUID) async throws -> [Like]
    
    // 活動フィード
    func getActivityFeed(limit: Int, offset: Int) async throws -> [ActivityFeedItem]
    func markActivityAsRead(activityID: UUID) async throws
    
    // ユーザー検索
    func searchUsers(query: String, limit: Int) async throws -> [UserSearchResult]
    func getSuggestedUsers(limit: Int) async throws -> [UserProfile]
}

// MARK: - ソーシャル機能リポジトリ実装

class SocialRepository: SocialRepositoryProtocol {
    private let supabase = SupabaseConfig.shared.client
    private let currentUserID: UUID
    
    init() {
        // TODO: 実際の実装では認証サービスから取得
        self.currentUserID = UUID()
    }
    
    // MARK: - フォロー関連
    
    func followUser(userID: UUID) async throws {
        let followRequest = [
            "follower_id": currentUserID.uuidString,
            "following_id": userID.uuidString,
            "created_at": Date().iso8601String
        ]
        
        try await supabase
            .from("follows")
            .insert(followRequest)
            .execute()
        
        // 統計情報を更新
        await updateFollowStats(followerID: currentUserID, followingID: userID, isFollowing: true)
    }
    
    func unfollowUser(userID: UUID) async throws {
        try await supabase
            .from("follows")
            .delete()
            .eq("follower_id", value: currentUserID.uuidString)
            .eq("following_id", value: userID.uuidString)
            .execute()
        
        // 統計情報を更新
        await updateFollowStats(followerID: currentUserID, followingID: userID, isFollowing: false)
    }
    
    func getFollowers(userID: UUID) async throws -> [UserProfile] {
        let response = try await supabase
            .from("follows")
            .select("follower:user_profiles!follower_id(*)")
            .eq("following_id", value: userID.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        // TODO: JSONから[UserProfile]にデコード
        return []
    }
    
    func getFollowing(userID: UUID) async throws -> [UserProfile] {
        let response = try await supabase
            .from("follows")
            .select("following:user_profiles!following_id(*)")
            .eq("follower_id", value: userID.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        // TODO: JSONから[UserProfile]にデコード
        return []
    }
    
    func checkFollowStatus(userID: UUID) async throws -> Bool {
        let response = try await supabase
            .from("follows")
            .select("id")
            .eq("follower_id", value: currentUserID.uuidString)
            .eq("following_id", value: userID.uuidString)
            .single()
            .execute()
        
        return response.data != nil
    }
    
    func getSocialStats(userID: UUID) async throws -> SocialStats {
        // フォロワー数
        let followersResponse = try await supabase
            .from("follows")
            .select("id", head: true)
            .eq("following_id", value: userID.uuidString)
            .execute()
        
        // フォロー中数
        let followingResponse = try await supabase
            .from("follows")
            .select("id", head: true)
            .eq("follower_id", value: userID.uuidString)
            .execute()
        
        // 投稿数
        let postsResponse = try await supabase
            .from("posts")
            .select("id", head: true)
            .eq("user_id", value: userID.uuidString)
            .execute()
        
        // TODO: 実際の数値を取得
        return SocialStats(
            userID: userID,
            followersCount: 0, // followersResponse.count
            followingCount: 0, // followingResponse.count
            postsCount: 0, // postsResponse.count
            totalLikesReceived: 0,
            totalCommentsReceived: 0
        )
    }
    
    // MARK: - コメント関連
    
    func createComment(_ request: CreateCommentRequest) async throws -> Comment {
        let commentData = [
            "post_id": request.postID.uuidString,
            "user_id": currentUserID.uuidString,
            "content": request.content,
            "parent_comment_id": request.parentCommentID?.uuidString,
            "created_at": Date().iso8601String,
            "updated_at": Date().iso8601String
        ].compactMapValues { $0 }
        
        let response = try await supabase
            .from("comments")
            .insert(commentData)
            .select("*, user:user_profiles(*)")
            .single()
            .execute()
        
        // TODO: JSONからCommentにデコード
        let comment = try JSONDecoder().decode(Comment.self, from: response.data)
        
        // 投稿のコメント数を更新
        await updatePostCommentsCount(postID: request.postID, increment: true)
        
        return comment
    }
    
    func getComments(postID: UUID, limit: Int = 20, offset: Int = 0) async throws -> [Comment] {
        let response = try await supabase
            .from("comments")
            .select("*, user:user_profiles(*)")
            .eq("post_id", value: postID.uuidString)
            .`is`("parent_comment_id", value: true) // トップレベルコメントのみ (is null)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
        
        // TODO: JSONから[Comment]にデコード
        return try JSONDecoder().decode([Comment].self, from: response.data)
    }
    
    func getReplies(commentID: UUID) async throws -> [Comment] {
        let response = try await supabase
            .from("comments")
            .select("*, user:user_profiles(*)")
            .eq("parent_comment_id", value: commentID.uuidString)
            .order("created_at", ascending: true)
            .execute()
        
        // TODO: JSONから[Comment]にデコード
        return try JSONDecoder().decode([Comment].self, from: response.data)
    }
    
    func likeComment(commentID: UUID) async throws {
        let likeData = [
            "user_id": currentUserID.uuidString,
            "comment_id": commentID.uuidString,
            "created_at": Date().iso8601String
        ]
        
        try await supabase
            .from("likes")
            .insert(likeData)
            .execute()
        
        // コメントのいいね数を更新
        await updateCommentLikesCount(commentID: commentID, increment: true)
    }
    
    func unlikeComment(commentID: UUID) async throws {
        try await supabase
            .from("likes")
            .delete()
            .eq("user_id", value: currentUserID.uuidString)
            .eq("comment_id", value: commentID.uuidString)
            .execute()
        
        // コメントのいいね数を更新
        await updateCommentLikesCount(commentID: commentID, increment: false)
    }
    
    func deleteComment(commentID: UUID) async throws {
        // コメントを削除
        try await supabase
            .from("comments")
            .delete()
            .eq("id", value: commentID.uuidString)
            .eq("user_id", value: currentUserID.uuidString) // 自分のコメントのみ削除可能
            .execute()
        
        // 関連するいいねも削除
        try await supabase
            .from("likes")
            .delete()
            .eq("comment_id", value: commentID.uuidString)
            .execute()
    }
    
    // MARK: - いいね関連
    
    func likePost(postID: UUID) async throws {
        let likeData = [
            "user_id": currentUserID.uuidString,
            "post_id": postID.uuidString,
            "created_at": Date().iso8601String
        ]
        
        try await supabase
            .from("likes")
            .insert(likeData)
            .execute()
        
        // 投稿のいいね数を更新
        await updatePostLikesCount(postID: postID, increment: true)
    }
    
    func unlikePost(postID: UUID) async throws {
        try await supabase
            .from("likes")
            .delete()
            .eq("user_id", value: currentUserID.uuidString)
            .eq("post_id", value: postID.uuidString)
            .execute()
        
        // 投稿のいいね数を更新
        await updatePostLikesCount(postID: postID, increment: false)
    }
    
    func getLikes(postID: UUID) async throws -> [Like] {
        let response = try await supabase
            .from("likes")
            .select("*, user:user_profiles(*)")
            .eq("post_id", value: postID.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        // TODO: JSONから[Like]にデコード
        return try JSONDecoder().decode([Like].self, from: response.data)
    }
    
    // MARK: - 活動フィード
    
    func getActivityFeed(limit: Int = 20, offset: Int = 0) async throws -> [ActivityFeedItem] {
        let response = try await supabase
            .from("activity_feed")
            .select("""
                *, 
                actor_user:user_profiles!actor_user_id(*),
                target_post:posts(*),
                target_comment:comments(*),
                target_user:user_profiles!target_user_id(*)
            """)
            .eq("recipient_user_id", value: currentUserID.uuidString)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
        
        // TODO: JSONから[ActivityFeedItem]にデコード
        return try JSONDecoder().decode([ActivityFeedItem].self, from: response.data)
    }
    
    func markActivityAsRead(activityID: UUID) async throws {
        try await supabase
            .from("activity_feed")
            .update(["is_read": true])
            .eq("id", value: activityID.uuidString)
            .eq("recipient_user_id", value: currentUserID.uuidString)
            .execute()
    }
    
    // MARK: - ユーザー検索
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [UserSearchResult] {
        let response = try await supabase
            .from("user_profiles")
            .select("*")
            .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
            .neq("id", value: currentUserID.uuidString)
            .limit(limit)
            .execute()
        
        // TODO: JSONから[UserSearchResult]にデコード
        // フォロー状態なども含めて取得
        return []
    }
    
    func getSuggestedUsers(limit: Int = 10) async throws -> [UserProfile] {
        // フォローしていないユーザーを取得
        let response = try await supabase
            .from("user_profiles")
            .select("*")
            .not("id", operator: .in, value: "(SELECT following_id FROM follows WHERE follower_id = '\(currentUserID.uuidString)')")
            .neq("id", value: currentUserID.uuidString)
            .limit(limit)
            .execute()
        
        // TODO: JSONから[UserProfile]にデコード
        return []
    }
    
    // MARK: - Helper Methods
    
    private func updateFollowStats(followerID: UUID, followingID: UUID, isFollowing: Bool) async {
        // フォロワー・フォロー数の統計を更新
        // 実際の実装では、PostgreSQL関数やトリガーを使用して自動更新
    }
    
    private func updatePostLikesCount(postID: UUID, increment: Bool) async {
        // 投稿のいいね数を更新
        let operation = increment ? "increment" : "decrement"
        // TODO: Supabaseのincrement/decrement関数を使用
    }
    
    private func updatePostCommentsCount(postID: UUID, increment: Bool) async {
        // 投稿のコメント数を更新
        let operation = increment ? "increment" : "decrement"
        // TODO: Supabaseのincrement/decrement関数を使用
    }
    
    private func updateCommentLikesCount(commentID: UUID, increment: Bool) async {
        // コメントのいいね数を更新
        let operation = increment ? "increment" : "decrement"
        // TODO: Supabaseのincrement/decrement関数を使用
    }
}