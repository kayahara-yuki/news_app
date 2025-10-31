-- Edge Function実行後の検証クエリ
-- タスク6.1: auto-delete-status-posts Edge Functionのテスト

-- =====================================================
-- 削除後の状態確認
-- =====================================================

-- 期限切れステータス投稿が削除されたことを確認
SELECT
    '期限切れステータス投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at < NOW()
  AND user_id = '00000000-0000-0000-0000-000000000001'
  AND content LIKE '%テスト%';
-- 期待値: 0

-- 有効なステータス投稿が残っていることを確認
SELECT
    '有効なステータス投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = true
  AND expires_at >= NOW()
  AND user_id = '00000000-0000-0000-0000-000000000001'
  AND content LIKE '%テスト%';
-- 期待値: 1

-- 通常投稿が残っていることを確認
SELECT
    '通常投稿数' as metric,
    COUNT(*) as count
FROM posts
WHERE is_status_post = false
  AND user_id = '00000000-0000-0000-0000-000000000001'
  AND content LIKE '%テスト%';
-- 期待値: 1

-- 孤立したいいねがないことを確認
SELECT
    '孤立したいいね数' as metric,
    COUNT(*) as count
FROM likes l
LEFT JOIN posts p ON l.post_id = p.id
WHERE p.id IS NULL
  AND l.user_id = '00000000-0000-0000-0000-000000000001';
-- 期待値: 0

-- 孤立したコメントがないことを確認
SELECT
    '孤立したコメント数' as metric,
    COUNT(*) as count
FROM comments c
LEFT JOIN posts p ON c.post_id = p.id
WHERE p.id IS NULL
  AND c.user_id = '00000000-0000-0000-0000-000000000001';
-- 期待値: 0

-- =====================================================
-- テスト結果サマリー
-- =====================================================
DO $$
DECLARE
    expired_count INT;
    active_count INT;
    normal_count INT;
    orphaned_likes INT;
    orphaned_comments INT;
    all_tests_passed BOOLEAN := TRUE;
BEGIN
    -- 各カウントを取得
    SELECT COUNT(*) INTO expired_count
    FROM posts
    WHERE is_status_post = true
      AND expires_at < NOW()
      AND user_id = '00000000-0000-0000-0000-000000000001'
      AND content LIKE '%テスト%';

    SELECT COUNT(*) INTO active_count
    FROM posts
    WHERE is_status_post = true
      AND expires_at >= NOW()
      AND user_id = '00000000-0000-0000-0000-000000000001'
      AND content LIKE '%テスト%';

    SELECT COUNT(*) INTO normal_count
    FROM posts
    WHERE is_status_post = false
      AND user_id = '00000000-0000-0000-0000-000000000001'
      AND content LIKE '%テスト%';

    SELECT COUNT(*) INTO orphaned_likes
    FROM likes l
    LEFT JOIN posts p ON l.post_id = p.id
    WHERE p.id IS NULL
      AND l.user_id = '00000000-0000-0000-0000-000000000001';

    SELECT COUNT(*) INTO orphaned_comments
    FROM comments c
    LEFT JOIN posts p ON c.post_id = p.id
    WHERE p.id IS NULL
      AND c.user_id = '00000000-0000-0000-0000-000000000001';

    -- 結果判定
    RAISE NOTICE '======================================';
    RAISE NOTICE 'テスト検証結果';
    RAISE NOTICE '======================================';

    RAISE NOTICE '期限切れステータス投稿数: % (期待値: 0)', expired_count;
    IF expired_count != 0 THEN
        all_tests_passed := FALSE;
        RAISE NOTICE '  ✗ FAILED';
    ELSE
        RAISE NOTICE '  ✓ PASSED';
    END IF;

    RAISE NOTICE '有効なステータス投稿数: % (期待値: 1)', active_count;
    IF active_count != 1 THEN
        all_tests_passed := FALSE;
        RAISE NOTICE '  ✗ FAILED';
    ELSE
        RAISE NOTICE '  ✓ PASSED';
    END IF;

    RAISE NOTICE '通常投稿数: % (期待値: 1)', normal_count;
    IF normal_count != 1 THEN
        all_tests_passed := FALSE;
        RAISE NOTICE '  ✗ FAILED';
    ELSE
        RAISE NOTICE '  ✓ PASSED';
    END IF;

    RAISE NOTICE '孤立したいいね数: % (期待値: 0)', orphaned_likes;
    IF orphaned_likes != 0 THEN
        all_tests_passed := FALSE;
        RAISE NOTICE '  ✗ FAILED';
    ELSE
        RAISE NOTICE '  ✓ PASSED';
    END IF;

    RAISE NOTICE '孤立したコメント数: % (期待値: 0)', orphaned_comments;
    IF orphaned_comments != 0 THEN
        all_tests_passed := FALSE;
        RAISE NOTICE '  ✗ FAILED';
    ELSE
        RAISE NOTICE '  ✓ PASSED';
    END IF;

    RAISE NOTICE '======================================';
    IF all_tests_passed THEN
        RAISE NOTICE '✓ すべてのテストに合格しました';
    ELSE
        RAISE NOTICE '✗ 一部のテストが失敗しました';
    END IF;
    RAISE NOTICE '======================================';
END $$;
