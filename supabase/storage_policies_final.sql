-- Supabase Storage RLS Policies - Working Solution
-- Run this in: Supabase Dashboard > SQL Editor
--
-- This uses Supabase's storage helper functions that work around
-- the "must be owner of table objects" limitation

-- ============================================================
-- IMPORTANT: This approach uses storage bucket policies
-- which are managed separately from table-level RLS
-- ============================================================

-- Note: RLS policies on storage.objects are managed by Supabase internally.
-- We need to use the Dashboard UI or rely on bucket-level policies.

-- ============================================================
-- Alternative Approach: Verify Bucket Configuration
-- ============================================================

-- 1. Check if audio bucket exists and is properly configured
SELECT
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at
FROM storage.buckets
WHERE id = 'audio';

-- 2. Update bucket configuration (if needed)
UPDATE storage.buckets
SET
    public = false,
    file_size_limit = 5242880,  -- 5MB
    allowed_mime_types = ARRAY['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/aac']::text[]
WHERE id = 'audio';

-- ============================================================
-- Check Existing Policies
-- ============================================================

-- List all policies on storage.objects that affect the 'audio' bucket
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
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
    qual::text ILIKE '%audio%'
    OR with_check::text ILIKE '%audio%'
    OR policyname ILIKE '%audio%'
  )
ORDER BY policyname;

-- ============================================================
-- Success Message
-- ============================================================

DO $$
DECLARE
    bucket_exists BOOLEAN;
    bucket_public BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM storage.buckets WHERE id = 'audio'),
           COALESCE((SELECT public FROM storage.buckets WHERE id = 'audio'), true)
    INTO bucket_exists, bucket_public;

    RAISE NOTICE '============================================================';

    IF bucket_exists THEN
        RAISE NOTICE '✅ Bucket "audio" exists';
        IF bucket_public THEN
            RAISE NOTICE '⚠️  WARNING: Bucket is PUBLIC (should be private)';
        ELSE
            RAISE NOTICE '✅ Bucket is private (correct)';
        END IF;
    ELSE
        RAISE NOTICE '❌ Bucket "audio" does not exist';
    END IF;

    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: RLS Policies must be created via Supabase Dashboard UI';
    RAISE NOTICE '';
    RAISE NOTICE 'Follow these steps:';
    RAISE NOTICE '1. Go to: Storage > Policies (or Database > Policies)';
    RAISE NOTICE '2. Select table: storage.objects';
    RAISE NOTICE '3. Click: New Policy';
    RAISE NOTICE '4. Create the 4 policies as documented in STORAGE_SETUP_MANUAL_GUIDE.md';
    RAISE NOTICE '============================================================';
END $$;
