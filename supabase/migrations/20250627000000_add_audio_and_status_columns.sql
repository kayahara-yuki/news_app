-- Migration: Add Audio and Status Post Support
-- Created: 2025-06-27
-- Feature: viral-quick-win-features
-- Description: Add audio_url, is_status_post, and expires_at columns to posts table
--              to support audio message posts and temporary status posts

-- ============================================================
-- 1. Add New Columns to Posts Table
-- ============================================================

-- Add audio_url column for storing Supabase Storage audio file URLs
ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS audio_url TEXT;

COMMENT ON COLUMN public.posts.audio_url IS
'URL of the audio file stored in Supabase Storage (audio bucket)';

-- Add is_status_post flag for temporary status posts (auto-deleted after 3 hours)
ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS is_status_post BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.posts.is_status_post IS
'Flag indicating if this is a temporary status post (e.g., "カフェなう")';

-- Add expires_at timestamp for auto-deletion scheduling
ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN public.posts.expires_at IS
'Scheduled deletion time for status posts (created_at + 3 hours for status posts)';

-- ============================================================
-- 2. Performance Index for Auto-Deletion Queries
-- ============================================================

-- Partial index for efficient status post expiration queries
-- Only indexes rows where is_status_post=true and expires_at is not null
CREATE INDEX IF NOT EXISTS idx_posts_expires_at
ON public.posts (expires_at)
WHERE is_status_post = true AND expires_at IS NOT NULL;

COMMENT ON INDEX idx_posts_expires_at IS
'Partial index for efficient auto-deletion queries of expired status posts';

-- ============================================================
-- 3. Verification Queries (For Testing)
-- ============================================================

-- Verify new columns exist
DO $$
BEGIN
    -- Check audio_url column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'posts'
        AND column_name = 'audio_url'
    ) THEN
        RAISE EXCEPTION 'Column audio_url was not created';
    END IF;

    -- Check is_status_post column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'posts'
        AND column_name = 'is_status_post'
    ) THEN
        RAISE EXCEPTION 'Column is_status_post was not created';
    END IF;

    -- Check expires_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'posts'
        AND column_name = 'expires_at'
    ) THEN
        RAISE EXCEPTION 'Column expires_at was not created';
    END IF;

    -- Verify index was created
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
        AND tablename = 'posts'
        AND indexname = 'idx_posts_expires_at'
    ) THEN
        RAISE EXCEPTION 'Index idx_posts_expires_at was not created';
    END IF;

    RAISE NOTICE 'Migration verification successful: All columns and indexes created';
END $$;

-- ============================================================
-- 4. Test Existing Data Compatibility
-- ============================================================

-- Verify that existing posts are not affected (all new columns should be NULL/FALSE)
DO $$
DECLARE
    existing_posts_count INTEGER;
    posts_with_audio_url INTEGER;
    status_posts_count INTEGER;
    posts_with_expires_at INTEGER;
BEGIN
    SELECT COUNT(*) INTO existing_posts_count FROM public.posts;

    IF existing_posts_count > 0 THEN
        SELECT COUNT(*) INTO posts_with_audio_url
        FROM public.posts WHERE audio_url IS NOT NULL;

        SELECT COUNT(*) INTO status_posts_count
        FROM public.posts WHERE is_status_post = true;

        SELECT COUNT(*) INTO posts_with_expires_at
        FROM public.posts WHERE expires_at IS NOT NULL;

        IF posts_with_audio_url > 0 THEN
            RAISE WARNING 'Found % existing posts with audio_url set (expected 0)', posts_with_audio_url;
        END IF;

        IF status_posts_count > 0 THEN
            RAISE WARNING 'Found % existing posts marked as status posts (expected 0)', status_posts_count;
        END IF;

        IF posts_with_expires_at > 0 THEN
            RAISE WARNING 'Found % existing posts with expires_at set (expected 0)', posts_with_expires_at;
        END IF;

        RAISE NOTICE 'Existing data compatibility check: % existing posts remain unchanged', existing_posts_count;
    ELSE
        RAISE NOTICE 'No existing posts found - fresh database';
    END IF;
END $$;

-- ============================================================
-- 5. Update Table Statistics
-- ============================================================

ANALYZE public.posts;

-- ============================================================
-- Migration Complete
-- ============================================================
