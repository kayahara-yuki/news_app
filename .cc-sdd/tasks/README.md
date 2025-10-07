# タスク管理

このディレクトリはcc-sddで生成されたタスクを管理します。

## タスクのライフサイクル

```
Todo → In Progress → In Review → Done
```

## ステータス定義

- **Todo**: 未着手のタスク
- **In Progress**: 作業中のタスク
- **In Review**: レビュー待ちのタスク
- **Done**: 完了したタスク

## タスク命名規則

タスクファイルは以下の形式で命名します:
```
TASK-[番号]-[簡潔な説明].md
```

例:
- `TASK-001-setup-project.md`
- `TASK-002-implement-news-list.md`
- `TASK-003-add-user-authentication.md`

## Vibe Kanban連携

このディレクトリのタスクファイルはVibe Kanbanで自動的に読み込まれ、
カンバンボード上で管理できます。

タスクのステータスを更新すると、自動的にボード上の位置が変更されます。
