-- likesテーブルのRLSポリシー診断SQL

-- 1. likesテーブルのRLS有効状態を確認
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'likes';

-- 2. likesテーブルの全RLSポリシーを確認
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'likes'
ORDER BY policyname;

-- 3. 現在のユーザーでいいねを追加できるかテスト
-- テスト用のINSERT（実際には実行されない - EXPLAIN ONLYで確認）
EXPLAIN (VERBOSE, FORMAT JSON)
INSERT INTO likes (post_id, user_id)
VALUES (
    'A2F676ED-6168-4736-A9BC-3C481FE8DF6F',
    'C5ADC347-571F-49BB-B7D1-E6A6BB87F421'
);

-- 4. 実際にいいねが存在するか確認（全投稿）
SELECT
    post_id,
    user_id,
    created_at
FROM likes
WHERE post_id = 'A2F676ED-6168-4736-A9BC-3C481FE8DF6F'
ORDER BY created_at DESC
LIMIT 10;

-- 5. いいね数の不整合がある投稿を全件確認
SELECT
    p.id,
    p.like_count as stored_count,
    COUNT(l.id) as actual_count,
    p.like_count - COUNT(l.id) as difference,
    CASE
        WHEN p.like_count = COUNT(l.id) THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM posts p
LEFT JOIN likes l ON p.id = l.post_id
GROUP BY p.id
HAVING p.like_count != COUNT(l.id)
ORDER BY difference DESC
LIMIT 20;
