-- Supabase Storage RLS Policies - Direct SQL Method
-- Run this in: Supabase Dashboard > SQL Editor
-- This bypasses the UI limitations and creates policies directly

-- ============================================================
-- 1. Enable RLS on storage.objects
-- ============================================================

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. Drop all existing audio-related policies (cleanup)
-- ============================================================

DO $$
BEGIN
    -- Drop any policies with 'audio' in the name
    EXECUTE (
        SELECT string_agg('DROP POLICY IF EXISTS "' || policyname || '" ON storage.objects;', ' ')
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname ILIKE '%audio%'
    );

    RAISE NOTICE 'Existing audio policies dropped';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'No existing policies to drop';
END $$;

-- ============================================================
-- 3. Create RLS Policies for Audio Bucket
-- ============================================================

-- Policy 1: Users can upload to their own folder
CREATE POLICY "Users can upload to their own folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'audio' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Users can update their own files
CREATE POLICY "Users can update their own files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'audio' AND
    (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'audio' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Users can delete their own files
CREATE POLICY "Users can delete their own files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'audio' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Anyone can read audio files
CREATE POLICY "Anyone can read audio files"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'audio');

-- ============================================================
-- 4. Verification
-- ============================================================

-- Verify all 4 policies were created
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
        RAISE NOTICE '✅ SUCCESS: All 4 policies created correctly';
    ELSE
        RAISE WARNING '❌ INCOMPLETE: Only % policies found (expected 4)', policy_count;
    END IF;
END $$;

-- List all created policies
SELECT
    policyname as "Policy Name",
    CASE cmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
        WHEN '*' THEN 'ALL'
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
    CASE
        WHEN cmd = 'a' THEN 1  -- INSERT first
        WHEN cmd = 'w' THEN 2  -- UPDATE second
        WHEN cmd = 'd' THEN 3  -- DELETE third
        WHEN cmd = 'r' THEN 4  -- SELECT last
    END;

-- ============================================================
-- 5. Success Message
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ Storage RLS policies setup complete!';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Bucket: audio';
    RAISE NOTICE 'Policies: 4 created';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Test file upload from iOS app';
    RAISE NOTICE '============================================================';
END $$;
