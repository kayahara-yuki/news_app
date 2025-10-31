//
//  StatusPostAutoDeleteIntegrationTests.swift
//  LocationNewsSNSTests
//
//  Created for testing status post auto-deletion integration
//

import XCTest
import CoreLocation
@testable import LocationNewsSNS

/// ステータス投稿→自動削除フローの統合テスト
/// Requirements: 8.3 - ステータス投稿→自動削除フローの統合テスト
@MainActor
final class StatusPostAutoDeleteIntegrationTests: XCTestCase {

    var postService: PostService!
    var postRepository: PostRepository!

    override func setUp() async throws {
        try await super.setUp()

        // サービスの初期化
        postRepository = PostRepository()
        postService = PostService(postRepository: postRepository)
    }

    override func tearDown() async throws {
        postService = nil
        postRepository = nil
        try await super.tearDown()
    }

    // MARK: - Integration Test 1: ステータス投稿の作成と有効期限設定

    /// Test 1: ステータス投稿が正しく作成され、有効期限が設定される
    /// Requirements: 5.1, 6.1
    func testStatusPostCreationWithExpiration() async throws {
        // Given: テスト用の位置情報
        let testLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let statusType = StatusType.cafe

        do {
            // When: ステータス投稿を作成
            try await postService.createStatusPost(
                status: statusType,
                location: testLocation
            )

            // Then: 投稿が正しく作成され、nearbyPostsに追加される
            XCTAssertGreaterThan(postService.nearbyPosts.count, 0, "Status post should be added to nearbyPosts")

            guard let post = postService.nearbyPosts.first else {
                XCTFail("Post should exist in nearbyPosts")
                return
            }

            XCTAssertEqual(post.content, statusType.rawValue, "Content should match status text")
            XCTAssertTrue(post.isStatusPost, "Post should be marked as status post")
            XCTAssertNotNil(post.expiresAt, "Status post should have expiration time")

            // Then: 有効期限が投稿時刻+3時間に設定される
            guard let expiresAt = post.expiresAt else {
                XCTFail("Expires at should not be nil")
                return
            }

            let now = Date()
            let threeHoursLater = now.addingTimeInterval(3 * 60 * 60)
            let timeDifference = abs(expiresAt.timeIntervalSince(threeHoursLater))

            // 誤差5分以内であることを確認
            XCTAssertLessThan(timeDifference, 5 * 60, "Expiration time should be approximately 3 hours from now")

            print("[Test] Status post created with expiration: \(expiresAt)")

            // Cleanup: 作成した投稿を削除
            try? await postRepository.deletePost(postID: post.id)

        } catch {
            print("[Test] Status post creation test skipped: \(error.localizedDescription)")
            throw XCTSkip("Supabase connection required: \(error.localizedDescription)")
        }
    }

    // MARK: - Integration Test 2: ステータス投稿の有効期限判定

