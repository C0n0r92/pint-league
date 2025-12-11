-- Pints League Database Fixes
-- Migration to fix logic bugs identified in code review

-- ============================================
-- FIX 1: Friendships - Bidirectional Query Support
-- The original schema only stored one direction.
-- We need functions that query both directions.
-- ============================================

-- Get all friends for a user (both directions)
CREATE OR REPLACE FUNCTION get_user_friends(target_user_id UUID)
RETURNS TABLE (
    friend_user_id UUID,
    username TEXT,
    display_name TEXT,
    avatar_url TEXT,
    status TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE 
            WHEN f.user_id = target_user_id THEN f.friend_id 
            ELSE f.user_id 
        END as friend_user_id,
        p.username,
        p.display_name,
        p.avatar_url,
        f.status,
        f.created_at
    FROM public.friendships f
    JOIN public.profiles p ON p.id = CASE 
        WHEN f.user_id = target_user_id THEN f.friend_id 
        ELSE f.user_id 
    END
    WHERE (f.user_id = target_user_id OR f.friend_id = target_user_id)
    AND f.status = 'accepted';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get pending friend requests (where current user is the recipient)
CREATE OR REPLACE FUNCTION get_pending_friend_requests(target_user_id UUID)
RETURNS TABLE (
    friendship_id UUID,
    requester_id UUID,
    username TEXT,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.id as friendship_id,
        f.user_id as requester_id,
        p.username,
        p.display_name,
        p.avatar_url,
        f.created_at
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.user_id
    WHERE f.friend_id = target_user_id
    AND f.status = 'pending';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FIX 2: Track unique pubs visited
-- Add trigger to update unique_pubs_count on new pint at new pub
-- ============================================

CREATE OR REPLACE FUNCTION update_unique_pubs_count()
RETURNS TRIGGER AS $$
DECLARE
    is_new_pub BOOLEAN;
BEGIN
    -- Only count if pub_id is set
    IF NEW.pub_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Check if this is the first pint at this pub for this user
    SELECT NOT EXISTS (
        SELECT 1 FROM public.pints 
        WHERE user_id = NEW.user_id 
        AND pub_id = NEW.pub_id 
        AND id != NEW.id
    ) INTO is_new_pub;
    
    IF is_new_pub THEN
        UPDATE public.profiles 
        SET 
            unique_pubs_count = unique_pubs_count + 1,
            updated_at = NOW()
        WHERE id = NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop if exists to avoid duplicate trigger error
DROP TRIGGER IF EXISTS on_pint_update_unique_pubs ON public.pints;

CREATE TRIGGER on_pint_update_unique_pubs
    AFTER INSERT ON public.pints
    FOR EACH ROW EXECUTE FUNCTION update_unique_pubs_count();

-- ============================================
-- FIX 3: Add INSERT policy for profiles
-- In case trigger fails, allow user to create their own profile
-- ============================================

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles 
    FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================
-- FIX 4: Update friends activity to use bidirectional lookup
-- ============================================

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
        -- Friends where current user initiated
        SELECT f.friend_id FROM public.friendships f 
        WHERE f.user_id = auth.uid() AND f.status = 'accepted'
        UNION
        -- Friends where current user was added
        SELECT f.user_id FROM public.friendships f 
        WHERE f.friend_id = auth.uid() AND f.status = 'accepted'
    )
    ORDER BY pt.logged_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FIX 5: Update friendships RLS for bidirectional
-- ============================================

DROP POLICY IF EXISTS "Users can view own friendships" ON public.friendships;
CREATE POLICY "Users can view own friendships" ON public.friendships 
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- ============================================
-- FIX 6: Prevent duplicate pints policy
-- (Soft protection - app should also check)
-- ============================================

-- Add unique constraint on session_id if quantity > 0 
-- This prevents logging multiple pints for the same auto-detected session
-- Note: NULL session_id is allowed multiple times (manual logs)
CREATE UNIQUE INDEX IF NOT EXISTS pints_session_unique_idx 
    ON public.pints(session_id) 
    WHERE session_id IS NOT NULL;

-- ============================================
-- FIX 7: Add pints view for friends (was already there but update for bidirectional)
-- ============================================

DROP POLICY IF EXISTS "Users can view friends pints" ON public.pints;
CREATE POLICY "Users can view friends pints" ON public.pints FOR SELECT USING (
    user_id IN (
        SELECT f.friend_id FROM public.friendships f 
        WHERE f.user_id = auth.uid() AND f.status = 'accepted'
        UNION
        SELECT f.user_id FROM public.friendships f 
        WHERE f.friend_id = auth.uid() AND f.status = 'accepted'
    )
);

-- ============================================
-- FIX 8: Add weekly points view for friends in same leagues
-- ============================================

DROP POLICY IF EXISTS "League members can view others weekly points" ON public.weekly_points;
CREATE POLICY "League members can view others weekly points" ON public.weekly_points FOR SELECT USING (
    user_id IN (
        SELECT lm.user_id FROM public.league_members lm
        WHERE lm.league_id IN (
            SELECT league_id FROM public.league_members WHERE user_id = auth.uid()
        )
    )
    OR 
    user_id IN (
        SELECT f.friend_id FROM public.friendships f 
        WHERE f.user_id = auth.uid() AND f.status = 'accepted'
        UNION
        SELECT f.user_id FROM public.friendships f 
        WHERE f.friend_id = auth.uid() AND f.status = 'accepted'
    )
);

-- ============================================
-- FIX 9: Ensure service role can insert weekly points
-- (For cron job that calculates points)
-- ============================================

DROP POLICY IF EXISTS "Service role can manage weekly points" ON public.weekly_points;
CREATE POLICY "Service role can manage weekly points" ON public.weekly_points 
    FOR ALL USING (auth.role() = 'service_role');

