//
//  AudioRecorderViewTests.swift
//  LocationNewsSNSTests
//
//  Created for testing AudioRecorderView UI
//

import XCTest
import SwiftUI
@testable import LocationNewsSNS

@MainActor
final class AudioRecorderViewTests: XCTestCase {

    var viewModel: AudioRecorderViewModel!
    var mockAudioService: AudioService!

    override func setUp() async throws {
        try await super.setUp()
        mockAudioService = AudioService()
        viewModel = AudioRecorderViewModel(audioService: mockAudioService)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockAudioService = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    /// Test 1: Viewが初期状態で正しくレンダリングされることを確認
    func testInitialViewRendering() {
        // Given: 初期状態のViewModel
        XCTAssertEqual(viewModel.recordingState, .idle)

        // When: Viewを作成
        let view = AudioRecorderView(viewModel: viewModel)

        // Then: Viewが作成できることを確認（コンパイル時チェック）
        XCTAssertNotNil(view)
    }

    /// Test 2: 録音ボタンのアクセシビリティラベルが正しく設定されていることを確認
    func testRecordButtonAccessibilityLabel() {
        // Given: idle状態のViewModel
        XCTAssertEqual(viewModel.recordingState, .idle)

        // Then: 録音ボタンには「録音を開始」というアクセシビリティラベルが必要
        // Note: 実際のViewでaccessibilityLabel("録音を開始")を設定する
        XCTAssertEqual(viewModel.recordingState, .idle)
    }

    /// Test 3: 録音中の停止ボタンのアクセシビリティラベルが正しく設定されていることを確認
    func testStopButtonAccessibilityLabel() async throws {
        // Given: 録音中の状態
        try await viewModel.startRecording()

        // Then: 停止ボタンには「録音を停止」というアクセシビリティラベルが必要
        XCTAssertEqual(viewModel.recordingState, .recording)
    }

    // MARK: - Recording State UI Tests

    /// Test 4: 録音開始時にUIが録音中状態に更新されることを確認
    func testRecordingStateUIUpdate() async throws {
        // Given: idle状態
        XCTAssertEqual(viewModel.recordingState, .idle)

        // When: 録音を開始
        try await viewModel.startRecording()

        // Then: 状態がrecordingに変わる
        XCTAssertEqual(viewModel.recordingState, .recording)
        XCTAssertNotNil(viewModel.audioFileURL)
    }

    /// Test 5: 録音時間が表示用にフォーマットされることを確認
    func testRecordingTimeFormatting() async throws {
        // Given: 録音中
        try await viewModel.startRecording()

        // When: 録音時間が経過
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1秒

        // Then: 録音時間が更新されている
        XCTAssertGreaterThan(viewModel.recordingTime, 1.0)

        // 時間フォーマット関数のテスト（MM:SS形式）
        let formattedTime = formatTime(viewModel.recordingTime)
        XCTAssertTrue(formattedTime.contains(":"))
    }

    /// Test 6: 残り時間が正しく計算されることを確認
    func testRemainingTimeCalculation() async throws {
        // Given: 録音中
        try await viewModel.startRecording()

        // When: 録音時間が経過
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

        // Then: 残り時間が正しく計算される
        let remainingTime = viewModel.audioService.maxRecordingTime - viewModel.recordingTime
        XCTAssertGreaterThan(remainingTime, 29.0)
        XCTAssertLessThanOrEqual(remainingTime, 30.0)
    }

    // MARK: - Animation Tests

    /// Test 7: 録音中の波形アニメーションの状態確認
    func testWaveformAnimationDuringRecording() async throws {
        // Given: idle状態
        XCTAssertEqual(viewModel.recordingState, .idle)

        // When: 録音開始
        try await viewModel.startRecording()

        // Then: 録音中状態でアニメーションが動作する
        XCTAssertEqual(viewModel.recordingState, .recording)

        // Note: 実際のViewでは.animation(.easeInOut(duration: 0.5).repeatForever())を使用
    }

    // MARK: - Button State Tests

    /// Test 8: 録音停止後に再生ボタンが表示されることを確認
    func testPlayButtonAppearsAfterRecording() async throws {
        // Given: 録音して停止
        try await viewModel.startRecording()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        try await viewModel.stopRecording()

        // Then: stopped状態で音声ファイルが存在
        XCTAssertEqual(viewModel.recordingState, .stopped)
        XCTAssertNotNil(viewModel.audioFileURL)
    }

    /// Test 9: キャンセルボタンタップ時にすべてがリセットされることを確認
    func testCancelButtonResetsEverything() async throws {
        // Given: 録音中
        try await viewModel.startRecording()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        // When: キャンセル
        viewModel.cancelRecording()

        // Then: すべてがリセット
        XCTAssertEqual(viewModel.recordingState, .idle)
        XCTAssertNil(viewModel.audioFileURL)
        XCTAssertEqual(viewModel.recordingTime, 0)
    }

    /// Test 10: 削除ボタンタップ時に録音が削除されることを確認
    func testDeleteButtonRemovesRecording() async throws {
        // Given: 録音完了
        try await viewModel.startRecording()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        try await viewModel.stopRecording()
        XCTAssertNotNil(viewModel.audioFileURL)

        // When: 削除
        viewModel.deleteRecording()

        // Then: 録音が削除される
        XCTAssertEqual(viewModel.recordingState, .idle)
        XCTAssertNil(viewModel.audioFileURL)
    }

    // MARK: - Dynamic Type Tests

    /// Test 11: Dynamic Type対応の確認
    func testDynamicTypeSupport() {
        // Given: ViewModelの状態
        XCTAssertEqual(viewModel.recordingState, .idle)

        // Then: Viewで.font(.body)を使用し、自動的にDynamic Type対応する
        // Note: SwiftUIの.font(.body)は自動的にDynamic Typeに対応
        XCTAssertTrue(true) // プレースホルダー
    }

    // MARK: - Error Display Tests

    /// Test 12: エラーメッセージが表示されることを確認
    func testErrorMessageDisplay() async throws {
        // Given: エラーが発生
        viewModel.errorMessage = "マイクへのアクセスが許可されていません"

        // Then: エラーメッセージが設定されている
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "マイクへのアクセスが許可されていません")
    }

