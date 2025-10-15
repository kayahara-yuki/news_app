//
//  FollowingListView.swift
//  LocationNewsSNS
//
//  Created by Claude on 2025/10/13.
//

import SwiftUI

struct FollowingListView: View {
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
            if viewModel.isLoading && viewModel.following.isEmpty {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.following.isEmpty {
                emptyView
            } else {
                followingList
            }
        }
        .navigationTitle("フォロー中")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadFollowing(userID: userID)

            // フォロー状態を設定（全員フォロー中）
            for user in viewModel.following {
                viewModel.followStatusCache[user.id] = true
            }
        }
        .refreshable {
            await viewModel.loadFollowing(userID: userID)
        }
    }

    private var followingList: some View {
        List(viewModel.following) { user in
            NavigationLink(destination: UserProfileView(userID: user.id)) {
                UserRowView(
                    user: user,
                    isFollowing: viewModel.followStatusCache[user.id] ?? true,
                    showFollowButton: user.id != authService.currentUser?.id,
                    onFollowTap: {
                        Task {
                            if viewModel.followStatusCache[user.id] == true {
                                await viewModel.unfollowUser(user.id)
                            } else {
                                await viewModel.followUser(user.id)
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

            Text("フォロー中のユーザーがいません")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("他のユーザーをフォローして投稿を見よう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        FollowingListView(
            userID: UUID(),
            socialService: SocialService(),
            authService: AuthService()
        )
        .environmentObject(AuthService())
    }
}
