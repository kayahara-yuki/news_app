# 技術スタック

## フロントエンド (iOS)
- **SwiftUI**: iOS 18+ ネイティブUI
- **MapKit**: Apple純正地図エンジン
- **CoreLocation**: 位置情報サービス
- **CryptoKit**: 暗号化・セキュリティ
- **Combine**: リアクティブプログラミング
- **Swift**: バージョン 5.0
- **iOS Deployment Target**: 18.0
- **Xcode**: 15.4+

## バックエンド (Supabase)
- **PostgreSQL + PostGIS**: 空間データベース
- **Supabase Auth**: JWT認証・OAuth
- **Supabase Realtime**: WebSocketリアルタイム通信
- **Supabase Storage**: ファイルストレージ
- **Edge Functions**: サーバーレス関数 (Deno)

## アーキテクチャ
- **MVVM + Clean Architecture**
  - SwiftUI時代に適した設計
  - ViewModel による状態管理
  - UseCase でビジネスロジック分離
  - Repository パターンでデータ層抽象化
- **Kiro-style Spec Driven Development**
  - 仕様駆動開発フレームワーク
  - フェーズ別承認ワークフロー

## 開発・運用
- **Swift Package Manager**: 依存関係管理
- **GitHub Actions**: CI/CD パイプライン (予定)
- **Fastlane**: 自動デプロイ (未設定)
- **SwiftLint**: コード品質管理 (設定済み)

## 依存ライブラリ
- Supabase Swift SDK
- その他のパッケージは Swift Package Manager で管理