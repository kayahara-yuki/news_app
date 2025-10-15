//
//  UserRowView.swift
//  LocationNewsSNS
//
//  Created by Claude on 2025/10/13.
//

import SwiftUI

struct UserRowView: View {
    let user: UserProfile
    let isFollowing: Bool
    let onFollowTap: () -> Void
    let showFollowButton: Bool

    init(
        user: UserProfile,
        isFollowing: Bool = false,
        showFollowButton: Bool = true,
        onFollowTap: @escaping () -> Void = {}
    ) {
        self.user = user
        self.isFollowing = isFollowing
        self.showFollowButton = showFollowButton
        self.onFollowTap = onFollowTap
    }

    var body: some View {
        HStack(spacing: 12) {
            // アバター画像
            if let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    defaultAvatar
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                defaultAvatar
            }

            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(user.displayName ?? user.username)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // フォローボタン
            if showFollowButton {
                Button(action: onFollowTap) {
                    Text(isFollowing ? "フォロー中" : "フォロー")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isFollowing ? .primary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            )
    }
}

#Preview {
    VStack {
        UserRowView(
            user: UserProfile(
                id: UUID(),
                email: "test@example.com",
                username: "testuser",
                displayName: "Test User",
                bio: "This is a test bio",
                avatarURL: nil,
                location: nil,
                isVerified: true,
                role: .user,
                privacySettings: PrivacySettings.default,
                createdAt: Date(),
                updatedAt: Date()
            ),
            isFollowing: false,
            onFollowTap: {}
        )
        .padding()

        UserRowView(
            user: UserProfile(
                id: UUID(),
                email: "test2@example.com",
                username: "testuser2",
                displayName: "Following User",
                bio: nil,
                avatarURL: nil,
                location: nil,
                isVerified: false,
                role: .user,
                privacySettings: PrivacySettings.default,
                createdAt: Date(),
                updatedAt: Date()
            ),
            isFollowing: true,
            onFollowTap: {}
        )
        .padding()
    }
}
