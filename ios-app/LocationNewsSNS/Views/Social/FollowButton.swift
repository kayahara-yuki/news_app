//
//  FollowButton.swift
//  LocationNewsSNS
//
//  Created by Claude on 2025/10/13.
//

import SwiftUI

struct FollowButton: View {
    let userID: UUID
    @Binding var isFollowing: Bool
    let onFollowToggle: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        Button(action: {
            Task {
                isProcessing = true
                await onFollowToggle()
                isProcessing = false
            }
        }) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isFollowing ? .primary : .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isFollowing ? "person.fill.checkmark" : "person.fill.badge.plus")
                        .font(.footnote)
                }

                Text(isFollowing ? "フォロー中" : "フォロー")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isFollowing ? .primary : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
}

#Preview {
    VStack(spacing: 20) {
        FollowButton(
            userID: UUID(),
            isFollowing: .constant(false),
            onFollowToggle: {}
        )

        FollowButton(
            userID: UUID(),
            isFollowing: .constant(true),
            onFollowToggle: {}
        )
    }
    .padding()
}
