import XCTest
@testable import LocationNewsSNS

/// ステータス投稿の残り時間表示機能のユニットテスト
/// Requirement 6.3, 6.4に対応
@MainActor
final class StatusPostRemainingTimeTests: XCTestCase {

    // MARK: - Test 1: 残り時間のフォーマット表示

    /// Test 1.1: 2時間以上残っている場合「あと〇時間で削除」と表示される
    func testRemainingTimeFormatForMoreThan2Hours() {
        // Given: 2時間30分後に削除されるステータス投稿
        let expiresAt = Date().addingTimeInterval(2.5 * 3600)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: 残り時間テキストを取得
        let remainingText = post.remainingTimeText

        // Then: 「あと2時間で削除」のようなテキストが返される
        XCTAssertTrue(remainingText.contains("あと"), "Should contain 'あと'")
        XCTAssertTrue(remainingText.contains("時間"), "Should contain '時間'")
        XCTAssertTrue(remainingText.contains("削除"), "Should contain '削除'")
    }

    /// Test 1.2: 1時間未満の場合「あと〇分で削除」と表示される
    func testRemainingTimeFormatForLessThan1Hour() {
        // Given: 45分後に削除されるステータス投稿
        let expiresAt = Date().addingTimeInterval(45 * 60)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: 残り時間テキストを取得
        let remainingText = post.remainingTimeText

        // Then: 「あと45分で削除」のようなテキストが返される
        XCTAssertTrue(remainingText.contains("あと"), "Should contain 'あと'")
        XCTAssertTrue(remainingText.contains("分"), "Should contain '分'")
        XCTAssertTrue(remainingText.contains("削除"), "Should contain '削除'")
    }

    /// Test 1.3: 1分未満の場合「まもなく削除」と表示される
    func testRemainingTimeFormatForLessThan1Minute() {
        // Given: 30秒後に削除されるステータス投稿
        let expiresAt = Date().addingTimeInterval(30)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: 残り時間テキストを取得
        let remainingText = post.remainingTimeText

        // Then: 「まもなく削除」と表示される
        XCTAssertEqual(remainingText, "まもなく削除", "Should show 'まもなく削除' for less than 1 minute")
    }

    /// Test 1.4: 期限切れの場合「削除済み」と表示される
    func testRemainingTimeFormatForExpiredPost() {
        // Given: 既に削除期限を過ぎたステータス投稿
        let expiresAt = Date().addingTimeInterval(-3600) // 1時間前
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: 残り時間テキストを取得
        let remainingText = post.remainingTimeText

        // Then: 「削除済み」と表示される
        XCTAssertEqual(remainingText, "削除済み", "Should show '削除済み' for expired posts")
    }

    /// Test 1.5: 通常投稿（expiresAtがnil）の場合はnilが返される
    func testRemainingTimeFormatForRegularPost() {
        // Given: 通常投稿（expiresAtがnil）
        let post = createMockRegularPost()

        // When: 残り時間テキストを取得
        let remainingText = post.remainingTimeText

        // Then: nilが返される
        XCTAssertNil(remainingText, "Regular posts should return nil for remaining time text")
    }

    // MARK: - Test 2: 「まもなく削除されます」バッジ表示判定

    /// Test 2.1: 残り時間が1時間未満の場合、shouldShowExpiringBadgeがtrueを返す
    func testShouldShowExpiringBadgeForLessThan1Hour() {
        // Given: 45分後に削除されるステータス投稿
        let expiresAt = Date().addingTimeInterval(45 * 60)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: バッジ表示判定
        let shouldShow = post.shouldShowExpiringBadge

        // Then: trueが返される
        XCTAssertTrue(shouldShow, "Should show expiring badge for posts expiring in less than 1 hour")
    }

    /// Test 2.2: 残り時間が1時間以上の場合、shouldShowExpiringBadgeがfalseを返す
    func testShouldNotShowExpiringBadgeForMoreThan1Hour() {
        // Given: 2時間後に削除されるステータス投稿
        let expiresAt = Date().addingTimeInterval(2 * 3600)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: バッジ表示判定
        let shouldShow = post.shouldShowExpiringBadge

        // Then: falseが返される
        XCTAssertFalse(shouldShow, "Should not show expiring badge for posts expiring in more than 1 hour")
    }

    /// Test 2.3: 期限切れの投稿の場合、shouldShowExpiringBadgeがfalseを返す
    func testShouldNotShowExpiringBadgeForExpiredPost() {
        // Given: 既に期限切れの投稿
        let expiresAt = Date().addingTimeInterval(-3600)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: バッジ表示判定
        let shouldShow = post.shouldShowExpiringBadge

        // Then: falseが返される
        XCTAssertFalse(shouldShow, "Should not show expiring badge for expired posts")
    }

    /// Test 2.4: 通常投稿の場合、shouldShowExpiringBadgeがfalseを返す
    func testShouldNotShowExpiringBadgeForRegularPost() {
        // Given: 通常投稿
        let post = createMockRegularPost()

        // When: バッジ表示判定
        let shouldShow = post.shouldShowExpiringBadge

        // Then: falseが返される
        XCTAssertFalse(shouldShow, "Should not show expiring badge for regular posts")
    }

    // MARK: - Test 3: 残り時間の境界値テスト

    /// Test 3.1: 残り時間がちょうど1時間の場合
    func testRemainingTimeExactly1Hour() {
        // Given: ちょうど1時間後に削除されるステータス投稿
        let expiresAt = Date().addingTimeInterval(3600)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: 残り時間テキストとバッジ表示判定
        let remainingText = post.remainingTimeText
        let shouldShow = post.shouldShowExpiringBadge

        // Then: 「あと1時間で削除」と表示され、バッジは表示されない
        XCTAssertTrue(remainingText.contains("1時間"), "Should show '1時間'")
        XCTAssertFalse(shouldShow, "Should not show expiring badge at exactly 1 hour")
    }

    /// Test 3.2: 残り時間がちょうど1分の場合
    func testRemainingTimeExactly1Minute() {
        // Given: ちょうど1分後に削除されるステータス投稿
        let expiresAt = Date().addingTimeInterval(60)
        let post = createMockStatusPost(expiresAt: expiresAt)

        // When: 残り時間テキストとバッジ表示判定
        let remainingText = post.remainingTimeText
        let shouldShow = post.shouldShowExpiringBadge

        // Then: 「あと1分で削除」と表示され、バッジは表示される
        XCTAssertTrue(remainingText.contains("1分"), "Should show '1分'")
        XCTAssertTrue(shouldShow, "Should show expiring badge at 1 minute")
    }

    // MARK: - Helper Methods

    private func createMockStatusPost(expiresAt: Date) -> Post {
        return Post(
            id: UUID(),
            user: createMockUser(),
            content: "☕ カフェなう",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "東京駅",
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
            expiresAt: expiresAt
        )
    }

    private func createMockRegularPost() -> Post {
        return Post(
            id: UUID(),
            user: createMockUser(),
            content: "通常の投稿です",
            url: nil,
            latitude: 35.6812,
            longitude: 139.7671,
            address: "東京駅",
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
            isStatusPost: false,
            expiresAt: nil
        )
    }

    private func createMockUser() -> UserProfile {
        return UserProfile(
            id: UUID(),
            email: "test@example.com",
            username: "testuser",
            displayName: "テストユーザー",
            bio: nil,
            avatarURL: nil,
            location: nil,
            isVerified: false,
            role: .user,
            privacySettings: PrivacySettings.default,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
