import SwiftUI

// MARK: - ユーザープロフィール詳細画面

struct UserProfileDetailView: View {
    let user: UserProfile

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialService: SocialService
    @EnvironmentObject var authService: AuthService

    @State private var isFollowing = false
    @State private var followerCount = 0
    @State private var followingCount = 0
    @State private var postCount = 0
    @State private var isLoadingStats = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // プロフィールヘッダー
                    profileHeader

                    Divider()
                        .padding(.vertical, 16)

                    // 統計情報
                    statsSection

                    Divider()
                        .padding(.vertical, 16)

                    // Bio（自己紹介）
                    if let bio = user.bio, !bio.isEmpty {
                        bioSection(bio)
                    }

                    // 投稿一覧（将来実装）
                    postsPlaceholder
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadUserData()
            }
        }
    }

    // MARK: - Profile Header

    @ViewBuilder
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // アバター画像
            if let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    defaultAvatar
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                defaultAvatar
            }

            // ユーザー名と認証バッジ
            HStack(spacing: 6) {
                Text(user.displayName ?? user.username)
                    .font(.title2)
                    .fontWeight(.bold)

                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }

            // ユーザーID
            Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // フォローボタン（自分以外のプロフィール）
            if user.id != authService.currentUser?.id {
                Button(action: toggleFollow) {
                    HStack {
                        Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                        Text(isFollowing ? "フォロー中" : "フォロー")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundColor(isFollowing ? .primary : .white)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                    .cornerRadius(22)
                }
                .padding(.horizontal, 40)
            }
        }
    }

    @ViewBuilder
    private var defaultAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            )
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        HStack(spacing: 40) {
            StatItem(title: "投稿", count: postCount)
            StatItem(title: "フォロワー", count: followerCount)
            StatItem(title: "フォロー中", count: followingCount)
        }
        .opacity(isLoadingStats ? 0.5 : 1.0)
    }

    // MARK: - Bio Section

    @ViewBuilder
    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自己紹介")
                .font(.headline)
                .fontWeight(.semibold)

            Text(bio)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 16)
    }

    // MARK: - Posts Placeholder

    @ViewBuilder
    private var postsPlaceholder: some View {
        VStack(spacing: 16) {
            Text("投稿一覧")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                Image(systemName: "newspaper")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)

                Text("投稿がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }

    // MARK: - Methods

    private func loadUserData() {
        Task {
            // フォロー状態を確認
            isFollowing = await socialService.checkFollowStatus(userID: user.id)

            // 統計情報を取得
            await socialService.loadSocialStats(userID: user.id)

            if let stats = socialService.socialStats {
                followerCount = stats.followersCount
                followingCount = stats.followingCount
                postCount = stats.postsCount
            }

            isLoadingStats = false
        }
    }

    private func toggleFollow() {
        Task {
            if isFollowing {
                await socialService.unfollowUser(user.id)
                isFollowing = false
                followerCount = max(0, followerCount - 1)
            } else {
                await socialService.followUser(user.id)
                isFollowing = true
                followerCount += 1
            }
        }
    }
}

// MARK: - Stat Item View

struct StatItem: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    UserProfileDetailView(
        user: UserProfile(
            id: UUID(),
            email: "test@example.com",
            username: "testuser",
            displayName: "テストユーザー",
            bio: "これはテストユーザーのプロフィールです。よろしくお願いします！",
            avatarURL: nil,
            location: "東京都",
            isVerified: true,
            role: .user,
            privacySettings: PrivacySettings.default,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .withDependencies()
}
