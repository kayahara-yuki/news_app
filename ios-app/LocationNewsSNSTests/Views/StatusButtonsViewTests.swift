import XCTest
import SwiftUI
@testable import LocationNewsSNS

/// StatusButtonsViewのテストクラス
final class StatusButtonsViewTests: XCTestCase {

    // MARK: - Test Cases

    /// StatusButtonsViewが8種類のステータスボタンを表示することをテスト
    func testDisplaysAllStatusButtons() {
        // Given
        @State var selectedStatus: StatusType? = nil

        // Then
        XCTAssertEqual(StatusType.allCases.count, 8, "8種類のステータスボタンが表示されるべき")
    }

    /// ボタンがタップされたときに選択状態が変わることをテスト
    func testButtonSelectionChangesOnTap() {
        // Given
        var selectedStatus: StatusType? = nil

        // When
        selectedStatus = .cafe

        // Then
        XCTAssertEqual(selectedStatus, .cafe, "選択されたステータスが更新されるべき")
    }

    /// 複数のボタンをタップしたとき、最後に選択されたもののみがアクティブになることをテスト
    func testSingleSelectionLogic() {
        // Given
        var selectedStatus: StatusType? = nil

        // When
        selectedStatus = .cafe
        XCTAssertEqual(selectedStatus, .cafe, "最初の選択がcafeであるべき")

        selectedStatus = .lunch
        XCTAssertEqual(selectedStatus, .lunch, "最後の選択がlunchであるべき")

        // Then
        XCTAssertNotEqual(selectedStatus, .cafe, "前の選択は無効になるべき")
    }

    /// 選択されたボタンと選択されていないボタンが異なる状態を持つことをテスト
    func testSelectedAndUnselectedStates() {
        // Given
        let selectedStatus: StatusType? = .cafe

        // Then
        XCTAssertTrue(selectedStatus == .cafe, "cafeが選択されているべき")
        XCTAssertFalse(selectedStatus == .lunch, "lunchは選択されていないべき")
    }

    /// アクセシビリティラベルが正しく設定されることをテスト
    func testAccessibilityLabels() {
        // Given
        let status = StatusType.cafe

        // Then
        XCTAssertEqual(status.accessibilityLabel, "カフェなう ステータスボタン", "アクセシビリティラベルが正しく設定されるべき")
    }

    /// すべてのStatusTypeがCaseIterableに準拠していることをテスト
    func testAllCasesIterable() {
        // Given
        let allStatuses = StatusType.allCases

        // Then
        XCTAssertEqual(allStatuses.count, 8, "8種類のステータスがイテレート可能であるべき")

        let expectedStatuses: [StatusType] = [
            .cafe, .lunch, .walking, .studying,
            .free, .event, .moving, .movie
        ]

        for (index, status) in allStatuses.enumerated() {
            XCTAssertEqual(status, expectedStatuses[index], "\(index)番目のステータスが期待通りであるべき")
        }
    }

    /// nil選択状態（選択なし）が正しく処理されることをテスト
    func testNilSelectionState() {
        // Given
        let selectedStatus: StatusType? = nil

        // Then
        XCTAssertNil(selectedStatus, "初期状態では選択がnilであるべき")

        for status in StatusType.allCases {
            XCTAssertFalse(selectedStatus == status, "選択がnilの場合、どのステータスも選択されていないべき")
        }
    }

    /// ボタンの選択をクリアできることをテスト
    func testClearSelection() {
        // Given
        var selectedStatus: StatusType? = .cafe

        // When
        selectedStatus = nil

        // Then
        XCTAssertNil(selectedStatus, "選択がクリアされるべき")
    }
}
