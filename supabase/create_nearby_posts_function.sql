-- ============================================
-- PostGIS Nearby Posts Function
-- ============================================
-- This script creates a function to find posts near a given location
-- Execute this in Supabase Dashboard SQL Editor

-- ============================================
-- nearby_posts function
-- ============================================
-- Parameters:
--   lat: Latitude of search location
--   lng: Longitude of search location
--   radius_meters: Search radius in meters (default: 5000m = 5km)
--   max_results: Maximum number of results to return (default: 50)
-- Returns: Posts within the specified radius, ordered by distance

CREATE OR REPLACE FUNCTION nearby_posts(
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  radius_meters INTEGER DEFAULT 5000,
  max_results INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  content TEXT,
  url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address TEXT,
  category TEXT,
  visibility TEXT,
  is_urgent BOOLEAN,
  is_verified BOOLEAN,
  like_count INTEGER,
  comment_count INTEGER,
  share_count INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  distance_meters DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    p.content,
    p.url,
    p.latitude,
    p.longitude,
    p.address,
    p.category,
    p.visibility,
    p.is_urgent,
    p.is_verified,
    p.like_count,
    p.comment_count,
    p.share_count,
    p.created_at,
    p.updated_at,
    ST_Distance(
      p.location,
      ST_GeogFromText('POINT(' || lng || ' ' || lat || ')')
    ) AS distance_meters
  FROM public.posts p
  WHERE
    p.location IS NOT NULL
    AND ST_DWithin(
      p.location,
      ST_GeogFromText('POINT(' || lng || ' ' || lat || ')'),
      radius_meters
    )
    -- Apply RLS: Only return posts user can see
    AND (
      p.visibility = 'public'
      OR p.user_id = auth.uid()
      OR (
        p.visibility = 'followers' AND EXISTS (
          SELECT 1 FROM public.follows
          WHERE follower_id = auth.uid() AND following_id = p.user_id
        )
      )
    )
  ORDER BY distance_meters ASC
  LIMIT max_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- Grant execute permission
-- ============================================

GRANT EXECUTE ON FUNCTION nearby_posts(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION nearby_posts(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, INTEGER) TO authenticated;

-- ============================================
-- Test query
-- ============================================
-- Example: Find posts within 5km of Tokyo Station (35.6812, 139.7671)
-- SELECT * FROM nearby_posts(35.6812, 139.7671, 5000, 20);

-- ============================================
-- nearby_posts_with_user function (includes user data)
-- ============================================
-- This version joins with users table to return complete post data with user info
-- Matches the iOS app's expected data structure

CREATE OR REPLACE FUNCTION nearby_posts_with_user(
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  radius_meters INTEGER DEFAULT 5000,
  max_results INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  username TEXT,
  display_name TEXT,
  avatar_url TEXT,
  is_verified BOOLEAN,
  user_role TEXT,
  content TEXT,
  url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address TEXT,
  category TEXT,
  visibility TEXT,
  is_urgent BOOLEAN,
  post_is_verified BOOLEAN,
  like_count INTEGER,
  comment_count INTEGER,
  share_count INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  distance_meters DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.is_verified,
    u.role AS user_role,
    p.content,
    p.url,
    p.latitude,
    p.longitude,
    p.address,
    p.category,
    p.visibility,
    p.is_urgent,
    p.is_verified AS post_is_verified,
    p.like_count,
    p.comment_count,
    p.share_count,
    p.created_at,
    p.updated_at,
    ST_Distance(
      p.location,
      ST_GeogFromText('POINT(' || lng || ' ' || lat || ')')
    ) AS distance_meters
  FROM public.posts p
  INNER JOIN public.users u ON p.user_id = u.id
  WHERE
    p.location IS NOT NULL
    -- Filter to posts from the last 7 days
    AND p.created_at >= NOW() - INTERVAL '7 days'
    -- Apply RLS: Only return posts user can see
    AND (
      p.visibility = 'public'
      OR p.user_id = auth.uid()
      OR (
        p.visibility = 'followers' AND EXISTS (
          SELECT 1 FROM public.follows
          WHERE follower_id = auth.uid() AND following_id = p.user_id
        )
      )
    )
  ORDER BY distance_meters ASC
  LIMIT max_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- Grant execute permission
-- ============================================

GRANT EXECUTE ON FUNCTION nearby_posts_with_user(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION nearby_posts_with_user(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, INTEGER) TO authenticated;

-- ============================================
-- Verification
-- ============================================
-- Check that functions are created:
-- SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE 'nearby_posts%';
