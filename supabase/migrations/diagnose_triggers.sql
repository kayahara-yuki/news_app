-- トリガー診断SQL

-- 1. 既存のトリガーを確認
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'likes'
ORDER BY trigger_name;

-- 2. トリガー関数の定義を確認
SELECT
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname IN ('increment_post_like_count', 'decrement_post_like_count')
ORDER BY p.proname;

-- 3. postsテーブルのRLSポリシーを確認
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
WHERE tablename = 'posts'
ORDER BY policyname;

-- 4. 現在のlike_countを確認（投稿ID: A2F676ED-6168-4736-A9BC-3C481FE8DF6F）
SELECT id, like_count,
       (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) as actual_like_count
FROM posts
WHERE id = 'A2F676ED-6168-4736-A9BC-3C481FE8DF6F';
