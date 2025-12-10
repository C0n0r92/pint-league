-- Pints League Database Schema
-- Initial migration with all tables, functions, triggers, and RLS policies

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================
-- TABLES
-- ============================================

-- Profiles (extends Supabase auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    home_city TEXT,
    country TEXT DEFAULT 'GB',
    total_pints INTEGER DEFAULT 0,
    total_points INTEGER DEFAULT 0,
    unique_pubs_count INTEGER DEFAULT 0,
    auto_confirm_high_confidence BOOLEAN DEFAULT false,
    gdpr_consent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pubs
CREATE TABLE public.pubs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    osm_id BIGINT UNIQUE,
    google_place_id TEXT,
    name TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    address TEXT,
    city TEXT,
    country TEXT DEFAULT 'GB',
    categories TEXT[] DEFAULT '{}',
    photo_url TEXT,
    rating DECIMAL(2,1),
    price_level INTEGER,
    opening_hours JSONB,
    popularity_score INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sessions (detected pub visits)
CREATE TABLE public.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    pub_id UUID REFERENCES public.pubs(id),
    pub_name TEXT,
    start_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_at TIMESTAMPTZ,
    duration_minutes INTEGER,
    estimated_pints INTEGER,
    source TEXT NOT NULL CHECK (source IN ('geo', 'bank', 'manual')),
    confidence TEXT DEFAULT 'medium' CHECK (confidence IN ('low', 'medium', 'high')),
    verified BOOLEAN DEFAULT false,
    discarded BOOLEAN DEFAULT false,
    bank_transaction_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pints (logged drinks)
CREATE TABLE public.pints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    pub_id UUID REFERENCES public.pubs(id),
    pub_name TEXT,
    session_id UUID REFERENCES public.sessions(id),
    drink_type TEXT DEFAULT 'pint',
    quantity INTEGER DEFAULT 1,
    photo_url TEXT,
    friends_tagged UUID[],
    source TEXT DEFAULT 'manual' CHECK (source IN ('manual', 'geo_auto', 'bank_auto')),
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Leagues
CREATE TABLE public.leagues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    code TEXT UNIQUE,
    creator_id UUID NOT NULL REFERENCES public.profiles(id),
    is_public BOOLEAN DEFAULT false,
    member_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- League Members
CREATE TABLE public.league_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    league_id UUID NOT NULL REFERENCES public.leagues(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rank INTEGER DEFAULT 0,
    total_points INTEGER DEFAULT 0,
    weekly_points INTEGER DEFAULT 0,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(league_id, user_id)
);

-- Weekly Points (calculated scoring)
CREATE TABLE public.weekly_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    total_points INTEGER DEFAULT 0,
    breakdown JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, week_start)
);

-- Friendships
CREATE TABLE public.friendships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, friend_id)
);

-- Bank Connections (TrueLayer)
CREATE TABLE public.bank_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT DEFAULT 'truelayer',
    access_token_encrypted TEXT,
    refresh_token_encrypted TEXT,
    expires_at TIMESTAMPTZ,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'revoked')),
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Bank Transactions
CREATE TABLE public.bank_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    transaction_id TEXT NOT NULL,
    merchant_name TEXT,
    amount DECIMAL(10,2),
    currency TEXT DEFAULT 'GBP',
    transaction_at TIMESTAMPTZ,
    matched_pub_id UUID REFERENCES public.pubs(id),
    match_confidence DECIMAL(3,2),
    processed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, transaction_id)
);

-- Achievements
CREATE TABLE public.achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    category TEXT,
    points INTEGER DEFAULT 0,
    criteria JSONB DEFAULT '{}'
);

-- User Achievements
CREATE TABLE public.user_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES public.achievements(id),
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

