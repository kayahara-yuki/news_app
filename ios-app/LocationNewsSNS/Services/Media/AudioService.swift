import Foundation
import AVFoundation
import Supabase
import Combine
import UIKit

// MARK: - Audio Service

/// 音声録音・再生・アップロードを管理するサービス
@MainActor
class AudioService: NSObject, ObservableObject {

    // MARK: - Shared Instance (for global playback control)

    /// グローバル再生制御用の共有インスタンス（オプション）
    /// 複数のAudioServiceインスタンスが同時に再生しないように管理
    private static var currentlyPlayingService: AudioService?

    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingTime: TimeInterval = 0
    @Published var currentPlaybackTime: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var uploadProgress: Double = 0.0

    /// バックグラウンド移行によって一時停止されたかどうか
    /// Requirements: 11.3 - フォアグラウンド復帰時に再開オプションを表示するため
    @Published var wasPausedByBackground = false

    // MARK: - Properties

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var recordingURL: URL?

    /// 最大録音時間（秒）
    let maxRecordingTime: TimeInterval = 30.0

    /// StorageRepository（アップロード用）
    private let storageRepository: StorageRepositoryProtocol

    /// アップロードタイムアウト（秒）
    private let uploadTimeout: TimeInterval = 30.0

    /// リトライ設定
    private let maxRetryAttempts = 3
    private let initialRetryDelay: TimeInterval = 1.0

    // Recording settings
    private let sampleRate: Double = 44100.0  // 44.1kHz
    private let bitRate: Int = 128000         // 128kbps
    private let channels: Int = 1             // Mono

    // MARK: - Initialization

    init(storageRepository: StorageRepositoryProtocol = StorageRepository()) {
        self.storageRepository = storageRepository
        super.init()
        setupAudioSession()
        setupBackgroundNotifications()
    }

