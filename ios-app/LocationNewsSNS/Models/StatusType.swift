import Foundation

/// ワンタップステータス共有のプリセットステータス
///
/// ユーザーが現在の状況をワンタップで共有できるステータスを定義します。
/// 各ステータスは絵文字とテキストで構成され、地図上にアイコンとして表示されます。
///
/// - Requirements: 4.2, 7.2
enum StatusType: String, CaseIterable, Codable {
    /// ☕ カフェなう
    case cafe = "☕ カフェなう"

    /// 🍴 ランチ中
    case lunch = "🍴 ランチ中"

    /// 🚶 散歩中
    case walking = "🚶 散歩中"

    /// 📚 勉強中
    case studying = "📚 勉強中"

    /// 😴 暇してる
    case free = "😴 暇してる"

    /// 🎉 イベント参加中
    case event = "🎉 イベント参加中"

    /// 🏃 移動中
    case moving = "🏃 移動中"

    /// 🎬 映画鑑賞中
    case movie = "🎬 映画鑑賞中"

    // MARK: - Computed Properties

    /// 地図表示用の絵文字アイコン
    ///
    /// rawValueから絵文字部分のみを抽出して返します。
    ///
    /// - Returns: 絵文字文字列（例: "☕"）
    var emoji: String {
        // rawValueから最初の絵文字を抽出
        let components = rawValue.components(separatedBy: " ")
        return components.first ?? ""
    }

    /// ステータスのテキスト部分
    ///
    /// rawValueから絵文字を除いたテキスト部分を返します。
    ///
    /// - Returns: テキスト部分（例: "カフェなう"）
    var text: String {
        // rawValueから絵文字を除いたテキスト部分を抽出
        let components = rawValue.components(separatedBy: " ")
        return components.dropFirst().joined(separator: " ")
    }

    /// VoiceOver用のアクセシビリティラベル
    ///
    /// スクリーンリーダーで読み上げられる説明文を返します。
    ///
    /// - Returns: アクセシビリティラベル（例: "カフェなう ステータスボタン"）
    var accessibilityLabel: String {
        return "\(text) ステータスボタン"
    }
}

// MARK: - Extensions

extension StatusType {
    /// ステータスの表示名（rawValueと同じ）
    var displayName: String {
        return rawValue
    }
}
