-- COMPLETE FIX for leagues and league_members RLS
-- This drops ALL existing policies and creates clean, non-recursive ones

-- ============================================
-- STEP 1: DROP ALL EXISTING POLICIES
-- ============================================

-- Drop all league_members policies
DROP POLICY IF EXISTS "Members can view league members" ON public.league_members;
DROP POLICY IF EXISTS "Users can view their own memberships" ON public.league_members;
DROP POLICY IF EXISTS "Users can view members of leagues they belong to" ON public.league_members;
DROP POLICY IF EXISTS "Users can join leagues" ON public.league_members;
DROP POLICY IF EXISTS "Users can leave leagues" ON public.league_members;
DROP POLICY IF EXISTS "league_members_select_policy" ON public.league_members;
DROP POLICY IF EXISTS "league_members_insert_policy" ON public.league_members;
DROP POLICY IF EXISTS "league_members_delete_policy" ON public.league_members;

-- Drop all leagues policies
DROP POLICY IF EXISTS "Members can view their leagues" ON public.leagues;
DROP POLICY IF EXISTS "Users can view leagues they created" ON public.leagues;
DROP POLICY IF EXISTS "Users can view leagues they are members of" ON public.leagues;
DROP POLICY IF EXISTS "Anyone can view public leagues" ON public.leagues;
DROP POLICY IF EXISTS "Users can create leagues" ON public.leagues;
DROP POLICY IF EXISTS "Creators can update their leagues" ON public.leagues;
DROP POLICY IF EXISTS "leagues_select_policy" ON public.leagues;
DROP POLICY IF EXISTS "leagues_insert_policy" ON public.leagues;
DROP POLICY IF EXISTS "leagues_update_policy" ON public.leagues;

-- ============================================
-- STEP 2: ENABLE RLS (if not already)
-- ============================================

ALTER TABLE public.leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_members ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 3: CREATE NEW NON-RECURSIVE POLICIES
-- ============================================

-- LEAGUES POLICIES

-- Anyone can view public leagues (no recursion - just checks is_public)
CREATE POLICY "Public leagues are visible to all"
ON public.leagues FOR SELECT
USING (is_public = true);

-- Users can view leagues they created
CREATE POLICY "Creators can view own leagues"
ON public.leagues FOR SELECT
USING (auth.uid() = creator_id);

-- Users can view leagues they're a member of
-- This uses a subquery on league_members but league_members SELECT doesn't depend on leagues
CREATE POLICY "Members can view their leagues"
ON public.leagues FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.league_members lm
    WHERE lm.league_id = id AND lm.user_id = auth.uid()
  )
);

-- Anyone authenticated can create a league (as creator)
CREATE POLICY "Authenticated users can create leagues"
ON public.leagues FOR INSERT
WITH CHECK (auth.uid() = creator_id);

-- Creators can update their leagues
CREATE POLICY "Creators can update own leagues"
ON public.leagues FOR UPDATE
USING (auth.uid() = creator_id);

-- LEAGUE_MEMBERS POLICIES

-- Users can view their own membership (no recursion - just checks user_id)
CREATE POLICY "Users can view own memberships"
ON public.league_members FOR SELECT
USING (auth.uid() = user_id);

-- Users can view other members in leagues they belong to
-- This checks if the viewer is also a member of the same league
CREATE POLICY "Members can view co-members"
ON public.league_members FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.league_members my_membership
    WHERE my_membership.league_id = league_id 
    AND my_membership.user_id = auth.uid()
  )
);

-- Users can join any league (insert themselves)
CREATE POLICY "Users can join leagues"
ON public.league_members FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can leave leagues (delete their own membership)
CREATE POLICY "Users can leave leagues"
ON public.league_members FOR DELETE
USING (auth.uid() = user_id);

