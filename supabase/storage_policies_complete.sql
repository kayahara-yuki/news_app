-- Supabase Storage RLS Policies - Complete Setup (SQL)
-- Run this in: Supabase Dashboard > SQL Editor
--
-- This uses a workaround: creating policies with DO blocks and SECURITY DEFINER functions

-- ============================================================
-- Method: Use anonymous DO block with proper privileges
-- ============================================================

DO $$
BEGIN
    -- Enable RLS if not already enabled
    EXECUTE 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY';

    -- Drop existing policies to avoid duplicates
    DROP POLICY IF EXISTS "Users can upload to their own folder" ON storage.objects;
    DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;
    DROP POLICY IF EXISTS "Anyone can read audio files" ON storage.objects;

    -- Policy 1: INSERT
    EXECUTE '
        CREATE POLICY "Users can upload to their own folder"
        ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (
            bucket_id = ''audio'' AND
            (storage.foldername(name))[1] = auth.uid()::text
        )
    ';

    -- Policy 2: UPDATE
    EXECUTE '
        CREATE POLICY "Users can update their own files"
        ON storage.objects
        FOR UPDATE
        TO authenticated
        USING (
            bucket_id = ''audio'' AND
            (storage.foldername(name))[1] = auth.uid()::text
        )
        WITH CHECK (
            bucket_id = ''audio'' AND
            (storage.foldername(name))[1] = auth.uid()::text
        )
    ';

    -- Policy 3: DELETE
    EXECUTE '
        CREATE POLICY "Users can delete their own files"
        ON storage.objects
        FOR DELETE
        TO authenticated
        USING (
            bucket_id = ''audio'' AND
            (storage.foldername(name))[1] = auth.uid()::text
        )
    ';

    -- Policy 4: SELECT
    EXECUTE '
        CREATE POLICY "Anyone can read audio files"
        ON storage.objects
        FOR SELECT
        TO public
        USING (bucket_id = ''audio'')
    ';

    RAISE NOTICE '✅ All 4 policies created successfully';

EXCEPTION
    WHEN insufficient_privilege THEN
        RAISE EXCEPTION 'Insufficient privileges. This script must be run as a superuser or via Supabase Dashboard SQL Editor.';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error creating policies: %', SQLERRM;
END $$;

-- ============================================================
-- Verification
-- ============================================================

-- List all audio-related policies
SELECT
    policyname as "Policy Name",
    CASE cmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
    END as "Operation",
    roles as "Target Roles"
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname IN (
      'Users can upload to their own folder',
      'Users can update their own files',
      'Users can delete their own files',
      'Anyone can read audio files'
  )
ORDER BY
    CASE cmd
        WHEN 'a' THEN 1  -- INSERT
        WHEN 'w' THEN 2  -- UPDATE
        WHEN 'd' THEN 3  -- DELETE
        WHEN 'r' THEN 4  -- SELECT
    END;

-- Verify count
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname IN (
          'Users can upload to their own folder',
          'Users can update their own files',
          'Users can delete their own files',
          'Anyone can read audio files'
      );

    IF policy_count = 4 THEN
        RAISE NOTICE '============================================================';
        RAISE NOTICE '✅ SUCCESS: All 4 policies created correctly!';
        RAISE NOTICE '============================================================';
        RAISE NOTICE 'Bucket: audio';
        RAISE NOTICE 'Policies: % configured', policy_count;
        RAISE NOTICE '';
        RAISE NOTICE 'You can now test file upload from your iOS app.';
        RAISE NOTICE '============================================================';
    ELSE
        RAISE WARNING '❌ Only % policies found (expected 4)', policy_count;
        RAISE WARNING 'Manual creation via Dashboard UI may be required.';
    END IF;
END $$;
