# cc-sdd プロジェクト管理

このディレクトリはcc-sdd（Spec-Driven Development）を使用したプロジェクト管理のためのものです。

## ディレクトリ構造

```
.cc-sdd/
├── config.json          # プロジェクト設定
├── features/            # 機能定義
├── specs/               # 仕様書
├── tasks/               # タスク定義
└── docs/                # 生成ドキュメント
```

## ワークフロー

1. **steering** - プロジェクト理解
2. **spec-init** - 機能初期化
3. **spec-requirements** - 要件定義
4. **spec-design** - 設計
5. **spec-tasks** - タスク分解
6. **spec-impl** - 実装

## 使用可能なコマンド

- `/kiro:steering` - プロジェクト理解フェーズ
- `/kiro:spec-init [機能名]` - 新機能の初期化
- `/kiro:spec-requirements` - 要件定義
- `/kiro:spec-design` - 設計フェーズ
- `/kiro:spec-tasks` - タスク分解
- `/kiro:spec-impl` - 実装フェーズ
- `/kiro:spec-status` - 進捗確認

## Vibe Kanban 連携

このプロジェクトはVibe Kanbanと連携して、タスクをカンバン形式で管理します。

起動コマンド:
```bash
PORT=3000 npx vibe-kanban
```
