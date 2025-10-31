//
//  PostServiceDraftTests.swift
//  LocationNewsSNSTests
//
//  Test: 投稿送信失敗時の下書き保存機能のテスト
//

import XCTest
import CoreLocation
@testable import LocationNewsSNS

@MainActor
final class PostServiceDraftTests: XCTestCase {

    var postService: PostService!
    var mockPostRepository: MockPostRepository!
    var mockAudioService: MockAudioService!

    override func setUp() async throws {
        try await super.setUp()
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
        try await super.tearDown()
    }

    // MARK: - 下書き保存機能テスト

    /// Test: 音声投稿送信失敗時に下書きが保存される
    func testCreatePostWithAudio_NetworkError_SavesDraft() async throws {
        // Arrange: ネットワークエラーをシミュレート
        mockAudioService.uploadAudioResult = .failure(AudioServiceError.uploadFailed("Network error"))

        let audioFileURL = createTestAudioFile()
        let userID = UUID()
        let content = "テスト投稿"
        let location = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

        // Act: 投稿作成を試みる
        do {
            try await postService.createPostWithAudio(
                content: content,
                audioFileURL: audioFileURL,
                latitude: location.latitude,
                longitude: location.longitude,
                address: "東京都千代田区",
                userID: userID
            )
            XCTFail("Should throw error")
        } catch {
            // Expected error
        }

        // Assert: 下書きが保存されていることを確認
        let savedDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(savedDrafts.count, 1)

        let draft = savedDrafts.first!
        XCTAssertEqual(draft.content, content)
        XCTAssertEqual(draft.audioFileURL, audioFileURL)
        XCTAssertNotNil(draft.failureReason)
        XCTAssertTrue(draft.failureReason?.contains("Network error") ?? false)

        // Cleanup
        try? FileManager.default.removeItem(at: audioFileURL)
    }

    /// Test: 通常投稿送信失敗時に下書きが保存される
    func testCreatePost_NetworkError_SavesDraft() async throws {
        // Arrange: ネットワークエラーをシミュレート
        mockPostRepository.createPostResult = .failure(NSError(
            domain: "NetworkError",
            code: -1009,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        ))

        let request = CreatePostRequest(
            content: "通常投稿",
            latitude: 35.6812,
            longitude: 139.7671
        )

        // Act: 投稿作成を試みる
        await postService.createPost(request)

        // Assert: 下書きが保存されていることを確認
        let savedDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(savedDrafts.count, 1)

        let draft = savedDrafts.first!
        XCTAssertEqual(draft.content, "通常投稿")
        XCTAssertNil(draft.audioFileURL)
        XCTAssertNotNil(draft.failureReason)
    }

