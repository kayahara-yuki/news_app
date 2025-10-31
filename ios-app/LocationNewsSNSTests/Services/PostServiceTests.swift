import XCTest
import CoreLocation
@testable import LocationNewsSNS

/// PostServiceのステータス投稿機能のテスト
@MainActor
final class PostServiceTests: XCTestCase {

    var postService: PostService!
    var mockPostRepository: MockPostRepository!
    var mockAudioService: MockAudioService!

    override func setUp() async throws {
        mockPostRepository = MockPostRepository()
        mockAudioService = MockAudioService()
        postService = PostService(
            postRepository: mockPostRepository,
            audioService: mockAudioService
        )
    }

    override func tearDown() async throws {
        postService = nil
        mockPostRepository = nil
        mockAudioService = nil
    }

    // MARK: - Status Post Tests

    /// Test 1: ステータス投稿作成メソッドが存在し、正しくisStatusPostフラグを設定する
    func testCreateStatusPost_SetsIsStatusPostFlag() async throws {
        // Given: ステータスとロケーション
        let status = StatusType.cafe
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

        // When: ステータス投稿を作成
        try await postService.createStatusPost(
            status: status,
            location: location
        )

        // Then: isStatusPostフラグがtrueに設定されていることを確認
        XCTAssertTrue(mockPostRepository.lastCreatePostRequest?.isStatusPost ?? false,
                      "isStatusPost flag should be true for status posts")
    }

    /// Test 2: ステータス投稿のexpiresAtが現在時刻+3時間に設定される
    func testCreateStatusPost_SetsExpiresAtThreeHoursLater() async throws {
        // Given: ステータスとロケーション
        let status = StatusType.lunch
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let beforeCreation = Date()

        // When: ステータス投稿を作成
        try await postService.createStatusPost(
            status: status,
            location: location
        )

        // Then: expiresAtが現在時刻+3時間（±1分の誤差許容）に設定されていることを確認
        guard let expiresAt = mockPostRepository.lastCreatePostRequest?.expiresAt else {
            XCTFail("expiresAt should not be nil for status posts")
            return
        }

        let expectedExpiresAt = beforeCreation.addingTimeInterval(3 * 60 * 60) // 3時間
        let timeDifference = abs(expiresAt.timeIntervalSince(expectedExpiresAt))

        XCTAssertLessThan(timeDifference, 60, // 60秒以内の誤差を許容
                          "expiresAt should be approximately 3 hours from creation time")
    }

    /// Test 3: ステータス投稿の内容にステータステキストが設定される
    func testCreateStatusPost_SetsContentToStatusText() async throws {
        // Given: ステータスとロケーション
        let status = StatusType.walking
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

        // When: ステータス投稿を作成
        try await postService.createStatusPost(
            status: status,
            location: location
        )

        // Then: 投稿内容がステータステキストに設定されていることを確認
        XCTAssertEqual(mockPostRepository.lastCreatePostRequest?.content,
                       status.rawValue,
                       "Post content should be the status text")
    }

    /// Test 4: ステータス投稿に位置情報が自動付与される
    func testCreateStatusPost_AutoAssignsLocation() async throws {
        // Given: ステータスとロケーション
        let status = StatusType.studying
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

        // When: ステータス投稿を作成
        try await postService.createStatusPost(
            status: status,
            location: location
        )

        // Then: 位置情報が正しく設定されていることを確認
        XCTAssertEqual(mockPostRepository.lastCreatePostRequest?.latitude,
                       location.latitude,
                       accuracy: 0.0001,
                       "Latitude should be set correctly")
        XCTAssertEqual(mockPostRepository.lastCreatePostRequest?.longitude,
                       location.longitude,
                       accuracy: 0.0001,
                       "Longitude should be set correctly")
    }

    /// Test 5: ステータス投稿が成功したらローカルリストに追加される
    func testCreateStatusPost_AddsToNearbyPostsOnSuccess() async throws {
        // Given: ステータスとロケーション
        let status = StatusType.free
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let initialPostCount = postService.nearbyPosts.count

        // When: ステータス投稿を作成
        try await postService.createStatusPost(
            status: status,
            location: location
        )

        // Then: nearbyPostsに投稿が追加されていることを確認
        XCTAssertEqual(postService.nearbyPosts.count,
                       initialPostCount + 1,
                       "New status post should be added to nearbyPosts")
    }

    /// Test 6: ステータス投稿成功時にエラーメッセージがクリアされる
    func testCreateStatusPost_ClearsErrorMessageOnSuccess() async throws {
        // Given: ステータスとロケーション、事前にエラーメッセージを設定
        let status = StatusType.event
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        postService.errorMessage = "Previous error"

        // When: ステータス投稿を作成
        try await postService.createStatusPost(
            status: status,
            location: location
        )

        // Then: エラーメッセージがクリアされていることを確認
        XCTAssertNil(postService.errorMessage,
                     "Error message should be cleared on successful post creation")
    }

    /// Test 7: リポジトリエラー時に適切なエラーメッセージが設定される
    func testCreateStatusPost_SetsErrorMessageOnRepositoryFailure() async throws {
        // Given: ステータス、ロケーション、Mockリポジトリでエラーを発生させる
        let status = StatusType.moving
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        mockPostRepository.shouldThrowError = true

        // When & Then: ステータス投稿を作成してエラーが発生することを確認
        do {
            try await postService.createStatusPost(
                status: status,
                location: location
            )
            XCTFail("Should throw error when repository fails")
        } catch {
            // エラーメッセージが設定されていることを確認
            XCTAssertNotNil(postService.errorMessage,
                            "Error message should be set when repository fails")
            XCTAssertTrue(postService.errorMessage?.contains("ステータス投稿の作成に失敗しました") ?? false,
                          "Error message should mention status post creation failure")
        }
    }

