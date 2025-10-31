//
//  AudioRecorderView.swift
//  LocationNewsSNS
//
//  Created for audio recording UI
//

import SwiftUI

/// 音声録音UIコンポーネント
struct AudioRecorderView: View {
    @ObservedObject var viewModel: AudioRecorderViewModel

    // アニメーション状態
    @State private var isAnimating = false

    // Dynamic Type対応
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        VStack(spacing: 16) {
            // エラーメッセージ表示
            if let errorMessage = viewModel.errorMessage {
                errorMessageView(errorMessage)
            }

            // メインコンテンツ
            switch viewModel.recordingState {
            case .idle:
                idleStateView
            case .recording:
                recordingStateView
            case .stopped:
                stoppedStateView
            case .playing:
                playingStateView
            }
        }
        .padding()
    }

    // MARK: - Idle State View

    /// 録音開始前の状態
    private var idleStateView: some View {
        VStack(spacing: 16) {
            // マイクボタン
            Button(action: {
                Task {
                    try? await viewModel.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
            }
            .accessibilityLabel("録音を開始")
            .accessibilityHint("タップして音声メッセージの録音を開始します")

            Text("タップして録音開始")
                .font(dynamicBodyFont)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Recording State View

    /// 録音中の状態
    private var recordingStateView: some View {
        VStack(spacing: 24) {
            // 録音時間表示
            recordingTimeDisplay

            // 波形アニメーション
            waveformAnimation

            // 停止とキャンセルボタン
            HStack(spacing: 32) {
                // 停止ボタン
                Button(action: {
                    Task {
                        try? await viewModel.stopRecording()
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.red)
                            .clipShape(Circle())

                        Text("停止")
                            .font(dynamicCaptionFont)
                            .foregroundColor(.primary)
                    }
                }
                .accessibilityLabel("録音を停止")
                .accessibilityHint("タップして録音を停止し、音声を保存します")

                // キャンセルボタン
                Button(action: {
                    viewModel.cancelRecording()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.gray)
                            .clipShape(Circle())

                        Text("キャンセル")
                            .font(dynamicCaptionFont)
                            .foregroundColor(.primary)
                    }
                }
                .accessibilityLabel("録音をキャンセル")
                .accessibilityHint("タップして録音をキャンセルし、破棄します")
            }
        }
    }

    /// 録音時間表示（カウントアップ + カウントダウン）
    private var recordingTimeDisplay: some View {
        VStack(spacing: 8) {
            // 経過時間（カウントアップ）
            Text(formatTime(viewModel.recordingTime))
                .font(dynamicTimerFont)
                .foregroundColor(.red)
                .accessibilityLabel("録音時間 \(formatTimeForAccessibility(viewModel.recordingTime))")

            // 残り時間（カウントダウン）
            let remainingTime = viewModel.audioService.maxRecordingTime - viewModel.recordingTime
            Text("残り \(formatTime(max(0, remainingTime)))")
                .font(dynamicBodyFont)
                .foregroundColor(.secondary)
        }
    }

    /// 波形アニメーション
    private var waveformAnimation: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 4)
                    .frame(height: isAnimating ? CGFloat.random(in: 20...60) : 20)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
        .accessibilityHidden(true) // 装飾的要素のため読み上げ不要
    }

    // MARK: - Stopped State View

    /// 録音停止後の状態
    private var stoppedStateView: some View {
        VStack(spacing: 16) {
            // 録音完了メッセージ
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)

                Text("録音完了")
                    .font(.headline)
            }

            // 録音時間表示
            Text("録音時間: \(formatTime(viewModel.recordingTime))")
                .font(dynamicBodyFont)
                .foregroundColor(.secondary)

            Divider()

            // 再生・削除ボタン
            HStack(spacing: 32) {
                // 再生ボタン
                Button(action: {
                    Task {
                        try? await viewModel.playRecording()
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.blue)
                            .clipShape(Circle())

                        Text("再生")
                            .font(dynamicCaptionFont)
                            .foregroundColor(.primary)
                    }
                }
                .accessibilityLabel("録音を再生")
                .accessibilityHint("タップして録音した音声を再生します")

                // 削除ボタン
                Button(action: {
                    viewModel.deleteRecording()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.red)
                            .clipShape(Circle())

                        Text("削除")
                            .font(dynamicCaptionFont)
                            .foregroundColor(.primary)
                    }
                }
                .accessibilityLabel("録音を削除")
                .accessibilityHint("タップして録音した音声を削除します")
            }
        }
    }

    // MARK: - Playing State View

    /// 再生中の状態
    private var playingStateView: some View {
        VStack(spacing: 16) {
            // 再生中メッセージ
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .font(.title2)

                Text("再生中")
                    .font(.headline)
            }

            // 停止ボタン
            Button(action: {
                viewModel.stopPlaying()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.blue)
                        .clipShape(Circle())

                    Text("停止")
                        .font(dynamicCaptionFont)
                        .foregroundColor(.primary)
                }
            }
            .accessibilityLabel("再生を停止")
            .accessibilityHint("タップして音声の再生を停止します")

            // 削除ボタン
            Button(action: {
                viewModel.deleteRecording()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.red)
                        .clipShape(Circle())

                    Text("削除")
                        .font(dynamicCaptionFont)
                        .foregroundColor(.primary)
                }
            }
            .accessibilityLabel("録音を削除")
            .accessibilityHint("タップして録音した音声を削除します")
        }
    }

    // MARK: - Error Message View

    /// エラーメッセージ表示
    private func errorMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text(message)
                .font(dynamicBodyFont)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("エラー: \(message)")
    }

    // MARK: - Dynamic Type Support

    /// Dynamic Typeに対応したボディフォント
    private var dynamicBodyFont: Font {
        sizeCategory.isAccessibilityCategory ? .title3 : .body
    }

    /// Dynamic Typeに対応したキャプションフォント
    private var dynamicCaptionFont: Font {
        sizeCategory.isAccessibilityCategory ? .body : .caption
    }

    /// Dynamic Typeに対応したタイマーフォント
    private var dynamicTimerFont: Font {
        if sizeCategory.isAccessibilityCategory {
            return .system(size: 36, weight: .bold, design: .rounded)
        } else {
            return .system(size: 48, weight: .bold, design: .rounded)
        }
    }

    // MARK: - Helper Functions

    /// 時間をMM:SS形式にフォーマット
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// アクセシビリティ用の時間フォーマット
    private func formatTimeForAccessibility(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60

        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - Preview

#Preview {
    AudioRecorderView(viewModel: AudioRecorderViewModel())
}
