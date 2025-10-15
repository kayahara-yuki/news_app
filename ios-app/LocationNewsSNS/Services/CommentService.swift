import Foundation
import Combine
import Supabase

// MARK: - コメント管理サービス

@MainActor
class CommentService: ObservableObject {
    @Published var comments: [UUID: [Comment]] = [:] // postID -> comments
    @Published var replies: [UUID: [Comment]] = [:] // commentID -> replies
    @Published var isLoading = false
    @Published var isLoadingReplies = false
    @Published var errorMessage: String?
    
    private let socialRepository: SocialRepositoryProtocol
    private let realtimeService: RealtimeService
    private var cancellables = Set<AnyCancellable>()
    private var commentChannel: RealtimeChannel?
    
    init(socialRepository: SocialRepositoryProtocol? = nil, authService: AuthService? = nil) {
        // AuthServiceから現在のユーザーIDを取得
        let currentUserID = authService?.currentUser?.id ?? UUID()
        self.socialRepository = socialRepository ?? SocialRepository(currentUserID: currentUserID)
        self.realtimeService = RealtimeService()
        setupRealtimeSubscriptions()
    }
    
    // MARK: - Realtime Setup
    
    private func setupRealtimeSubscriptions() {
        // TODO: Supabase Realtime API の型定義が必要
        // リアルタイムイベント処理は一旦無効化
        commentChannel = realtimeService.subscribeToChannel(
            "comments_updates",
            table: "comments"
        )
    }
    
    // MARK: - コメント管理
    
    /// コメントを投稿
    func createComment(
        postID: UUID,
        content: String,
        parentCommentID: UUID? = nil
    ) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "コメントが空です"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let request = CreateCommentRequest(
                postID: postID,
                content: content,
                parentCommentID: parentCommentID
            )
            
            let newComment = try await socialRepository.createComment(request)
            
            // ローカル状態を更新
            if parentCommentID == nil {
                // トップレベルコメント
                if comments[postID] == nil {
                    comments[postID] = []
                }
                comments[postID]?.insert(newComment, at: 0)
            } else {
                // 返信コメント
                if let parentID = parentCommentID {
                    if replies[parentID] == nil {
                        replies[parentID] = []
                    }
                    replies[parentID]?.append(newComment)
                }
            }
            
            // 通知を送信
            NotificationCenter.default.post(
                name: .commentCreated,
                object: nil,
                userInfo: [
                    "comment": newComment,
                    "postID": postID
                ]
            )
            