    deinit {
        // Note: deinitはnonisolatedコンテキストなのでNotificationCenter.removeObserverを直接呼び出す
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Setup

    /// オーディオセッションを設定
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            print("[AudioService] Audio session setup complete")
        } catch {
            print("[AudioService] Failed to setup audio session: \(error.localizedDescription)")
            errorMessage = "音声セッションの設定に失敗しました"
        }
    }

    // MARK: - Background Notifications Setup (Requirement 11.3)

    /// バックグラウンド/フォアグラウンド通知の監視を設定
    /// Requirements: 11.3 - 音声録音中にアプリがバックグラウンドに移行 → 録音を一時停止
    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        print("[AudioService] Background notifications setup complete")
    }

    /// バックグラウンド通知の監視を削除
    private func removeBackgroundNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        print("[AudioService] Background notifications removed")
    }

    /// バックグラウンド移行時の処理
    /// Requirements: 11.3 - 録音を一時停止し、フォアグラウンド復帰時に再開オプションを表示
    @objc private func handleDidEnterBackground() {
        Task { @MainActor in
            if isRecording {
                print("[AudioService] App entered background while recording - pausing")
                stopRecording(fromBackground: true)
                wasPausedByBackground = true
            }
        }
    }

    /// フォアグラウンド復帰時の処理
    @objc private func handleWillEnterForeground() {
        Task { @MainActor in
            if wasPausedByBackground {
                print("[AudioService] App returned to foreground - resume option available")
                // フラグはViewModelまたはユーザーが再開/破棄を選択するまで保持
            }
        }
    }

    // MARK: - Permission

    /// マイクアクセス許可をリクエスト
    /// - Returns: 許可されたかどうか
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording

    /// 録音を開始
    /// - Returns: 録音ファイルの一時URL
    func startRecording() async throws -> URL {
        // マイク許可チェック
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            errorMessage = "マイクアクセスが許可されていません"
            throw AudioServiceError.microphoneAccessDenied
        }

        // 既存の録音を停止
        if isRecording {
            stopRecording()
        }

        // 録音ファイルのURL生成
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent(fileName)

        guard let url = recordingURL else {
            throw AudioServiceError.invalidURL
        }

        // 録音設定
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),  // AAC format
            AVSampleRateKey: sampleRate,               // 44.1kHz
            AVNumberOfChannelsKey: channels,           // Mono
            AVEncoderBitRateKey: bitRate,              // 128kbps
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            // レコーダーを初期化
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()

            // 録音開始
            let success = audioRecorder?.record() ?? false
            guard success else {
                throw AudioServiceError.recordingFailed
            }

            isRecording = true
            recordingTime = 0

            // タイマー開始
            startRecordingTimer()

            print("[AudioService] Recording started: \(url.lastPathComponent)")
            return url

        } catch {
            errorMessage = "録音の開始に失敗しました"
            throw AudioServiceError.recordingFailed
        }
    }

    /// 録音を停止
    /// - Returns: 録音されたファイルのURL（録音していない場合はnil）
    /// - Parameter fromBackground: バックグラウンド移行による停止かどうか（内部使用）
    @discardableResult
    func stopRecording(fromBackground: Bool = false) -> URL? {
        guard isRecording, let recorder = audioRecorder else {
            return nil
        }

        recorder.stop()
        isRecording = false
        stopRecordingTimer()

        // 通常停止の場合はバックグラウンドフラグをクリア
        if !fromBackground {
            wasPausedByBackground = false
        }

        print("[AudioService] Recording stopped. Duration: \(recordingTime)s")
        return recordingURL
    }

    /// 録音をキャンセル（ファイルも削除）
    func cancelRecording() {
        stopRecording()

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            print("[AudioService] Recording cancelled and file deleted")
        }

        recordingURL = nil
        recordingTime = 0
    }

    // MARK: - Playback

    /// 音声を再生
    /// - Parameter url: 音声ファイルのURL
    func playAudio(from url: URL) async throws {
        // グローバル排他制御: 他のAudioServiceインスタンスが再生中の場合は停止
        if let currentlyPlaying = AudioService.currentlyPlayingService,
           currentlyPlaying !== self {
            currentlyPlaying.stopAudio()
            print("[AudioService] Stopped playback from another instance")
        }

        // 既存の再生を停止
        if isPlaying {
            pauseAudio()
        }

        do {
            // プレイヤーを初期化
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            // 再生開始
            let success = audioPlayer?.play() ?? false
            guard success else {
                throw AudioServiceError.playbackFailed
            }

            isPlaying = true
            AudioService.currentlyPlayingService = self
            startPlaybackTimer()

            print("[AudioService] Playback started: \(url.lastPathComponent)")

        } catch {
            errorMessage = "音声の再生に失敗しました"
            throw AudioServiceError.playbackFailed
        }
    }

    /// 音声再生を一時停止
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()

        // グローバル状態をクリア（一時停止時）
        if AudioService.currentlyPlayingService === self {
            AudioService.currentlyPlayingService = nil
        }

        print("[AudioService] Playback paused")
    }

    /// 音声再生を停止
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentPlaybackTime = 0
        stopPlaybackTimer()

        // グローバル状態をクリア
        if AudioService.currentlyPlayingService === self {
            AudioService.currentlyPlayingService = nil
        }

        print("[AudioService] Playback stopped")
    }

    /// 再生位置をシーク
    /// - Parameter time: シークする時間（秒）
    func seekToTime(_ time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(time, 0), player.duration)
        currentPlaybackTime = player.currentTime
        print("[AudioService] Seeked to: \(time)s")
    }

    /// 現在の再生時間を取得
    /// - Returns: 現在の再生時間（秒）
    func getCurrentTime() -> TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }

    /// 音声のデュレーションを取得
    /// - Returns: 音声の長さ（秒）
    func getDuration() -> TimeInterval {
        return audioPlayer?.duration ?? 0
    }

    // MARK: - Timer Management

    /// 録音タイマーを開始
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingTime += 0.1

                // 最大録音時間に達したら自動停止
                if self.recordingTime >= self.maxRecordingTime {
                    self.stopRecording()
                }
            }
        }
    }

    /// 録音タイマーを停止
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    /// 再生タイマーを開始
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            Task { @MainActor in
                self.currentPlaybackTime = player.currentTime
            }
        }
    }

    /// 再生タイマーを停止
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Cleanup

    /// リソースをクリーンアップ
    func cleanup() {
        cancelRecording()
        stopAudio()
        audioRecorder = nil
        audioPlayer = nil
        print("[AudioService] Cleanup complete")
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                print("[AudioService] Recording finished successfully")
            } else {
                print("[AudioService] Recording failed")
                errorMessage = "録音に失敗しました"
            }
            isRecording = false
            stopRecordingTimer()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("[AudioService] Recording encode error: \(error?.localizedDescription ?? "Unknown")")
            errorMessage = "録音中にエラーが発生しました"
            isRecording = false
            stopRecordingTimer()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            print("[AudioService] Playback finished")
            isPlaying = false
            currentPlaybackTime = 0
            stopPlaybackTimer()

            // グローバル状態をクリア
            if AudioService.currentlyPlayingService === self {
                AudioService.currentlyPlayingService = nil
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("[AudioService] Playback decode error: \(error?.localizedDescription ?? "Unknown")")
            errorMessage = "再生中にエラーが発生しました"
            isPlaying = false
            stopPlaybackTimer()

            // グローバル状態をクリア
            if AudioService.currentlyPlayingService === self {
                AudioService.currentlyPlayingService = nil
            }
        }
    }
}

