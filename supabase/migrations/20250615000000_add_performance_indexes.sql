-- Migration: Performance Optimization Indexes
-- Created: 2025-06-15
-- Description: Add indexes to improve query performance for spatial queries, JOINs, and sorting

-- ============================================================
-- 1. Spatial Index (CRITICAL - Highest Priority)
-- ============================================================
-- This index dramatically improves nearby_posts queries using ST_DWithin
-- Without this index, spatial queries perform full table scans
CREATE INDEX IF NOT EXISTS idx_posts_location_gist
ON public.posts USING GIST (location);

COMMENT ON INDEX idx_posts_location_gist IS
'Spatial index for efficient nearby posts queries using ST_DWithin';

-- ============================================================
-- 2. Foreign Key Indexes (High Priority)
-- ============================================================
-- These indexes improve JOIN performance and foreign key constraint checks

-- Posts table
CREATE INDEX IF NOT EXISTS idx_posts_user_id
ON public.posts (user_id);

COMMENT ON INDEX idx_posts_user_id IS
'Index for joining posts with users';

-- Comments table
CREATE INDEX IF NOT EXISTS idx_comments_post_id
ON public.comments (post_id);

CREATE INDEX IF NOT EXISTS idx_comments_user_id
ON public.comments (user_id);

COMMENT ON INDEX idx_comments_post_id IS
'Index for fetching comments by post';

COMMENT ON INDEX idx_comments_user_id IS
'Index for fetching comments by user';

-- Likes table
CREATE INDEX IF NOT EXISTS idx_likes_post_id
ON public.likes (post_id);

CREATE INDEX IF NOT EXISTS idx_likes_user_id
ON public.likes (user_id);

COMMENT ON INDEX idx_likes_post_id IS
'Index for fetching likes by post';

COMMENT ON INDEX idx_likes_user_id IS
'Index for fetching likes by user';

-- ============================================================
-- 3. Sorting Indexes (Medium Priority)
-- ============================================================
-- These indexes improve ORDER BY created_at DESC queries

CREATE INDEX IF NOT EXISTS idx_posts_created_at
ON public.posts (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_comments_created_at
ON public.comments (created_at DESC);

COMMENT ON INDEX idx_posts_created_at IS
'Index for sorting posts by creation time';

COMMENT ON INDEX idx_comments_created_at IS
'Index for sorting comments by creation time';

-- ============================================================
-- 4. Composite Indexes (Optional - For Filtered Queries)
-- ============================================================
-- These indexes improve queries that filter by category or urgency

CREATE INDEX IF NOT EXISTS idx_posts_category_created_at
ON public.posts (category, created_at DESC);

COMMENT ON INDEX idx_posts_category_created_at IS
'Composite index for category-filtered queries sorted by time';

-- Partial index for urgent posts (smaller, more efficient)
CREATE INDEX IF NOT EXISTS idx_posts_is_urgent_created_at
ON public.posts (is_urgent, created_at DESC)
WHERE is_urgent = true;

COMMENT ON INDEX idx_posts_is_urgent_created_at IS
'Partial index for urgent posts sorted by time';

-- ============================================================
-- 5. Unique Constraint (Data Integrity)
-- ============================================================
-- Prevent duplicate likes from the same user on the same post

CREATE UNIQUE INDEX IF NOT EXISTS idx_likes_user_post_unique
ON public.likes (user_id, post_id);

COMMENT ON INDEX idx_likes_user_post_unique IS
'Unique constraint to prevent duplicate likes';

-- ============================================================
-- 6. Analyze Tables (Optional - Update Statistics)
-- ============================================================
-- Update table statistics for the query planner

ANALYZE public.posts;
ANALYZE public.users;
ANALYZE public.comments;
ANALYZE public.likes;
