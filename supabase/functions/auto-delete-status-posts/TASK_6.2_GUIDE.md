# タスク6.2 実装ガイド

## 概要

Edge Functionのデプロイと定期実行設定（Cronトリガー）を行います。

## 前提条件

- ✅ タスク6.1完了（Edge Function実装済み）
- ✅ Edge FunctionがSupabaseにデプロイ済み
- ⏳ テストデータの作成が必要
- ⏳ Cron設定が必要

## 実装手順

### ステップ1: テストデータの作成と動作確認

#### 1.1 Supabase SQL Editorにアクセス

1. https://app.supabase.com/project/ikjxfoyfeliiovbwelyx にアクセス
2. 左サイドバーから「SQL Editor」をクリック
3. 「New query」をクリック

#### 1.2 テストデータの作成

`quick_test.sql` の内容をコピーして実行:

```sql
-- quick_test.sqlの内容をコピー&ペースト
```

**期待される結果:**
- 期限切れステータス投稿: 2件
- 有効なステータス投稿: 1件
- 通常投稿: 1件

#### 1.3 Edge Functionの手動実行

ターミナルで以下のコマンドを実行:

```bash
curl -i --location --request POST \
  'https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts' \
  --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTI5NDUsImV4cCI6MjA3NTU4ODk0NX0.E61qFPidet3gHJpqaBLeih2atXqx5LDc9zv5onEeM30' \
  --header 'Content-Type: application/json'
```

**期待されるレスポンス:**

```json
{
  "success": true,
  "result": {
    "deletedPosts": 2,
    "deletedLikes": 0,
    "deletedComments": 0,
    "deletedAudioFiles": 1,
    "errors": []
  },
  "message": "Successfully deleted 2 expired status posts"
}
```

#### 1.4 削除結果の確認

Supabase SQL Editorで `test_verification.sql` を実行:

```sql
-- test_verification.sqlの内容をコピー&ペースト
```

**期待される結果:**
- ✓ 期限切れステータス投稿数: 0
- ✓ 有効なステータス投稿数: 1
- ✓ 通常投稿数: 1
- ✓ 孤立したいいね数: 0
- ✓ 孤立したコメント数: 0

---

### ステップ2: Cron設定（定期実行）

#### 方法A: Supabase Dashboard（推奨）

1. https://app.supabase.com/project/ikjxfoyfeliiovbwelyx にアクセス
2. 左サイドバーから「Database」→「Cron Jobs」をクリック
3. 「Create a new cron job」をクリック
4. 以下を設定:
   - **Name**: `auto-delete-status-posts-hourly`
   - **Schedule**: `0 * * * *` (毎時00分)
   - **SQL Command**:
     ```sql
     SELECT
       net.http_post(
         url:='https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts',
         headers:='{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlranhmb3lmZWxpaW92YndlbHl4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDAxMjk0NSwiZXhwIjoyMDc1NTg4OTQ1fQ.9HS9-3V5jMUtnkIbIuBDZdz1kDX7eXfuETO4ATGzhhc", "Content-Type": "application/json"}'::jsonb
       ) as request_id;
     ```
5. 「Create」をクリック

#### 方法B: SQL Editorで直接設定

Supabase SQL Editorで `setup_cron.sql` を実行:

```sql
-- setup_cron.sqlの内容をコピー&ペースト
```

#### Cron設定の確認

SQL Editorで以下を実行:

```sql
SELECT
    jobid,
    jobname,
    schedule,
    active,
    database
FROM cron.job
WHERE jobname = 'auto-delete-status-posts-hourly';
```

**期待される結果:**
```
jobid | jobname                          | schedule   | active | database
------|----------------------------------|------------|--------|----------
1     | auto-delete-status-posts-hourly  | 0 * * * *  | true   | postgres
```

#### Cron実行履歴の確認

```sql
SELECT
    runid,
    jobid,
    status,
    return_message,
    start_time,
    end_time
FROM cron.job_run_details
WHERE jobid = (
    SELECT jobid FROM cron.job WHERE jobname = 'auto-delete-status-posts-hourly'
)
ORDER BY start_time DESC
LIMIT 10;
```

---

### ステップ3: 本番環境での動作確認

#### 3.1 実際のステータス投稿で確認

