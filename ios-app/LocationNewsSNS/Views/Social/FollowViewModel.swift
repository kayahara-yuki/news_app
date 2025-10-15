//
//  FollowViewModel.swift
//  LocationNewsSNS
//
//  Created by Claude on 2025/10/13.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FollowViewModel: ObservableObject {
    @Published var followers: [UserProfile] = []
    @Published var following: [UserProfile] = []
    @Published var socialStats: SocialStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var followStatusCache: [UUID: Bool] = [:]

    private let socialService: SocialService
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(socialService: SocialService, authService: AuthService) {
        self.socialService = socialService
        self.authService = authService
        observeSocialServiceChanges()
    }

    // MARK: - Setup

    private func observeSocialServiceChanges() {
        // SocialServiceの変更を監視
        socialService.$followers
            .assign(to: &$followers)

        socialService.$following
            .assign(to: &$following)

        socialService.$socialStats
            .assign(to: &$socialStats)

        socialService.$isLoading
            .assign(to: &$isLoading)

        socialService.$errorMessage
            .assign(to: &$errorMessage)
    }

    // MARK: - Public Methods

    /// ユーザーをフォロー
    func followUser(_ userID: UUID) async {
        await socialService.followUser(userID)
        followStatusCache[userID] = true
    }

    /// ユーザーのフォローを解除
    func unfollowUser(_ userID: UUID) async {
        await socialService.unfollowUser(userID)
        followStatusCache[userID] = false
    }

    /// フォロー状態をチェック
    func checkFollowStatus(userID: UUID) async -> Bool {
        // キャッシュがあればそれを返す
        if let cached = followStatusCache[userID] {
            return cached
        }

        let isFollowing = await socialService.checkFollowStatus(userID: userID)
        followStatusCache[userID] = isFollowing
        return isFollowing
    }

    /// フォロワーリストを読み込み
    func loadFollowers(userID: UUID) async {
        await socialService.loadFollowers(userID: userID)
    }

    /// フォロー中リストを読み込み
    func loadFollowing(userID: UUID) async {
        await socialService.loadFollowing(userID: userID)
    }

    /// ソーシャル統計を読み込み
    func loadSocialStats(userID: UUID) async {
        await socialService.loadSocialStats(userID: userID)
    }

    /// 現在のユーザーのソーシャル情報を読み込み
    func loadCurrentUserSocialInfo() async {
        guard let currentUser = authService.currentUser else { return }

        await loadFollowers(userID: currentUser.id)
        await loadFollowing(userID: currentUser.id)
        await loadSocialStats(userID: currentUser.id)
    }

    /// 複数ユーザーのフォロー状態を一括チェック
    func checkMultipleFollowStatus(userIDs: [UUID]) async {
        let results = await socialService.checkMultipleFollowStatus(userIDs: userIDs)

        // キャッシュを更新
        for (userID, isFollowing) in results {
            followStatusCache[userID] = isFollowing
        }
    }

    /// キャッシュをクリア
    func clearCache() {
        followStatusCache.removeAll()
    }
}
