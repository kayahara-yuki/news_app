import Foundation
import Combine
import CoreLocation

// MARK: - Post UseCase Protocol

protocol PostUseCaseProtocol {
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async throws -> [Post]
    func createPost(_ request: CreatePostRequest) async throws -> Post
    func deletePost(id: UUID) async throws
    func likePost(id: UUID) async throws
    func unlikePost(id: UUID) async throws
    func sharePost(id: UUID) async throws
    func reportPost(id: UUID, reason: String) async throws
    func getPostDetails(id: UUID) async throws -> Post
    func getUserPosts(userID: UUID, limit: Int, offset: Int) async throws -> [Post]
}

// MARK: - Post UseCase Implementation

class PostUseCase: PostUseCaseProtocol {
    private let postService: any PostServiceProtocol
    private let postRepository: any PostRepositoryProtocol
    
    init(postService: any PostServiceProtocol, postRepository: any PostRepositoryProtocol) {
        self.postService = postService
        self.postRepository = postRepository
    }
    
    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async throws -> [Post] {
        // バリデーション
        guard (-90...90).contains(latitude) else {
            throw PostError.invalidLocation("緯度が無効です")
        }
        
        guard (-180...180).contains(longitude) else {
            throw PostError.invalidLocation("経度が無効です")
        }
        
        guard radius > 0 && radius <= 50000 else { // 最大50km
            throw PostError.invalidRadius
        }
        
        // ビジネスロジック: 近隣投稿取得
        return try await postRepository.fetchNearbyPosts(
            latitude: latitude,
            longitude: longitude,
            radius: radius
        )
    }
    
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        // バリデーション
        guard !request.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PostError.emptyContent
        }
        
        guard request.content.count <= 2000 else {
            throw PostError.contentTooLong
        }

        // 位置情報の検証
        if let latitude = request.latitude, let longitude = request.longitude {
            guard (-90...90).contains(latitude) && (-180...180).contains(longitude) else {
                throw PostError.invalidLocation("位置情報が無効です")
            }
        }

        // ビジネスロジック: 投稿作成
        let post = try await postRepository.createPost(request)

        // 緊急投稿の場合、特別な処理
        if let emergencyLevel = request.emergencyLevel {
            try await handleEmergencyPost(post)
        }

        return post
    }
    
    func deletePost(id: UUID) async throws {
        // 投稿の存在確認と権限チェック
        let post = try await postRepository.getPost(id: id)
        
        // TODO: 現在のユーザーが投稿者または管理者かチェック
        // guard canDeletePost(post) else {
        //     throw PostError.noPermission
        // }
        
        try await postRepository.deletePost(id: id)
    }
    
    func likePost(id: UUID) async throws {
        // 投稿の存在確認
        let _ = try await postRepository.getPost(id: id)
        
        // TODO: ユーザーが既にいいねしているかチェック
        // let hasLiked = try await postRepository.hasUserLikedPost(id: id, userID: currentUserID)
        // guard !hasLiked else {
        //     throw PostError.alreadyLiked
        // }
        
        try await postRepository.likePost(id: id)
    }
    
    func unlikePost(id: UUID) async throws {
        // 投稿の存在確認
        let _ = try await postRepository.getPost(id: id)
        
        // TODO: ユーザーがいいねしているかチェック
        // let hasLiked = try await postRepository.hasUserLikedPost(id: id, userID: currentUserID)
        // guard hasLiked else {
        //     throw PostError.notLiked
        // }
        
        try await postRepository.unlikePost(id: id)
    }
    
    func sharePost(id: UUID) async throws {
        // 投稿の存在確認
        let post = try await postRepository.getPost(id: id)
        
        // プライベート投稿のシェア制限
        guard post.visibility != .private else {
            throw PostError.cannotSharePrivatePost
        }
        
        try await postRepository.sharePost(id: id)
    }
    
    func reportPost(id: UUID, reason: String) async throws {
        // バリデーション
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PostError.emptyReportReason
        }
        
        guard reason.count <= 500 else {
            throw PostError.reportReasonTooLong
        }
        
        // 投稿の存在確認
        let _ = try await postRepository.getPost(id: id)
        
        try await postRepository.reportPost(id: id, reason: reason)
    }
    
    func getPostDetails(id: UUID) async throws -> Post {
        return try await postRepository.getPost(id: id)
    }
    
    func getUserPosts(userID: UUID, limit: Int, offset: Int) async throws -> [Post] {
        guard limit > 0 && limit <= 100 else {
            throw PostError.invalidLimit
        }
        
        guard offset >= 0 else {
            throw PostError.invalidOffset
        }
        
        return try await postRepository.getUserPosts(userID: userID, limit: limit, offset: offset)
    }
    
    // MARK: - Private Methods
    
    private func handleEmergencyPost(_ post: Post) async throws {
        // 緊急投稿の特別処理
        // - 近隣ユーザーへの通知
        // - 管理者への通知
        // - 信頼性スコアの確認
        print("緊急投稿の処理: \(post.id)")
    }
}

// MARK: - Create Post Request
// Note: CreatePostRequestは Models/PostRequests.swift で定義されています

// MARK: - Post Errors

enum PostError: Error, LocalizedError {
    case emptyContent
    case contentTooLong
    case invalidURL
    case invalidLocation(String)
    case invalidRadius
    case invalidLimit
    case invalidOffset
    case emptyReportReason
    case reportReasonTooLong
    case postNotFound
    case noPermission
    case alreadyLiked
    case notLiked
    case cannotSharePrivatePost
    case networkError(String)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "投稿内容を入力してください"
        case .contentTooLong:
            return "投稿内容は2000文字以内で入力してください"
        case .invalidURL:
            return "有効なURLを入力してください"
        case .invalidLocation(let message):
            return message
        case .invalidRadius:
            return "検索範囲が無効です（1m〜50km）"
        case .invalidLimit:
            return "取得件数が無効です（1〜100件）"
        case .invalidOffset:
            return "オフセットが無効です"
        case .emptyReportReason:
            return "報告理由を入力してください"
        case .reportReasonTooLong:
            return "報告理由は500文字以内で入力してください"
        case .postNotFound:
            return "投稿が見つかりません"
        case .noPermission:
            return "この操作を行う権限がありません"
        case .alreadyLiked:
            return "既にいいねしています"
        case .notLiked:
            return "いいねしていません"
        case .cannotSharePrivatePost:
            return "プライベート投稿はシェアできません"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .unknownError:
            return "不明なエラーが発生しました"
        }
    }
}