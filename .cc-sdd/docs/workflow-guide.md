# cc-sdd + Vibe Kanban ワークフローガイド

## 概要

このプロジェクトでは、**cc-sdd（Spec-Driven Development）** と **Vibe Kanban** を組み合わせて、
効率的なタスク管理と開発プロセスを実現しています。

## 開発ワークフロー

### 1. Steering（プロジェクト理解）

**目的**: プロジェクトの全体像を理解する

**実行方法**:
```bash
# Gemini CLI の場合
/kiro:steering

# Claude Code の場合
/kiro:steering
```

**成果物**:
- プロジェクト概要ドキュメント
- 技術スタックの理解
- 開発方針の策定

### 2. Spec Init（機能初期化）

**目的**: 新機能の概要を定義する

**実行方法**:
```bash
/kiro:spec-init [機能の説明]

# 例
/kiro:spec-init ニュース一覧表示機能
```

**成果物**:
- 機能定義ファイル（`.cc-sdd/features/`）
- ユーザーストーリー
- 基本的な受け入れ基準

### 3. Spec Requirements（要件定義）

**目的**: 詳細な要件を定義する

**実行方法**:
```bash
/kiro:spec-requirements
```

**成果物**:
- 詳細な要件定義書
- 機能要件・非機能要件
- 制約条件

### 4. Spec Design（設計）

**目的**: 技術設計を行う

**実行方法**:
```bash
/kiro:spec-design
```

**成果物**:
- アーキテクチャ設計
- データモデル設計
- API設計
- UI/UX設計

### 5. Spec Tasks（タスク分解）

**目的**: 実装可能な単位にタスクを分解する

**実行方法**:
```bash
/kiro:spec-tasks
```

**成果物**:
- タスク定義ファイル（`.cc-sdd/tasks/TASK-XXX-*.md`）
- 各タスクの受け入れ基準
- タスク間の依存関係

### 6. Spec Impl（実装）

**目的**: タスクを実装する

**実行方法**:
```bash
/kiro:spec-impl
```

**プロセス**:
1. Vibe Kanbanでタスクを「In Progress」に移動
2. 実装作業
3. テスト実施
4. 「In Review」に移動
5. レビュー後「Done」に移動

## Vibe Kanban の使い方

### 起動方法

```bash
# 方法1: npmスクリプト
npm run kanban

# 方法2: 直接実行
PORT=3000 npx vibe-kanban

# 方法3: 別ポートで起動
npm run kanban:dev  # PORT=3001
```

### タスク管理

#### タスクの作成
1. `.cc-sdd/tasks/` に新しいMarkdownファイルを作成
2. テンプレート（`task-template.md`）を使用
3. タスクID、タイトル、受け入れ基準などを記入

#### タスクステータスの更新
タスクファイル内の **ステータス** フィールドを更新:
- `Todo` - 未着手
- `In Progress` - 作業中
- `In Review` - レビュー待ち
- `Done` - 完了

Vibe Kanbanが自動的にステータス変更を反映します。

### カンバンボードの列

| 列名 | 説明 | ステータス値 |
|-----|------|-------------|
| **Todo** | 未着手のタスク | `Todo` |
| **In Progress** | 作業中のタスク | `In Progress` |
| **In Review** | レビュー待ち | `In Review` |
| **Done** | 完了したタスク | `Done` |

## ベストプラクティス

### 1. 各フェーズで人間の承認を得る
- AI生成の仕様やタスクは必ず人間がレビュー
- 承認後に次のフェーズへ進む

### 2. タスクは小さく分割する
- 1タスク = 2〜8時間程度
- 大きすぎるタスクは分割

### 3. 受け入れ基準を明確にする
- 各タスクに具体的な受け入れ基準を記載
- チェックボックス形式で管理

### 4. ドキュメントを更新し続ける
- 実装後も仕様書を最新に保つ
- 変更履歴を記録

### 5. 依存関係を明確にする
- タスク間の依存関係を記載
- 並行実行可能かを明示

## トラブルシューティング

### Vibe Kanbanが起動しない
```bash
# Node.jsバージョン確認
node --version  # 18.0.0以上が必要

# ポートが使用中の場合
PORT=3001 npx vibe-kanban
```

### タスクが表示されない
- タスクファイルの命名規則を確認（`TASK-*.md`）
- `.cc-sdd/tasks/` ディレクトリにあるか確認
- Markdownの形式が正しいか確認

### cc-sddコマンドが見つからない
```bash
# 再インストール
npx cc-sdd@latest --lang ja
```

## 参考リンク

- [cc-sdd 公式ドキュメント](https://github.com/tomada/cc-sdd)
- [Vibe Kanban](https://github.com/vibe-kanban/vibe-kanban)
- プロジェクトREADME: [.cc-sdd/README.md](.cc-sdd/README.md)

---

**作成日**: 2025-10-07
**最終更新**: 2025-10-07
**バージョン**: 1.0.0