1. iOSアプリでステータス投稿を作成
2. Supabase SQL Editorで `expires_at` を過去に設定:
   ```sql
   UPDATE posts
   SET expires_at = NOW() - INTERVAL '1 hour'
   WHERE id = 'YOUR_POST_ID';
   ```
3. 次のCron実行（毎時00分）を待つ、または手動実行
4. 投稿が削除されたことを確認

#### 3.2 Edge Functionログの確認

1. https://app.supabase.com/project/ikjxfoyfeliiovbwelyx にアクセス
2. 左サイドバーから「Edge Functions」をクリック
3. `auto-delete-status-posts` をクリック
4. 「Logs」タブをクリック
5. 実行ログを確認:
   ```
   [auto-delete-status-posts] Function started
   [auto-delete-status-posts] Fetching expired status posts...
   [auto-delete-status-posts] Found 2 expired posts
   [auto-delete-status-posts] Processing post abc-123 (☕ カフェなう)
   [auto-delete-status-posts] Deleting audio file: https://...
   [auto-delete-status-posts] Audio file deleted: user_id/filename.m4a
   [auto-delete-status-posts] Deleted 0 likes for post abc-123
   [auto-delete-status-posts] Deleted 0 comments for post abc-123
   [auto-delete-status-posts] Post abc-123 deleted successfully
   [auto-delete-status-posts] Deletion completed:
     - Deleted posts: 2
     - Deleted likes: 0
     - Deleted comments: 0
     - Deleted audio files: 1
     - Errors: 0
   ```

---

## トラブルシューティング

### Cronジョブが実行されない

**原因1: pg_cron拡張が無効**
```sql
-- pg_cron拡張を確認
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- 結果が空の場合は有効化
CREATE EXTENSION pg_cron;
```

**原因2: Supabase無料プランの制限**

無料プランではpg_cronが利用できない場合があります。代替案:
- GitHub Actionsで定期実行（推奨）
- Vercel Cronで定期実行
- 外部Cronサービス（cron-job.org等）

### Edge Functionがエラーを返す

**エラー: 403 Forbidden**
- Authorization headerが正しく設定されているか確認
- Service Role Keyを使用しているか確認

**エラー: 500 Internal Server Error**
- Edge Functionのログを確認（Dashboard → Edge Functions → Logs）
- Supabaseクライアントの初期化が正しいか確認

### 投稿が削除されない

**原因: expires_atが未来の時刻**
```sql
-- 期限切れ投稿を確認
SELECT id, content, expires_at
FROM posts
WHERE is_status_post = true
  AND expires_at < NOW();
```

**原因: is_status_postがfalse**
```sql
-- ステータス投稿フラグを確認
SELECT id, content, is_status_post, expires_at
FROM posts
WHERE expires_at < NOW();
```

---

## 完了確認チェックリスト

- [ ] テストデータを作成し、Edge Functionを手動実行して削除成功
- [ ] 検証クエリで削除結果を確認（期待値と一致）
- [ ] Cron設定を完了（Dashboard or SQL Editor）
- [ ] Cronジョブが登録されていることを確認（`cron.job`テーブル）
- [ ] Edge Functionのログで正常実行を確認
- [ ] 実際のステータス投稿で動作確認
- [ ] tasks.mdのタスク6.2を完了とマーク

---

## 次のステップ

タスク6.2完了後、以下を確認してください:

1. **自動削除の動作確認**
   - 次のCron実行時刻（毎時00分）まで待機
   - Cron実行履歴を確認
   - Edge Functionログを確認

2. **誤削除が発生しないことの確認**
   - 有効なステータス投稿が残っていることを確認
   - 通常投稿が削除されていないことを確認

3. **パフォーマンスの確認**
   - 大量の期限切れ投稿がある場合の実行時間を測定
   - タイムアウトが発生しないか確認

4. **タスク6.3（手動削除機能）の実装**
   - ユーザーが手動でステータス投稿を削除した際の処理
   - 音声ファイルと関連データの即座削除

---

## 参考資料

- [DEPLOY.md](DEPLOY.md) - デプロイ手順詳細
- [README.md](README.md) - 使用方法・トラブルシューティング
- [test_verification.sql](test_verification.sql) - 検証クエリ
- [quick_test.sql](quick_test.sql) - クイックテスト用SQL
- [setup_cron.sql](setup_cron.sql) - Cron設定SQL
