-- トリガー動作テスト用SQL

-- テスト対象の投稿ID（ログから取得）
-- post_id: A2F676ED-6168-4736-A9BC-3C481FE8DF6F
-- user_id: C5ADC347-571F-49BB-B7D1-E6A6BB87F421

-- 1. テスト前の状態を確認
SELECT
    'Before Test' as status,
    id,
    like_count as current_like_count,
    (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) as actual_likes
FROM posts
WHERE id = 'A2F676ED-6168-4736-A9BC-3C481FE8DF6F';

-- 2. いいねを追加してトリガーをテスト
-- 注意: このユーザーIDの組み合わせで既にいいねが存在する場合は、先に削除が必要
INSERT INTO likes (post_id, user_id)
VALUES (
    'A2F676ED-6168-4736-A9BC-3C481FE8DF6F',
    'C5ADC347-571F-49BB-B7D1-E6A6BB87F421'
)
ON CONFLICT DO NOTHING;

-- 3. テスト後の状態を確認（like_countが+1されているはず）
SELECT
    'After Insert' as status,
    id,
    like_count as current_like_count,
    (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) as actual_likes
FROM posts
WHERE id = 'A2F676ED-6168-4736-A9BC-3C481FE8DF6F';

-- 4. いいねを削除してトリガーをテスト
DELETE FROM likes
WHERE post_id = 'A2F676ED-6168-4736-A9BC-3C481FE8DF6F'
  AND user_id = 'C5ADC347-571F-49BB-B7D1-E6A6BB87F421';

-- 5. 削除後の状態を確認（like_countが-1されているはず）
SELECT
    'After Delete' as status,
    id,
    like_count as current_like_count,
    (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) as actual_likes
FROM posts
WHERE id = 'A2F676ED-6168-4736-A9BC-3C481FE8DF6F';

-- 6. like_countと実際のいいね数の整合性を確認
SELECT
    id,
    like_count,
    (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) as actual_count,
    CASE
        WHEN like_count = (SELECT COUNT(*) FROM likes WHERE post_id = posts.id)
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM posts
WHERE id = 'A2F676ED-6168-4736-A9BC-3C481FE8DF6F';
