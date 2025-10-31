-- ============================================
-- Row Level Security (RLS) Policies Setup
-- ============================================
-- This script sets up RLS policies for all tables
-- Execute this in Supabase Dashboard SQL Editor

-- ============================================
-- 1. Enable RLS on all tables
-- ============================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. Users table policies
-- ============================================

-- Everyone can view user profiles
CREATE POLICY "Users are viewable by everyone"
ON public.users
FOR SELECT
USING (true);

-- Users can insert their own profile (during signup)
CREATE POLICY "Users can insert their own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Only moderators and admins can delete users
CREATE POLICY "Moderators and admins can delete users"
ON public.users
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

-- ============================================
-- 3. Posts table policies
-- ============================================

-- Everyone can view public posts
CREATE POLICY "Everyone can view public posts"
ON public.posts
FOR SELECT
USING (
  visibility = 'public'
  OR user_id = auth.uid()
  OR (
    visibility = 'followers' AND EXISTS (
      SELECT 1 FROM public.follows
      WHERE follower_id = auth.uid() AND following_id = user_id
    )
  )
);

-- Authenticated users can create posts
CREATE POLICY "Authenticated users can create posts"
ON public.posts
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own posts
CREATE POLICY "Users can update their own posts"
ON public.posts
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own posts, moderators can delete any post
CREATE POLICY "Users can delete their own posts"
ON public.posts
FOR DELETE
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

-- ============================================
-- 4. Comments table policies
-- ============================================

-- Everyone can view comments on posts they can see
CREATE POLICY "Everyone can view comments"
ON public.comments
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.posts
    WHERE id = post_id
    AND (
      visibility = 'public'
      OR user_id = auth.uid()
      OR (
        visibility = 'followers' AND EXISTS (
          SELECT 1 FROM public.follows
          WHERE follower_id = auth.uid() AND following_id = posts.user_id
        )
      )
    )
  )
);

-- Authenticated users can create comments
CREATE POLICY "Authenticated users can create comments"
ON public.comments
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM public.posts
    WHERE id = post_id
    AND (
      visibility = 'public'
      OR user_id = auth.uid()
      OR (
        visibility = 'followers' AND EXISTS (
          SELECT 1 FROM public.follows
          WHERE follower_id = auth.uid() AND following_id = posts.user_id
        )
      )
    )
  )
);

-- Users can update their own comments
CREATE POLICY "Users can update their own comments"
ON public.comments
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own comments, moderators can delete any comment
CREATE POLICY "Users can delete their own comments"
ON public.comments
FOR DELETE
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role IN ('moderator', 'admin')
  )
);

-- ============================================
-- 5. Likes table policies
-- ============================================

-- Everyone can view likes
CREATE POLICY "Everyone can view likes"
ON public.likes
FOR SELECT
USING (true);

-- Authenticated users can create likes
CREATE POLICY "Authenticated users can create likes"
ON public.likes
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can delete their own likes
CREATE POLICY "Users can delete their own likes"
ON public.likes
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 6. Grant permissions for anon and authenticated roles
-- ============================================

-- Grant SELECT to anon role (for public data access)
GRANT SELECT ON public.users TO anon;
GRANT SELECT ON public.posts TO anon;
GRANT SELECT ON public.comments TO anon;
GRANT SELECT ON public.likes TO anon;

-- Grant all operations to authenticated role
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.posts TO authenticated;
GRANT ALL ON public.comments TO authenticated;
GRANT ALL ON public.likes TO authenticated;

-- ============================================
-- Verification queries
-- ============================================
-- Run these to verify policies are created:
-- SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';
