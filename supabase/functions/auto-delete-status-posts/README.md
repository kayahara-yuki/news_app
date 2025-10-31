# auto-delete-status-posts

ステータス投稿の自動削除機能を実装したSupabase Edge Function。

## 概要

期限切れ（`expires_at < NOW()`）のステータス投稿を定期的に削除する。

### 削除対象
- 期限切れのステータス投稿（`is_status_post = true` AND `expires_at < NOW()`）
- 関連する音声ファイル（Supabase Storage）
- 関連するいいね（likesテーブル）
- 関連するコメント（commentsテーブル）

### 実行頻度
- Cronトリガー: 毎時00分実行（推奨）

## テスト方法

### 1. テストデータの作成

```bash
# Supabase SQL Editorでtest_data.sqlを実行
cat supabase/functions/auto-delete-status-posts/test_data.sql
```

期待されるテストデータ:
- 期限切れステータス投稿（音声あり）: 1件
- 期限切れステータス投稿（音声なし）: 1件
- 有効なステータス投稿: 1件
- 通常投稿: 1件

### 2. Edge Functionのローカル実行

```bash
# Supabase CLIを使用（ローカル環境）
supabase functions serve auto-delete-status-posts --env-file .env.local

# 別のターミナルで実行
curl -i --location --request POST 'http://localhost:54321/functions/v1/auto-delete-status-posts' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json'
```

### 3. デプロイ後のテスト

```bash
# Supabaseにデプロイ
supabase functions deploy auto-delete-status-posts

# 本番環境で実行
curl -i --location --request POST 'https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json'
```

### 4. 検証クエリ

```sql
-- 期限切れステータス投稿が削除されたことを確認
SELECT
    '削除後の期限切れ投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at < NOW()
  AND user_id = '00000000-0000-0000-0000-000000000001';
-- 期待値: 0

-- 有効なステータス投稿が残っていることを確認
SELECT
    '有効なステータス投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at >= NOW()
  AND user_id = '00000000-0000-0000-0000-000000000001';
-- 期待値: 1

-- 通常投稿が残っていることを確認
SELECT
    '通常投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = false
  AND user_id = '00000000-0000-0000-0000-000000000001'
  AND content LIKE '%テスト%';
-- 期待値: 1

-- 孤立したいいね・コメントがないことを確認
SELECT
    '孤立したいいね数' as metric,
    COUNT(*) as count
FROM likes l
LEFT JOIN posts p ON l.post_id = p.id
WHERE p.id IS NULL
  AND l.user_id = '00000000-0000-0000-0000-000000000001';
-- 期待値: 0

SELECT
    '孤立したコメント数' as metric,
    COUNT(*) as count
FROM comments c
LEFT JOIN posts p ON c.post_id = p.id
WHERE p.id IS NULL
  AND c.user_id = '00000000-0000-0000-0000-000000000001';
-- 期待値: 0
```

## レスポンス形式

### 成功時

```json
{
  "success": true,
  "result": {
    "deletedPosts": 2,
    "deletedLikes": 2,
    "deletedComments": 1,
    "deletedAudioFiles": 1,
    "errors": []
  },
  "message": "Successfully deleted 2 expired status posts"
}
```

### 削除対象なし

```json
{
  "success": true,
  "result": {
    "deletedPosts": 0,
    "deletedLikes": 0,
    "deletedComments": 0,
    "deletedAudioFiles": 0,
    "errors": []
  },
  "message": "No expired posts to delete"
}
```

### エラー発生時

```json
{
  "success": false,
  "result": {
    "deletedPosts": 1,
    "deletedLikes": 1,
    "deletedComments": 0,
    "deletedAudioFiles": 0,
    "errors": [
      "Failed to delete comments for post abc-123: permission denied"
    ]
  },
  "message": "Completed with 1 errors"
}
```

## Cronトリガーの設定

Supabase Dashboardで以下のように設定:

1. Database → Cron Jobs → Create a new cron job
2. Schedule: `0 * * * *` (毎時00分)
3. Function: `auto-delete-status-posts`
4. Enabled: ✓

または、SQL で直接設定:

```sql
-- pg_cron拡張を有効化（Supabaseでは既に有効）
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 毎時00分に実行
SELECT cron.schedule(
  'auto-delete-status-posts',
  '0 * * * *',
  $$
  SELECT
    net.http_post(
      url:='https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts',
      headers:='{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY", "Content-Type": "application/json"}'::jsonb
    ) as request_id;
  $$
);
```

## エラーハンドリング

- 音声ファイル削除失敗: ログに記録し、次の投稿処理を継続
- いいね削除失敗: ログに記録し、次の投稿処理を継続
- コメント削除失敗: ログに記録し、次の投稿処理を継続
- 投稿削除失敗: ログに記録し、次の投稿処理を継続
- 致命的エラー: HTTP 500を返し、処理を中断

## ロギング

すべてのログは`console.log`/`console.error`で出力され、Supabase Dashboardの「Logs」タブで確認可能。

ログレベル:
- `[auto-delete-status-posts]`: 情報ログ
- `[auto-delete-status-posts] Error`: エラーログ

## セキュリティ

- サービスロールキーを使用してRLSをバイパス（管理者権限で削除）
- Edge Functionの呼び出しにはAnon KeyまたはService Role Keyが必要
- 外部からの直接呼び出しを防ぐため、Cron経由でのみ実行を推奨

## パフォーマンス

- 期限切れ投稿数に比例して実行時間が増加
- 想定: 100件の期限切れ投稿で約10秒以内
- タイムアウト: Supabase Edge Functionのデフォルト（150秒）

## トラブルシューティング

### 投稿が削除されない

1. Edge Functionのログを確認
2. `expires_at`カラムが正しく設定されているか確認
3. Cronジョブが正しく実行されているか確認（`SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`）

### 音声ファイルが削除されない

1. `audio_url`の形式が正しいか確認
2. Supabase StorageのRLSポリシーを確認（サービスロールキーはRLSをバイパスするはず）
3. ログで`extractAudioPath`の結果を確認

### 関連データ（いいね・コメント）が削除されない

1. 外部キー制約がないため、手動削除が必要
2. ログでエラーメッセージを確認
3. RLSポリシーを確認（サービスロールキーはRLSをバイパスするはず）
