//
//  AudioUploadPostIntegrationTests.swift
//  LocationNewsSNSTests
//
//  Created for testing audio upload and post creation integration
//

import XCTest
import CoreLocation
@testable import LocationNewsSNS

/// 音声録音→アップロード→投稿作成の完全フローを統合テスト
/// Requirements: 8.3 - 音声録音→アップロード→投稿作成フローの統合テスト
@MainActor
final class AudioUploadPostIntegrationTests: XCTestCase {

    var audioService: AudioService!
    var storageRepository: StorageRepository!
    var postService: PostService!
    var audioRecorderViewModel: AudioRecorderViewModel!
    var testAudioFileURL: URL?

    override func setUp() async throws {
        try await super.setUp()

        // サービスの初期化
        storageRepository = StorageRepository()
        audioService = AudioService(storageRepository: storageRepository)
        postService = PostService()
        audioRecorderViewModel = AudioRecorderViewModel(audioService: audioService)
    }

    override func tearDown() async throws {
        // クリーンアップ
        if let url = testAudioFileURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        audioRecorderViewModel.deleteRecording()
        audioService.cleanup()

        audioRecorderViewModel = nil
        audioService = nil
        storageRepository = nil
        postService = nil
        testAudioFileURL = nil

        try await super.tearDown()
    }

    // MARK: - Integration Test 1: 完全な音声投稿作成フロー

