-- ============================================
-- 過去7日以内のテスト投稿データを追加
-- ============================================
-- Supabase Dashboard → SQL Editor で実行してください

-- ============================================
-- 注意事項
-- ============================================
-- 1. このスクリプトは既存のユーザーデータを使用します
-- 2. 実行前に、usersテーブルにユーザーが存在することを確認してください
-- 3. 投稿は東京周辺（緯度: 35.6-35.7, 経度: 139.6-139.8）に配置されます

-- ============================================
-- テストユーザーの確認（最初のユーザーIDを取得）
-- ============================================
DO $$
DECLARE
    test_user_id UUID;
    post_count INTEGER := 0;
BEGIN
    -- 最初のユーザーIDを取得
    SELECT id INTO test_user_id FROM public.users LIMIT 1;

    IF test_user_id IS NULL THEN
        RAISE EXCEPTION 'ユーザーが存在しません。先にユーザーを作成してください。';
    END IF;

    RAISE NOTICE 'テストユーザーID: %', test_user_id;

    -- ============================================
    -- 過去7日以内のテスト投稿を挿入
    -- ============================================

    -- 1日前の投稿（東京駅周辺）
    INSERT INTO public.posts (
        user_id, content, latitude, longitude, location, address, category,
        visibility, is_urgent, created_at, updated_at
    ) VALUES
        (test_user_id, '東京駅周辺でイベント開催中！多くの人で賑わっています。',
         35.6812, 139.7671, ST_SetSRID(ST_MakePoint(139.7671, 35.6812), 4326), '東京都千代田区丸の内', 'event',
         'public', false, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

        (test_user_id, '東京タワーが美しくライトアップされています。',
         35.6586, 139.7454, ST_SetSRID(ST_MakePoint(139.7454, 35.6586), 4326), '東京都港区芝公園', 'social',
         'public', false, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),

        (test_user_id, '渋谷スクランブル交差点、今日も混雑しています。',
         35.6595, 139.7004, ST_SetSRID(ST_MakePoint(139.7004, 35.6595), 4326), '東京都渋谷区道玄坂', 'social',
         'public', false, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day');

    post_count := post_count + 3;

    -- 2日前の投稿（新宿・池袋周辺）
    INSERT INTO public.posts (
        user_id, content, latitude, longitude, location, address, category,
        visibility, is_urgent, created_at, updated_at
    ) VALUES
        (test_user_id, '新宿御苑で桜が咲き始めました。',
         35.6852, 139.7101, ST_SetSRID(ST_MakePoint(139.7101, 35.6852), 4326), '東京都新宿区内藤町', 'social',
         'public', false, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),

        (test_user_id, '池袋サンシャインシティでセール開催中！',
         35.7295, 139.7193, ST_SetSRID(ST_MakePoint(139.7193, 35.7295), 4326), '東京都豊島区東池袋', 'business',
         'public', false, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days');

    post_count := post_count + 2;

    -- 3日前の投稿（上野・秋葉原周辺）
    INSERT INTO public.posts (
        user_id, content, latitude, longitude, location, address, category,
        visibility, is_urgent, created_at, updated_at
    ) VALUES
        (test_user_id, '上野動物園でパンダの赤ちゃんが公開されています。',
         35.7153, 139.7737, ST_SetSRID(ST_MakePoint(139.7737, 35.7153), 4326), '東京都台東区上野公園', 'social',
         'public', false, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),

        (test_user_id, '秋葉原で新作ゲームの発売イベント開催！',
         35.6983, 139.7731, ST_SetSRID(ST_MakePoint(139.7731, 35.6983), 4326), '東京都千代田区外神田', 'event',
         'public', false, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days');

    post_count := post_count + 2;

    -- 4日前の投稿（お台場・品川周辺）
    INSERT INTO public.posts (
        user_id, content, latitude, longitude, location, address, category,
        visibility, is_urgent, created_at, updated_at
    ) VALUES
        (test_user_id, 'お台場海浜公園で花火大会の準備が進んでいます。',
         35.6301, 139.7753, ST_SetSRID(ST_MakePoint(139.7753, 35.6301), 4326), '東京都港区台場', 'event',
         'public', false, NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),

        (test_user_id, '品川駅周辺で新しいカフェがオープン！',
         35.6284, 139.7387, ST_SetSRID(ST_MakePoint(139.7387, 35.6284), 4326), '東京都港区高輪', 'business',
         'public', false, NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days');

    post_count := post_count + 2;

    -- 5日前の投稿（浅草・両国周辺）
    INSERT INTO public.posts (
        user_id, content, latitude, longitude, location, address, category,
        visibility, is_urgent, created_at, updated_at
    ) VALUES
        (test_user_id, '浅草寺で夏祭りの準備が始まりました。',
         35.7148, 139.7967, ST_SetSRID(ST_MakePoint(139.7967, 35.7148), 4326), '東京都台東区浅草', 'event',
         'public', false, NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),

        (test_user_id, '両国国技館で相撲の稽古を見学できます。',
         35.6974, 139.7933, ST_SetSRID(ST_MakePoint(139.7933, 35.6974), 4326), '東京都墨田区横網', 'social',
         'public', false, NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days');

    post_count := post_count + 2;

    -- 6日前の投稿（緊急情報含む）
    INSERT INTO public.posts (
        user_id, content, latitude, longitude, location, address, category,
        visibility, is_urgent, created_at, updated_at
    ) VALUES
        (test_user_id, '【緊急】六本木で停電が発生しています。復旧作業中です。',
         35.6627, 139.7308, ST_SetSRID(ST_MakePoint(139.7308, 35.6627), 4326), '東京都港区六本木', 'emergency',
         'public', true, NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days'),

        (test_user_id, '銀座で新しい商業施設がグランドオープン！',
         35.6717, 139.7648, ST_SetSRID(ST_MakePoint(139.7648, 35.6717), 4326), '東京都中央区銀座', 'business',
         'public', false, NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days');

    post_count := post_count + 2;

    -- 7日前の投稿（境界値テスト）
    INSERT INTO public.posts (
        user_id, content, latitude, longitude, location, address, category,
        visibility, is_urgent, created_at, updated_at
    ) VALUES
        (test_user_id, '丸の内で新しいオフィスビルが完成しました。',
         35.6816, 139.7660, ST_SetSRID(ST_MakePoint(139.7660, 35.6816), 4326), '東京都千代田区丸の内', 'business',
         'public', false, NOW() - INTERVAL '7 days' + INTERVAL '1 hour', NOW() - INTERVAL '7 days' + INTERVAL '1 hour'),

        (test_user_id, '日本橋で伝統工芸品の展示会が開催されています。',
         35.6840, 139.7740, ST_SetSRID(ST_MakePoint(139.7740, 35.6840), 4326), '東京都中央区日本橋', 'event',
         'public', false, NOW() - INTERVAL '7 days' + INTERVAL '30 minutes', NOW() - INTERVAL '7 days' + INTERVAL '30 minutes');

    post_count := post_count + 2;

    RAISE NOTICE '挿入完了: % 件の投稿を追加しました', post_count;

END $$;

-- ============================================
-- 確認クエリ
-- ============================================

-- 過去7日以内の投稿件数を確認
SELECT
    COUNT(*) as posts_last_7_days,
    MIN(created_at) as oldest_post,
    MAX(created_at) as newest_post
FROM public.posts
WHERE created_at >= NOW() - INTERVAL '7 days';

-- カテゴリ別の投稿件数
SELECT
    category,
    COUNT(*) as count
FROM public.posts
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY category
ORDER BY count DESC;

-- 緊急投稿の件数
SELECT
    COUNT(*) as urgent_posts
FROM public.posts
WHERE created_at >= NOW() - INTERVAL '7 days'
    AND is_urgent = true;
