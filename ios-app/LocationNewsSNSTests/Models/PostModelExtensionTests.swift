import XCTest
@testable import LocationNewsSNS

/// Post モデル拡張のテスト（音声投稿＋ステータス投稿対応）
final class PostModelExtensionTests: XCTestCase {

    // MARK: - Test Data

    /// テスト用のユーザー
    private let testUser = UserProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        username: "testuser",
        email: "test@example.com",
        displayName: "Test User",
        bio: nil,
        avatarURL: nil,
        role: .user,
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Audio URL Tests

    /// Test 1: 音声URLフィールドが存在することを確認
    func testPostHasAudioURLField() {
        let post = createTestPost(audioURL: "https://example.com/audio/test.m4a")
        XCTAssertNotNil(post.audioURL, "Post should have audioURL field")
        XCTAssertEqual(post.audioURL, "https://example.com/audio/test.m4a")
    }

    /// Test 2: 音声URLがnilの場合も正常に動作
    func testPostWithoutAudioURL() {
        let post = createTestPost(audioURL: nil)
        XCTAssertNil(post.audioURL, "Post audioURL should be nil")
    }

    // MARK: - Status Post Tests

    /// Test 3: ステータス投稿フラグが存在することを確認
    func testPostHasIsStatusPostField() {
        let post = createTestPost(isStatusPost: true)
        XCTAssertTrue(post.isStatusPost, "Post should have isStatusPost field")
    }

    /// Test 4: 通常投稿はステータス投稿フラグがfalse
    func testRegularPostIsNotStatusPost() {
        let post = createTestPost(isStatusPost: false)
        XCTAssertFalse(post.isStatusPost, "Regular post should not be status post")
    }

    // MARK: - Expires At Tests

    /// Test 5: 有効期限フィールドが存在することを確認
    func testPostHasExpiresAtField() {
        let expiryDate = Date().addingTimeInterval(3 * 3600) // 3時間後
        let post = createTestPost(expiresAt: expiryDate)
        XCTAssertNotNil(post.expiresAt, "Post should have expiresAt field")
        XCTAssertEqual(post.expiresAt, expiryDate)
    }

    /// Test 6: 通常投稿は有効期限がnil
    func testRegularPostHasNoExpiry() {
        let post = createTestPost(expiresAt: nil)
        XCTAssertNil(post.expiresAt, "Regular post should not have expiry")
    }

    // MARK: - Computed Properties Tests

    /// Test 7: isExpired 計算プロパティ - 期限切れの場合
    func testIsExpiredForExpiredPost() {
        let pastDate = Date().addingTimeInterval(-3600) // 1時間前
        let post = createTestPost(isStatusPost: true, expiresAt: pastDate)
        XCTAssertTrue(post.isExpired, "Post should be expired")
    }

    /// Test 8: isExpired 計算プロパティ - 期限内の場合
    func testIsExpiredForValidPost() {
        let futureDate = Date().addingTimeInterval(3600) // 1時間後
        let post = createTestPost(isStatusPost: true, expiresAt: futureDate)
        XCTAssertFalse(post.isExpired, "Post should not be expired")
    }

    /// Test 9: isExpired 計算プロパティ - expiresAtがnilの場合
    func testIsExpiredForPostWithoutExpiry() {
        let post = createTestPost(isStatusPost: false, expiresAt: nil)
        XCTAssertFalse(post.isExpired, "Post without expiry should not be expired")
    }

    /// Test 10: remainingTime 計算プロパティ - 期限内の場合
    func testRemainingTimeForValidPost() {
        let futureDate = Date().addingTimeInterval(3600) // 1時間後
        let post = createTestPost(isStatusPost: true, expiresAt: futureDate)
        XCTAssertNotNil(post.remainingTime, "Post should have remaining time")
        XCTAssertGreaterThan(post.remainingTime!, 3500, "Remaining time should be approximately 3600 seconds")
    }

    /// Test 11: remainingTime 計算プロパティ - expiresAtがnilの場合
    func testRemainingTimeForPostWithoutExpiry() {
        let post = createTestPost(isStatusPost: false, expiresAt: nil)
        XCTAssertNil(post.remainingTime, "Post without expiry should have nil remaining time")
    }

    // MARK: - Codable Tests

    /// Test 12: JSON エンコード/デコード - 音声URL付き投稿
    func testJSONCodingWithAudioURL() throws {
        let originalPost = createTestPost(
            audioURL: "https://example.com/audio/test.m4a",
            isStatusPost: false,
            expiresAt: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalPost)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedPost = try decoder.decode(Post.self, from: data)

        XCTAssertEqual(decodedPost.id, originalPost.id)
        XCTAssertEqual(decodedPost.audioURL, originalPost.audioURL)
        XCTAssertEqual(decodedPost.isStatusPost, originalPost.isStatusPost)
        XCTAssertEqual(decodedPost.expiresAt, originalPost.expiresAt)
    }

    /// Test 13: JSON エンコード/デコード - ステータス投稿
    func testJSONCodingWithStatusPost() throws {
        let expiryDate = Date().addingTimeInterval(3 * 3600)
        let originalPost = createTestPost(
            audioURL: nil,
            isStatusPost: true,
            expiresAt: expiryDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalPost)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedPost = try decoder.decode(Post.self, from: data)

        XCTAssertEqual(decodedPost.id, originalPost.id)
        XCTAssertEqual(decodedPost.isStatusPost, true)
        XCTAssertNotNil(decodedPost.expiresAt)
    }

    /// Test 14: Snake Case と Camel Case のマッピング
    func testCodingKeysMapping() throws {
        let jsonString = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "user": {
                "id": "00000000-0000-0000-0000-000000000001",
                "username": "testuser",
                "email": "test@example.com",
                "display_name": "Test User",
                "role": "user",
                "created_at": "2025-01-01T00:00:00Z",
                "updated_at": "2025-01-01T00:00:00Z"
            },
            "content": "Test post",
            "latitude": 35.6812,
            "longitude": 139.7671,
            "category": "social",
            "visibility": "public",
            "is_urgent": false,
            "is_verified": false,
            "like_count": 0,
            "comment_count": 0,
            "share_count": 0,
            "created_at": "2025-01-01T00:00:00Z",
            "updated_at": "2025-01-01T00:00:00Z",
            "audio_url": "https://example.com/audio/test.m4a",
            "is_status_post": true,
            "expires_at": "2025-01-01T03:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let post = try decoder.decode(Post.self, from: jsonString.data(using: .utf8)!)

        XCTAssertEqual(post.audioURL, "https://example.com/audio/test.m4a")
        XCTAssertEqual(post.isStatusPost, true)
        XCTAssertNotNil(post.expiresAt)
    }

    // MARK: - Helper Methods

    /// テスト用の Post インスタンスを作成
    private func createTestPost(
        audioURL: String? = nil,
        isStatusPost: Bool = false,
        expiresAt: Date? = nil
    ) -> Post {
        return Post(
            id: UUID(),
            user: testUser,
            content: "Test post content",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo, Japan",
            category: .social,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: audioURL,
            isStatusPost: isStatusPost,
            expiresAt: expiresAt
        )
    }
}
