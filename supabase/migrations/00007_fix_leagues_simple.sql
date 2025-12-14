-- SIMPLE FIX - No self-referencing policies at all
-- This completely avoids recursion by using simpler rules

-- ============================================
-- STEP 1: DROP ALL POLICIES ON BOTH TABLES
-- ============================================

DO $$ 
DECLARE
    pol RECORD;
BEGIN
    -- Drop all policies on league_members
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'league_members' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.league_members', pol.policyname);
    END LOOP;
    
    -- Drop all policies on leagues
    FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'leagues' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.leagues', pol.policyname);
    END LOOP;
END $$;

-- ============================================
-- STEP 2: SIMPLE POLICIES - NO RECURSION
-- ============================================

-- LEAGUES: Simple policies
-- Public leagues visible to everyone
CREATE POLICY "leagues_select_public" ON public.leagues 
FOR SELECT USING (is_public = true);

-- Creators can always see their leagues
CREATE POLICY "leagues_select_creator" ON public.leagues 
FOR SELECT USING (creator_id = auth.uid());

-- Anyone can create a league (must be the creator)
CREATE POLICY "leagues_insert" ON public.leagues 
FOR INSERT WITH CHECK (creator_id = auth.uid());

-- Creators can update
CREATE POLICY "leagues_update" ON public.leagues 
FOR UPDATE USING (creator_id = auth.uid());

-- LEAGUE_MEMBERS: Super simple - users can only see/manage their OWN memberships
-- This completely avoids checking other rows in the same table

CREATE POLICY "league_members_select_own" ON public.league_members 
FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "league_members_insert_own" ON public.league_members 
FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "league_members_delete_own" ON public.league_members 
FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- STEP 3: Create a view for seeing other league members
-- (This avoids the RLS recursion entirely)
-- ============================================

CREATE OR REPLACE VIEW public.league_members_view AS
SELECT lm.*
FROM public.league_members lm
WHERE lm.league_id IN (
    SELECT league_id FROM public.league_members WHERE user_id = auth.uid()
);

-- Grant access to the view
GRANT SELECT ON public.league_members_view TO authenticated;