// MARK: - Upload

extension AudioService {

    /// 音声ファイルをSupabase Storageにアップロード
    /// - Parameters:
    ///   - fileURL: ローカル音声ファイルのURL
    ///   - userID: ユーザーID
    /// - Returns: アップロードされたファイルのPublic URL

    // MARK: - File Size Validation

    /// ファイルサイズの警告メッセージを返す（2MB超の場合）
    /// - Parameter fileURL: チェックするファイルのURL
    /// - Returns: 警告メッセージ（2MB以下の場合はnil）
    /// - Requirements: 9.6
    func checkFileSizeWarning(fileURL: URL) async -> String? {
        // ファイルの存在確認
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[AudioService] File not found for size check: \(fileURL.path)")
            return nil
        }

        do {
            // ファイルサイズを取得
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attributes[.size] as? Int64 else {
                print("[AudioService] Failed to get file size")
                return nil
            }

            // 2MBの閾値（バイト）
            let fileSizeThreshold: Int64 = 2 * 1024 * 1024 // 2MB

            // 2MBを超える場合は警告メッセージを返す
            if fileSize > fileSizeThreshold {
                let fileSizeInMB = Double(fileSize) / (1024.0 * 1024.0)
                let message = String(format: "ファイルサイズが大きいため（%.1fMB）、アップロードに時間がかかる場合があります", fileSizeInMB)
                print("[AudioService] File size warning: \(fileSizeInMB)MB")
                return message
            }

            // 2MB以下の場合は警告なし
            return nil

        } catch {
            print("[AudioService] Error checking file size: \(error.localizedDescription)")
            return nil
        }
    }

    func uploadAudio(fileURL: URL, userID: UUID) async throws -> URL {
        print("[AudioService] 🚀 uploadAudio started")
        print("[AudioService] 📁 fileURL: \(fileURL.absoluteString)")
        print("[AudioService] 📂 fileURL.path: \(fileURL.path)")
        print("[AudioService] 👤 userID: \(userID.uuidString)")

        // ファイルの存在確認
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        print("[AudioService] 📂 File exists: \(fileExists)")

        guard fileExists else {
            print("[AudioService] ❌ File not found at path: \(fileURL.path)")
            throw AudioServiceError.fileNotFound
        }

        // ファイルサイズを確認
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? Int64 {
            print("[AudioService] 📦 File size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
        }

        // ファイルをDataに変換
        let audioData: Data
        do {
            print("[AudioService] 📖 Reading file data...")
            audioData = try Data(contentsOf: fileURL)
            print("[AudioService] ✅ File read successful: \(audioData.count) bytes")
        } catch {
            print("[AudioService] ❌ File read failed: \(error.localizedDescription)")
            throw AudioServiceError.fileReadFailed(error.localizedDescription)
        }

        // ファイルパス生成: {user_id}/{timestamp}.m4a (バケット名は含めない)
        // RLSポリシーが (storage.foldername(name))[1] = auth.uid() を期待するため
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(timestamp).m4a"
        let filePath = "\(userID.uuidString)/\(fileName)"
        print("[AudioService] 🗂️ Storage path: \(filePath)")

        // Exponential Backoffでリトライ
        var lastError: Error?
        for attempt in 0..<maxRetryAttempts {
            do {
                print("[AudioService] 🔄 Upload attempt \(attempt + 1)/\(maxRetryAttempts)")

                // 進捗をリセット
                uploadProgress = 0.0

                // アップロード実行
                print("[AudioService] 📤 Calling storageRepository.upload...")
                let publicURL = try await storageRepository.upload(
                    bucket: "audio",
                    path: filePath,
                    data: audioData
                )

                // 進捗を100%に
                uploadProgress = 1.0

                print("[AudioService] ✅ Upload successful: \(publicURL.absoluteString)")
                return publicURL

            } catch {
                lastError = error
                print("[AudioService] ❌ Upload attempt \(attempt + 1) failed: \(error.localizedDescription)")
                print("[AudioService] Error type: \(type(of: error))")
                print("[AudioService] Error details: \(error)")

                // 最後の試行でなければリトライ
                if attempt < maxRetryAttempts - 1 {
                    let delay = initialRetryDelay * pow(2.0, Double(attempt))
                    print("[AudioService] ⏳ Retrying in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // すべてのリトライが失敗
        print("[AudioService] ❌ All retry attempts failed")
        throw AudioServiceError.uploadFailed(lastError?.localizedDescription ?? "Unknown error")
    }

    /// 音声ファイルをStorageから削除
    /// - Parameters:
    ///   - audioURL: 削除する音声ファイルのURL
    ///   - userID: ユーザーID
    func deleteAudio(audioURL: URL, userID: UUID) async throws {
        print("[AudioService] Delete started: \(audioURL.absoluteString)")

        // URLからパスを抽出
        // 例: https://supabase.co/storage/v1/object/public/audio/user_id/timestamp.m4a
        // -> audio/user_id/timestamp.m4a
        let pathComponents = audioURL.pathComponents
        guard let audioIndex = pathComponents.firstIndex(of: "audio"),
              audioIndex + 2 < pathComponents.count else {
            throw AudioServiceError.invalidURL
        }

        let userFolder = pathComponents[audioIndex + 1]
        let fileName = pathComponents[audioIndex + 2]
        let filePath = "audio/\(userFolder)/\(fileName)"

        // 削除実行
        do {
            try await storageRepository.delete(bucket: "audio", path: filePath)
            print("[AudioService] Delete successful")
        } catch {
            throw AudioServiceError.deleteFailed(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum AudioServiceError: LocalizedError {
    case microphoneAccessDenied
    case recordingFailed
    case playbackFailed
    case invalidURL
    case fileNotFound
    case fileReadFailed(String)
    case uploadFailed(String)
    case deleteFailed(String)
    case permissionDenied
    case notRecording
    case invalidState
    case storageQuotaExceeded  // Requirement 11.6: ストレージ容量制限エラー

    var errorDescription: String? {
        switch self {
        case .microphoneAccessDenied:
            return "マイクアクセスが拒否されました"
        case .recordingFailed:
            return "録音に失敗しました"
        case .playbackFailed:
            return "再生に失敗しました"
        case .invalidURL:
            return "無効なファイルURLです"
        case .fileNotFound:
            return "音声ファイルが見つかりません"
        case .fileReadFailed(let message):
            return "ファイルの読み込みに失敗しました: \(message)"
        case .uploadFailed(let message):
            return "アップロードに失敗しました: \(message)"
        case .deleteFailed(let message):
            return "削除に失敗しました: \(message)"
        case .permissionDenied:
            return "権限が拒否されました"
        case .notRecording:
            return "録音していません"
        case .invalidState:
            return "無効な状態です"
        case .storageQuotaExceeded:
            // Requirement 11.6: エラーメッセージ「ストレージ容量が不足しています。古い投稿を削除してください」
            return "ストレージ容量が不足しています。古い投稿を削除してください"
        }
    }
}
