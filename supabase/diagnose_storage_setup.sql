-- ============================================================
-- Supabase Storage診断SQL
-- 目的: audioバケットとRLSポリシーの設定状態を確認
-- 実行方法: Supabase Dashboard > SQL Editor で実行
-- ============================================================

-- ============================================================
-- 1. バケット存在確認
-- ============================================================
SELECT
    '=== BUCKET CHECK ===' as check_type,
    CASE
        WHEN EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'audio')
        THEN '✅ audio bucket EXISTS'
        ELSE '❌ audio bucket NOT FOUND'
    END as result;

-- バケット詳細情報
SELECT
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at,
    updated_at
FROM storage.buckets
WHERE id = 'audio';

-- ============================================================
-- 2. RLS有効化確認
-- ============================================================
SELECT
    '=== RLS STATUS ===' as check_type,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'storage'
  AND tablename = 'objects';

-- ============================================================
-- 3. RLSポリシー一覧
-- ============================================================
SELECT
    '=== RLS POLICIES ===' as check_type,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects';

-- 詳細なポリシー情報
SELECT
    policyname as "Policy Name",
    CASE cmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
        WHEN '*' THEN 'ALL'
    END as "Operation",
    roles as "Target Roles",
    CASE
        WHEN qual IS NOT NULL THEN 'USING clause defined'
        ELSE 'No USING clause'
    END as "USING Status",
    CASE
        WHEN with_check IS NOT NULL THEN 'WITH CHECK defined'
        ELSE 'No WITH CHECK'
    END as "WITH CHECK Status"
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
ORDER BY
    CASE cmd
        WHEN 'a' THEN 1  -- INSERT
        WHEN 'w' THEN 2  -- UPDATE
        WHEN 'd' THEN 3  -- DELETE
        WHEN 'r' THEN 4  -- SELECT
        ELSE 5
    END;

-- ============================================================
-- 4. audio関連ポリシーの詳細
-- ============================================================
SELECT
    '=== AUDIO-SPECIFIC POLICIES ===' as check_type;

SELECT
    policyname,
    cmd as operation,
    roles,
    qual::text as using_expression,
    with_check::text as with_check_expression
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
      policyname ILIKE '%audio%' OR
      policyname IN (
          'Users can upload to their own folder',
          'Users can update their own files',
          'Users can delete their own files',
          'Anyone can read audio files'
      )
  );

-- ============================================================
-- 5. 診断結果サマリー
-- ============================================================
DO $$
DECLARE
    bucket_exists BOOLEAN;
    rls_enabled BOOLEAN;
    policy_count INTEGER;
    expected_policies TEXT[] := ARRAY[
        'Users can upload to their own folder',
        'Users can update their own files',
        'Users can delete their own files',
        'Anyone can read audio files'
    ];
    missing_policies TEXT[];
BEGIN
    -- バケット存在確認
    SELECT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'audio') INTO bucket_exists;

    -- RLS有効化確認
    SELECT rowsecurity INTO rls_enabled
    FROM pg_tables
    WHERE schemaname = 'storage' AND tablename = 'objects';

    -- ポリシー数確認
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = ANY(expected_policies);

    -- 不足ポリシー確認
    SELECT ARRAY_AGG(policy)
    INTO missing_policies
    FROM UNNEST(expected_policies) AS policy
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname = policy
    );

    -- レポート出力
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'SUPABASE STORAGE DIAGNOSTIC REPORT';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE '1. Bucket Status:';
    IF bucket_exists THEN
        RAISE NOTICE '   ✅ audio bucket EXISTS';
    ELSE
        RAISE NOTICE '   ❌ audio bucket NOT FOUND';
        RAISE NOTICE '   → Action: Create bucket via Dashboard or CLI';
    END IF;
    RAISE NOTICE '';

    RAISE NOTICE '2. RLS Status:';
    IF rls_enabled THEN
        RAISE NOTICE '   ✅ RLS is ENABLED on storage.objects';
    ELSE
        RAISE NOTICE '   ❌ RLS is DISABLED on storage.objects';
        RAISE NOTICE '   → Action: Enable RLS';
    END IF;
    RAISE NOTICE '';

    RAISE NOTICE '3. RLS Policies:';
    RAISE NOTICE '   Expected: 4 policies';
    RAISE NOTICE '   Found: % policies', policy_count;

    IF policy_count = 4 THEN
        RAISE NOTICE '   ✅ All required policies configured';
    ELSE
        RAISE NOTICE '   ❌ Missing policies:';
        IF missing_policies IS NOT NULL THEN
            FOR i IN 1..array_length(missing_policies, 1) LOOP
                RAISE NOTICE '      - %', missing_policies[i];
            END LOOP;
        END IF;
        RAISE NOTICE '   → Action: Run storage_policies_complete.sql';
    END IF;
    RAISE NOTICE '';

    RAISE NOTICE '============================================================';

    IF bucket_exists AND rls_enabled AND policy_count = 4 THEN
        RAISE NOTICE '✅ RESULT: Storage setup is COMPLETE';
        RAISE NOTICE '   → If upload still fails, check:';
        RAISE NOTICE '      1. User authentication (auth.uid() must match user ID)';
        RAISE NOTICE '      2. File path format (must be: audio/{user_id}/filename)';
        RAISE NOTICE '      3. Network/CORS configuration';
    ELSE
        RAISE NOTICE '❌ RESULT: Storage setup is INCOMPLETE';
        RAISE NOTICE '   → Follow action items above';
    END IF;

    RAISE NOTICE '============================================================';
END $$;
