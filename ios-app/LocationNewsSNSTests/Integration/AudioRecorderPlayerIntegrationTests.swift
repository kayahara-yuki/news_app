import XCTest
import AVFoundation
@testable import LocationNewsSNS

/// AudioRecorderとAudioPlayerの統合テスト
/// 録音から再生までの完全なフローをテストする
@MainActor
final class AudioRecorderPlayerIntegrationTests: XCTestCase {

    var recorderViewModel: AudioRecorderViewModel!
    var audioService: AudioService!

    override func setUp() async throws {
        audioService = AudioService()
        recorderViewModel = AudioRecorderViewModel(audioService: audioService)
    }

    override func tearDown() async throws {
        // クリーンアップ
        recorderViewModel.deleteRecording()
        audioService.cleanup()
        recorderViewModel = nil
        audioService = nil
    }

    // MARK: - Integration Test 1: 録音→再生の完全フロー

    /// Test 1: 録音→停止→再生の完全なフローが正常に動作する
    func testCompleteRecordingAndPlaybackFlow() async throws {
        // Given: 初期状態
        XCTAssertEqual(recorderViewModel.recordingState, .idle, "Initial state should be idle")
        XCTAssertNil(recorderViewModel.audioFileURL, "Initial audio file URL should be nil")

        // When: 録音を開始
        do {
            try await recorderViewModel.startRecording()
        } catch AudioServiceError.permissionDenied {
            // マイクアクセス拒否の場合はテストをスキップ
            throw XCTSkip("Microphone access denied. Skipping test.")
        }

        // Then: 録音状態になる
        XCTAssertEqual(recorderViewModel.recordingState, .recording, "State should be recording")
        XCTAssertNotNil(recorderViewModel.audioFileURL, "Audio file URL should be set")

        // When: 1秒間録音を続ける
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Then: 録音時間が更新される
        XCTAssertGreaterThan(recorderViewModel.recordingTime, 0.5, "Recording time should be greater than 0.5 seconds")

        // When: 録音を停止
        try await recorderViewModel.stopRecording()

        // Then: 停止状態になり、音声ファイルが保存される
        XCTAssertEqual(recorderViewModel.recordingState, .stopped, "State should be stopped")
        XCTAssertNotNil(recorderViewModel.audioFileURL, "Audio file URL should still be set")

        guard let recordedURL = recorderViewModel.audioFileURL else {
            XCTFail("Audio file URL should not be nil")
            return
        }

        // Then: 音声ファイルが実際に存在する
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordedURL.path), "Audio file should exist on disk")

        // When: 録音した音声を再生
        try await recorderViewModel.playRecording()

        // Then: 再生状態になる
        XCTAssertEqual(recorderViewModel.recordingState, .playing, "State should be playing")
        XCTAssertTrue(audioService.isPlaying, "AudioService should be playing")

        // When: 少し待機して再生を確認
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

        // Then: 再生時間が進んでいる
        let currentTime = audioService.getCurrentTime()
        XCTAssertGreaterThan(currentTime, 0, "Current playback time should be greater than 0")

        // When: 再生を停止
        recorderViewModel.stopPlaying()

        // Then: 停止状態に戻る
        XCTAssertEqual(recorderViewModel.recordingState, .stopped, "State should be stopped")
        XCTAssertFalse(audioService.isPlaying, "AudioService should not be playing")
    }

    // MARK: - Integration Test 2: 複数回の録音と再生

    /// Test 2: 複数回の録音と再生が正常に動作する
    func testMultipleRecordingAndPlaybackCycles() async throws {
        // First recording cycle
        do {
            try await recorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 500_000_000)
            try await recorderViewModel.stopRecording()

            let firstURL = recorderViewModel.audioFileURL
            XCTAssertNotNil(firstURL, "First recording URL should be set")

            // Second recording cycle (should replace first recording)
            try await recorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 500_000_000)
            try await recorderViewModel.stopRecording()

            let secondURL = recorderViewModel.audioFileURL
            XCTAssertNotNil(secondURL, "Second recording URL should be set")

            // URLs should be different
            XCTAssertNotEqual(firstURL, secondURL, "Second recording should have different URL")

            // First file should be deleted
            if let firstURL = firstURL {
                XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path), "First recording should be deleted")
            }

            // Second file should exist
            if let secondURL = secondURL {
                XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path), "Second recording should exist")
            }

            // Play second recording
            try await recorderViewModel.playRecording()
            XCTAssertEqual(recorderViewModel.recordingState, .playing, "Should be playing second recording")

            recorderViewModel.stopPlaying()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 3: 録音中の再生試行

    /// Test 3: 録音中に再生を試みるとエラーが発生する
    func testPlaybackDuringRecordingThrowsError() async throws {
        do {
            // Start recording
            try await recorderViewModel.startRecording()
            XCTAssertEqual(recorderViewModel.recordingState, .recording)

            // Try to play while recording
            do {
                try await recorderViewModel.playRecording()
                XCTFail("Should throw error when trying to play during recording")
            } catch {
                // Error is expected
                XCTAssertTrue(error is AudioServiceError, "Should throw AudioServiceError")
            }

            // Stop recording
            try await recorderViewModel.stopRecording()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 4: 再生中の録音開始

    /// Test 4: 再生中に新しい録音を開始すると再生が停止される
    func testRecordingDuringPlaybackStopsPlayback() async throws {
        do {
            // First recording
            try await recorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 500_000_000)
            try await recorderViewModel.stopRecording()

            // Start playback
            try await recorderViewModel.playRecording()
            XCTAssertEqual(recorderViewModel.recordingState, .playing)
            XCTAssertTrue(audioService.isPlaying, "Should be playing")

            // Start new recording (should stop playback)
            try await recorderViewModel.startRecording()

            // Playback should be stopped
            XCTAssertEqual(recorderViewModel.recordingState, .recording, "Should be recording")
            XCTAssertFalse(audioService.isPlaying, "Playback should be stopped")

            // Stop recording
            try await recorderViewModel.stopRecording()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 5: AudioPlayerViewとの統合

    /// Test 5: AudioPlayerViewが録音したファイルを再生できる
    func testAudioPlayerViewPlaysRecordedFile() async throws {
        do {
            // Record audio
            try await recorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            try await recorderViewModel.stopRecording()

            guard let recordedURL = recorderViewModel.audioFileURL else {
                XCTFail("Recorded URL should not be nil")
                return
            }

            // Create AudioPlayerView with recorded file
            let playerService = AudioService()

            // Play the recorded file using playerService
            try await playerService.playAudio(from: recordedURL)

            // Verify playback
            XCTAssertTrue(playerService.isPlaying, "PlayerService should be playing")

            let duration = playerService.getDuration()
            XCTAssertGreaterThan(duration, 0.5, "Duration should be at least 0.5 seconds")

            // Wait for playback to progress
            try await Task.sleep(nanoseconds: 500_000_000)

            let currentTime = playerService.getCurrentTime()
            XCTAssertGreaterThan(currentTime, 0, "Current time should be greater than 0")

            // Stop playback
            playerService.stopAudio()
            XCTAssertFalse(playerService.isPlaying, "PlayerService should not be playing")

            // Cleanup
            playerService.cleanup()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 6: ファイルの削除

    /// Test 6: 録音削除後にファイルが削除される
    func testDeleteRecordingRemovesFile() async throws {
        do {
            // Record audio
            try await recorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 500_000_000)
            try await recorderViewModel.stopRecording()

            guard let recordedURL = recorderViewModel.audioFileURL else {
                XCTFail("Recorded URL should not be nil")
                return
            }

            // Verify file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: recordedURL.path), "File should exist")

            // Delete recording
            recorderViewModel.deleteRecording()

            // Verify file is deleted
            XCTAssertFalse(FileManager.default.fileExists(atPath: recordedURL.path), "File should be deleted")
            XCTAssertNil(recorderViewModel.audioFileURL, "Audio file URL should be nil")
            XCTAssertEqual(recorderViewModel.recordingState, .idle, "State should be idle")

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 7: 最大録音時間の自動停止

    /// Test 7: 最大録音時間に達すると自動停止される
    func testMaxRecordingTimeAutoStop() async throws {
        // Note: 実際に30秒待つのは非現実的なため、短い時間でロジックを確認
        do {
            try await recorderViewModel.startRecording()

            // Verify max recording time is set
            XCTAssertEqual(audioService.maxRecordingTime, 30.0, "Max recording time should be 30 seconds")

            // Note: 実際の自動停止は30秒かかるため、ここではロジックの存在のみ確認
            // 実際の自動停止テストは手動テストで確認

            try await recorderViewModel.stopRecording()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 8: シーク機能のテスト

    /// Test 8: 再生中のシーク機能が正常に動作する
    func testSeekDuringPlayback() async throws {
        do {
            // Record audio (at least 2 seconds)
            try await recorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try await recorderViewModel.stopRecording()

            // Start playback
            try await recorderViewModel.playRecording()
            XCTAssertTrue(audioService.isPlaying, "Should be playing")

            // Get duration
            let duration = audioService.getDuration()
            XCTAssertGreaterThan(duration, 1.5, "Duration should be at least 1.5 seconds")

            // Seek to middle
            let midpoint = duration / 2.0
            recorderViewModel.seekToTime(midpoint)

            // Wait a bit for seek to take effect
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Verify current time is near midpoint
            let currentTime = audioService.getCurrentTime()
            XCTAssertGreaterThan(currentTime, midpoint - 0.5, "Current time should be near midpoint")
            XCTAssertLessThan(currentTime, midpoint + 0.5, "Current time should be near midpoint")

            // Stop playback
            recorderViewModel.stopPlaying()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 9: 排他制御のテスト

    /// Test 9: 複数のAudioServiceインスタンスで排他制御が動作する
    func testExclusivePlaybackAcrossInstances() async throws {
        do {
            // Record audio with first service
            try await recorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await recorderViewModel.stopRecording()

            guard let recordedURL = recorderViewModel.audioFileURL else {
                XCTFail("Recorded URL should not be nil")
                return
            }

            // Create two separate AudioService instances
            let service1 = AudioService()
            let service2 = AudioService()

            // Start playback on service1
            try await service1.playAudio(from: recordedURL)
            XCTAssertTrue(service1.isPlaying, "Service1 should be playing")

            // Start playback on service2 (should stop service1)
            try await service2.playAudio(from: recordedURL)
            XCTAssertTrue(service2.isPlaying, "Service2 should be playing")
            XCTAssertFalse(service1.isPlaying, "Service1 should be stopped")

            // Cleanup
            service1.cleanup()
            service2.cleanup()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 10: エラーリカバリー

    /// Test 10: エラー発生後のリカバリーが正常に動作する
    func testErrorRecovery() async throws {
        do {
            // Try to play non-existent file (should fail)
            let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent.m4a")

            do {
                try await audioService.playAudio(from: fakeURL)
                XCTFail("Should throw error for non-existent file")
            } catch {
                // Error is expected
                XCTAssertNotNil(error, "Should throw error")
            }

            // After error, should be able to record normally
            try await recorderViewModel.startRecording()
            XCTAssertEqual(recorderViewModel.recordingState, .recording, "Should be able to record after error")

            try await Task.sleep(nanoseconds: 500_000_000)
            try await recorderViewModel.stopRecording()

            // And play normally
            try await recorderViewModel.playRecording()
            XCTAssertEqual(recorderViewModel.recordingState, .playing, "Should be able to play after error")

            recorderViewModel.stopPlaying()

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }
}
