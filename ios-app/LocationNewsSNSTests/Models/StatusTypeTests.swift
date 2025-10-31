import XCTest
@testable import LocationNewsSNS

/// StatusTypeのテストクラス
final class StatusTypeTests: XCTestCase {

    // MARK: - Test Cases

    /// すべてのステータスタイプが定義されていることをテスト
    func testAllStatusTypes() {
        let expectedStatuses: [StatusType] = [
            .cafe, .lunch, .walking, .studying,
            .free, .event, .moving, .movie
        ]

        XCTAssertEqual(StatusType.allCases.count, 8, "8種類のステータスが定義されているべき")

        for status in expectedStatuses {
            XCTAssertTrue(StatusType.allCases.contains(status), "\(status)が定義されているべき")
        }
    }

    /// 各ステータスが正しいrawValueを持つことをテスト
    func testStatusRawValues() {
        XCTAssertEqual(StatusType.cafe.rawValue, "☕ カフェなう")
        XCTAssertEqual(StatusType.lunch.rawValue, "🍴 ランチ中")
        XCTAssertEqual(StatusType.walking.rawValue, "🚶 散歩中")
        XCTAssertEqual(StatusType.studying.rawValue, "📚 勉強中")
        XCTAssertEqual(StatusType.free.rawValue, "😴 暇してる")
        XCTAssertEqual(StatusType.event.rawValue, "🎉 イベント参加中")
        XCTAssertEqual(StatusType.moving.rawValue, "🏃 移動中")
        XCTAssertEqual(StatusType.movie.rawValue, "🎬 映画鑑賞中")
    }

    /// 各ステータスが正しい絵文字を返すことをテスト
    func testStatusEmojis() {
        XCTAssertEqual(StatusType.cafe.emoji, "☕")
        XCTAssertEqual(StatusType.lunch.emoji, "🍴")
        XCTAssertEqual(StatusType.walking.emoji, "🚶")
        XCTAssertEqual(StatusType.studying.emoji, "📚")
        XCTAssertEqual(StatusType.free.emoji, "😴")
        XCTAssertEqual(StatusType.event.emoji, "🎉")
        XCTAssertEqual(StatusType.moving.emoji, "🏃")
        XCTAssertEqual(StatusType.movie.emoji, "🎬")
    }

    /// 各ステータスが正しいテキスト部分を返すことをテスト
    func testStatusText() {
        XCTAssertEqual(StatusType.cafe.text, "カフェなう")
        XCTAssertEqual(StatusType.lunch.text, "ランチ中")
        XCTAssertEqual(StatusType.walking.text, "散歩中")
        XCTAssertEqual(StatusType.studying.text, "勉強中")
        XCTAssertEqual(StatusType.free.text, "暇してる")
        XCTAssertEqual(StatusType.event.text, "イベント参加中")
        XCTAssertEqual(StatusType.moving.text, "移動中")
        XCTAssertEqual(StatusType.movie.text, "映画鑑賞中")
    }

    /// アクセシビリティラベルが正しく設定されることをテスト
    func testAccessibilityLabel() {
        XCTAssertEqual(StatusType.cafe.accessibilityLabel, "カフェなう ステータスボタン")
        XCTAssertEqual(StatusType.lunch.accessibilityLabel, "ランチ中 ステータスボタン")
        XCTAssertEqual(StatusType.walking.accessibilityLabel, "散歩中 ステータスボタン")
        XCTAssertEqual(StatusType.studying.accessibilityLabel, "勉強中 ステータスボタン")
        XCTAssertEqual(StatusType.free.accessibilityLabel, "暇してる ステータスボタン")
        XCTAssertEqual(StatusType.event.accessibilityLabel, "イベント参加中 ステータスボタン")
        XCTAssertEqual(StatusType.moving.accessibilityLabel, "移動中 ステータスボタン")
        XCTAssertEqual(StatusType.movie.accessibilityLabel, "映画鑑賞中 ステータスボタン")
    }

    /// Codableプロトコルに準拠していることをテスト
    func testCodable() throws {
        let status = StatusType.cafe

        // エンコード
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)

        // デコード
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(StatusType.self, from: data)

        XCTAssertEqual(status, decodedStatus, "エンコード・デコードが正しく動作するべき")
    }
}
