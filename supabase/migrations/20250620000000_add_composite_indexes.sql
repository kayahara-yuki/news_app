-- ============================================
-- パフォーマンス最適化: 複合インデックスの追加
-- ============================================
-- 作成日: 2025-06-20
-- 目的: nearby_posts_with_user RPC関数のパフォーマンス向上

-- ============================================
-- 1. visibility + location 複合インデックス
-- ============================================
-- public投稿の空間検索を高速化
-- WHERE visibility = 'public' AND ST_DWithin(location, ...) のクエリに最適化

CREATE INDEX IF NOT EXISTS idx_posts_public_location
ON posts USING GIST(location)
WHERE visibility = 'public';

COMMENT ON INDEX idx_posts_public_location IS 'public投稿の空間検索を高速化するPartial Index';

-- ============================================
-- 2. user_id + created_at 複合インデックス
-- ============================================
-- ユーザー別の投稿取得時のソートを高速化
-- ORDER BY created_at DESC を含むクエリに最適化

CREATE INDEX IF NOT EXISTS idx_posts_user_created
ON posts(user_id, created_at DESC)
WHERE user_id IS NOT NULL;

COMMENT ON INDEX idx_posts_user_created IS 'ユーザー別投稿取得時のソート高速化';

-- ============================================
-- 3. is_urgent + location 複合インデックス
-- ============================================
-- 緊急投稿の空間検索を高速化
-- 緊急情報検索時のパフォーマンス向上

CREATE INDEX IF NOT EXISTS idx_posts_urgent_location
ON posts USING GIST(location)
WHERE is_urgent = true;

COMMENT ON INDEX idx_posts_urgent_location IS '緊急投稿の空間検索を高速化するPartial Index';

-- ============================================
-- 4. category + created_at 複合インデックス
-- ============================================
-- カテゴリ別投稿取得時のソートを高速化

CREATE INDEX IF NOT EXISTS idx_posts_category_created
ON posts(category, created_at DESC);

COMMENT ON INDEX idx_posts_category_created IS 'カテゴリ別投稿取得時のソート高速化';

-- ============================================
-- インデックス作成の確認
-- ============================================
-- 以下のクエリで作成されたインデックスを確認できます:
--
-- SELECT
--   schemaname,
--   tablename,
--   indexname,
--   indexdef
-- FROM pg_indexes
-- WHERE tablename = 'posts'
-- AND indexname LIKE 'idx_posts_%'
-- ORDER BY indexname;
