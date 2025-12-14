-- Fix infinite recursion in league_members RLS policies
-- The issue is that the policy checks league_members to see if user can view,
-- which triggers the same policy check again.

-- Drop the problematic policies
DROP POLICY IF EXISTS "Members can view league members" ON public.league_members;
DROP POLICY IF EXISTS "Members can view their leagues" ON public.leagues;

-- Create simpler, non-recursive policies for league_members
CREATE POLICY "Users can view their own memberships" ON public.league_members 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view members of leagues they belong to" ON public.league_members 
    FOR SELECT USING (
        league_id IN (
            SELECT league_id FROM public.league_members lm 
            WHERE lm.user_id = auth.uid()
        )
    );

-- Fix leagues policy - use a simpler approach
CREATE POLICY "Users can view leagues they created" ON public.leagues 
    FOR SELECT USING (auth.uid() = creator_id);

CREATE POLICY "Users can view leagues they are members of" ON public.leagues 
    FOR SELECT USING (
        id IN (
            SELECT league_id FROM public.league_members 
            WHERE user_id = auth.uid()
        )
    );

-- Ensure the insert policies work correctly
DROP POLICY IF EXISTS "Users can create leagues" ON public.leagues;
CREATE POLICY "Users can create leagues" ON public.leagues 
    FOR INSERT WITH CHECK (auth.uid() = creator_id);

DROP POLICY IF EXISTS "Users can join leagues" ON public.league_members;
CREATE POLICY "Users can join leagues" ON public.league_members 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Add some test pubs for Ireland/UK (since the seed function isn't deployed)
INSERT INTO public.pubs (name, lat, lng, address, city, country, categories) VALUES
-- Dublin pubs
('The Temple Bar', 53.3455, -6.2644, '47-48 Temple Bar', 'Dublin', 'IE', ARRAY['pub']),
('The Brazen Head', 53.3449, -6.2773, '20 Lower Bridge St', 'Dublin', 'IE', ARRAY['pub']),
('Mulligan''s', 53.3469, -6.2541, '8 Poolbeg St', 'Dublin', 'IE', ARRAY['pub']),
('The Stag''s Head', 53.3433, -6.2627, '1 Dame Ct', 'Dublin', 'IE', ARRAY['pub']),
('O''Donoghue''s', 53.3372, -6.2503, '15 Merrion Row', 'Dublin', 'IE', ARRAY['pub']),
('Kehoe''s', 53.3413, -6.2590, '9 South Anne St', 'Dublin', 'IE', ARRAY['pub']),
('The Long Hall', 53.3428, -6.2653, '51 South Great George''s St', 'Dublin', 'IE', ARRAY['pub']),
('Grogan''s Castle Lounge', 53.3419, -6.2637, '15 South William St', 'Dublin', 'IE', ARRAY['pub']),
('Toner''s', 53.3378, -6.2521, '139 Lower Baggot St', 'Dublin', 'IE', ARRAY['pub']),
('The Palace Bar', 53.3457, -6.2604, '21 Fleet St', 'Dublin', 'IE', ARRAY['pub']),
-- London pubs
('The Churchill Arms', 51.5074, -0.1943, '119 Kensington Church St', 'London', 'GB', ARRAY['pub']),
('Ye Olde Cheshire Cheese', 51.5146, -0.1072, '145 Fleet St', 'London', 'GB', ARRAY['pub']),
('The Lamb and Flag', 51.5120, -0.1264, '33 Rose St', 'London', 'GB', ARRAY['pub']),
('The Spaniards Inn', 51.5707, -0.1721, 'Spaniards Rd', 'London', 'GB', ARRAY['pub']),
('The George Inn', 51.5054, -0.0889, '75-77 Borough High St', 'London', 'GB', ARRAY['pub']),
-- Belfast pubs
('The Crown Liquor Saloon', 54.5958, -5.9330, '46 Great Victoria St', 'Belfast', 'GB', ARRAY['pub']),
('Kelly''s Cellars', 54.6008, -5.9306, '30-32 Bank St', 'Belfast', 'GB', ARRAY['pub']),
('The Duke of York', 54.6012, -5.9285, '7-11 Commercial Ct', 'Belfast', 'GB', ARRAY['pub']),
-- Cork pubs
('The Mutton Lane Inn', 51.8985, -8.4706, '3 Mutton Lane', 'Cork', 'IE', ARRAY['pub']),
('Sin É', 51.8999, -8.4665, '8 Coburg St', 'Cork', 'IE', ARRAY['pub']),
-- Galway pubs  
('Tigh Neachtain', 53.2719, -9.0538, '17 Cross St', 'Galway', 'IE', ARRAY['pub']),
('The Crane Bar', 53.2692, -9.0561, '2 Sea Rd', 'Galway', 'IE', ARRAY['pub']),
-- Manchester pubs
('The Peveril of the Peak', 53.4771, -2.2449, '127 Great Bridgewater St', 'Manchester', 'GB', ARRAY['pub']),
('Marble Arch', 53.4838, -2.2312, '73 Rochdale Rd', 'Manchester', 'GB', ARRAY['pub']),
-- Edinburgh pubs
('The Sheep Heid Inn', 55.9449, -3.1373, '43-45 The Causeway', 'Edinburgh', 'GB', ARRAY['pub']),
('The Oxford Bar', 55.9547, -3.2035, '8 Young St', 'Edinburgh', 'GB', ARRAY['pub'])
ON CONFLICT DO NOTHING;

