import SwiftUI

extension Font {
    /// アプリ全体で使用する標準フォント
    /// iOS 18のHiragino Sans警告を回避するため、明示的にシステムフォントを使用
    static func appDefault(size: CGFloat = 17, weight: Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }

    static func appRounded(size: CGFloat = 17, weight: Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .rounded)
    }
}
