//
//  AudioServiceFileSizeTests.swift
//  LocationNewsSNSTests
//
//  Test: ファイルサイズ超過チェック機能のテスト
//

import XCTest
@testable import LocationNewsSNS

@MainActor
final class AudioServiceFileSizeTests: XCTestCase {

    var audioService: AudioService!
    var mockStorageRepository: MockStorageRepository!

    override func setUp() async throws {
        try await super.setUp()
        mockStorageRepository = MockStorageRepository()
        audioService = AudioService(storageRepository: mockStorageRepository)
    }

    override func tearDown() async throws {
        audioService.cleanup()
        audioService = nil
        mockStorageRepository = nil
        try await super.tearDown()
    }

    // MARK: - ファイルサイズ超過チェックテスト

    /// Test: 2MB以下のファイルは警告なしでアップロードできる
    func testUploadAudio_SmallFile_NoWarning() async throws {
        // Arrange: 1MBのテストファイルを作成
        let fileURL = createTestAudioFile(sizeInMB: 1.0)
        let userID = UUID()

        // Act: アップロード実行
        mockStorageRepository.uploadResult = .success(URL(string: "https://example.com/audio.m4a")!)

        let publicURL = try await audioService.uploadAudio(fileURL: fileURL, userID: userID)

        // Assert: 警告メッセージが出ないことを確認
        XCTAssertNil(audioService.errorMessage)
        XCTAssertNotNil(publicURL)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Test: 2MB超のファイルは警告が表示される
    func testCheckFileSizeWarning_LargeFile_ReturnsWarning() async throws {
        // Arrange: 3MBのテストファイルを作成
        let fileURL = createTestAudioFile(sizeInMB: 3.0)

        // Act: ファイルサイズチェック実行
        let warning = await audioService.checkFileSizeWarning(fileURL: fileURL)

        // Assert: 警告メッセージが返されることを確認
        XCTAssertNotNil(warning)
        XCTAssertTrue(warning?.contains("ファイルサイズが大きいため") ?? false)
        XCTAssertTrue(warning?.contains("アップロードに時間がかかる場合があります") ?? false)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Test: 2MB以下のファイルは警告なし
    func testCheckFileSizeWarning_SmallFile_NoWarning() async throws {
        // Arrange: 1MBのテストファイルを作成
        let fileURL = createTestAudioFile(sizeInMB: 1.0)

        // Act: ファイルサイズチェック実行
        let warning = await audioService.checkFileSizeWarning(fileURL: fileURL)

        // Assert: 警告がnilであることを確認
        XCTAssertNil(warning)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Test: ファイルが存在しない場合はエラーを返す
    func testCheckFileSizeWarning_NonExistentFile_ReturnsNil() async throws {
        // Arrange: 存在しないファイルのURL
        let nonExistentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent.m4a")

        // Act: ファイルサイズチェック実行
        let warning = await audioService.checkFileSizeWarning(fileURL: nonExistentURL)

        // Assert: nilが返されることを確認
        XCTAssertNil(warning)
    }

    /// Test: 正確に2MBのファイルは警告なし（境界値テスト）
    func testCheckFileSizeWarning_ExactlyTwoMB_NoWarning() async throws {
        // Arrange: ちょうど2MBのテストファイルを作成
        let fileURL = createTestAudioFile(sizeInMB: 2.0)

        // Act: ファイルサイズチェック実行
        let warning = await audioService.checkFileSizeWarning(fileURL: fileURL)

        // Assert: 警告がnilであることを確認（2MB以下）
        XCTAssertNil(warning)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Test: 2MB + 1バイトのファイルは警告あり（境界値テスト）
    func testCheckFileSizeWarning_TwoMBPlusOneByte_ReturnsWarning() async throws {
        // Arrange: 2MB + 1バイトのテストファイルを作成
        let fileURL = createTestAudioFile(sizeInBytes: 2_097_153) // 2MB + 1byte

        // Act: ファイルサイズチェック実行
        let warning = await audioService.checkFileSizeWarning(fileURL: fileURL)

        // Assert: 警告メッセージが返されることを確認
        XCTAssertNotNil(warning)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - ヘルパーメソッド

    /// 指定サイズのテストオーディオファイルを作成
    /// - Parameter sizeInMB: ファイルサイズ (MB)
    /// - Returns: 作成されたファイルのURL
    private func createTestAudioFile(sizeInMB: Double) -> URL {
        let sizeInBytes = Int(sizeInMB * 1024 * 1024)
        return createTestAudioFile(sizeInBytes: sizeInBytes)
    }

    /// 指定バイト数のテストオーディオファイルを作成
    /// - Parameter sizeInBytes: ファイルサイズ (バイト)
    /// - Returns: 作成されたファイルのURL
    private func createTestAudioFile(sizeInBytes: Int) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_audio_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // ダミーデータを生成
        let dummyData = Data(count: sizeInBytes)

        // ファイルに書き込み
        try? dummyData.write(to: fileURL)

        return fileURL
    }
}

// MARK: - Mock Storage Repository

class MockStorageRepository: StorageRepositoryProtocol {
    var uploadResult: Result<URL, Error>?
    var deleteResult: Result<Void, Error>?
    var getPublicURLResult: Result<URL, Error>?

    func upload(bucket: String, path: String, data: Data) async throws -> URL {
        guard let result = uploadResult else {
            throw StorageError.uploadFailed("No mock result configured")
        }
        return try result.get()
    }

    func delete(bucket: String, path: String) async throws {
        guard let result = deleteResult else {
            throw StorageError.deleteFailed("No mock result configured")
        }
        try result.get()
    }

    func getPublicURL(bucket: String, path: String) async throws -> URL {
        guard let result = getPublicURLResult else {
            throw StorageError.urlGenerationFailed("No mock result configured")
        }
        return try result.get()
    }
}
