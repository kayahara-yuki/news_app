import SwiftUI

// MARK: - Post Detail Sheet (X/Twitter風)

struct PostDetailSheet: View {
    let post: Post

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var commentService: CommentService
    @EnvironmentObject var authService: AuthService

    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var commentCount: Int
    @State private var showUserProfile = false
    @State private var showComments = true

    init(post: Post) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
        _commentCount = State(initialValue: post.commentCount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // ユーザー情報ヘッダー（タップ可能）
                        userHeaderSection

                        // 投稿内容
                        postContentSection

                        // バッジ
                        badgesSection

                        // 位置情報
                        if post.latitude != nil && post.longitude != nil {
                            locationSection
                        }

                        // 投稿日時
                        timestampSection

                        // いいね・コメント数
                        engagementStatsSection

                        Divider()
                            .padding(.vertical, 12)

                        // アクションボタン
                        actionButtonsSection

                        Divider()
                            .padding(.vertical, 12)

                        // コメントセクション
                        commentsSection
                    }
                }
            }
            .navigationTitle("投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showUserProfile) {
                UserProfileDetailView(user: post.user)
            }
            .onAppear {
                loadComments()
                checkLikeStatus()
                refreshPostData()
            }
        }
    }

    // MARK: - User Header Section

    @ViewBuilder
    private var userHeaderSection: some View {
        Button(action: { showUserProfile = true }) {
            HStack(spacing: 12) {
                // アバター
                if let avatarURL = post.user.avatarURL, let url = URL(string: avatarURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(post.user.displayName ?? post.user.username)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        if post.user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }

                    Text("@\(post.user.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Post Content Section

    @ViewBuilder
    private var postContentSection: some View {
        Text(post.content)
            .font(.body)
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }

    // MARK: - Badges Section

    @ViewBuilder
    private var badgesSection: some View {
        HStack(spacing: 8) {
            if post.isUrgent {
                Label("緊急", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(12)
            }

            if post.isVerified {
                Label("検証済み", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Text(post.category.displayName)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray)
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundColor(.secondary)

            if let address = post.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("緯度: \(post.latitude!, specifier: "%.4f"), 経度: \(post.longitude!, specifier: "%.4f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Timestamp Section

    @ViewBuilder
    private var timestampSection: some View {
        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 4)
    }

    // MARK: - Engagement Stats Section

    @ViewBuilder
    private var engagementStatsSection: some View {
        HStack(spacing: 20) {
            HStack(spacing: 4) {
                Text("\(likeCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("いいね")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Text("\(commentCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("コメント")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Action Buttons Section

    @ViewBuilder
    private var actionButtonsSection: some View {
        HStack(spacing: 0) {
            // いいねボタン
            Button(action: toggleLike) {
                HStack(spacing: 8) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(isLiked ? .red : .secondary)
                    Text("\(likeCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            // コメントボタン
            Button(action: { showComments.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("\(commentCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            // シェアボタン
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Comments Section

    @ViewBuilder
    private var commentsSection: some View {
        if showComments {
            VStack(alignment: .leading, spacing: 0) {
                Text("コメント")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                // CommentsViewを埋め込み
                CommentsView(post: post)
                    .environmentObject(commentService)
                    .environmentObject(authService)
                    .frame(minHeight: 400)
            }
        }
    }

    // MARK: - Methods

    private func loadComments() {
        Task {
            await commentService.loadComments(postID: post.id)
        }
    }

    private func checkLikeStatus() {
        guard let currentUserID = authService.currentUser?.id else {
            isLiked = false
            return
        }

        Task {
            let likedStatus = await postService.checkLikeStatus(postID: post.id, userID: currentUserID)
            await MainActor.run {
                isLiked = likedStatus
            }
        }
    }

    private func toggleLike() {
        Task {
            if isLiked {
                await postService.unlikePost(id: post.id)
                likeCount = max(0, likeCount - 1)
                isLiked = false
            } else {
                await postService.likePost(id: post.id)
                likeCount += 1
                isLiked = true
            }
        }
    }

    private func refreshPostData() {
        Task {
            // 投稿の最新データを取得
            if let updatedPost = await postService.getPost(id: post.id) {
                await MainActor.run {
                    likeCount = updatedPost.likeCount
                    commentCount = updatedPost.commentCount
                }
            } else {
                print("⚠️ [WARNING] PostDetailView.refreshPostData - 投稿の取得に失敗")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PostDetailSheet(
        post: Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                email: "test@example.com",
                username: "testuser",
                displayName: "テストユーザー",
                bio: "テストです",
                avatarURL: nil,
                location: nil,
                isVerified: true,
                role: .user,
                privacySettings: PrivacySettings.default,
                createdAt: Date(),
                updatedAt: Date()
            ),
            content: "これはテスト投稿です。X（Twitter）風のUIで表示されます。",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "東京駅",
            category: .news,
            visibility: .public,
            isUrgent: false,
            isVerified: true,
            likeCount: 42,
            commentCount: 10,
            shareCount: 5,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date()
        )
    )
    
    
    
    .withDependencies()
}
