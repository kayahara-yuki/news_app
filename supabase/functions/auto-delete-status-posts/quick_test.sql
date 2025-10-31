-- クイックテスト用SQL
-- タスク6.2: Edge Functionの動作確認

-- =====================================================
-- ステップ1: テストデータの作成
-- =====================================================

-- 期限切れステータス投稿1（音声あり）
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
    audio_url
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
    'https://ikjxfoyfeliiovbwelyx.supabase.co/storage/v1/object/public/audio/00000000-0000-0000-0000-000000000001/test_audio_1.m4a'
);

-- 期限切れステータス投稿2（音声なし）
INSERT INTO posts (
    user_id,
    content,
    location,
    latitude,
    longitude,
    address,
    category,
    is_status_post,
    expires_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '🚶 散歩中（テスト期限切れ2）',
    ST_SetSRID(ST_MakePoint(139.6917, 35.6895), 4326),
    35.6895,
    139.6917,
    '東京都新宿区',
    'other',
    true,
    NOW() - INTERVAL '30 minutes' -- 30分前に期限切れ
);

-- 有効なステータス投稿
INSERT INTO posts (
    user_id,
    content,
    location,
    latitude,
    longitude,
    address,
    category,
    is_status_post,
    expires_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '📚 勉強中（テスト有効）',
    ST_SetSRID(ST_MakePoint(139.6503, 35.6762), 4326),
    35.6762,
    139.6503,
    '東京都世田谷区',
    'other',
    true,
    NOW() + INTERVAL '2 hours' -- まだ2時間有効
);

-- 通常投稿
INSERT INTO posts (
    user_id,
    content,
    location,
    latitude,
    longitude,
    address,
    category,
    is_status_post
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '通常の投稿です（テスト）',
    ST_SetSRID(ST_MakePoint(139.7671, 35.6812), 4326),
    35.6812,
    139.7671,
    '東京都渋谷区',
    'other',
    false
);

-- =====================================================
-- ステップ2: 作成したテストデータの確認
-- =====================================================

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

-- =====================================================
-- ステップ3: 削除対象の確認
-- =====================================================

SELECT
    '削除対象の投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at < NOW()
  AND user_id = '00000000-0000-0000-0000-000000000001';
-- 期待値: 2

-- =====================================================
-- 次のステップ
-- =====================================================
-- 1. このSQLをSupabase SQL Editorで実行
-- 2. Edge Functionを実行:
--    curl -i --location --request POST \
--      'https://ikjxfoyfeliiovbwelyx.supabase.co/functions/v1/auto-delete-status-posts' \
--      --header 'Authorization: Bearer YOUR_ANON_KEY' \
--      --header 'Content-Type: application/json'
-- 3. 検証クエリ（test_verification.sql）を実行して確認
