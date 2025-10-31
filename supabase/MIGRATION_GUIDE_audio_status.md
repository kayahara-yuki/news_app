# マイグレーションガイド: 音声投稿とステータス投稿機能

## 概要

このマイグレーションは、`posts`テーブルに音声メッセージ投稿とワンタップステータス共有機能を追加します。

### 追加されるカラム

| カラム名 | データ型 | NULL許可 | デフォルト | 説明 |
|---------|---------|---------|----------|------|
| `audio_url` | TEXT | YES | NULL | Supabase Storage上の音声ファイルURL |
| `is_status_post` | BOOLEAN | NO | FALSE | ステータス投稿フラグ（一時投稿） |
| `expires_at` | TIMESTAMP WITH TIME ZONE | YES | NULL | 自動削除予定日時（ステータス投稿のみ） |

### 追加されるインデックス

- `idx_posts_expires_at`: ステータス投稿の自動削除クエリ用の部分インデックス

---

## マイグレーション適用手順

### 前提条件

- Supabaseプロジェクトへのアクセス権限
- データベースマイグレーション実行権限
- （推奨）本番環境への適用前に開発/ステージング環境でテスト

### Step 1: バックアップの作成（本番環境のみ）

```bash
# Supabaseダッシュボード > Database > Backups からバックアップを作成
# または、pg_dumpでバックアップ
pg_dump -h <your-supabase-host> -U postgres -d postgres -t public.posts > posts_backup.sql
```

### Step 2: マイグレーションファイルの確認

```bash
# マイグレーションファイルの内容を確認
cat supabase/migrations/20250627000000_add_audio_and_status_columns.sql
```

### Step 3: マイグレーションの適用

#### Option A: Supabase CLIを使用（推奨）

```bash
# Supabase CLIでマイグレーション適用
supabase db push

# またはマイグレーションファイルを直接実行
supabase db execute -f supabase/migrations/20250627000000_add_audio_and_status_columns.sql
```

#### Option B: Supabaseダッシュボードから実行

1. Supabaseダッシュボードにログイン
2. `SQL Editor`を開く
3. `supabase/migrations/20250627000000_add_audio_and_status_columns.sql`の内容をコピー&ペースト
4. `Run`ボタンをクリック

#### Option C: psqlから直接実行

```bash
psql -h <your-supabase-host> -U postgres -d postgres -f supabase/migrations/20250627000000_add_audio_and_status_columns.sql
```

### Step 4: マイグレーション検証

マイグレーションファイルには自動検証ロジックが含まれています。実行後、以下のメッセージが表示されることを確認してください：

```
NOTICE:  Migration verification successful: All columns and indexes created
NOTICE:  Existing data compatibility check: X existing posts remain unchanged
```

または手動で検証：

```sql
-- 新しいカラムが追加されたことを確認
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'posts'
  AND column_name IN ('audio_url', 'is_status_post', 'expires_at');

-- インデックスが作成されたことを確認
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'posts'
  AND indexname = 'idx_posts_expires_at';

-- 既存データが影響を受けていないことを確認
SELECT
    COUNT(*) as total_posts,
    COUNT(audio_url) as posts_with_audio,
    COUNT(CASE WHEN is_status_post = true THEN 1 END) as status_posts,
    COUNT(expires_at) as posts_with_expiry
FROM public.posts;
```

期待される結果：
- `total_posts`: 既存の投稿数
- `posts_with_audio`: 0（既存投稿には音声なし）
- `status_posts`: 0（既存投稿はステータス投稿ではない）
- `posts_with_expiry`: 0（既存投稿に有効期限なし）

### Step 5: アプリケーションの動作確認

1. 既存の投稿取得クエリが正常動作することを確認

```sql
-- 既存のクエリ例（近くの投稿取得）
SELECT id, content, latitude, longitude, address, category, created_at,
       audio_url, is_status_post, expires_at
FROM public.posts
WHERE ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(139.7671, 35.6812), 4326)::geography,
    5000
)
ORDER BY created_at DESC
LIMIT 10;
```

2. 新しいカラムが適切にNULL値として返されることを確認

---

## ロールバック手順

問題が発生した場合は、以下の手順でロールバックできます。

### ⚠️ 警告

- **ロールバックは破壊的操作です**
- すべての`audio_url`, `is_status_post`, `expires_at`データが削除されます
- **Supabase Storageの音声ファイルは自動削除されません**（手動削除が必要）

### ロールバック実行

```bash
# Supabase CLIでロールバック
supabase db execute -f supabase/migrations/20250627000000_add_audio_and_status_columns_rollback.sql
```

または、Supabaseダッシュボードから`20250627000000_add_audio_and_status_columns_rollback.sql`を実行。

### ロールバック検証

```sql
-- カラムが削除されたことを確認
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'posts'
  AND column_name IN ('audio_url', 'is_status_post', 'expires_at');
-- 結果が0行であればロールバック成功
```

---

## トラブルシューティング

### エラー: "permission denied for table posts"

**原因**: データベース権限不足

**解決策**:
```sql
-- postgresユーザーで実行
GRANT ALL ON TABLE public.posts TO authenticated;
GRANT ALL ON TABLE public.posts TO service_role;
```

### エラー: "column already exists"

**原因**: マイグレーションが既に適用されている

**解決策**:
```sql
-- 現在のカラムを確認
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'posts';

-- 既に存在する場合は、マイグレーションをスキップ
```

### 既存クエリのパフォーマンス低下

**原因**: 新しいカラム追加による統計情報の古さ

**解決策**:
```sql
-- テーブル統計を更新
ANALYZE public.posts;

-- クエリプランを確認
EXPLAIN ANALYZE
SELECT * FROM public.posts
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(139.7671, 35.6812), 4326)::geography, 5000)
ORDER BY created_at DESC;
```

---

## 次のステップ

マイグレーション完了後、以下のタスクを実行してください：

1. ✅ **タスク1.1完了**: postsテーブルのカラム追加とインデックス作成
2. ⏭️ **次はタスク1.2**: Supabase Storageバケットとセキュリティポリシーの設定
3. ⏭️ **その後タスク1.3**: Postモデルの拡張（SwiftUIコード）

---

## 参考情報

- **マイグレーションファイル**: `supabase/migrations/20250627000000_add_audio_and_status_columns.sql`
- **ロールバックファイル**: `supabase/migrations/20250627000000_add_audio_and_status_columns_rollback.sql`
- **設計書**: `.kiro/specs/viral-quick-win-features/design.md`
- **要件定義**: `.kiro/specs/viral-quick-win-features/requirements.md`