            errorMessage = nil
            
        } catch {
            print("コメント投稿エラー: \(error)")
            errorMessage = "コメントの投稿に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// 投稿のコメントを取得
    func loadComments(postID: UUID, refresh: Bool = false) async {
        if refresh {
            comments[postID] = []
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let postComments = try await socialRepository.getComments(
                postID: postID,
                limit: 20,
                offset: comments[postID]?.count ?? 0
            )
            
            if comments[postID] == nil {
                comments[postID] = postComments
            } else {
                comments[postID]?.append(contentsOf: postComments)
            }
            
            errorMessage = nil
            
        } catch {
            print("コメント取得エラー: \(error)")
            errorMessage = "コメントの取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// コメントの返信を取得
    func loadReplies(commentID: UUID) async {
        isLoadingReplies = true
        defer { isLoadingReplies = false }
        
        do {
            let commentReplies = try await socialRepository.getReplies(commentID: commentID)
            replies[commentID] = commentReplies
            errorMessage = nil
            
        } catch {
            print("返信取得エラー: \(error)")
            errorMessage = "返信の取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// コメントにいいね
    func likeComment(_ commentID: UUID, postID: UUID) async {
        do {
            try await socialRepository.likeComment(commentID: commentID)
            
            // ローカル状態を更新
            updateCommentLikeStatus(commentID: commentID, postID: postID, isLiked: true)
            
            errorMessage = nil
            
        } catch {
            print("コメントいいねエラー: \(error)")
            errorMessage = "いいねに失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// コメントのいいねを取り消し
    func unlikeComment(_ commentID: UUID, postID: UUID) async {
        do {
            try await socialRepository.unlikeComment(commentID: commentID)
            
            // ローカル状態を更新
            updateCommentLikeStatus(commentID: commentID, postID: postID, isLiked: false)
            
            errorMessage = nil
            
        } catch {
            print("コメントいいね取り消しエラー: \(error)")
            errorMessage = "いいねの取り消しに失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// コメントを削除
    func deleteComment(_ commentID: UUID, postID: UUID) async {
        do {
            try await socialRepository.deleteComment(commentID: commentID)
            
            // ローカル状態から削除
            removeCommentFromLocal(commentID: commentID, postID: postID)
            
            // 通知を送信
            NotificationCenter.default.post(
                name: .commentDeleted,
                object: nil,
                userInfo: [
                    "commentID": commentID,
                    "postID": postID
                ]
            )
            
            errorMessage = nil
            
        } catch {
            print("コメント削除エラー: \(error)")
            errorMessage = "コメントの削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateCommentLikeStatus(commentID: UUID, postID: UUID, isLiked: Bool) {
        // 投稿のコメントを更新
        if let commentIndex = comments[postID]?.firstIndex(where: { $0.id == commentID }) {
            var updatedComment = comments[postID]![commentIndex]
            // TODO: Comment構造体にisLikedByCurrentUserプロパティの更新ロジックを追加
            comments[postID]![commentIndex] = updatedComment
        }
        
        // 返信コメントも確認
        for (parentCommentID, replyList) in replies {
            if let replyIndex = replyList.firstIndex(where: { $0.id == commentID }) {
                var updatedReply = replies[parentCommentID]![replyIndex]
                // TODO: 同様の更新ロジック
                replies[parentCommentID]![replyIndex] = updatedReply
            }
        }
    }
    
    private func removeCommentFromLocal(commentID: UUID, postID: UUID) {
        // 投稿のコメントから削除
        comments[postID]?.removeAll { $0.id == commentID }
        
        // 返信コメントから削除
        for (parentCommentID, _) in replies {
            replies[parentCommentID]?.removeAll { $0.id == commentID }
        }
        
        // このコメントの返信も削除
        replies.removeValue(forKey: commentID)
    }
    
    // MARK: - Realtime Event Handlers
    // TODO: Supabase Realtime API の型定義が必要
    // 以下のハンドラは一旦コメントアウト

    /*
    private func handleNewComment(_ change: PostgresChange) {
        guard let record = change.record else { return }

        // TODO: JSONからCommentオブジェクトを作成
        // 適切な投稿またはコメントに追加

        print("新しいコメント受信: \(record)")
    }

    private func handleCommentUpdate(_ change: PostgresChange) {
        guard let record = change.record else { return }

        // TODO: 既存のコメントを更新
        print("コメント更新: \(record)")
    }

    private func handleCommentDelete(_ change: PostgresChange) {
        guard let oldRecord = change.oldRecord else { return }

        // TODO: コメントを削除
        print("コメント削除: \(oldRecord)")
    }
    */
    
    // MARK: - Utility Methods
    
    /// 特定の投稿のコメント数を取得
    func getCommentsCount(postID: UUID) -> Int {
        return comments[postID]?.count ?? 0
    }
    
    /// 特定のコメントの返信数を取得
    func getRepliesCount(commentID: UUID) -> Int {
        return replies[commentID]?.count ?? 0
    }
    
    /// コメントをクリア（メモリ最適化）
    func clearComments(postID: UUID) {
        comments.removeValue(forKey: postID)
    }
    
    /// すべてのコメントをクリア
    func clearAllComments() {
        comments.removeAll()
        replies.removeAll()
    }
    
    /// コメントのプレビューテキストを取得
    func getCommentPreview(postID: UUID) -> String? {
        guard let postComments = comments[postID],
              let latestComment = postComments.first else {
            return nil
        }
        
        let preview = latestComment.content.prefix(50)
        return String(preview) + (latestComment.content.count > 50 ? "..." : "")
    }
    
    /// コメントのメンション検出
    func detectMentions(in text: String) -> [String] {
        let mentionPattern = "@([a-zA-Z0-9_]+)"
        let regex = try? NSRegularExpression(pattern: mentionPattern)
        let range = NSRange(text.startIndex..., in: text)
        
        let matches = regex?.matches(in: text, range: range) ?? []
        
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }
    
    /// コメントの感情分析（簡易版）
    func analyzeSentiment(comment: Comment) -> CommentSentiment {
        let content = comment.content.lowercased()
        
        let positiveWords = ["good", "great", "awesome", "love", "like", "amazing", "excellent"]
        let negativeWords = ["bad", "terrible", "hate", "awful", "horrible", "worst"]
        
        let positiveCount = positiveWords.reduce(0) { count, word in
            count + (content.contains(word) ? 1 : 0)
        }
        
        let negativeCount = negativeWords.reduce(0) { count, word in
            count + (content.contains(word) ? 1 : 0)
        }
        
        if positiveCount > negativeCount {
            return .positive
        } else if negativeCount > positiveCount {
            return .negative
        } else {
            return .neutral
        }
    }
}

// MARK: - Supporting Types

enum CommentSentiment {
    case positive
    case negative
    case neutral
}

// MARK: - Notification Names

extension Notification.Name {
    static let commentCreated = Notification.Name("commentCreated")
    static let commentDeleted = Notification.Name("commentDeleted")
    static let commentLiked = Notification.Name("commentLiked")
    static let replyCreated = Notification.Name("replyCreated")
}