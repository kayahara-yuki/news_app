-- Migration: Add comment_id support to likes table
-- Date: 2025-10-20
-- Description: Extend likes table to support both post likes and comment likes

-- Step 1: Add comment_id column
ALTER TABLE likes ADD COLUMN IF NOT EXISTS comment_id UUID REFERENCES comments(id) ON DELETE CASCADE;

-- Step 2: Make post_id nullable (if it's currently NOT NULL)
ALTER TABLE likes ALTER COLUMN post_id DROP NOT NULL;

-- Step 3: Add constraint to ensure either post_id or comment_id is set (but not both)
ALTER TABLE likes ADD CONSTRAINT likes_target_check
  CHECK (
    (post_id IS NOT NULL AND comment_id IS NULL) OR
    (post_id IS NULL AND comment_id IS NOT NULL)
  );

-- Step 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_likes_comment_id ON likes(comment_id);

-- Step 5: Create unique constraint for user + comment (prevent duplicate likes)
CREATE UNIQUE INDEX IF NOT EXISTS idx_likes_user_comment
  ON likes(user_id, comment_id)
  WHERE comment_id IS NOT NULL;

-- Step 6: Update existing unique constraint name for clarity (optional)
-- The existing constraint "likes_user_id_post_id_key" should remain for post likes

-- Verification queries (optional - comment out if not needed)
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'likes';

-- SELECT constraint_name, constraint_type
-- FROM information_schema.table_constraints
-- WHERE table_name = 'likes';
