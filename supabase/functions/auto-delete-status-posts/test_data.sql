-- テスト用: ステータス投稿自動削除機能のテストデータ作成
-- タスク6.1: Supabase Edge Functionの実装テスト

-- テストデータのクリーンアップ（既存のテストデータを削除）
DELETE FROM comments WHERE post_id IN (
    SELECT id FROM posts
    WHERE user_id = '00000000-0000-0000-0000-000000000001'
    AND content LIKE '%テスト%'
);

DELETE FROM likes WHERE post_id IN (
    SELECT id FROM posts
    WHERE user_id = '00000000-0000-0000-0000-000000000001'
    AND content LIKE '%テスト%'
);

DELETE FROM posts
WHERE user_id = '00000000-0000-0000-0000-000000000001'
AND (content LIKE '%テスト%' OR content IN ('☕ カフェなう', '🚶 散歩中', '📚 勉強中', '通常の投稿です'));

-- =====================================================
-- テストデータの作成
-- =====================================================

-- ケース1: 期限切れステータス投稿（音声ファイル付き）
INSERT INTO posts (
    user_id,
    content,
    location,
    latitude,
    longitude,
    address,
    category,
    is_status_post,
    expires_at,
    audio_url,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '☕ カフェなう（テスト期限切れ1）',
    ST_SetSRID(ST_MakePoint(139.7671, 35.6812), 4326),
    35.6812,
    139.7671,
    '東京都渋谷区',
    'social',  -- 'food'ではなく'social'を使用
    true,
    NOW() - INTERVAL '1 hour', -- 1時間前に期限切れ
    'https://ikjxfoyfeliiovbwelyx.supabase.co/storage/v1/object/public/audio/00000000-0000-0000-0000-000000000001/test_audio_1.m4a',
    NOW() - INTERVAL '4 hours',
    NOW() - INTERVAL '4 hours'
);

-- 期限切れ投稿にいいねを追加
INSERT INTO likes (user_id, post_id, created_at)
SELECT
    '00000000-0000-0000-0000-000000000001',
    id,
    NOW() - INTERVAL '3 hours'
FROM posts
WHERE content = '☕ カフェなう（テスト期限切れ1）';

-- 期限切れ投稿にコメントを追加
INSERT INTO comments (user_id, post_id, content, created_at)
SELECT
    '00000000-0000-0000-0000-000000000001',
    id,
    'いいね！',
    NOW() - INTERVAL '3 hours'
FROM posts
WHERE content = '☕ カフェなう（テスト期限切れ1）';

-- ケース2: 期限切れステータス投稿（音声ファイルなし）
INSERT INTO posts (
    user_id,
    content,
    location,
    latitude,
    longitude,
    address,
    category,
    is_status_post,
    expires_at,
    audio_url,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '🚶 散歩中（テスト期限切れ2）',
    ST_SetSRID(ST_MakePoint(139.6917, 35.6895), 4326),
    35.6895,
    139.6917,
    '東京都新宿区',
    'other',
    true,
    NOW() - INTERVAL '30 minutes', -- 30分前に期限切れ
    NULL,
    NOW() - INTERVAL '3 hours 30 minutes',
    NOW() - INTERVAL '3 hours 30 minutes'
);

-- 期限切れ投稿にいいねを追加
INSERT INTO likes (user_id, post_id, created_at)
SELECT
    '00000000-0000-0000-0000-000000000001',
    id,
    NOW() - INTERVAL '2 hours'
FROM posts
WHERE content = '🚶 散歩中（テスト期限切れ2）';

-- ケース3: まだ有効なステータス投稿
INSERT INTO posts (
    user_id,
    content,
    location,
    latitude,
    longitude,
    address,
    category,
    is_status_post,
    expires_at,
    audio_url,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '📚 勉強中（テスト有効）',
    ST_SetSRID(ST_MakePoint(139.6503, 35.6762), 4326),
    35.6762,
    139.6503,
    '東京都世田谷区',
    'other',
    true,
    NOW() + INTERVAL '2 hours', -- まだ2時間有効
    NULL,
    NOW() - INTERVAL '1 hour',
    NOW() - INTERVAL '1 hour'
);

-- ケース4: 通常の投稿（ステータス投稿ではない）
INSERT INTO posts (
    user_id,
    content,
    location,
    latitude,
    longitude,
    address,
    category,
    is_status_post,
    expires_at,
    audio_url,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '通常の投稿です（テスト）',
    ST_SetSRID(ST_MakePoint(139.7671, 35.6812), 4326),
    35.6812,
    139.7671,
    '東京都渋谷区',
    'other',
    false,
    NULL,
    NULL,
    NOW() - INTERVAL '5 hours',
    NOW() - INTERVAL '5 hours'
);

-- =====================================================
-- テストデータの確認クエリ
-- =====================================================

-- テスト用投稿一覧
SELECT
    id,
    content,
    is_status_post,
    expires_at,
    audio_url IS NOT NULL as has_audio,
    CASE
        WHEN expires_at IS NULL THEN 'N/A (通常投稿)'
        WHEN expires_at < NOW() THEN '期限切れ'
        ELSE '有効'
    END as status,
    created_at
FROM posts
WHERE user_id = '00000000-0000-0000-0000-000000000001'
  AND content LIKE '%テスト%'
ORDER BY created_at DESC;

-- 削除対象の投稿数
SELECT
    '削除対象の投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at < NOW()
  AND user_id = '00000000-0000-0000-0000-000000000001';

-- 削除対象の関連いいね数
SELECT
    '削除対象のいいね数' as metric,
    COUNT(*) as count
FROM likes l
JOIN posts p ON l.post_id = p.id
WHERE p.is_status_post = true
  AND p.expires_at < NOW()
  AND p.user_id = '00000000-0000-0000-0000-000000000001';

-- 削除対象の関連コメント数
SELECT
    '削除対象のコメント数' as metric,
    COUNT(*) as count
FROM comments c
JOIN posts p ON c.post_id = p.id
WHERE p.is_status_post = true
  AND p.expires_at < NOW()
  AND p.user_id = '00000000-0000-0000-0000-000000000001';
