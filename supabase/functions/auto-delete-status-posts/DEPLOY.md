# Edge Functionのデプロイ手順

## 方法1: Supabase Dashboard（推奨）

### 手順

1. **Supabase Dashboardにアクセス**
   - https://app.supabase.com/project/ikjxfoyfeliiovbwelyx にアクセス
   - プロジェクトを選択

2. **Edge Functionsセクションに移動**
   - 左サイドバーから「Edge Functions」をクリック

3. **新しいFunctionを作成**
   - 「Create a new function」をクリック
   - Function名: `auto-delete-status-posts`
   - テンプレート: Blank

4. **コードをコピー&ペースト**
   - `supabase/functions/auto-delete-status-posts/index.ts` の内容をコピー
   - エディタに貼り付け
   - 「Deploy」をクリック

5. **環境変数の確認**
   - `SUPABASE_URL` と `SUPABASE_SERVICE_ROLE_KEY` は自動的に設定されます

6. **動作確認**
   - 「Invoke function」ボタンをクリック
   - レスポンスを確認

## 方法2: Supabase CLI（ローカル開発推奨）

### 前提条件

- Supabase CLIがインストール済み
- プロジェクトがリンク済み

### 手順

```bash
# プロジェクトルートで実行
cd /Users/zeroplus-shere2/Downloads/news_sns

# Edge Functionをデプロイ
supabase functions deploy auto-delete-status-posts --project-ref ikjxfoyfeliiovbwelyx

# 動作確認
supabase functions invoke auto-delete-status-posts --project-ref ikjxfoyfeliiovbwelyx
```

## 方法3: 手動テスト（curlコマンド）

デプロイ後、以下のコマンドで動作確認できます:

```bash
curl -i --location --request POST \
  'https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json'
```

期待されるレスポンス:

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

## Cron設定（自動実行）

### 方法A: Supabase Dashboard

1. Database → Cron Jobs → Create a new cron job
2. 設定:
   - Name: `auto-delete-status-posts-hourly`
   - Schedule: `0 * * * *` (毎時00分)
   - SQL Command:
     ```sql
     SELECT
       net.http_post(
         url:='https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts',
         headers:='{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY", "Content-Type": "application/json"}'::jsonb
       ) as request_id;
     ```

### 方法B: SQL Editorで直接実行

```sql
-- pg_cron拡張を有効化（Supabaseでは既に有効な場合が多い）
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Cron jobを作成
SELECT cron.schedule(
  'auto-delete-status-posts-hourly',
  '0 * * * *', -- 毎時00分
  $$
  SELECT
    net.http_post(
      url:='https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts',
      headers:='{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY", "Content-Type": "application/json"}'::jsonb
    ) as request_id;
  $$
);

-- Cron jobの確認
SELECT * FROM cron.job;

-- Cron jobの実行履歴確認
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 10;
```

### 注意事項

- `YOUR_SERVICE_ROLE_KEY` は実際のサービスロールキーに置き換えてください
- Supabase無料プランではCron機能が制限される場合があります
- 代替案として、GitHub ActionsやVercel Cronなど外部サービスからEdge Functionを定期実行することも可能です

## トラブルシューティング

### デプロイエラー

- **設定ファイルエラー**: `supabase/config.toml` が正しく設定されているか確認
- **認証エラー**: `supabase login` でログインしているか確認
- **プロジェクトリンクエラー**: `supabase link --project-ref ikjxfoyfeliiovbwelyx` でリンクしているか確認

### 実行エラー

- **403 Forbidden**: Authorization headerが正しく設定されているか確認
- **500 Internal Server Error**: Edge Functionのログを確認（Dashboard → Edge Functions → Logs）
- **タイムアウト**: 大量の期限切れ投稿がある場合、処理時間が長くなる可能性があります

### デバッグ方法

1. **ログの確認**:
   - Dashboard → Edge Functions → auto-delete-status-posts → Logs
   - `console.log` と `console.error` の出力を確認

2. **手動テストデータの作成**:
   - `supabase/functions/auto-delete-status-posts/test_data.sql` を実行
   - Edge Functionを手動実行
   - 削除結果を確認

3. **ローカルでの実行**:
   ```bash
   # ローカル環境でEdge Functionを起動
   supabase functions serve auto-delete-status-posts

   # 別ターミナルで実行
   curl -i --location --request POST 'http://localhost:54321/functions/v1/auto-delete-status-posts' \
     --header 'Authorization: Bearer YOUR_ANON_KEY' \
     --header 'Content-Type: application/json'
   ```

## セキュリティチェックリスト

- [ ] Service Role Keyは環境変数で管理（ハードコードしない）
- [ ] Anon Keyは公開されても問題ない（RLSで保護）
- [ ] Edge FunctionはHTTPSでのみアクセス可能
- [ ] Cron jobのSQL内でService Role Keyを使用（RLSバイパス）
- [ ] 削除ログを定期的に確認

## デプロイチェックリスト

- [ ] `index.ts` のコードレビュー完了
- [ ] テストデータで動作確認済み
- [ ] エラーハンドリングの確認
- [ ] ログ出力の確認
- [ ] Cron設定の確認
- [ ] 本番環境での動作確認
- [ ] ロールバック手順の確認