    /// Test 2: 有効期限が切れたステータス投稿を正しく判定できる
    /// Requirements: 6.1
    func testExpiredStatusPostDetection() async throws {
        // Given: 過去の有効期限を持つモックPost
        let expiredDate = Date().addingTimeInterval(-1 * 60 * 60) // 1時間前
        let mockPost = Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user
            ),
            content: "☕ カフェなう",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo",
            category: .social,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date().addingTimeInterval(-4 * 60 * 60), // 4時間前
            updatedAt: Date().addingTimeInterval(-4 * 60 * 60),
            audioURL: nil,
            isStatusPost: true,
            expiresAt: expiredDate
        )

        // When: 有効期限判定
        let isExpired = mockPost.isExpired

        // Then: 有効期限切れと判定される
        XCTAssertTrue(isExpired, "Post should be expired")

        // Then: 残り時間が負の値
        let remainingTime = mockPost.remainingTime
        XCTAssertNotNil(remainingTime, "Remaining time should not be nil")
        if let remainingTime = remainingTime {
            XCTAssertLessThan(remainingTime, 0, "Remaining time should be negative for expired post")
        }
    }

    // MARK: - Integration Test 3: 有効なステータス投稿の判定

    /// Test 3: 有効期限内のステータス投稿を正しく判定できる
    /// Requirements: 6.3
    func testValidStatusPostDetection() async throws {
        // Given: 未来の有効期限を持つモックPost
        let futureDate = Date().addingTimeInterval(2 * 60 * 60) // 2時間後
        let mockPost = Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user
            ),
            content: "☕ カフェなう",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo",
            category: .social,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: nil,
            isStatusPost: true,
            expiresAt: futureDate
        )

        // When: 有効期限判定
        let isExpired = mockPost.isExpired

        // Then: 有効期限内と判定される
        XCTAssertFalse(isExpired, "Post should not be expired")

        // Then: 残り時間が正の値
        let remainingTime = mockPost.remainingTime
        XCTAssertNotNil(remainingTime, "Remaining time should not be nil")
        if let remainingTime = remainingTime {
            XCTAssertGreaterThan(remainingTime, 0, "Remaining time should be positive for valid post")
            XCTAssertLessThan(remainingTime, 3 * 60 * 60, "Remaining time should be less than 3 hours")
        }
    }

    // MARK: - Integration Test 4: 手動削除時のクリーンアップ

    /// Test 4: ステータス投稿を手動削除すると関連データも削除される
    /// Requirements: 6.5
    func testManualDeletionCleansUpRelatedData() async throws {
        do {
            // Given: ステータス投稿を作成
            let testLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            let statusText = "🍴 ランチ中"

            let post = try await postService.createStatusPost(
                status: statusText,
                location: testLocation
            )

            XCTAssertNotNil(post, "Status post should be created")
            XCTAssertTrue(post.isStatusPost, "Should be status post")

            let postID = post.id

            // When: 手動削除を実行
            try await postRepository.deletePost(postID: postID)
            print("[Test] Status post manually deleted: \(postID)")

            // Then: 投稿が削除されている
            do {
                _ = try await postRepository.getPost(postID: postID)
                XCTFail("Post should be deleted")
            } catch {
                // 投稿が見つからないエラーが期待される
                XCTAssertNotNil(error, "Should throw error for deleted post")
            }

        } catch {
            print("[Test] Manual deletion test skipped: \(error.localizedDescription)")
            throw XCTSkip("Supabase connection required: \(error.localizedDescription)")
        }
    }

    // MARK: - Integration Test 5: 通常投稿は自動削除されない

    /// Test 5: 通常投稿（isStatusPost=false）は自動削除対象外
    /// Requirements: 5.2
    func testNormalPostNotAutoDeleted() async throws {
        do {
            // Given: 通常投稿を作成
            let testLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            let normalContent = "これは通常の投稿です"

            let post = try await postService.createPost(
                content: normalContent,
                location: testLocation
            )

            // Then: 通常投稿には有効期限がない
            XCTAssertNotNil(post, "Normal post should be created")
            XCTAssertFalse(post.isStatusPost, "Should not be status post")
            XCTAssertNil(post.expiresAt, "Normal post should not have expiration time")

            print("[Test] Normal post created without expiration: \(post.id)")

            // Cleanup
            try? await postRepository.deletePost(postID: post.id)

        } catch {
            print("[Test] Normal post test skipped: \(error.localizedDescription)")
            throw XCTSkip("Supabase connection required: \(error.localizedDescription)")
        }
    }

    // MARK: - Integration Test 6: ステータス投稿の残り時間表示

    /// Test 6: ステータス投稿の残り時間が正しく計算される
    /// Requirements: 6.3, 6.4
    func testRemainingTimeCalculation() async throws {
        do {
            // Given: ステータス投稿を作成
            let testLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            let statusText = "🚶 散歩中"

            let post = try await postService.createStatusPost(
                status: statusText,
                location: testLocation
            )

            XCTAssertNotNil(post.expiresAt, "Status post should have expiration time")

            // When: 残り時間を計算
            let remainingTime = post.remainingTime

            // Then: 残り時間が正しく計算される
            XCTAssertNotNil(remainingTime, "Remaining time should not be nil")
            if let remainingTime = remainingTime {
                // 3時間弱（誤差を考慮）
                XCTAssertGreaterThan(remainingTime, 2.5 * 60 * 60, "Remaining time should be close to 3 hours")
                XCTAssertLessThan(remainingTime, 3.5 * 60 * 60, "Remaining time should not exceed 3.5 hours")

                // 残り時間の文字列表現を確認
                let hours = Int(remainingTime / 3600)
                print("[Test] Remaining time: approximately \(hours) hours")
            }

            // Cleanup
            try? await postRepository.deletePost(postID: post.id)

        } catch {
            print("[Test] Remaining time test skipped: \(error.localizedDescription)")
            throw XCTSkip("Supabase connection required: \(error.localizedDescription)")
        }
    }

    // MARK: - Integration Test 7: 複数ステータス投稿の作成

    /// Test 7: 複数のステータス投稿を連続して作成できる
    /// Requirements: 5.1
    func testMultipleStatusPostCreation() async throws {
        var createdPostIDs: [UUID] = []

        do {
            let testLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            let statuses = ["☕ カフェなう", "📚 勉強中", "🎉 イベント参加中"]

            // When: 複数のステータス投稿を作成
            for status in statuses {
                let post = try await postService.createStatusPost(
                    status: status,
                    location: testLocation
                )

                XCTAssertNotNil(post, "Status post should be created")
                XCTAssertTrue(post.isStatusPost, "Should be status post")
                XCTAssertNotNil(post.expiresAt, "Should have expiration time")

                createdPostIDs.append(post.id)
                print("[Test] Status post created: \(status)")
            }

            // Then: すべての投稿が作成された
            XCTAssertEqual(createdPostIDs.count, statuses.count, "All status posts should be created")

            // Cleanup: すべての投稿を削除
            for postID in createdPostIDs {
                try? await postRepository.deletePost(postID: postID)
            }

        } catch {
            // Cleanup on error
            for postID in createdPostIDs {
                try? await postRepository.deletePost(postID: postID)
            }
            print("[Test] Multiple status posts test skipped: \(error.localizedDescription)")
            throw XCTSkip("Supabase connection required: \(error.localizedDescription)")
        }
    }

    // MARK: - Integration Test 8: ステータス投稿の取得フィルタリング

    /// Test 8: 有効期限切れのステータス投稿をフィルタリングできる
    /// Requirements: 6.2
    func testExpiredStatusPostFiltering() async throws {
        // Given: 有効なステータス投稿と期限切れステータス投稿のモック
        let validPost = Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user
            ),
            content: "☕ カフェなう",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo",
            category: .social,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            audioURL: nil,
            isStatusPost: true,
            expiresAt: Date().addingTimeInterval(2 * 60 * 60) // 2時間後
        )

        let expiredPost = Post(
            id: UUID(),
            user: UserProfile(
                id: UUID(),
                username: "testuser",
                email: "test@example.com",
                displayName: "Test User",
                role: .user
            ),
            content: "🍴 ランチ中",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "Tokyo",
            category: .social,
            visibility: .public,
            isUrgent: false,
            isVerified: false,
            likeCount: 0,
            commentCount: 0,
            shareCount: 0,
            createdAt: Date().addingTimeInterval(-4 * 60 * 60), // 4時間前
            updatedAt: Date().addingTimeInterval(-4 * 60 * 60),
            audioURL: nil,
            isStatusPost: true,
            expiresAt: Date().addingTimeInterval(-1 * 60 * 60) // 1時間前
        )

        let posts = [validPost, expiredPost]

        // When: 有効な投稿のみをフィルタリング
        let validPosts = posts.filter { !$0.isExpired }

        // Then: 有効期限内の投稿のみが含まれる
        XCTAssertEqual(validPosts.count, 1, "Only valid post should be included")
        XCTAssertEqual(validPosts.first?.id, validPost.id, "Valid post should be in filtered results")
    }
}
