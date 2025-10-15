import SwiftUI

// MARK: - コメント表示・管理画面

struct CommentsView: View {
    let post: Post
    
    @EnvironmentObject var commentService: CommentService
    @EnvironmentObject var authService: AuthService
    
    @State private var newCommentText = ""
    @State private var replyingTo: Comment?
    @State private var showingReplySheet = false
    @FocusState private var isCommentFieldFocused: Bool
    
    private let maxCommentLength = 500
    
    var body: some View {
        VStack(spacing: 0) {
            // コメントリスト
            commentsList
            
            // コメント入力エリア
            commentInputArea
        }
        .navigationTitle("コメント")
        .navigationBarItems(trailing: Button("完了") {
            // 画面を閉じる
        })
        .onAppear {
            loadComments()
        }
        .sheet(isPresented: $showingReplySheet) {
            if let replyTarget = replyingTo {
                ReplyCommentView(
                    post: post,
                    parentComment: replyTarget,
                    onReplyPosted: { loadComments() }
                )
            }
        }
    }
    
    // MARK: - Comments List
    
    @ViewBuilder
    private var commentsList: some View {
        if commentService.isLoading && commentService.comments[post.id]?.isEmpty != false {
            loadingView
        } else if let comments = commentService.comments[post.id], !comments.isEmpty {
            List {
                ForEach(comments) { comment in
                    CommentRowView(
                        comment: comment,
                        post: post,
                        onReply: { replyToComment(comment) },
                        onLike: { likeComment(comment) },
                        onDelete: { deleteComment(comment) }
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .listStyle(PlainListStyle())
            .refreshable {
                await refreshComments()
            }
        } else {
            emptyCommentsView
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("コメントを読み込み中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var emptyCommentsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("まだコメントがありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("最初にコメントしてみませんか？")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Comment Input Area
    
    @ViewBuilder
    private var commentInputArea: some View {
        VStack(spacing: 8) {
            if let replyTarget = replyingTo {
                replyIndicator(for: replyTarget)
            }
            
            HStack(spacing: 12) {
                // ユーザーアバター
                if let avatarURL = authService.currentUser?.avatarURL {
                    CachedAsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                }
                
                // コメント入力フィールド
                TextField("コメントを入力...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isCommentFieldFocused)
                    .lineLimit(1...4)
                    .onChange(of: newCommentText) { newValue in
                        if newValue.count > maxCommentLength {
                            newCommentText = String(newValue.prefix(maxCommentLength))
                        }
                    }
                
                // 投稿ボタン
                Button(action: postComment) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(canPostComment ? .blue : .gray)
                }
                .disabled(!canPostComment)
            }
            .padding(.horizontal)
            
            // 文字数カウンター
            if !newCommentText.isEmpty {
                HStack {
                    Spacer()
                    Text("\(newCommentText.count)/\(maxCommentLength)")
                        .font(.caption)
                        .foregroundColor(newCommentText.count > maxCommentLength * 9 / 10 ? .red : .secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
    
    @ViewBuilder
    private func replyIndicator(for comment: Comment) -> some View {
        HStack {
            Image(systemName: "arrowshape.turn.up.left")
                .foregroundColor(.blue)
                .font(.caption)
            
            Text("\(comment.user.displayName ?? comment.user.username)に返信")
                .font(.caption)
                .foregroundColor(.blue)
            
            Spacer()
            
            Button("キャンセル") {
                replyingTo = nil
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
    }
    
    // MARK: - Computed Properties
    
    private var canPostComment: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        newCommentText.count <= maxCommentLength &&
        !commentService.isLoading
    }
    
    // MARK: - Methods
    
    private func loadComments() {
        Task {
            await commentService.loadComments(postID: post.id)
        }
    }
    
    private func refreshComments() async {
        await commentService.loadComments(postID: post.id, refresh: true)
    }
    
    private func postComment() {
        guard canPostComment else { return }
        
        let content = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentID = replyingTo?.id
        
        Task {
            await commentService.createComment(
                postID: post.id,
                content: content,
                parentCommentID: parentID
            )
            
            // 成功した場合はフィールドをクリア
            if commentService.errorMessage == nil {
                newCommentText = ""
                replyingTo = nil
                isCommentFieldFocused = false
            }
        }
    }
    
    private func replyToComment(_ comment: Comment) {
        replyingTo = comment
        isCommentFieldFocused = true
    }
    
    private func likeComment(_ comment: Comment) {
        Task {
            if comment.isLikedByCurrentUser {
                await commentService.unlikeComment(comment.id, postID: post.id)
            } else {
                await commentService.likeComment(comment.id, postID: post.id)
            }
        }
    }
    
    private func deleteComment(_ comment: Comment) {
        Task {
            await commentService.deleteComment(comment.id, postID: post.id)
        }
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    let comment: Comment
    let post: Post
    let onReply: () -> Void
    let onLike: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var commentService: CommentService
    @EnvironmentObject var authService: AuthService
    @State private var showingReplies = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // メインコメント
            commentContent
            
            // アクションボタン
            commentActions
            
            // 返信表示
            if showingReplies {
                repliesSection
            }
        }
        .alert("コメントを削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                onDelete()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
    
    @ViewBuilder
    private var commentContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // ユーザーアバター
            if let avatarURL = comment.user.avatarURL {
                CachedAsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // ユーザー名と時間
                HStack {
                    Text(comment.user.displayName ?? comment.user.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if comment.user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text(comment.timeAgoString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // コメント内容
                Text(comment.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    @ViewBuilder
    private var commentActions: some View {
        HStack(spacing: 20) {
            // いいねボタン
            Button(action: onLike) {
                HStack(spacing: 4) {
                    Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .foregroundColor(comment.isLikedByCurrentUser ? .red : .gray)
                    
                    if comment.likesCount > 0 {
                        Text("\(comment.likesCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 返信ボタン
            Button(action: onReply) {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .foregroundColor(.gray)
                    
                    Text("返信")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // 返信数表示
            if comment.repliesCount > 0 {
                Button(action: { showingReplies.toggle() }) {
                    Text("\(comment.repliesCount)件の返信を\(showingReplies ? "非表示" : "表示")")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // 削除ボタン（自分のコメントのみ）
            if comment.user.id == authService.currentUser?.id {
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.leading, 52) // アバターの幅分インデント
    }
    
    @ViewBuilder
    private var repliesSection: some View {
        if let replies = commentService.replies[comment.id] {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(replies) { reply in
                    ReplyRowView(
                        reply: reply,
                        onLike: { likeReply(reply) },
                        onDelete: { deleteReply(reply) }
                    )
                }
            }
            .padding(.leading, 52)
        } else if commentService.isLoadingReplies {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("返信を読み込み中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 52)
        }
    }
    
    private func likeReply(_ reply: Comment) {
        Task {
            if reply.isLikedByCurrentUser {
                await commentService.unlikeComment(reply.id, postID: post.id)
            } else {
                await commentService.likeComment(reply.id, postID: post.id)
            }
        }
    }
    
    private func deleteReply(_ reply: Comment) {
        Task {
            await commentService.deleteComment(reply.id, postID: post.id)
        }
    }
}

// MARK: - Reply Row View

struct ReplyRowView: View {
    let reply: Comment
    let onLike: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 小さなアバター
            if let avatarURL = reply.user.avatarURL {
                CachedAsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // ユーザー名と時間
                HStack {
                    Text(reply.user.displayName ?? reply.user.username)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(reply.timeAgoString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if reply.user.id == authService.currentUser?.id {
                        Button(action: { showingDeleteAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.caption2)
                        }
                    }
                }
                
                // 返信内容
                Text(reply.content)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                
                // いいねボタン
                Button(action: onLike) {
                    HStack(spacing: 2) {
                        Image(systemName: reply.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundColor(reply.isLikedByCurrentUser ? .red : .gray)
                            .font(.caption2)
                        
                        if reply.likesCount > 0 {
                            Text("\(reply.likesCount)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .alert("返信を削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                onDelete()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}

// MARK: - Reply Comment View

struct ReplyCommentView: View {
    let post: Post
    let parentComment: Comment
    let onReplyPosted: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var commentService: CommentService
    
    @State private var replyText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxReplyLength = 500
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // 返信先コメント表示
                parentCommentView
                
                // 返信入力エリア
                VStack(alignment: .leading, spacing: 8) {
                    Text("返信を入力")
                        .font(.headline)
                    
                    TextField("返信を入力...", text: $replyText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .lineLimit(3...8)
                        .onChange(of: replyText) { newValue in
                            if newValue.count > maxReplyLength {
                                replyText = String(newValue.prefix(maxReplyLength))
                            }
                        }
                    
                    HStack {
                        Spacer()
                        Text("\(replyText.count)/\(maxReplyLength)")
                            .font(.caption)
                            .foregroundColor(replyText.count > maxReplyLength * 9 / 10 ? .red : .secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("返信")
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() },
                trailing: Button("投稿") { postReply() }
                    .disabled(!canPostReply)
            )
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
    @ViewBuilder
    private var parentCommentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("返信先")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .top, spacing: 12) {
                if let avatarURL = parentComment.user.avatarURL {
                    CachedAsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(parentComment.user.displayName ?? parentComment.user.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(parentComment.content)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var canPostReply: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        replyText.count <= maxReplyLength &&
        !commentService.isLoading
    }
    
    private func postReply() {
        guard canPostReply else { return }
        
        let content = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            await commentService.createComment(
                postID: post.id,
                content: content,
                parentCommentID: parentComment.id
            )
            
            if commentService.errorMessage == nil {
                onReplyPosted()
                dismiss()
            }
        }
    }
}

#Preview {
    CommentsView(post: Post(
        id: UUID(),
        user: UserProfile(
            id: UUID(),
            email: "test@example.com",
            username: "testuser",
            displayName: "Test User",
            bio: nil,
            avatarURL: nil,
            location: nil,
            isVerified: false,
            role: .user,
            privacySettings: PrivacySettings.default,
            createdAt: Date(),
            updatedAt: Date()
        ),
        content: "Test post content",
        url: nil,
        latitude: 35.6762,
        longitude: 139.6503,
        address: "東京都",
        category: .other,
        visibility: .public,
        isUrgent: false,
        isVerified: false,
        likeCount: 10,
        commentCount: 5,
        shareCount: 2,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(CommentService())
    .environmentObject(AuthService())
}