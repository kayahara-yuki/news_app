//
//  FollowersListView.swift
//  LocationNewsSNS
//
//  Created by Claude on 2025/10/13.
//

import SwiftUI

struct FollowersListView: View {
    let userID: UUID
    @StateObject private var viewModel: FollowViewModel
    @EnvironmentObject private var authService: AuthService

    init(userID: UUID, socialService: SocialService, authService: AuthService) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: FollowViewModel(
            socialService: socialService,
            authService: authService
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.followers.isEmpty {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.followers.isEmpty {
                emptyView
            } else {
                followersList
            }
        }
        .navigationTitle("フォロワー")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadFollowers(userID: userID)

            // フォロー状態を一括チェック
            let followerIDs = viewModel.followers.map { $0.id }
            await viewModel.checkMultipleFollowStatus(userIDs: followerIDs)
        }
        .refreshable {
            await viewModel.loadFollowers(userID: userID)
        }
    }

    private var followersList: some View {
        List(viewModel.followers) { follower in
            NavigationLink(destination: UserProfileView(userID: follower.id)) {
                UserRowView(
                    user: follower,
                    isFollowing: viewModel.followStatusCache[follower.id] ?? false,
                    showFollowButton: follower.id != authService.currentUser?.id,
                    onFollowTap: {
                        Task {
                            if viewModel.followStatusCache[follower.id] == true {
                                await viewModel.unfollowUser(follower.id)
                            } else {
                                await viewModel.followUser(follower.id)
                            }
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("フォロワーがいません")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("まだフォロワーがいません")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ユーザープロフィール画面のプレースホルダー
struct UserProfileView: View {
    let userID: UUID

    var body: some View {
        Text("ユーザープロフィール: \(userID.uuidString)")
            .navigationTitle("プロフィール")
    }
}

#Preview {
    NavigationStack {
        FollowersListView(
            userID: UUID(),
            socialService: SocialService(),
            authService: AuthService()
        )
        .environmentObject(AuthService())
    }
}
