-- ============================================
-- デバッグ用診断クエリ
-- ============================================
-- Supabase Dashboard → SQL Editor で実行してください

-- ============================================
-- 1. 過去3日以内の投稿数を確認
-- ============================================
SELECT
    COUNT(*) as total_posts_last_3_days,
    COUNT(DISTINCT user_id) as unique_users,
    MIN(created_at) as oldest_post,
    MAX(created_at) as newest_post
FROM public.posts
WHERE created_at >= NOW() - INTERVAL '3 days';

-- ============================================
-- 2. 全投稿の日付分布を確認
-- ============================================
SELECT
    DATE(created_at) as post_date,
    COUNT(*) as post_count
FROM public.posts
GROUP BY DATE(created_at)
ORDER BY post_date DESC
LIMIT 10;

-- ============================================
-- 3. 投稿の詳細情報（最新10件）
-- ============================================
SELECT
    p.id,
    p.content,
    p.latitude,
    p.longitude,
    p.category,
    p.is_urgent,
    p.created_at,
    u.username,
    u.display_name
FROM public.posts p
LEFT JOIN public.users u ON p.user_id = u.id
ORDER BY p.created_at DESC
LIMIT 10;

-- ============================================
-- 4. RPC関数のテスト実行（東京駅周辺）
-- ============================================
-- 東京駅: 35.6812, 139.7671
-- 半径: 10000000m (実質的に全投稿)
SELECT * FROM nearby_posts_with_user(
    35.6812,          -- lat
    139.7671,         -- lng
    10000000,         -- radius_meters (10,000km)
    50                -- max_results
);

-- ============================================
-- 5. RPC関数の結果件数のみ確認
-- ============================================
SELECT COUNT(*) as result_count
FROM nearby_posts_with_user(
    35.6812,          -- lat
    139.7671,         -- lng
    10000000,         -- radius_meters
    50                -- max_results
);

-- ============================================
-- 6. 位置情報がNULLの投稿を確認
-- ============================================
SELECT
    COUNT(*) as posts_without_location,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM public.posts) as percentage
FROM public.posts
WHERE location IS NULL OR latitude IS NULL OR longitude IS NULL;

-- ============================================
-- 7. RPC関数が存在するか確認
-- ============================================
SELECT
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name LIKE 'nearby_posts%';

-- ============================================
-- 8. 過去3日以内の投稿を直接クエリ（RPC関数を使わない）
-- ============================================
SELECT
    p.id,
    p.content,
    p.latitude,
    p.longitude,
    p.created_at,
    u.username
FROM public.posts p
INNER JOIN public.users u ON p.user_id = u.id
WHERE p.location IS NOT NULL
    AND p.created_at >= NOW() - INTERVAL '3 days'
    AND p.visibility = 'public'
ORDER BY p.created_at DESC
LIMIT 50;

-- ============================================
-- 9. ユーザー数と投稿数の統計
-- ============================================
SELECT
    (SELECT COUNT(*) FROM public.users) as total_users,
    (SELECT COUNT(*) FROM public.posts) as total_posts,
    (SELECT COUNT(*) FROM public.posts WHERE created_at >= NOW() - INTERVAL '3 days') as posts_last_3_days,
    (SELECT COUNT(*) FROM public.posts WHERE created_at >= NOW() - INTERVAL '1 day') as posts_last_24h;

-- ============================================
-- 10. RPC関数の定義を確認
-- ============================================
SELECT
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name = 'nearby_posts_with_user';
