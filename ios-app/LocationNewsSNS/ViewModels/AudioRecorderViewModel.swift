//
//  AudioRecorderViewModel.swift
//  LocationNewsSNS
//
//  Created for audio recording functionality
//

import Foundation
import SwiftUI
import Combine
import UIKit

/// 録音状態を表す列挙型
enum RecordingState: Equatable {
    case idle        // 初期状態・録音なし
    case recording   // 録音中
    case stopped     // 録音停止済み（音声ファイルあり）
    case playing     // 再生中
}

/// 音声録音機能を管理するViewModel
@MainActor
class AudioRecorderViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 現在の録音状態
    @Published var recordingState: RecordingState = .idle

    /// 録音経過時間（秒）
    @Published var recordingTime: TimeInterval = 0

    /// 録音された音声ファイルのURL
    @Published var audioFileURL: URL?

    /// エラーメッセージ
    @Published var errorMessage: String?

    /// フォアグラウンド復帰時に録音を再開できるかどうか
    /// Requirements: 11.3 - フォアグラウンド復帰時に再開オプションを表示
    @Published var canResumeRecording: Bool = false

    // MARK: - Accessibility Properties

    /// 録音開始のアナウンスメントが完了したかどうか
    /// Requirements: 12.2 - 録音開始の音声フィードバック
    @Published var didAnnounceRecordingStart: Bool = false

    /// 最後のアナウンスメント時刻
    /// Requirements: 12.5 - 録音進行状況の音声通知
    @Published var lastAnnouncementTime: TimeInterval?

    // MARK: - Dependencies

    /// 音声サービス
    let audioService: AudioService

    /// 録音時間更新用のタイマー
    private var recordingTimer: Timer?

    /// Combineのサブスクリプション保持
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    /// アナウンスメント間隔（秒）
    /// Requirements: 12.5 - 15秒ごとに進行状況を通知
    private let announcementInterval: TimeInterval = 15.0

    /// 警告アナウンスメントのタイミング（残り秒数）
    /// Requirements: 12.5 - 残り5秒で警告
    private let warningThreshold: TimeInterval = 5.0

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameter audioService: 音声サービス（デフォルトは新規インスタンス）
    init(audioService: AudioService? = nil) {
        self.audioService = audioService ?? AudioService()

        // AudioServiceの状態を監視
        setupAudioServiceObservers()
    }

    // MARK: - Private Methods

    /// AudioServiceの状態変化を監視するセットアップ
    /// Requirements: 11.3 - バックグラウンド一時停止を検知して再開オプションを表示
    private func setupAudioServiceObservers() {
        // AudioServiceのwasPausedByBackgroundを監視
        audioService.$wasPausedByBackground
            .sink { [weak self] wasPaused in
                guard let self = self else { return }
                Task { @MainActor in
                    self.canResumeRecording = wasPaused
                    if wasPaused {
                        // バックグラウンドで一時停止された場合は状態をstoppedに変更
                        self.recordingState = .stopped
                        print("[AudioRecorderViewModel] Recording paused by background - can resume")
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// 録音時間の更新を開始
    private func startRecordingTimeUpdates() {
        recordingTimer?.invalidate()
        recordingTime = 0
        lastAnnouncementTime = nil

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingTime = self.audioService.recordingTime

                // アクセシビリティアナウンスメント
                self.checkAndAnnounceProgress()

                // 最大録音時間に達したら自動停止
                if self.recordingTime >= self.audioService.maxRecordingTime {
                    try? await self.stopRecording()
                }
            }
        }
    }

    /// 録音時間の更新を停止
    private func stopRecordingTimeUpdates() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        didAnnounceRecordingStart = false
        lastAnnouncementTime = nil
    }

    // MARK: - Accessibility Methods

    /// 録音進行状況をチェックしてアナウンスメントを発行
    /// Requirements: 12.5 - 録音進行状況の音声通知
    private func checkAndAnnounceProgress() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let currentTime = recordingTime
        let remainingTime = audioService.maxRecordingTime - currentTime

        // 警告アナウンスメント（残り5秒）
        if remainingTime <= warningThreshold && remainingTime > warningThreshold - 1.0 {
            let message = "残り\(Int(remainingTime))秒です"
            UIAccessibility.post(notification: .announcement, argument: message)
            print("[AudioRecorderViewModel] Accessibility announcement: \(message)")
            return
        }

        // 定期的なアナウンスメント（15秒ごと）
        if let lastTime = lastAnnouncementTime {
            if currentTime - lastTime >= announcementInterval {
                announceProgress(currentTime)
            }
        } else if currentTime >= announcementInterval {
            // 初回アナウンスメント（15秒経過時）
            announceProgress(currentTime)
        }
    }

    /// 録音進行状況をアナウンス
    /// Requirements: 12.5 - 録音進行状況の音声通知
    private func announceProgress(_ time: TimeInterval) {
        let seconds = Int(time)
        let message = "\(seconds)秒経過"
        UIAccessibility.post(notification: .announcement, argument: message)
        lastAnnouncementTime = time
        print("[AudioRecorderViewModel] Accessibility announcement: \(message)")
    }

    /// 録音開始のアナウンスメント
    /// Requirements: 12.2 - 録音開始の音声フィードバック
    private func announceRecordingStart() {
        guard UIAccessibility.isVoiceOverRunning else { return }

        let message = "録音開始"
        UIAccessibility.post(notification: .announcement, argument: message)
        didAnnounceRecordingStart = true
        print("[AudioRecorderViewModel] Accessibility announcement: \(message)")
    }

    // MARK: - Public Methods - Recording

    /// 録音を開始
    func startRecording() async throws {
        // マイク権限の確認
        let hasPermission = await audioService.requestMicrophonePermission()
        guard hasPermission else {
            errorMessage = "マイクへのアクセスが許可されていません"
            throw AudioServiceError.permissionDenied
        }

        do {
            // 既存の録音がある場合は削除
            if let existingURL = audioFileURL {
                try? FileManager.default.removeItem(at: existingURL)
                audioFileURL = nil
            }

            // 録音開始
            let url = try await audioService.startRecording()
            audioFileURL = url
            recordingState = .recording
            errorMessage = nil

            // 録音時間の更新を開始
            startRecordingTimeUpdates()

            // アクセシビリティアナウンスメント
            announceRecordingStart()

        } catch {
            errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
            recordingState = .idle
            throw error
        }
    }

    /// 録音を停止
    func stopRecording() async throws {
        guard recordingState == .recording else {
            throw AudioServiceError.notRecording
        }

        // 録音時間の更新を停止
        stopRecordingTimeUpdates()

        // 録音停止
        if let url = audioService.stopRecording() {
            audioFileURL = url
            recordingState = .stopped
            errorMessage = nil
            // 通常停止なので再開フラグはクリアされる（AudioServiceで処理済み）
        } else {
            errorMessage = "録音の停止に失敗しました"
            recordingState = .idle
            throw AudioServiceError.recordingFailed
        }
    }

    /// バックグラウンドで一時停止された録音を再開
    /// Requirements: 11.3 - フォアグラウンド復帰時に再開オプションを表示
    func resumeRecording() async throws {
        guard canResumeRecording else {
            throw AudioServiceError.invalidState
        }

        // 録音を再開
        do {
            let url = try await audioService.startRecording()
            audioFileURL = url
            recordingState = .recording
            errorMessage = nil
            canResumeRecording = false
            audioService.wasPausedByBackground = false

            // 録音時間の更新を再開
            startRecordingTimeUpdates()

            print("[AudioRecorderViewModel] Recording resumed after background pause")
        } catch {
            errorMessage = "録音の再開に失敗しました: \(error.localizedDescription)"
            recordingState = .idle
            canResumeRecording = false
            throw error
        }
    }

    /// バックグラウンドで一時停止された録音を破棄
    /// Requirements: 11.3 - 再開しない選択肢を提供
    func discardPausedRecording() {
        canResumeRecording = false
        audioService.wasPausedByBackground = false

        // ファイルを削除
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }

        audioFileURL = nil
        recordingState = .idle
        recordingTime = 0
        errorMessage = nil

        print("[AudioRecorderViewModel] Paused recording discarded")
    }

    /// 録音をキャンセル（録音中のファイルを削除）
    func cancelRecording() {
        stopRecordingTimeUpdates()
        audioService.cancelRecording()

        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }

        audioFileURL = nil
        recordingState = .idle
        recordingTime = 0
        errorMessage = nil
    }

    /// 録音を削除
    func deleteRecording() {
        // 再生中の場合は停止
        if recordingState == .playing {
            audioService.stopAudio()
        }

        // ファイルを削除
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }

        audioFileURL = nil
        recordingState = .idle
        recordingTime = 0
        errorMessage = nil
    }

    // MARK: - Public Methods - Playback

    /// 録音を再生
    func playRecording() async throws {
        guard let url = audioFileURL else {
            errorMessage = "再生する音声ファイルがありません"
            throw AudioServiceError.fileNotFound
        }

        guard recordingState == .stopped else {
            throw AudioServiceError.invalidState
        }

        do {
            try await audioService.playAudio(from: url)
            recordingState = .playing
            errorMessage = nil
        } catch {
            errorMessage = "再生の開始に失敗しました: \(error.localizedDescription)"
            throw error
        }
    }

    /// 再生を一時停止
    func pausePlaying() {
        guard recordingState == .playing else { return }

        audioService.pauseAudio()
        recordingState = .stopped
    }

    /// 再生を停止
    func stopPlaying() {
        guard recordingState == .playing else { return }

        audioService.stopAudio()
        recordingState = .stopped
    }

    /// 再生位置をシーク
    /// - Parameter time: シーク先の時間（秒）
    func seekToTime(_ time: TimeInterval) {
        audioService.seekToTime(time)
    }

    /// 現在の再生位置を取得
    /// - Returns: 現在の再生位置（秒）
    func getCurrentTime() -> TimeInterval {
        return audioService.getCurrentTime()
    }

    /// 音声の長さを取得
    /// - Returns: 音声の長さ（秒）
    func getDuration() -> TimeInterval {
        return audioService.getDuration()
    }

    // MARK: - Cleanup

    deinit {
        recordingTimer?.invalidate()
    }
}