    // MARK: - Manual Delete Tests (Task 6.3)

    /// Test 8: 音声ファイル付き投稿を削除すると、音声ファイルも削除される
    func testDeletePost_WithAudio_DeletesAudioFile() async throws {
        // Given: 音声ファイル付き投稿をnearbyPostsに追加
        let audioURL = "https://example.com/storage/audio/user123/12345.m4a"
        let postWithAudio = Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user,
                createdAt: Date()
            ),
            content: "Test post with audio",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo Station",
            category: .other,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: audioURL,
            isStatusPost: false,
            expiresAt: nil
        )

        postService.nearbyPosts = [postWithAudio]

        // When: 投稿を削除
        await postService.deletePost(id: postWithAudio.id)

        // Then: AudioServiceのdeleteAudioが呼ばれたことを確認
        XCTAssertTrue(mockAudioService.deleteAudioCalled,
                      "AudioService.deleteAudio should be called when deleting post with audio")
        XCTAssertEqual(mockAudioService.lastDeletedAudioURL?.absoluteString,
                       audioURL,
                       "Correct audio URL should be passed to deleteAudio")
    }

    /// Test 9: 音声ファイルなし投稿を削除しても、AudioServiceは呼ばれない
    func testDeletePost_WithoutAudio_DoesNotCallAudioService() async throws {
        // Given: 音声ファイルなし投稿をnearbyPostsに追加
        let postWithoutAudio = Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user,
                createdAt: Date()
            ),
            content: "Test post without audio",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo Station",
            category: .other,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: nil,
            isStatusPost: false,
            expiresAt: nil
        )

        postService.nearbyPosts = [postWithoutAudio]

        // When: 投稿を削除
        await postService.deletePost(id: postWithoutAudio.id)

        // Then: AudioServiceのdeleteAudioが呼ばれていないことを確認
        XCTAssertFalse(mockAudioService.deleteAudioCalled,
                       "AudioService.deleteAudio should not be called when deleting post without audio")
    }

    /// Test 10: 音声ファイル削除に失敗しても、投稿削除は成功する
    func testDeletePost_AudioDeleteFails_StillDeletesPost() async throws {
        // Given: 音声ファイル付き投稿、AudioServiceで削除エラーを発生させる
        let audioURL = "https://example.com/storage/audio/user123/12345.m4a"
        let postWithAudio = Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user,
                createdAt: Date()
            ),
            content: "Test post with audio",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo Station",
            category: .other,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: audioURL,
            isStatusPost: false,
            expiresAt: nil
        )

        postService.nearbyPosts = [postWithAudio]
        mockAudioService.shouldThrowErrorOnDelete = true

        // When: 投稿を削除
        await postService.deletePost(id: postWithAudio.id)

        // Then: 投稿はnearbyPostsから削除されている（音声削除失敗は無視される）
        XCTAssertEqual(postService.nearbyPosts.count, 0,
                       "Post should be deleted even if audio deletion fails")
    }
}

// MARK: - Mock Classes

/// PostRepositoryのモッククラス
class MockPostRepository: PostRepositoryProtocol {
    var lastCreatePostRequest: CreatePostRequest?
    var shouldThrowError = false
    var mockPost: Post?

    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async throws -> [Post] {
        return []
    }

    func createPost(_ request: CreatePostRequest) async throws -> Post {
        lastCreatePostRequest = request

        if shouldThrowError {
            throw NSError(domain: "MockPostRepository", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Mock repository error"])
        }

        // モック投稿を返す
        return mockPost ?? Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user,
                createdAt: Date()
            ),
            content: request.content,
            url: request.url,
            latitude: request.latitude,
            longitude: request.longitude,
            address: request.locationName,
            category: .other,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: nil,
            isStatusPost: request.isStatusPost ?? false,
            expiresAt: request.expiresAt
        )
    }

    func likePost(id: UUID) async throws {}
    func unlikePost(id: UUID) async throws {}
    func hasUserLikedPost(id: UUID, userID: UUID) async throws -> Bool { return false }
    func getPost(id: UUID) async throws -> Post {
        return Post(
            id: id,
            user: UserProfile(id: UUID(), username: "test", email: "test@example.com", displayName: "Test", role: .user, createdAt: Date()),
            content: "Test",
            url: nil,
            latitude: nil,
            longitude: nil,
            address: nil,
            category: .other,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: nil,
            isStatusPost: false,
            expiresAt: nil
        )
    }
    func deletePost(id: UUID) async throws {}
}

/// AudioServiceのモッククラス
@MainActor
class MockAudioService: AudioService {
    var deleteAudioCalled = false
    var lastDeletedAudioURL: URL?
    var shouldThrowErrorOnDelete = false

    override func deleteAudio(audioURL: URL, userID: UUID) async throws {
        deleteAudioCalled = true
        lastDeletedAudioURL = audioURL

        if shouldThrowErrorOnDelete {
            throw AudioServiceError.deleteFailed("Mock deletion error")
        }
    }
}
