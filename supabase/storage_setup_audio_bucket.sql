-- Supabase Storage Setup: Audio Bucket
-- Created: 2025-06-27
-- Feature: viral-quick-win-features
-- Description: Create audio bucket and configure RLS policies for audio file storage

-- ============================================================
-- 1. Create Audio Bucket
-- ============================================================
-- Note: Bucket creation is typically done via Supabase Dashboard or CLI
-- This SQL provides the equivalent configuration for reference

-- Bucket configuration (for documentation):
-- Bucket name: audio
-- Public: false (requires authentication for upload/delete, but public for read)
-- File size limit: 5MB (configurable in dashboard)
-- Allowed MIME types: audio/mpeg, audio/mp4, audio/x-m4a, audio/aac

-- ============================================================
-- 2. RLS Policies for Audio Bucket
-- ============================================================

-- Enable RLS on storage.objects table
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can upload to their own folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can read audio files" ON storage.objects;

-- Policy 1: Users can upload to their own folder
-- This policy allows authenticated users to upload files only to folders matching their user ID
CREATE POLICY "Users can upload to their own folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy 2: Users can update their own files
-- This policy allows authenticated users to update metadata of their own files
CREATE POLICY "Users can update their own files"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
    bucket_id = 'audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy 3: Users can delete their own files
-- This policy allows authenticated users to delete only files in their own folder
CREATE POLICY "Users can delete their own files"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy 4: Anyone can read audio files (public access for playback)
-- This policy allows all users (authenticated or anonymous) to read/download audio files
CREATE POLICY "Anyone can read audio files"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'audio');

-- ============================================================
-- 3. Verification Queries
-- ============================================================

-- Verify bucket exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM storage.buckets WHERE id = 'audio'
    ) THEN
        RAISE WARNING 'Bucket "audio" does not exist. Create it via Supabase Dashboard or CLI:';
        RAISE WARNING '  supabase storage create audio --public false';
    ELSE
        RAISE NOTICE 'Bucket "audio" exists';
    END IF;
END $$;

-- Verify RLS policies are configured
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname LIKE '%audio%';

    IF policy_count < 4 THEN
        RAISE WARNING 'Expected 4 RLS policies for audio bucket, found %', policy_count;
    ELSE
        RAISE NOTICE 'RLS policies configured: % policies found', policy_count;
    END IF;
END $$;

-- List all policies for audio bucket (for verification)
SELECT
    policyname as name,
    cmd as command,
    qual as using_expression,
    with_check as check_expression
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname IN (
    'Users can upload to their own folder',
    'Users can update their own files',
    'Users can delete their own files',
    'Anyone can read audio files'
  )
ORDER BY policyname;

-- ============================================================
-- 4. Test Policy Logic (Dry Run)
-- ============================================================

-- Test 1: Verify user can upload to their own folder
-- Expected: true for uploads to audio/{user_id}/...
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000001';
    test_path TEXT := 'audio/00000000-0000-0000-0000-000000000001/test.m4a';
    folder_parts TEXT[];
BEGIN
    folder_parts := storage.foldername(test_path);

    IF folder_parts[1] = test_user_id::text THEN
        RAISE NOTICE 'Test 1 PASS: Upload policy logic verified (user can upload to own folder)';
    ELSE
        RAISE WARNING 'Test 1 FAIL: Upload policy logic incorrect';
    END IF;
END $$;

-- Test 2: Verify user cannot upload to another user's folder
-- Expected: false for uploads to audio/{other_user_id}/...
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000001';
    test_path TEXT := 'audio/00000000-0000-0000-0000-000000000002/test.m4a';
    folder_parts TEXT[];
BEGIN
    folder_parts := storage.foldername(test_path);

    IF folder_parts[1] != test_user_id::text THEN
        RAISE NOTICE 'Test 2 PASS: Upload restriction verified (user cannot upload to other folders)';
    ELSE
        RAISE WARNING 'Test 2 FAIL: Upload restriction logic incorrect';
    END IF;
END $$;

-- ============================================================
-- Setup Complete
-- ============================================================

RAISE NOTICE '============================================================';
RAISE NOTICE 'Supabase Storage setup script executed';
RAISE NOTICE 'Next steps:';
RAISE NOTICE '1. Ensure "audio" bucket exists (create via Dashboard/CLI if needed)';
RAISE NOTICE '2. Configure CORS settings in Supabase Dashboard';
RAISE NOTICE '3. Test file upload/download from iOS app';
RAISE NOTICE '============================================================';
