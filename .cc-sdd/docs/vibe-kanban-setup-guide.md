# Vibe Kanban セットアップガイド

## 現在の状況

✅ Vibe Kanban MCPサーバーが登録されました
✅ タスクリストファイルが作成されました（`.cc-sdd/tasks/all-tasks.md`）
⏳ Vibe KanbanのGUIでプロジェクトを作成する必要があります

## 次のステップ

### 1. Vibe Kanbanを起動（既に起動済み）

```bash
PORT=3000 npx vibe-kanban
```

ブラウザで `http://localhost:3000` を開く

### 2. GitHubリポジトリと連携

Vibe KanbanのGUIで：
1. GitHubアカウントと連携
2. 免責事項に同意
3. 標準エージェント（Claude Code）とエディタを選択

### 3. プロジェクトを作成

Vibe KanbanのGUI上で：
1. **Create Project** → **From Git Repository** を選択
2. プロジェクト名: `news_sns`
3. リポジトリを選択（またはローカルパスを指定）

### 4. MCP経由でタスクを登録

Claude Codeに以下を依頼します：

```
.cc-sdd/tasks/all-tasks.md のタスクをvibe_kanbanの「news_sns」プロジェクトに以下のルールを守って登録してください：

- タスクは降順で登録する（T008からT001）
- 各タスクの登録時は日本語訳も下部に記載
- 各タスクの想定時間を下部に記載
- Parallel実行できるタスクは、マーカーとして通番の後に[P]を付与
- 完了済みタスク（T001, T002）はDoneステータスで登録
- 依存関係がある場合は明記
```

### 5. MCPツールを使用した登録方法

Vibe Kanban MCPサーバーが提供するツール：
- `vibe_kanban_create_task` - タスクを作成
- `vibe_kanban_list_tasks` - タスク一覧を取得
- `vibe_kanban_update_task` - タスクを更新
- `vibe_kanban_list_projects` - プロジェクト一覧を取得

### 6. 手動登録の場合

Vibe KanbanのGUIから手動でタスクを登録することもできます：

1. プロジェクトページを開く
2. 「Add Task」ボタンをクリック
3. タスク情報を入力：
   - Title: `T003: ニュース一覧画面の実装`
   - Description: 受け入れ基準と実装詳細
   - Estimated Time: 4時間
   - Status: Todo

## タスクリスト概要

| タスクID | タイトル | 想定時間 | 並列実行 | 依存 | ステータス |
|---------|---------|---------|---------|------|-----------|
| T001 | cc-sdd環境のセットアップ | 2時間 | × | - | Done |
| T002 | Vibe Kanbanのセットアップ | 1.5時間 | × | - | Done |
| T003 | ニュース一覧画面の実装 | 4時間 | × | T001, T002 | Todo |
| T004 | ニュース詳細画面の実装 | 3時間 | × | T003 | Todo |
| T005[P] | NewsArticleモデルの作成 | 0.5時間 | ○ | - | Todo |
| T006[P] | NewsAPIServiceの作成 | 1時間 | ○ | - | Todo |
| T007 | ユーザー認証機能の設計 | 2時間 | × | - | Todo |
| T008 | ログイン画面の実装 | 3時間 | × | T007 | Todo |

## トラブルシューティング

### Vibe Kanbanに接続できない

MCPサーバーの接続を確認：
```bash
claude mcp list
```

### タスクが表示されない

1. プロジェクトが正しく作成されているか確認
2. GitHubリポジトリが正しく連携されているか確認
3. ページをリロード

### MCPツールが見つからない

Claude Codeを再起動してMCP設定を再読み込み

## 参考

- [元記事: Spec KitのタスクリストをVibe Kanbanでカンバン管理する](https://zenn.dev/watany/articles/78a06904f681dd)
- タスクリスト: [.cc-sdd/tasks/all-tasks.md](../tasks/all-tasks.md)
- 個別タスク: `.cc-sdd/tasks/TASK-*.md`

---

**作成日**: 2025-10-07
**最終更新**: 2025-10-07