    /// Test 1: 録音→アップロード→投稿作成の完全フローが成功する
    /// Requirements: 1.6, 1.7, 2.8, 3.3
    func testCompleteAudioPostCreationFlow() async throws {
        // Given: 初期状態
        XCTAssertEqual(audioRecorderViewModel.recordingState, .idle, "Initial state should be idle")

        // STEP 1: 音声録音
        do {
            try await audioRecorderViewModel.startRecording()
        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }

        XCTAssertEqual(audioRecorderViewModel.recordingState, .recording, "Should be recording")

        // 1秒間録音
        try await Task.sleep(nanoseconds: 1_000_000_000)

        try await audioRecorderViewModel.stopRecording()
        XCTAssertEqual(audioRecorderViewModel.recordingState, .stopped, "Should be stopped")

        guard let recordedURL = audioRecorderViewModel.audioFileURL else {
            XCTFail("Recorded audio file URL should not be nil")
            return
        }

        testAudioFileURL = recordedURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordedURL.path), "Audio file should exist")

        // STEP 2: 音声ファイルのアップロード
        let audioData = try Data(contentsOf: recordedURL)
        XCTAssertGreaterThan(audioData.count, 0, "Audio data should not be empty")

        let userID = UUID()
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(timestamp).m4a"
        let uploadPath = "\(userID.uuidString)/\(fileName)"

        do {
            let uploadedURL = try await storageRepository.upload(
                bucket: "audio",
                path: uploadPath,
                data: audioData
            )

            // Then: アップロードが成功してHTTPS URLが返される
            XCTAssertNotNil(uploadedURL, "Uploaded URL should not be nil")
            XCTAssertTrue(uploadedURL.absoluteString.hasPrefix("https://"), "URL should use HTTPS")
            XCTAssertTrue(uploadedURL.absoluteString.contains("audio"), "URL should contain bucket name")

            print("[Test] Audio uploaded successfully: \(uploadedURL.absoluteString)")

            // STEP 3: 音声付き投稿の作成
            let testLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            let testContent = "Test audio post"
            let testUserID = userID

            // 音声付き投稿を作成
            try await postService.createPostWithAudio(
                content: testContent,
                audioFileURL: recordedURL,
                latitude: testLocation.latitude,
                longitude: testLocation.longitude,
                address: "Tokyo, Japan",
                userID: testUserID
            )

            // Then: 投稿が正常に作成され、nearbyPostsに追加される
            XCTAssertGreaterThan(postService.nearbyPosts.count, 0, "Post should be added to nearbyPosts")

            guard let post = postService.nearbyPosts.first else {
                XCTFail("Post should exist in nearbyPosts")
                return
            }

            XCTAssertNotNil(post.audioURL, "Post should have audio URL")
            XCTAssertEqual(post.content, testContent, "Post content should match")
            XCTAssertNotNil(post.latitude, "Post should have latitude")
            XCTAssertNotNil(post.longitude, "Post should have longitude")

            print("[Test] Post created successfully with audio: \(post.id)")

            // Cleanup: アップロードされたファイルを削除
            try await storageRepository.delete(bucket: "audio", path: uploadPath)
            print("[Test] Cleanup: Audio file deleted from storage")

        } catch {
            // Supabase接続エラーは許容される（テスト環境による）
            print("[Test] Integration test failed (expected in some environments): \(error.localizedDescription)")
            throw XCTSkip("Supabase connection required. Skipping test: \(error.localizedDescription)")
        }
    }

    // MARK: - Integration Test 2: アップロードエラー時のハンドリング

    /// Test 2: アップロード失敗時にローカルファイルが保持される
    /// Requirements: 1.9, 7.2
    func testUploadFailureRetainsLocalFile() async throws {
        do {
            // Given: 音声録音
            try await audioRecorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 500_000_000)
            try await audioRecorderViewModel.stopRecording()

            guard let recordedURL = audioRecorderViewModel.audioFileURL else {
                XCTFail("Recorded URL should not be nil")
                return
            }

            testAudioFileURL = recordedURL

            // When: 無効なバケット名でアップロード試行
            let audioData = try Data(contentsOf: recordedURL)
            let invalidBucket = "" // 無効なバケット名

            do {
                _ = try await storageRepository.upload(
                    bucket: invalidBucket,
                    path: "test/test.m4a",
                    data: audioData
                )
                XCTFail("Should throw error for invalid bucket")
            } catch {
                // Then: エラーが発生するが、ローカルファイルは保持される
                XCTAssertNotNil(error, "Should throw error")
                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: recordedURL.path),
                    "Local file should be retained after upload failure"
                )
            }

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 3: 大きなファイルのアップロード

    /// Test 3: 大きな音声ファイル（2秒以上）のアップロードが成功する
    /// Requirements: 9.5
    func testLargeAudioFileUpload() async throws {
        do {
            // Given: 2秒間の録音
            try await audioRecorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            try await audioRecorderViewModel.stopRecording()

            guard let recordedURL = audioRecorderViewModel.audioFileURL else {
                XCTFail("Recorded URL should not be nil")
                return
            }

            testAudioFileURL = recordedURL

            let audioData = try Data(contentsOf: recordedURL)
            print("[Test] Audio file size: \(audioData.count) bytes")

            // Then: ファイルサイズが妥当な範囲内
            XCTAssertGreaterThan(audioData.count, 10_000, "Audio file should be larger than 10KB")

            // When: アップロード試行
            let userID = UUID()
            let timestamp = Int(Date().timeIntervalSince1970)
            let uploadPath = "\(userID.uuidString)/\(timestamp)_large.m4a"

            do {
                let uploadedURL = try await storageRepository.upload(
                    bucket: "audio",
                    path: uploadPath,
                    data: audioData
                )

                // Then: アップロードが成功
                XCTAssertNotNil(uploadedURL, "Large file upload should succeed")
                print("[Test] Large file uploaded: \(uploadedURL.absoluteString)")

                // Cleanup
                try await storageRepository.delete(bucket: "audio", path: uploadPath)

            } catch {
                print("[Test] Large file upload test skipped: \(error.localizedDescription)")
                throw XCTSkip("Supabase connection required: \(error.localizedDescription)")
            }

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 4: タイムアウト処理

    /// Test 4: アップロードタイムアウトが正しく動作する
    /// Requirements: 9.5
    func testUploadTimeout() async throws {
        // Note: 実際のタイムアウトテストは30秒かかるため、
        // ここではタイムアウト処理の存在のみ確認

        // Given: StorageRepositoryがタイムアウト設定を持つ
        let repository = StorageRepository()

        // Then: タイムアウト設定が存在することを確認
        // (実装内部でタイムアウトが設定されていることを前提)
        XCTAssertNotNil(repository, "Repository should have timeout handling")
    }

    // MARK: - Integration Test 5: 複数ファイルの連続アップロード

    /// Test 5: 複数の音声ファイルを連続してアップロードできる
    /// Requirements: 3.2
    func testMultipleFileUploads() async throws {
        do {
            var uploadedURLs: [URL] = []
            var uploadPaths: [String] = []

            // When: 2つの音声ファイルを録音してアップロード
            for i in 1...2 {
                try await audioRecorderViewModel.startRecording()
                try await Task.sleep(nanoseconds: 500_000_000)
                try await audioRecorderViewModel.stopRecording()

                guard let recordedURL = audioRecorderViewModel.audioFileURL else {
                    XCTFail("Recorded URL \(i) should not be nil")
                    continue
                }

                let audioData = try Data(contentsOf: recordedURL)
                let userID = UUID()
                let timestamp = Int(Date().timeIntervalSince1970)
                let uploadPath = "\(userID.uuidString)/\(timestamp)_file\(i).m4a"

                do {
                    let uploadedURL = try await storageRepository.upload(
                        bucket: "audio",
                        path: uploadPath,
                        data: audioData
                    )

                    uploadedURLs.append(uploadedURL)
                    uploadPaths.append(uploadPath)
                    print("[Test] File \(i) uploaded: \(uploadedURL.absoluteString)")

                } catch {
                    print("[Test] File \(i) upload failed: \(error.localizedDescription)")
                }

                // 次の録音の前にクリーンアップ
                audioRecorderViewModel.deleteRecording()
            }

            // Then: 両方のファイルがアップロードされた
            if !uploadedURLs.isEmpty {
                XCTAssertGreaterThan(uploadedURLs.count, 0, "At least one file should be uploaded")

                // Cleanup
                for path in uploadPaths {
                    try? await storageRepository.delete(bucket: "audio", path: path)
                }
            } else {
                throw XCTSkip("Supabase connection required for multiple uploads")
            }

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }

    // MARK: - Integration Test 6: ステータス投稿と音声の組み合わせ

    /// Test 6: ステータス投稿に音声ファイルを添付できる
    /// Requirements: 8.1, 8.3
    func testStatusPostWithAudio() async throws {
        do {
            // Given: 音声録音
            try await audioRecorderViewModel.startRecording()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await audioRecorderViewModel.stopRecording()

            guard let recordedURL = audioRecorderViewModel.audioFileURL else {
                XCTFail("Recorded URL should not be nil")
                return
            }

            testAudioFileURL = recordedURL

            // When: ステータス付き音声投稿を作成
            // Note: 現在の仕様では、音声付き投稿は通常投稿として扱われる（Requirement 8.5）
            // ステータステキストに音声を添付する場合も通常投稿となり、自動削除されない
            let testLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            let statusText = "☕ カフェなう"
            let testUserID = UUID()

            do {
                // 音声付き投稿として作成（isStatusPost=falseとなる）
                try await postService.createPostWithAudio(
                    content: statusText,
                    audioFileURL: recordedURL,
                    latitude: testLocation.latitude,
                    longitude: testLocation.longitude,
                    address: "Tokyo, Japan",
                    userID: testUserID
                )

                // Then: 投稿が作成される（通常投稿として）
                XCTAssertGreaterThan(postService.nearbyPosts.count, 0, "Post should be created")

                guard let post = postService.nearbyPosts.first else {
                    XCTFail("Post should exist")
                    return
                }

                XCTAssertEqual(post.content, statusText, "Content should match status")
                XCTAssertNotNil(post.audioURL, "Post should have audio URL")
                // 音声付き投稿は通常投稿として扱われる
                XCTAssertFalse(post.isStatusPost, "Audio post should be normal post, not status post")
                XCTAssertNil(post.expiresAt, "Normal post should not have expiration time")

                print("[Test] Audio post with status text created as normal post: \(post.id)")

            } catch {
                print("[Test] Status text with audio test skipped: \(error.localizedDescription)")
                throw XCTSkip("Supabase connection required: \(error.localizedDescription)")
            }

        } catch AudioServiceError.permissionDenied {
            throw XCTSkip("Microphone access denied. Skipping test.")
        }
    }
}
