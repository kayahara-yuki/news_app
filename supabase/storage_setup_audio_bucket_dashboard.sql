-- Supabase Storage Setup: Audio Bucket (Dashboard Version)
-- Created: 2025-06-27
-- Feature: viral-quick-win-features
-- Description: Create audio bucket and configure RLS policies for audio file storage
-- IMPORTANT: Run this script from Supabase Dashboard > SQL Editor (requires postgres role)

-- ============================================================
-- 1. Create Audio Bucket (if not exists)
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'audio',
    'audio',
    false,
    5242880, -- 5MB in bytes
    ARRAY['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/aac']
)
ON CONFLICT (id) DO UPDATE
SET
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/aac'];

-- ============================================================
-- 2. Enable RLS on storage.objects
-- ============================================================

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. Drop existing policies (for idempotency)
-- ============================================================

DROP POLICY IF EXISTS "Users can upload to their own folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can read audio files" ON storage.objects;

-- ============================================================
-- 4. Create RLS Policies
-- ============================================================

-- Policy 1: Users can upload to their own folder
CREATE POLICY "Users can upload to their own folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy 2: Users can update their own files
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
CREATE POLICY "Users can delete their own files"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'audio' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy 4: Anyone can read audio files
CREATE POLICY "Anyone can read audio files"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'audio');

-- ============================================================
-- 5. Verification
-- ============================================================

-- Verify bucket exists
SELECT
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE id = 'audio';

-- Verify RLS policies
SELECT
    policyname as policy_name,
    CASE cmd
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
        WHEN '*' THEN 'ALL'
    END as operation,
    roles
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
-- Success Message
-- ============================================================

DO $$
DECLARE
    bucket_exists BOOLEAN;
    policy_count INTEGER;
BEGIN
    -- Check bucket
    SELECT EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'audio') INTO bucket_exists;

    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname LIKE '%audio%';

    IF bucket_exists AND policy_count >= 4 THEN
        RAISE NOTICE '============================================================';
        RAISE NOTICE '✅ Supabase Storage setup completed successfully!';
        RAISE NOTICE '============================================================';
        RAISE NOTICE 'Bucket: audio (created)';
        RAISE NOTICE 'RLS Policies: % configured', policy_count;
        RAISE NOTICE '';
        RAISE NOTICE 'Next steps:';
        RAISE NOTICE '1. Test file upload from iOS app';
        RAISE NOTICE '2. Verify RLS policies are working correctly';
        RAISE NOTICE '============================================================';
    ELSE
        IF NOT bucket_exists THEN
            RAISE WARNING 'Bucket "audio" was not created';
        END IF;
        IF policy_count < 4 THEN
            RAISE WARNING 'Expected 4 RLS policies, found %', policy_count;
        END IF;
    END IF;
END $$;
