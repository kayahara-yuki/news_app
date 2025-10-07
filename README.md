# news_sns - ニュースSNSアプリケーション

iOS/macOS向けのニュースSNSアプリケーションです。
**cc-sdd（Spec-Driven Development）** と **Vibe Kanban** を使用した開発管理を採用しています。

## 🚀 プロジェクト概要

- **プラットフォーム**: iOS / macOS
- **言語**: Swift
- **フレームワーク**: SwiftUI
- **開発手法**: cc-sdd（仕様駆動開発）
- **タスク管理**: Vibe Kanban

## 📋 主な機能

- [ ] ニュース一覧表示
- [ ] ニュース詳細表示
- [ ] いいね機能
- [ ] コメント機能
- [ ] ユーザー認証
- [ ] タイムライン

## 🛠 開発環境セットアップ

### 必要な環境

- **Xcode**: 15.0以上
- **Swift**: 5.9以上
- **Node.js**: 18.0以上（Vibe Kanban用）

### cc-sdd のセットアップ

```bash
# cc-sddを初期化（既に完了）
npx cc-sdd@latest --lang ja
```

### Vibe Kanban の起動

```bash
# 方法1: npmスクリプトを使用
npm run kanban

# 方法2: 直接実行
PORT=3000 npx vibe-kanban
```

ブラウザで `http://localhost:3000` を開くと、カンバンボードが表示されます。

## 📁 プロジェクト構造

```
news_sns/
├── .cc-sdd/                    # cc-sdd管理ディレクトリ
│   ├── config.json            # プロジェクト設定
│   ├── features/              # 機能定義
│   ├── specs/                 # 仕様書
│   ├── tasks/                 # タスク定義（Vibe Kanban連携）
│   ├── docs/                  # ドキュメント
│   └── vibe-kanban.config.json # Kanban設定
├── .gemini/commands/kiro/     # Gemini CLI用コマンド
├── .claude/commands/kiro/     # Claude Code用コマンド
├── news_sns/                  # Swiftソースコード
│   ├── news_snsApp.swift
│   ├── ContentView.swift
│   └── Assets.xcassets/
├── package.json               # Node.js設定（Kanban用）
└── README.md                  # このファイル
```

## 🔄 開発ワークフロー

### 1. 機能の初期化

```bash
/kiro:spec-init [機能の説明]
```

### 2. 要件定義

```bash
/kiro:spec-requirements
```

### 3. 設計

```bash
/kiro:spec-design
```

### 4. タスク分解

```bash
/kiro:spec-tasks
```

### 5. 実装

```bash
/kiro:spec-impl
```

### 6. ステータス確認

```bash
/kiro:spec-status
```

詳細は [ワークフローガイド](.cc-sdd/docs/workflow-guide.md) を参照してください。

## 📊 タスク管理

### タスクの構造

各タスクは `.cc-sdd/tasks/TASK-XXX-*.md` 形式で管理されています。

```markdown
# タスクファイルの例
- タスクID: TASK-001
- タイトル: ニュース一覧画面の実装
- ステータス: Todo / In Progress / In Review / Done
- 優先度: High / Medium / Low
- 見積時間: 4時間
```

### カンバンボード

Vibe Kanbanで以下の4つの列でタスクを管理:

1. **Todo** - 未着手
2. **In Progress** - 作業中
3. **In Review** - レビュー待ち
4. **Done** - 完了

## 📝 既存タスク一覧

- ✅ **TASK-001**: cc-sdd環境のセットアップ
- ✅ **TASK-002**: Vibe Kanbanのセットアップ
- 📝 **TASK-003**: ニュース一覧画面の実装
- 📝 **TASK-004**: ニュース詳細画面の実装

## 🧪 テスト

```bash
# Xcodeでテストを実行
# Product > Test (⌘U)
```

## 📚 ドキュメント

- [ワークフローガイド](.cc-sdd/docs/workflow-guide.md) - 開発フローの詳細
- [Steeringドキュメント](.cc-sdd/docs/steering.md) - プロジェクト理解
- [タスク管理ガイド](.cc-sdd/tasks/README.md) - タスク管理の詳細

## 🤝 コントリビューション

1. 新機能は `/kiro:spec-init` から始める
2. タスクは小さく分割（2〜8時間程度）
3. 各フェーズで人間のレビューを実施
4. ドキュメントを常に最新に保つ

## 📄 ライセンス

MIT

## 👤 Author

zeroplus-shere2

---

**作成日**: 2025-10-07
**cc-sdd バージョン**: latest
**開発ステータス**: 🟢 Active
