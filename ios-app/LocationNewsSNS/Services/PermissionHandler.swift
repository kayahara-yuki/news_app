import Foundation
import AVFoundation
import CoreLocation
import SwiftUI
import Combine

/// パーミッション管理クラス
///
/// 責務:
/// - マイクアクセス許可の管理
/// - 位置情報アクセス許可の管理
/// - AVFoundation利用可能性の確認
/// - パーミッション拒否時のエラーハンドリング
@MainActor
class PermissionHandler: ObservableObject {

    // MARK: - Published Properties

    /// マイクパーミッションアラートを表示すべきか
    @Published var shouldShowMicrophonePermissionAlert: Bool = false

    /// 位置情報パーミッションアラートを表示すべきか
    @Published var shouldShowLocationPermissionAlert: Bool = false

    /// パーミッションアラートメッセージ
    @Published var permissionAlertMessage: String?

    /// ステータス投稿が有効か（位置情報パーミッションに依存）
    @Published var isStatusPostEnabled: Bool = false

    /// 音声録音ボタンを表示すべきか（AVFoundation利用可能性に依存）
    @Published var shouldShowAudioRecorderButton: Bool = true

    // MARK: - Private Properties

    /// 現在のマイクアクセス許可状態
    private(set) var microphoneAuthorizationStatus: AVAudioSession.RecordPermission = .undetermined

    /// 現在の位置情報アクセス許可状態
    private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Computed Properties

    /// AVFoundationが利用可能か
    var isAVFoundationAvailable: Bool {
        // iOS 16以降では常にtrue
        // 将来的に古いバージョンをサポートする場合はバージョンチェックを追加
        if #available(iOS 16.0, *) {
            return true
        } else {
            return false
        }
    }

    // MARK: - Initialization

    init() {
        updateMicrophoneAuthorizationStatus()
        updateAVFoundationAvailability()
    }

    // MARK: - Microphone Permission

    /// マイクアクセス許可状態を更新
    func updateMicrophoneAuthorizationStatus() {
        microphoneAuthorizationStatus = AVAudioSession.sharedInstance().recordPermission
    }

    /// マイクアクセス拒否時の処理
    func handleMicrophoneAccessDenied() {
        shouldShowMicrophonePermissionAlert = true
        permissionAlertMessage = """
        マイクアクセスが必要です

        音声メッセージを録音するには、設定からマイクアクセスを許可してください。
        """

        print("[PermissionHandler] Microphone access denied")
    }

    /// マイクアクセス許可をリクエスト
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    self.updateMicrophoneAuthorizationStatus()
                    if !granted {
                        self.handleMicrophoneAccessDenied()
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Location Permission

    /// 位置情報アクセス許可状態を更新
    /// - Parameter status: 新しい許可状態
    func updateLocationAuthorizationStatus(_ status: CLAuthorizationStatus) {
        locationAuthorizationStatus = status

        // ステータス投稿の有効/無効を更新
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isStatusPostEnabled = true
            shouldShowLocationPermissionAlert = false

        case .denied, .restricted:
            isStatusPostEnabled = false
            shouldShowLocationPermissionAlert = true
            permissionAlertMessage = """
            位置情報アクセスが必要です

            ステータス投稿を利用するには、設定から位置情報アクセスを許可してください。
            """
            print("[PermissionHandler] Location access denied or restricted")

        case .notDetermined:
            isStatusPostEnabled = false
            shouldShowLocationPermissionAlert = false

        @unknown default:
            isStatusPostEnabled = false
            shouldShowLocationPermissionAlert = false
        }
    }

    // MARK: - AVFoundation Availability

    /// AVFoundationの利用可能性を更新
    private func updateAVFoundationAvailability() {
        shouldShowAudioRecorderButton = isAVFoundationAvailable

        if !isAVFoundationAvailable {
            print("[PermissionHandler] AVFoundation is not available on this device")
        }
    }

    // MARK: - Settings

    /// 設定画面を開けるか
    /// - Returns: 設定画面を開けるかどうか
    func canOpenSettings() -> Bool {
        return UIApplication.shared.canOpenURL(URL(string: UIApplication.openSettingsURLString)!)
    }

    /// 設定画面を開く
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("[PermissionHandler] Failed to create settings URL")
            return
        }

        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL) { success in
                if success {
                    print("[PermissionHandler] Settings opened successfully")
                } else {
                    print("[PermissionHandler] Failed to open settings")
                }
            }
        }
    }

    // MARK: - Alert Dismissal

    /// マイクパーミッションアラートを閉じる
    func dismissMicrophonePermissionAlert() {
        shouldShowMicrophonePermissionAlert = false
        permissionAlertMessage = nil
    }

    /// 位置情報パーミッションアラートを閉じる
    func dismissLocationPermissionAlert() {
        shouldShowLocationPermissionAlert = false
        permissionAlertMessage = nil
    }
}

// MARK: - Permission Alert View Modifier

/// パーミッションアラートを表示するViewModifier
struct PermissionAlertModifier: ViewModifier {
    @ObservedObject var permissionHandler: PermissionHandler

    func body(content: Content) -> some View {
        content
            .alert(
                "アクセス許可が必要です",
                isPresented: $permissionHandler.shouldShowMicrophonePermissionAlert
            ) {
                Button("キャンセル", role: .cancel) {
                    permissionHandler.dismissMicrophonePermissionAlert()
                }

                Button("設定を開く") {
                    permissionHandler.openSettings()
                    permissionHandler.dismissMicrophonePermissionAlert()
                }
            } message: {
                if let message = permissionHandler.permissionAlertMessage {
                    Text(message)
                }
            }
            .alert(
                "位置情報アクセスが必要です",
                isPresented: $permissionHandler.shouldShowLocationPermissionAlert
            ) {
                Button("キャンセル", role: .cancel) {
                    permissionHandler.dismissLocationPermissionAlert()
                }

                Button("設定を開く") {
                    permissionHandler.openSettings()
                    permissionHandler.dismissLocationPermissionAlert()
                }
            } message: {
                if let message = permissionHandler.permissionAlertMessage {
                    Text(message)
                }
            }
    }
}

extension View {
    /// パーミッションアラートを追加
    /// - Parameter permissionHandler: PermissionHandlerインスタンス
    /// - Returns: パーミッションアラートが追加されたView
    func permissionAlerts(_ permissionHandler: PermissionHandler) -> some View {
        modifier(PermissionAlertModifier(permissionHandler: permissionHandler))
    }
}