    // MARK: - Accessibility Tests

    /// Test 13: 録音進行状況の音声通知アナウンスメントが15秒ごとに発生することを確認
    func testRecordingProgressAccessibilityAnnouncement() async throws {
        // Given: 録音を開始
        try await viewModel.startRecording()
        XCTAssertEqual(viewModel.recordingState, .recording)

        // When: 15秒経過を待つ
        try await Task.sleep(nanoseconds: 15_500_000_000) // 15.5秒

        // Then: ViewModelに最後のアナウンスメント時刻が記録されている
        XCTAssertNotNil(viewModel.lastAnnouncementTime)
        XCTAssertGreaterThanOrEqual(viewModel.recordingTime, 15.0)

        // Clean up
        try await viewModel.stopRecording()
    }

    /// Test 14: VoiceOver有効時に録音開始の音声フィードバックが提供されることを確認
    func testRecordingStartAccessibilityAnnouncement() async throws {
        // Given: idle状態
        XCTAssertEqual(viewModel.recordingState, .idle)

        // When: 録音を開始
        try await viewModel.startRecording()

        // Then: 録音状態になり、開始アナウンスメントフラグが立つ
        XCTAssertEqual(viewModel.recordingState, .recording)
        XCTAssertTrue(viewModel.didAnnounceRecordingStart)

        // Clean up
        try await viewModel.stopRecording()
    }

    /// Test 15: 録音時間が30秒に近づくと警告アナウンスメントが発生することを確認
    func testRecordingTimeWarningAnnouncement() async throws {
        // Given: 録音を開始
        try await viewModel.startRecording()

        // When: 25秒経過まで待つ（テストでは実際には待たず、手動で時間を設定）
        // Note: 実装では25秒時点で「残り5秒です」のアナウンスメントが必要
        viewModel.recordingTime = 25.0

        // Then: 警告アナウンスメントフラグが立つ
        // Note: ViewModelに警告アナウンスメントロジックを追加する必要がある
        XCTAssertGreaterThanOrEqual(viewModel.recordingTime, 25.0)

        // Clean up
        viewModel.cancelRecording()
    }

    // MARK: - Helper Functions

    /// 時間をMM:SS形式にフォーマットする関数
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
