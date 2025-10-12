# iOS/SwiftUI 開発ワークフロー - MCP ツール活用ガイド

## プロジェクト概要

このプロジェクトは、SwiftUI を使用した iOS ニュース SNS アプリの開発です。Context7、Serena、Cipher を活用して効率的な開発を行います。

## セットアップ確認

### インストール済みツール

- ✅ Context7: SwiftUI/iOS 最新ドキュメント取得
- ✅ Serena: Swift コード解析（SourceKit-LSP 対応）
- ✅ Cipher: iOS 開発パターンの学習・蓄積

### プロジェクト設定

- Swift 5.9 対応
- iOS 15.0 以上をターゲット
- MVVM アーキテクチャ
- Core Data（データ永続化）
- Combine（リアクティブプログラミング）

## iOS 開発特化ワークフロー

### 1. 新機能実装フロー

```bash
# Step 1: SwiftUIの最新機能を確認
claude "SwiftUI iOS 17の新機能Navigation APIについて詳しく教えて。use context7"

# Step 2: 現在のプロジェクト構造を解析
claude "現在のSwiftUIプロジェクトでNavigationStackを実装するのに最適な場所を提案して"

# Step 3: アーキテクチャに沿った実装
claude "MVVMパターンに従ってNavigationStackを使ったView階層を実装して"

# Step 4: 実装パターンを学習
claude "今回のNavigationStack実装パターンをiOS開発のベストプラクティスとして記憶して"
```

### 2. UI/UX 改善ワークフロー

```bash
# Step 1: Human Interface Guidelinesの確認
claude "iOS Human Interface GuidelinesのNavigation最新ガイドラインを教えて。use context7"

# Step 2: 現在のUI実装を解析
claude "現在のUIコンポーネントがHIGに準拠しているかチェックして"

# Step 3: 改善実装
claude "HIGに準拠したNavigationBarとTabViewの実装に修正して"

# Step 4: UIパターンの蓄積
claude "HIGに準拠したUI実装パターンを記憶して、今後のUI実装時に参照できるようにして"
```

### 3. パフォーマンス最適化ワークフロー

```bash
# Step 1: SwiftUIパフォーマンスベストプラクティス確認
claude "SwiftUI iOS 17のパフォーマンス最適化テクニックを教えて。use context7"

# Step 2: 現在のコードのパフォーマンス分析
claude "現在のSwiftUIビューでパフォーマンスボトルネックになりそうな箇所を特定して"

# Step 3: 最適化実装
claude "特定された箇所を@StateObject、@ObservedObject、@EnvironmentObjectを適切に使い分けて最適化して"

# Step 4: 最適化パターンの学習
claude "今回の最適化手法をパフォーマンスベストプラクティスとして記憶して"
```

## SwiftUI 特化プロンプト例

### View 実装

```bash
# カスタムビューコンポーネント作成
claude "再利用可能なNewsCardViewコンポーネントをSwiftUIで作成。title、content、imageURL、publishedDateを表示し、タップアクションに対応。iOS 15対応でアクセシビリティも考慮して"

# アニメーション実装
claude "NewsCardViewにスムーズなフェードイン・フェードアウトアニメーションを追加。iOS 17のspring animationを使用して"
```

### データ管理

```bash
# Core Data実装
claude "ニュース記事を保存するためのCore DataのNewsArticleエンティティを設計。title、content、imageURL、publishedDate、isFavoriteフィールドを含む。SwiftUIのFetchRequestと連携"

# ViewModel実装
claude "NewsListViewModelをCombineを使って実装。APIからニュースを取得、Core Dataに保存、フィルタリング機能を含む。MVVM準拠"
```

### ネットワーキング

```bash
# APIクライアント実装
claude "ニュースAPIクライアントをasync/awaitパターンで実装。エラーハンドリング、キャッシング、リトライ機能を含む。iOS 15のURLSessionを活用"
```

## 実践的な使用例

### プロジェクト初期セットアップ

```bash
# 1. プロジェクト構造の設計
claude "SwiftUIでニュースSNSアプリのプロジェクト構造を提案。MVVM、Clean Architecture、フォルダ構成を含む"

# 2. 基本アーキテクチャの実装
claude "提案されたアーキテクチャに基づいてApp.swift、ContentView.swift、基本的なViewModelを実装"

# 3. 設計決定の記録
claude "採用したアーキテクチャの理由と実装方針をプロジェクトドキュメントとして記憶"
```

### UI 実装セッション

```bash
# 1. デザインシステムの構築
claude "iOS Human Interface Guidelinesに準拠したカラーパレット、タイポグラフィ、コンポーネントライブラリを設計"

# 2. メイン画面の実装
claude "ニュースフィード画面をSwiftUIで実装。LazyVStack、RefreshableModifier、Search機能を含む"

# 3. UIパターンの学習
claude "実装したUIパターンとコンポーネントを再利用可能なテンプレートとして記憶"
```

## トラブルシューティング

### Serena（Swift 解析）の問題

```bash
# SourceKit-LSPの確認
xcrun sourcekit-lsp

# Xcodeプロジェクトの再構築
xcodebuild clean -project *.xcodeproj
xcodebuild build -project *.xcodeproj
```

### Context7（Swift/iOS 情報取得）の活用

```bash
# SwiftUI特化情報取得
claude "SwiftUI iOS 17 NavigationStack best practices。use context7"
claude "Core Data SwiftUI integration patterns。use context7"
claude "iOS Human Interface Guidelines navigation。use context7"
```

### Cipher（iOS 知識蓄積）の活用

```bash
# iOS開発ベストプラクティスの記録
claude "今回実装したSwiftUIのリスト最適化パターンを記憶。LazyVStackとonAppearの組み合わせが効果的だった理由も含めて"

# 過去の実装パターンの参照
claude "以前実装したCore Dataの設定パターンを教えて。同じ問題に遭遇したら参考にしたい"
```

## 開発効率向上のコツ

### 1. SwiftUI 特化の質問パターン

- 「iOS XX 対応で」を必ず付ける
- 「Human Interface Guidelines 準拠で」を意識
- 「アクセシビリティ対応も含めて」を追加

### 2. 段階的開発アプローチ

1. Context7 で最新情報収集
2. Serena で現状分析
3. 実装・テスト
4. Cipher で知識蓄積

### 3. チーム開発での活用

```bash
# チーム共通のiOS開発規約設定
claude "このプロジェクトのSwiftUI開発規約を記憶：
- View階層は最大3レベル
- ViewModelは@MainActorを使用
- Core Dataアクセスは専用Repositoryクラス経由
- カラーとフォントはDesignSystemから使用"
```

## パフォーマンス監視

### Serena のキャッシュ管理

```bash
# 定期的なキャッシュクリア（週1回推奨）
find .serena/cache -type f -delete

# Xcodeキャッシュもクリア
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### Cipher のストレージ最適化

```bash
# ストレージ使用量確認
du -sh .cipher/

# 古い学習データのクリーンアップ
cipher cleanup --days 30
```

## 参考リンク

- [SwiftUI 公式ドキュメント](https://developer.apple.com/documentation/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Core Data プログラミングガイド](https://developer.apple.com/documentation/coredata)
- [Combine フレームワーク](https://developer.apple.com/documentation/combine)
