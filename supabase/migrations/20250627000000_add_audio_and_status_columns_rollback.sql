-- Rollback Migration: Remove Audio and Status Post Support
-- Created: 2025-06-27
-- Feature: viral-quick-win-features
-- Description: Rollback script to remove audio_url, is_status_post, and expires_at columns

-- ============================================================
-- WARNING: This is a destructive operation
-- ============================================================
-- This rollback will permanently delete:
-- - All audio_url references
-- - All is_status_post flags
-- - All expires_at timestamps
--
-- Audio files in Supabase Storage will NOT be automatically deleted.
-- Manual cleanup of the audio bucket may be required.
-- ============================================================

-- ============================================================
-- 1. Drop Index
-- ============================================================

DROP INDEX IF EXISTS public.idx_posts_expires_at;

-- ============================================================
-- 2. Remove Columns
-- ============================================================

ALTER TABLE public.posts
DROP COLUMN IF EXISTS audio_url;

ALTER TABLE public.posts
DROP COLUMN IF EXISTS is_status_post;

ALTER TABLE public.posts
DROP COLUMN IF EXISTS expires_at;

-- ============================================================
-- 3. Verification
-- ============================================================

DO $$
BEGIN
    -- Verify columns are removed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'posts'
        AND column_name IN ('audio_url', 'is_status_post', 'expires_at')
    ) THEN
        RAISE EXCEPTION 'Rollback failed: Columns still exist';
    END IF;

    -- Verify index is removed
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
        AND tablename = 'posts'
        AND indexname = 'idx_posts_expires_at'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: Index still exists';
    END IF;

    RAISE NOTICE 'Rollback successful: All columns and indexes removed';
END $$;

-- ============================================================
-- 4. Update Table Statistics
-- ============================================================

ANALYZE public.posts;

-- ============================================================
-- Rollback Complete
-- ============================================================

RAISE NOTICE 'REMINDER: Audio files in Supabase Storage must be manually cleaned up if needed';
