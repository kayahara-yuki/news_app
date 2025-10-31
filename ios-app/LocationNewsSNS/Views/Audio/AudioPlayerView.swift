//
//  AudioPlayerView.swift
//  LocationNewsSNS
//
//  Created for audio playback UI
//

import SwiftUI

/// 音声プレイヤーUIコンポーネント
struct AudioPlayerView: View {
    let audioURL: URL
    @ObservedObject var audioService: AudioService

    // ローカル状態
    @State private var isLoading = false
    @State private var sliderValue: Double = 0
    @State private var isDraggingSlider = false

    var body: some View {
        VStack(spacing: 12) {
            // 再生コントロール部分
            HStack(spacing: 16) {
                // 再生/一時停止ボタン
                playPauseButton

                // 時間表示とシークバー
                VStack(spacing: 4) {
                    // シークバー
                    seekBar

                    // 時間表示
                    timeDisplay
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .onAppear {
            updateSliderValue()
        }
        .onChange(of: audioService.currentPlaybackTime) { _ in
            if !isDraggingSlider {
                updateSliderValue()
            }
        }
    }

    // MARK: - Play/Pause Button

    /// 再生/一時停止ボタン
    private var playPauseButton: some View {
        Button(action: {
            if audioService.isPlaying {
                audioService.pauseAudio()
            } else {
                Task {
                    isLoading = true
                    do {
                        try await audioService.playAudio(from: audioURL)
                    } catch {
                        print("[AudioPlayerView] Playback error: \(error)")
                    }
                    isLoading = false
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(audioService.isPlaying ? Color.blue : Color.green)
                    .frame(width: 44, height: 44)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
        .accessibilityLabel(audioService.isPlaying ? "一時停止" : "再生")
        .accessibilityHint(audioService.isPlaying ? "タップして音声を一時停止します" : "タップして音声を再生します")
    }

    // MARK: - Seek Bar

    /// シークバー
    private var seekBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景トラック
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)

                // 再生進捗
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * sliderValue, height: 4)
                    .cornerRadius(2)

                // ドラッグ可能なつまみ
                Circle()
                    .fill(Color.blue)
                    .frame(width: 16, height: 16)
                    .offset(x: geometry.size.width * sliderValue - 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingSlider = true
                                let newValue = min(max(0, value.location.x / geometry.size.width), 1)
                                sliderValue = newValue
                            }
                            .onEnded { value in
                                isDraggingSlider = false
                                let newValue = min(max(0, value.location.x / geometry.size.width), 1)
                                let newTime = Double(newValue) * audioService.getDuration()
                                audioService.seekToTime(newTime)
                                sliderValue = newValue
                            }
                    )
            }
        }
        .frame(height: 20)
        .accessibilityLabel("シークバー")
        .accessibilityHint("スライドして再生位置を変更します")
        .accessibilityValue("\(Int(sliderValue * 100))パーセント")
    }

    // MARK: - Time Display

    /// 時間表示
    private var timeDisplay: some View {
        HStack {
            // 現在の再生時間
            Text(formatTime(audioService.getCurrentTime()))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .accessibilityLabel("再生時間 \(formatTimeForAccessibility(audioService.getCurrentTime()))")

            Spacer()

            // デュレーション
            Text(formatTime(audioService.getDuration()))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .accessibilityLabel("合計時間 \(formatTimeForAccessibility(audioService.getDuration()))")
        }
    }

    // MARK: - Helper Functions

    /// スライダーの値を更新
    private func updateSliderValue() {
        let duration = audioService.getDuration()
        if duration > 0 {
            sliderValue = audioService.getCurrentTime() / duration
        } else {
            sliderValue = 0
        }
    }

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
    AudioPlayerView(
        audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
        audioService: AudioService()
    )
    .padding()
}
