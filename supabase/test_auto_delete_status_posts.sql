-- テスト用: ステータス投稿自動削除機能のテストデータ作成とテストスクリプト
-- タスク6.1: Supabase Edge Functionの実装テスト

-- =====================================================
-- テストデータのセットアップ
-- =====================================================

-- テスト用ユーザーIDの定義（既存のユーザーIDを使用）
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000001';
    expired_post_id_1 UUID;
    expired_post_id_2 UUID;
    active_post_id UUID;
    normal_post_id UUID;
BEGIN
    -- =====================================================
    -- ケース1: 期限切れステータス投稿（音声ファイル付き）
    -- =====================================================
    INSERT INTO posts (
        id,
        user_id,
        content,
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
        gen_random_uuid(),
        test_user_id,
        '☕ カフェなう',
        35.6812,
        139.7671,
        '東京都渋谷区',
        'food',
        true,
        NOW() - INTERVAL '1 hour', -- 1時間前に期限切れ
        'https://ikjxfoyfeliiovbwelyx.supabase.co/storage/v1/object/public/audio/00000000-0000-0000-0000-000000000001/test_audio_1.m4a',
        NOW() - INTERVAL '4 hours',
        NOW() - INTERVAL '4 hours'
    ) RETURNING id INTO expired_post_id_1;

    -- 期限切れ投稿にいいねを追加
    INSERT INTO likes (user_id, post_id, created_at)
    VALUES (test_user_id, expired_post_id_1, NOW() - INTERVAL '3 hours');

    -- 期限切れ投稿にコメントを追加
    INSERT INTO comments (user_id, post_id, content, created_at)
    VALUES (test_user_id, expired_post_id_1, 'いいね！', NOW() - INTERVAL '3 hours');

    RAISE NOTICE 'Created expired status post 1 with ID: %', expired_post_id_1;

    -- =====================================================
    -- ケース2: 期限切れステータス投稿（音声ファイルなし）
    -- =====================================================
    INSERT INTO posts (
        id,
        user_id,
        content,
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
        gen_random_uuid(),
        test_user_id,
        '🚶 散歩中',
        35.6895,
        139.6917,
        '東京都新宿区',
        'other',
        true,
        NOW() - INTERVAL '30 minutes', -- 30分前に期限切れ
        NULL,
        NOW() - INTERVAL '3 hours 30 minutes',
        NOW() - INTERVAL '3 hours 30 minutes'
    ) RETURNING id INTO expired_post_id_2;

    -- 期限切れ投稿にいいねを追加
    INSERT INTO likes (user_id, post_id, created_at)
    VALUES (test_user_id, expired_post_id_2, NOW() - INTERVAL '2 hours');

    RAISE NOTICE 'Created expired status post 2 with ID: %', expired_post_id_2;

    -- =====================================================
    -- ケース3: まだ有効なステータス投稿
    -- =====================================================
    INSERT INTO posts (
        id,
        user_id,
        content,
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
        gen_random_uuid(),
        test_user_id,
        '📚 勉強中',
        35.6762,
        139.6503,
        '東京都世田谷区',
        'other',
        true,
        NOW() + INTERVAL '2 hours', -- まだ2時間有効
        NULL,
        NOW() - INTERVAL '1 hour',
        NOW() - INTERVAL '1 hour'
    ) RETURNING id INTO active_post_id;

    RAISE NOTICE 'Created active status post with ID: %', active_post_id;

    -- =====================================================
    -- ケース4: 通常の投稿（ステータス投稿ではない）
    -- =====================================================
    INSERT INTO posts (
        id,
        user_id,
        content,
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
        gen_random_uuid(),
        test_user_id,
        '通常の投稿です',
        35.6812,
        139.7671,
        '東京都渋谷区',
        'other',
        false,
        NULL,
        NULL,
        NOW() - INTERVAL '5 hours',
        NOW() - INTERVAL '5 hours'
    ) RETURNING id INTO normal_post_id;

    RAISE NOTICE 'Created normal post with ID: %', normal_post_id;

    -- =====================================================
    -- 現在のテストデータ確認
    -- =====================================================
    RAISE NOTICE '======================================';
    RAISE NOTICE 'Test data summary:';
    RAISE NOTICE '======================================';
END $$;

-- テストデータの確認クエリ
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
ORDER BY created_at DESC
LIMIT 10;

-- =====================================================
-- 期待される削除対象の確認
-- =====================================================
SELECT
    'Expected to delete' as action,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at < NOW();

-- =====================================================
-- 関連データの確認
-- =====================================================
SELECT
    'Likes to delete' as type,
    COUNT(*) as count
FROM likes l
JOIN posts p ON l.post_id = p.id
WHERE p.is_status_post = true
  AND p.expires_at < NOW();

SELECT
    'Comments to delete' as type,
    COUNT(*) as count
FROM comments c
JOIN posts p ON c.post_id = p.id
WHERE p.is_status_post = true
  AND p.expires_at < NOW();

-- =====================================================
-- テスト実行後の検証クエリ（手動実行用）
-- =====================================================
-- Edge Function実行後にこのクエリを実行して確認
/*
-- 期限切れステータス投稿が削除されたことを確認
SELECT
    'After deletion' as status,
    COUNT(*) as remaining_expired_posts
FROM posts
WHERE is_status_post = true
  AND expires_at < NOW();

-- まだ有効なステータス投稿が残っていることを確認
SELECT
    'Active status posts' as status,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at >= NOW();

-- 通常投稿が残っていることを確認
SELECT
    'Normal posts' as status,
    COUNT(*) as count
FROM posts
WHERE is_status_post = false;

-- 孤立したいいね・コメントがないことを確認
SELECT
    'Orphaned likes' as type,
    COUNT(*) as count
FROM likes l
LEFT JOIN posts p ON l.post_id = p.id
WHERE p.id IS NULL;

SELECT
    'Orphaned comments' as type,
    COUNT(*) as count
FROM comments c
LEFT JOIN posts p ON c.post_id = p.id
WHERE p.id IS NULL;
*/