-- Device Tokens (for push notifications)
CREATE TABLE public.device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT CHECK (platform IN ('ios', 'android', 'web')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Phone Hashes (for friend discovery)
CREATE TABLE public.phone_hashes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    phone_hash TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

-- Spatial index for pub location queries
CREATE INDEX pubs_location_idx ON public.pubs USING GIST(location);

-- Full-text search index for pubs
CREATE INDEX pubs_name_search_idx ON public.pubs USING GIN(to_tsvector('english', name));

-- Common query indexes
CREATE INDEX sessions_user_id_idx ON public.sessions(user_id);
CREATE INDEX sessions_start_at_idx ON public.sessions(start_at DESC);
CREATE INDEX pints_user_id_idx ON public.pints(user_id);
CREATE INDEX pints_logged_at_idx ON public.pints(logged_at DESC);
CREATE INDEX league_members_league_id_idx ON public.league_members(league_id);
CREATE INDEX league_members_user_id_idx ON public.league_members(user_id);
CREATE INDEX friendships_user_id_idx ON public.friendships(user_id);
CREATE INDEX weekly_points_user_week_idx ON public.weekly_points(user_id, week_start);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Generate unique league code
CREATE OR REPLACE FUNCTION generate_league_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Find nearby pubs
CREATE OR REPLACE FUNCTION nearby_pubs(user_lat DOUBLE PRECISION, user_lng DOUBLE PRECISION, radius_m INTEGER DEFAULT 500)
RETURNS TABLE (
    id UUID,
    name TEXT,
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    address TEXT,
    city TEXT,
    distance_m DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.lat,
        p.lng,
        p.address,
        p.city,
        ST_Distance(
            p.location::geography,
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
        ) as distance_m
    FROM public.pubs p
    WHERE ST_DWithin(
        p.location::geography,
        ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
        radius_m
    )
    ORDER BY distance_m
    LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Search pubs by name
CREATE OR REPLACE FUNCTION search_pubs(search_query TEXT, limit_count INTEGER DEFAULT 20)
RETURNS TABLE (
    id UUID,
    name TEXT,
    address TEXT,
    city TEXT,
    country TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.address,
        p.city,
        p.country
    FROM public.pubs p
    WHERE to_tsvector('english', p.name) @@ plainto_tsquery('english', search_query)
       OR p.name ILIKE '%' || search_query || '%'
    ORDER BY 
        CASE WHEN p.name ILIKE search_query || '%' THEN 0 ELSE 1 END,
        p.popularity_score DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Find friends by phone hashes
CREATE OR REPLACE FUNCTION find_friends_by_phone_hashes(hashes TEXT[])
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    display_name TEXT,
    avatar_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as user_id,
        p.username,
        p.display_name,
        p.avatar_url
    FROM public.phone_hashes ph
    JOIN public.profiles p ON p.id = ph.user_id
    WHERE ph.phone_hash = ANY(hashes)
    AND ph.user_id != auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get friends activity feed
CREATE OR REPLACE FUNCTION get_friends_activity(limit_count INTEGER DEFAULT 20)
RETURNS TABLE (
    pint_id UUID,
    user_id UUID,
    username TEXT,
    avatar_url TEXT,
    pub_name TEXT,
    quantity INTEGER,
    logged_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pt.id as pint_id,
        pt.user_id,
        pr.username,
        pr.avatar_url,
        pt.pub_name,
        pt.quantity,
        pt.logged_at
    FROM public.pints pt
    JOIN public.profiles pr ON pr.id = pt.user_id
    WHERE pt.user_id IN (
        SELECT f.friend_id FROM public.friendships f 
        WHERE f.user_id = auth.uid() AND f.status = 'accepted'
    )
    ORDER BY pt.logged_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- TRIGGERS
-- ============================================

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Auto-generate league code
CREATE OR REPLACE FUNCTION set_league_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.code IS NULL THEN
        LOOP
            NEW.code := generate_league_code();
            EXIT WHEN NOT EXISTS (SELECT 1 FROM public.leagues WHERE code = NEW.code);
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_league_insert
    BEFORE INSERT ON public.leagues
    FOR EACH ROW EXECUTE FUNCTION set_league_code();

-- Update league member count
CREATE OR REPLACE FUNCTION update_league_member_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.leagues SET member_count = member_count + 1 WHERE id = NEW.league_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.leagues SET member_count = member_count - 1 WHERE id = OLD.league_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_league_member_change
    AFTER INSERT OR DELETE ON public.league_members
    FOR EACH ROW EXECUTE FUNCTION update_league_member_count();

-- Update pub popularity on pint logged
CREATE OR REPLACE FUNCTION update_pub_popularity()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pub_id IS NOT NULL THEN
        UPDATE public.pubs 
        SET popularity_score = popularity_score + 1 
        WHERE id = NEW.pub_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_pint_logged
    AFTER INSERT ON public.pints
    FOR EACH ROW EXECUTE FUNCTION update_pub_popularity();

-- Update profile stats on pint logged
CREATE OR REPLACE FUNCTION update_profile_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles 
    SET 
        total_pints = total_pints + NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_pint_logged_update_stats
    AFTER INSERT ON public.pints
    FOR EACH ROW EXECUTE FUNCTION update_profile_stats();

-- Auto-set location geography from lat/lng
CREATE OR REPLACE FUNCTION set_pub_location()
RETURNS TRIGGER AS $$
BEGIN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326)::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_pub_insert_update
    BEFORE INSERT OR UPDATE ON public.pubs
    FOR EACH ROW EXECUTE FUNCTION set_pub_location();

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.phone_hashes ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view any profile" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Pubs policies (publicly readable)
CREATE POLICY "Anyone can view pubs" ON public.pubs FOR SELECT USING (true);
CREATE POLICY "Service role can manage pubs" ON public.pubs FOR ALL USING (auth.role() = 'service_role');

-- Sessions policies
CREATE POLICY "Users can view own sessions" ON public.sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own sessions" ON public.sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own sessions" ON public.sessions FOR UPDATE USING (auth.uid() = user_id);

-- Pints policies
CREATE POLICY "Users can view own pints" ON public.pints FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view friends pints" ON public.pints FOR SELECT USING (
    user_id IN (SELECT friend_id FROM public.friendships WHERE user_id = auth.uid() AND status = 'accepted')
);
CREATE POLICY "Users can insert own pints" ON public.pints FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own pints" ON public.pints FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own pints" ON public.pints FOR DELETE USING (auth.uid() = user_id);

-- Leagues policies
CREATE POLICY "Anyone can view public leagues" ON public.leagues FOR SELECT USING (is_public = true);
CREATE POLICY "Members can view their leagues" ON public.leagues FOR SELECT USING (
    id IN (SELECT league_id FROM public.league_members WHERE user_id = auth.uid())
);
CREATE POLICY "Users can create leagues" ON public.leagues FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Creator can update league" ON public.leagues FOR UPDATE USING (auth.uid() = creator_id);

-- League members policies
CREATE POLICY "Members can view league members" ON public.league_members FOR SELECT USING (
    league_id IN (SELECT league_id FROM public.league_members WHERE user_id = auth.uid())
);
CREATE POLICY "Users can join leagues" ON public.league_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave leagues" ON public.league_members FOR DELETE USING (auth.uid() = user_id);

-- Weekly points policies
CREATE POLICY "Users can view own weekly points" ON public.weekly_points FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "League members can view others weekly points" ON public.weekly_points FOR SELECT USING (
    user_id IN (
        SELECT lm.user_id FROM public.league_members lm
        WHERE lm.league_id IN (SELECT league_id FROM public.league_members WHERE user_id = auth.uid())
    )
);

-- Friendships policies
CREATE POLICY "Users can view own friendships" ON public.friendships FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "Users can create friendships" ON public.friendships FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update friendships they're part of" ON public.friendships FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "Users can delete own friendships" ON public.friendships FOR DELETE USING (auth.uid() = user_id);

-- Bank connections policies
CREATE POLICY "Users can view own bank connections" ON public.bank_connections FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own bank connections" ON public.bank_connections FOR ALL USING (auth.uid() = user_id);

-- Bank transactions policies  
CREATE POLICY "Users can view own transactions" ON public.bank_transactions FOR SELECT USING (auth.uid() = user_id);

-- Achievements policies
CREATE POLICY "Anyone can view achievements" ON public.achievements FOR SELECT USING (true);

-- User achievements policies
CREATE POLICY "Users can view own achievements" ON public.user_achievements FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view others achievements" ON public.user_achievements FOR SELECT USING (true);

-- Device tokens policies
CREATE POLICY "Users can manage own tokens" ON public.device_tokens FOR ALL USING (auth.uid() = user_id);

-- Phone hashes policies
CREATE POLICY "Users can manage own phone hash" ON public.phone_hashes FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- SEED DATA: Achievements
-- ============================================

INSERT INTO public.achievements (code, name, description, icon, category, points, criteria) VALUES
('first_pint', 'First Pint', 'Log your first pint', '🍺', 'milestone', 10, '{"pints_count": 1}'),
('pub_explorer', 'Pub Explorer', 'Visit 10 different pubs', '🗺️', 'exploration', 50, '{"unique_pubs": 10}'),
('pub_master', 'Pub Master', 'Visit 50 different pubs', '👑', 'exploration', 200, '{"unique_pubs": 50}'),
('century', 'Century', 'Log 100 pints', '💯', 'milestone', 100, '{"pints_count": 100}'),
('social_butterfly', 'Social Butterfly', 'Add 10 friends', '🦋', 'social', 30, '{"friends_count": 10}'),
('pub_crawl', 'Pub Crawler', 'Visit 3 pubs in one day', '🚶', 'special', 25, '{"pubs_in_day": 3}'),
('league_champion', 'League Champion', 'Win a league', '🏆', 'competition', 100, '{"league_wins": 1}'),
('monday_warrior', 'Monday Warrior', 'Log a pint on a Monday', '💪', 'special', 15, '{"monday_pint": true}'),
('verified_drinker', 'Verified Drinker', 'Connect your bank account', '✅', 'verification', 20, '{"bank_connected": true}'),
('streak_3', 'Hat Trick', '3 day logging streak', '🎩', 'streak', 15, '{"streak_days": 3}'),
('streak_7', 'Week Warrior', '7 day logging streak', '📅', 'streak', 50, '{"streak_days": 7}'),
('streak_30', 'Monthly Master', '30 day logging streak', '📆', 'streak', 200, '{"streak_days": 30}');

-- ============================================
-- STORAGE BUCKETS (run in Supabase dashboard)
-- ============================================
-- Note: Execute these in Supabase SQL Editor or use Storage API
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('pint-photos', 'pint-photos', true);

