-- Location News SNS Database Schema
-- PostgreSQL with PostGIS extension for spatial data

-- Enable PostGIS extension for spatial data
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User profiles table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    bio TEXT,
    avatar_url TEXT,
    location TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    role TEXT DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin', 'official')),
    privacy_settings JSONB DEFAULT '{
        "locationSharing": true,
        "locationPrecision": "city",
        "profileVisibility": "public",
        "emergencyOverride": true
    }',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Posts table
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    url TEXT,
    url_metadata JSONB,
    category TEXT DEFAULT 'other' CHECK (category IN ('news', 'event', 'emergency', 'traffic', 'weather', 'social', 'business', 'other')),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    is_urgent BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    visibility TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'followers', 'private')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Emergency events table
CREATE TABLE IF NOT EXISTS emergency_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('earthquake', 'tsunami', 'flood', 'fire', 'storm', 'evacuation', 'other')),
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius DOUBLE PRECISION DEFAULT 1000, -- meters
    is_active BOOLEAN DEFAULT TRUE,
    source_agency TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Shelters table
CREATE TABLE IF NOT EXISTS shelters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    capacity INTEGER NOT NULL DEFAULT 0,
    current_occupancy INTEGER DEFAULT 0,
    facilities TEXT[] DEFAULT '{}',
    contact_phone TEXT,
    is_operational BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Comments table
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    like_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Likes table
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- Follows table
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK(follower_id != following_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_posts_location ON posts USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);
CREATE INDEX IF NOT EXISTS idx_emergency_events_location ON emergency_events USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_emergency_events_active ON emergency_events(is_active);
CREATE INDEX IF NOT EXISTS idx_shelters_location ON shelters USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_shelters_operational ON shelters(is_operational);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- RLS (Row Level Security) policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- Users can read their own data
CREATE POLICY "Users can read own data" ON users
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own data
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Posts are publicly readable
CREATE POLICY "Posts are publicly readable" ON posts
    FOR SELECT USING (true);

-- Users can create their own posts
CREATE POLICY "Users can create own posts" ON posts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own posts
CREATE POLICY "Users can update own posts" ON posts
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own posts
CREATE POLICY "Users can delete own posts" ON posts
    FOR DELETE USING (auth.uid() = user_id);

-- Comments are publicly readable
CREATE POLICY "Comments are publicly readable" ON comments
    FOR SELECT USING (true);

-- Users can create comments
CREATE POLICY "Users can create comments" ON comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own comments
CREATE POLICY "Users can update own comments" ON comments
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own comments
CREATE POLICY "Users can delete own comments" ON comments
    FOR DELETE USING (auth.uid() = user_id);

-- Likes are publicly readable
CREATE POLICY "Likes are publicly readable" ON likes
    FOR SELECT USING (true);

-- Users can manage their own likes
CREATE POLICY "Users can manage own likes" ON likes
    FOR ALL USING (auth.uid() = user_id);

-- Follows are publicly readable
CREATE POLICY "Follows are publicly readable" ON follows
    FOR SELECT USING (true);

-- Users can manage their own follows
CREATE POLICY "Users can manage own follows" ON follows
    FOR ALL USING (auth.uid() = follower_id);

-- Create functions for spatial queries
CREATE OR REPLACE FUNCTION nearby_posts(lat DOUBLE PRECISION, lng DOUBLE PRECISION, radius_meters DOUBLE PRECISION)
RETURNS TABLE(
    id UUID,
    user_id UUID,
    content TEXT,
    category TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE
) LANGUAGE sql STABLE AS $$
    SELECT 
        p.id,
        p.user_id,
        p.content,
        p.category,
        p.latitude,
        p.longitude,
        ST_Distance(p.location, ST_Point(lng, lat)::geography) as distance_meters,
        p.created_at
    FROM posts p
    WHERE ST_DWithin(p.location, ST_Point(lng, lat)::geography, radius_meters)
    ORDER BY distance_meters, p.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION nearby_emergency_events(lat DOUBLE PRECISION, lng DOUBLE PRECISION, radius_meters DOUBLE PRECISION)
RETURNS TABLE(
    id UUID,
    title TEXT,
    description TEXT,
    event_type TEXT,
    severity TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE
) LANGUAGE sql STABLE AS $$
    SELECT 
        e.id,
        e.title,
        e.description,
        e.event_type,
        e.severity,
        e.latitude,
        e.longitude,
        ST_Distance(e.location, ST_Point(lng, lat)::geography) as distance_meters,
        e.created_at
    FROM emergency_events e
    WHERE e.is_active = true
    AND ST_DWithin(e.location, ST_Point(lng, lat)::geography, radius_meters)
    ORDER BY distance_meters, e.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION nearby_shelters(lat DOUBLE PRECISION, lng DOUBLE PRECISION, radius_meters DOUBLE PRECISION)
RETURNS TABLE(
    id UUID,
    name TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    capacity INTEGER,
    current_occupancy INTEGER,
    distance_meters DOUBLE PRECISION
) LANGUAGE sql STABLE AS $$
    SELECT 
        s.id,
        s.name,
        s.address,
        s.latitude,
        s.longitude,
        s.capacity,
        s.current_occupancy,
        ST_Distance(s.location, ST_Point(lng, lat)::geography) as distance_meters
    FROM shelters s
    WHERE s.is_operational = true
    AND ST_DWithin(s.location, ST_Point(lng, lat)::geography, radius_meters)
    ORDER BY distance_meters;
$$;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at BEFORE UPDATE ON posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_emergency_events_updated_at BEFORE UPDATE ON emergency_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shelters_updated_at BEFORE UPDATE ON shelters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();