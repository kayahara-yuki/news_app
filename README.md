# 位置情報ベースニュース共有SNSプラットフォーム

地図をメインUIとした位置情報ベースのニュース共有・SNSプラットフォームです。災害時にもどこで何が起きているかがわかりやすく、リンク投稿によってニュースの発生場所を可視化できます。

## 🚀 プロジェクト概要

- **プラットフォーム**: iOS (SwiftUI)
- **バックエンド**: Supabase
- **地図**: MapKit
- **アーキテクチャ**: MVVM + Clean Architecture
- **特徴**: Liquid Glass エフェクト、リアルタイム更新、災害時対応

## 📱 主な機能

### 🗺️ 地図ベースUI
- MapKit を使用したネイティブ地図表示
- 投稿位置のアノテーション・クラスタリング
- 緊急事態・避難所情報の表示

### 📰 ニュース共有
- URL リンク投稿による位置情報付きニュース
- メタデータ自動取得
- カテゴリ別投稿分類

### 🌐 SNS機能
- ユーザーフォロー・フォロワー
- いいね・コメント・リアクション
- リアルタイム通知

### 🚨 災害時対応
- 緊急モード自動切り替え
- 避難所情報・安否確認
- 公式機関情報の優先表示

### 🔒 プライバシー保護
- 位置情報の段階的精度設定
- データ暗号化・匿名化
- 緊急時オーバーライド

## 🏗️ プロジェクト構造

```
news_sns/
├── ios-app/                          # iOS アプリ
│   ├── LocationNewsSNS.xcodeproj/    # Xcode プロジェクト
│   ├── LocationNewsSNS/              # アプリソースコード
│   │   ├── Configuration/            # 設定・依存性注入
│   │   ├── Models/                   # データモデル
│   │   ├── Services/                 # ビジネスロジック
│   │   ├── Views/                    # SwiftUI ビュー
│   │   └── Resources/                # アセット・設定ファイル
│   ├── fastlane/                     # 自動デプロイ設定
│   └── Package.swift                 # Swift Package Manager
├── .kiro/specs/                      # Kiro 仕様書
│   └── location-news-sns/
│       ├── spec.md                   # プロジェクト仕様
│       ├── requirements.md           # 要件定義
│       ├── design.md                 # 設計書
│       └── tasks.md                  # タスク分解
├── .github/workflows/                # CI/CD パイプライン
└── docs/                            # ドキュメント
```

## 🛠️ 技術スタック

### フロントエンド (iOS)
- **SwiftUI**: iOS 18+ ネイティブUI
- **MapKit**: Apple純正地図エンジン
- **CoreLocation**: 位置情報サービス
- **CryptoKit**: 暗号化・セキュリティ
- **Combine**: リアクティブプログラミング

### バックエンド (Supabase)
- **PostgreSQL + PostGIS**: 空間データベース
- **Supabase Auth**: JWT認証・OAuth
- **Supabase Realtime**: WebSocketリアルタイム通信
- **Supabase Storage**: ファイルストレージ
- **Edge Functions**: サーバーレス関数 (Deno)

### 開発・運用
- **Xcode 15.4+**: iOS開発環境
- **Swift Package Manager**: 依存関係管理
- **GitHub Actions**: CI/CD パイプライン
- **Fastlane**: 自動デプロイ
- **SwiftLint**: コード品質管理

## 🚀 セットアップ手順

### 1. 前提条件
```bash
# 必要なソフトウェア
- Xcode 15.4 以上
- iOS 18.0 以上のシミュレータ/デバイス
- Node.js 18+ (Edge Functions開発用)
```

### 2. リポジトリクローン
```bash
git clone https://github.com/your-org/location-news-sns.git
cd location-news-sns
```

### 3. Supabase設定
```bash
# Supabaseプロジェクト作成 (https://supabase.com)
# 設定ファイルの更新
# ios-app/LocationNewsSNS/Configuration/SupabaseConfig.swift

private let supabaseURL = "YOUR_SUPABASE_URL"
private let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
```

### 4. iOSアプリビルド
```bash
cd ios-app
# Xcodeでプロジェクトを開く
open LocationNewsSNS.xcodeproj

# または コマンドラインでビルド
xcodebuild -project LocationNewsSNS.xcodeproj -scheme LocationNewsSNS build
```

### 5. データベース設定
Supabaseダッシュボードで以下のテーブルを作成:
- `users` - ユーザープロフィール
- `posts` - 投稿データ
- `emergency_events` - 緊急事態情報
- `shelters` - 避難所情報

詳細なスキーマは `design.md` を参照。

## 🧪 テスト実行

```bash
# ユニットテスト実行
cd ios-app
xcodebuild test -project LocationNewsSNS.xcodeproj -scheme LocationNewsSNS -destination 'platform=iOS Simulator,name=iPhone 15'

# SwiftLint実行
swiftlint --config .swiftlint.yml

# Fastlaneでのテスト
fastlane test
```

## 🚀 デプロイ

### TestFlight (ベータ版)
```bash
cd ios-app
fastlane deploy_testflight
```

### App Store (本番)
```bash
cd ios-app
fastlane deploy_appstore
```

## 📋 開発フロー

1. **Issue作成**: 機能追加・バグ修正のIssue作成
2. **ブランチ作成**: `feature/機能名` または `bugfix/バグ名`
3. **開発**: Kiro仕様に基づく開発
4. **テスト**: 自動テスト・手動テスト実行
5. **PR作成**: メインブランチへのプルリクエスト
6. **レビュー**: コードレビュー・承認
7. **マージ**: 自動CI/CDによるデプロイ

## 📖 ドキュメント

- [要件定義書](.kiro/specs/location-news-sns/requirements.md)
- [設計書](.kiro/specs/location-news-sns/design.md)
- [タスク分解](.kiro/specs/location-news-sns/tasks.md)
- [API仕様書](docs/api-specification.md)

## 🤝 コントリビューション

1. このリポジトリをフォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/AmazingFeature`)
3. 変更をコミット (`git commit -m 'Add some AmazingFeature'`)
4. ブランチにプッシュ (`git push origin feature/AmazingFeature`)
5. プルリクエストを作成

## 📝 ライセンス

このプロジェクトは MIT License の下で公開されています。詳細は [LICENSE](LICENSE) ファイルを参照してください。

## 📞 お問い合わせ

- プロジェクト管理者: [@your-username](https://github.com/your-username)
- プロジェクトリンク: [https://github.com/your-org/location-news-sns](https://github.com/your-org/location-news-sns)

## 🙏 謝辞

- [Supabase](https://supabase.com) - バックエンドサービス
- [Apple MapKit](https://developer.apple.com/mapkit/) - 地図エンジン
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UIフレームワーク
- [Kiro SDD](https://github.com/kiro-framework) - 仕様駆動開発フレームワーク