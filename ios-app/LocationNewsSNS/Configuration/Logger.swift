import Foundation

/// アプリ全体で使用するログユーティリティ
/// パフォーマンス最適化: リリースビルドではデバッグログを出力しない
enum AppLogger {
    enum LogLevel {
        case debug
        case info
        case warning
        case error
    }

    /// ログを出力（DEBUGビルドのみ）
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("🐛 [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }

    /// 情報ログを出力
    static func info(_ message: String, file: String = #file) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("ℹ️ [\(fileName)] \(message)")
        #endif
    }

    /// 警告ログを出力（DEBUGとRELEASEの両方）
    static func warning(_ message: String, file: String = #file) {
        let fileName = (file as NSString).lastPathComponent
        print("⚠️ [\(fileName)] \(message)")
    }

    /// エラーログを出力（DEBUGとRELEASEの両方）
    static func error(_ message: String, file: String = #file) {
        let fileName = (file as NSString).lastPathComponent
        print("❌ [\(fileName)] \(message)")
    }
}
