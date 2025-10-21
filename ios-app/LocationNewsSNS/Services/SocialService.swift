import Foundation
import Combine
import Supabase

// MARK: - ソーシャル機能サービス

@MainActor
class SocialService: ObservableObject {
    @Published var followers: [UserProfile] = []
    @Published var following: [UserProfile] = []
    @Published var socialStats: SocialStats?
    @Published var activityFeed: [ActivityFeedItem] = []
    @Published var suggestedUsers: [UserProfile] = []
    @Published var searchResults: [UserSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let socialRepository: SocialRepositoryProtocol
    private let realtimeService: RealtimeService
    private var cancellables = Set<AnyCancellable>()
    private var followChannel: RealtimeChannelV2?
    
    init(socialRepository: SocialRepositoryProtocol? = nil) {
        self.socialRepository = socialRepository ?? SocialRepository()
        self.realtimeService = RealtimeService()
        setupRealtimeSubscriptions()
    }
    
    // MARK: - Realtime Setup
    
    private func setupRealtimeSubscriptions() {
        Task {
            // フォロー関連のリアルタイム更新
            followChannel = await realtimeService.subscribeToChannel(
                "social_updates",
                table: "follows"
            )
        }

        // リアルタイムイベント処理は RealtimeService 内で管理
        // 必要に応じて NotificationCenter でイベントを受け取る
    }
    
    // MARK: - フォロー関連
    
    /// ユーザーをフォロー
    func followUser(_ userID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await socialRepository.followUser(userID: userID)
            
            // ローカル状態を更新
            await refreshSocialStats()
            
            // 通知を送信
            NotificationCenter.default.post(
                name: .userFollowed,
                object: nil,
                userInfo: ["userID": userID]
            )
            
            errorMessage = nil
            
        } catch {
            print("フォローエラー: \(error)")
            errorMessage = "フォローに失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// ユーザーのフォローを解除
    func unfollowUser(_ userID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await socialRepository.unfollowUser(userID: userID)
            
            // ローカル状態を更新
            following.removeAll { $0.id == userID }
            await refreshSocialStats()
            
            // 通知を送信
            NotificationCenter.default.post(
                name: .userUnfollowed,
                object: nil,
                userInfo: ["userID": userID]
            )
            
            errorMessage = nil
            
        } catch {
            print("フォロー解除エラー: \(error)")
            errorMessage = "フォロー解除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// フォロー状態をチェック
    func checkFollowStatus(userID: UUID) async -> Bool {
        do {
            return try await socialRepository.checkFollowStatus(userID: userID)
        } catch {
            print("フォロー状態チェックエラー: \(error)")
            return false
        }
    }
    
    /// フォロワーリストを取得
    func loadFollowers(userID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let followersList = try await socialRepository.getFollowers(userID: userID)
            followers = followersList
            errorMessage = nil
            
        } catch {
            print("フォロワー取得エラー: \(error)")
            errorMessage = "フォロワーの取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// フォロー中リストを取得
    func loadFollowing(userID: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let followingList = try await socialRepository.getFollowing(userID: userID)
            following = followingList
            errorMessage = nil
            
        } catch {
            print("フォロー中取得エラー: \(error)")
            errorMessage = "フォロー中の取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// ソーシャル統計を取得
    func loadSocialStats(userID: UUID) async {
        do {
            let stats = try await socialRepository.getSocialStats(userID: userID)
            socialStats = stats
            errorMessage = nil
            
        } catch {
            print("統計取得エラー: \(error)")
            errorMessage = "統計の取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 活動フィード
    
    /// 活動フィードを取得
    func loadActivityFeed() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let feed = try await socialRepository.getActivityFeed(limit: 50, offset: 0)
            activityFeed = feed
            errorMessage = nil
            
        } catch {
            print("活動フィード取得エラー: \(error)")
            errorMessage = "活動フィードの取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// 活動を既読にマーク
    func markActivityAsRead(_ activityID: UUID) async {
        do {
            try await socialRepository.markActivityAsRead(activityID: activityID)
            
            // ローカル状態を更新
            if let index = activityFeed.firstIndex(where: { $0.id == activityID }) {
                // 既読状態を更新（ActivityFeedItemにisReadプロパティを追加する必要がある）
            }
            
        } catch {
            print("既読マークエラー: \(error)")
        }
    }
    
    // MARK: - ユーザー検索・推奨
    
    /// ユーザーを検索
    func searchUsers(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await socialRepository.searchUsers(query: query, limit: 20)
            searchResults = results
            errorMessage = nil
            
        } catch {
            print("ユーザー検索エラー: \(error)")
            errorMessage = "ユーザー検索に失敗しました: \(error.localizedDescription)"
        }
    }
    
    /// おすすめユーザーを取得
    func loadSuggestedUsers() async {
        do {
            let suggested = try await socialRepository.getSuggestedUsers(limit: 10)
            suggestedUsers = suggested
            errorMessage = nil
            
        } catch {
            print("おすすめユーザー取得エラー: \(error)")
            errorMessage = "おすすめユーザーの取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Realtime Event Handlers
    // リアルタイムイベント処理は RealtimeService 内で管理
    
    // MARK: - Helper Methods
    
    private func refreshSocialStats() async {
        // 現在のユーザーIDを取得して統計を更新
        // TODO: 実際の実装では認証サービスから現在のユーザーIDを取得
        let currentUserID = UUID()
        await loadSocialStats(userID: currentUserID)
    }
    
    /// フォロー関係の一括チェック
    func checkMultipleFollowStatus(userIDs: [UUID]) async -> [UUID: Bool] {
        var results: [UUID: Bool] = [:]
        
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for userID in userIDs {
                group.addTask { [weak self] in
                    let isFollowing = await self?.checkFollowStatus(userID: userID) ?? false
                    return (userID, isFollowing)
                }
            }
            
            for await (userID, isFollowing) in group {
                results[userID] = isFollowing
            }
        }
        
        return results
    }
    
    /// フォロー推奨アルゴリズム
    func getPersonalizedSuggestions() async {
        // 共通の友達、興味、位置などに基づく推奨
        // TODO: より高度な推奨アルゴリズムの実装
        await loadSuggestedUsers()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userFollowed = Notification.Name("userFollowed")
    static let userUnfollowed = Notification.Name("userUnfollowed")
    static let newActivityReceived = Notification.Name("newActivityReceived")
    static let followRequestReceived = Notification.Name("followRequestReceived")
}