    /// Test: 保存された下書きを再送信できる
    func testRetrySendingDraft_Success() async throws {
        // Arrange: まず失敗して下書きを保存
        mockPostRepository.createPostResult = .failure(NSError(
            domain: "NetworkError",
            code: -1009
        ))

        let request = CreatePostRequest(
            content: "リトライテスト",
            latitude: 35.6812,
            longitude: 139.7671
        )

        await postService.createPost(request)

        let savedDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(savedDrafts.count, 1)

        // Arrange: 次は成功するように設定
        let mockPost = Post(
            id: UUID(),
            user: UserProfile(id: UUID(), username: "testuser", email: "test@example.com"),
            content: "リトライテスト",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: nil,
            category: .general,
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
        mockPostRepository.createPostResult = .success(mockPost)

        // Act: 下書きを再送信
        let draft = savedDrafts.first!
        try await postService.retrySendingDraft(draft)

        // Assert: 再送信成功後、下書きが削除されることを確認
        let remainingDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(remainingDrafts.count, 0)
    }

    /// Test: 下書きを手動で削除できる
    func testDeleteDraft_Success() async throws {
        // Arrange: 下書きを作成
        mockPostRepository.createPostResult = .failure(NSError(domain: "Error", code: -1))

        let request = CreatePostRequest(
            content: "削除テスト",
            latitude: 35.6812,
            longitude: 139.7671
        )

        await postService.createPost(request)

        let savedDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(savedDrafts.count, 1)

        // Act: 下書きを削除
        let draft = savedDrafts.first!
        await postService.deleteDraft(draft)

        // Assert: 下書きが削除されたことを確認
        let remainingDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(remainingDrafts.count, 0)
    }

    /// Test: 複数の下書きを保存・管理できる
    func testMultipleDrafts_Success() async throws {
        // Arrange: 複数の投稿を失敗させる
        mockPostRepository.createPostResult = .failure(NSError(domain: "Error", code: -1))

        let request1 = CreatePostRequest(content: "下書き1", latitude: 35.6812, longitude: 139.7671)
        let request2 = CreatePostRequest(content: "下書き2", latitude: 35.6812, longitude: 139.7671)
        let request3 = CreatePostRequest(content: "下書き3", latitude: 35.6812, longitude: 139.7671)

        // Act: 3つの投稿を試みる
        await postService.createPost(request1)
        await postService.createPost(request2)
        await postService.createPost(request3)

        // Assert: 3つの下書きが保存されることを確認
        let savedDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(savedDrafts.count, 3)

        let contents = savedDrafts.map { $0.content }
        XCTAssertTrue(contents.contains("下書き1"))
        XCTAssertTrue(contents.contains("下書き2"))
        XCTAssertTrue(contents.contains("下書き3"))
    }

    /// Test: 音声ファイル付き下書きは音声ファイルが保持される
    func testDraftWithAudio_PreservesAudioFile() async throws {
        // Arrange
        mockAudioService.uploadAudioResult = .failure(AudioServiceError.uploadFailed("Network error"))

        let audioFileURL = createTestAudioFile()
        let userID = UUID()

        // Act
        do {
            try await postService.createPostWithAudio(
                content: "音声テスト",
                audioFileURL: audioFileURL,
                latitude: 35.6812,
                longitude: 139.7671,
                address: nil,
                userID: userID
            )
        } catch {
            // Expected
        }

        // Assert: 音声ファイルが削除されていないことを確認
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioFileURL.path))

        let savedDrafts = await postService.getSavedDrafts()
        XCTAssertEqual(savedDrafts.count, 1)
        XCTAssertNotNil(savedDrafts.first?.audioFileURL)

        // Cleanup
        try? FileManager.default.removeItem(at: audioFileURL)
    }

    // MARK: - ヘルパーメソッド

    /// テストオーディオファイルを作成
    private func createTestAudioFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_audio_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let dummyData = Data(count: 1024) // 1KB
        try? dummyData.write(to: fileURL)

        return fileURL
    }
}

// MARK: - Mock Post Repository

class MockPostRepository: PostRepositoryProtocol {
    var createPostResult: Result<Post, Error>?
    var createPostWithAudioResult: Result<Post, Error>?

    func fetchNearbyPosts(latitude: Double, longitude: Double, radius: Double) async throws -> [Post] {
        return []
    }

    func createPost(_ request: CreatePostRequest) async throws -> Post {
        guard let result = createPostResult else {
            throw NSError(domain: "MockError", code: -1)
        }
        return try result.get()
    }

    func createPostWithAudio(_ request: CreatePostRequest, audioURL: String) async throws -> Post {
        guard let result = createPostWithAudioResult ?? createPostResult else {
            throw NSError(domain: "MockError", code: -1)
        }
        return try result.get()
    }

    func likePost(id: UUID) async throws {}
    func unlikePost(id: UUID) async throws {}
    func hasUserLikedPost(id: UUID, userID: UUID) async throws -> Bool { return false }
    func getPost(id: UUID) async throws -> Post {
        throw NSError(domain: "NotImplemented", code: -1)
    }
    func deletePost(id: UUID) async throws {}
}

// MARK: - Mock Audio Service

class MockAudioService: AudioService {
    var uploadAudioResult: Result<URL, Error>?

    override func uploadAudio(fileURL: URL, userID: UUID) async throws -> URL {
        guard let result = uploadAudioResult else {
            throw AudioServiceError.uploadFailed("No mock result configured")
        }
        return try result.get()
    }
}
