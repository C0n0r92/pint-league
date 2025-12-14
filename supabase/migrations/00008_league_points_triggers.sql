-- Update league member points when pints are logged
-- This ensures leaderboards update in real-time

-- Function to update league member points after a pint is logged
CREATE OR REPLACE FUNCTION update_league_member_points()
RETURNS TRIGGER AS $$
DECLARE
    league_record RECORD;
    current_week_start DATE;
    weekly_points_total INT;
BEGIN
    -- Calculate current week start (Monday)
    current_week_start := date_trunc('week', CURRENT_DATE);
    
    -- For each league the user is in
    FOR league_record IN 
        SELECT league_id FROM league_members WHERE user_id = NEW.user_id
    LOOP
        -- Calculate total points for this user
        UPDATE league_members
        SET 
            total_points = (
                SELECT COALESCE(SUM(quantity * 10), 0)
                FROM pints
                WHERE user_id = NEW.user_id
            ),
            weekly_points = (
                SELECT COALESCE(SUM(quantity * 10), 0)
                FROM pints
                WHERE user_id = NEW.user_id
                AND logged_at >= current_week_start
                AND logged_at < current_week_start + INTERVAL '7 days'
            ),
            updated_at = NOW()
        WHERE user_id = NEW.user_id AND league_id = league_record.league_id;
        
        -- Update ranks in the league
        WITH ranked_members AS (
            SELECT 
                id,
                ROW_NUMBER() OVER (ORDER BY total_points DESC, joined_at ASC) as new_rank
            FROM league_members
            WHERE league_id = league_record.league_id
        )
        UPDATE league_members lm
        SET rank = rm.new_rank
        FROM ranked_members rm
        WHERE lm.id = rm.id;
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS update_league_points_on_pint ON pints;

-- Create trigger that fires after a pint is inserted
CREATE TRIGGER update_league_points_on_pint
    AFTER INSERT ON pints
    FOR EACH ROW
    EXECUTE FUNCTION update_league_member_points();

-- Also update when user joins a league (initialize their points)
CREATE OR REPLACE FUNCTION initialize_league_member_points()
RETURNS TRIGGER AS $$
DECLARE
    current_week_start DATE;
BEGIN
    current_week_start := date_trunc('week', CURRENT_DATE);
    
    -- Set initial points when joining
    NEW.total_points := (
        SELECT COALESCE(SUM(quantity * 10), 0)
        FROM pints
        WHERE user_id = NEW.user_id
    );
    
    NEW.weekly_points := (
        SELECT COALESCE(SUM(quantity * 10), 0)
        FROM pints
        WHERE user_id = NEW.user_id
        AND logged_at >= current_week_start
        AND logged_at < current_week_start + INTERVAL '7 days'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS initialize_member_points_on_join ON league_members;

-- Create trigger for when user joins league
CREATE TRIGGER initialize_member_points_on_join
    BEFORE INSERT ON league_members
    FOR EACH ROW
    EXECUTE FUNCTION initialize_league_member_points();

-- Manually update existing members (one-time fix)
DO $$
DECLARE
    member_record RECORD;
    current_week_start DATE;
BEGIN
    current_week_start := date_trunc('week', CURRENT_DATE);
    
    FOR member_record IN SELECT id, user_id, league_id FROM league_members
    LOOP
        UPDATE league_members
        SET 
            total_points = (
                SELECT COALESCE(SUM(quantity * 10), 0)
                FROM pints
                WHERE user_id = member_record.user_id
            ),
            weekly_points = (
                SELECT COALESCE(SUM(quantity * 10), 0)
                FROM pints
                WHERE user_id = member_record.user_id
                AND logged_at >= current_week_start
                AND logged_at < current_week_start + INTERVAL '7 days'
            )
        WHERE id = member_record.id;
    END LOOP;
    
    -- Update ranks for all leagues
    FOR member_record IN SELECT DISTINCT league_id FROM league_members
    LOOP
        WITH ranked_members AS (
            SELECT 
                id,
                ROW_NUMBER() OVER (ORDER BY total_points DESC, joined_at ASC) as new_rank
            FROM league_members
            WHERE league_id = member_record.league_id
        )
        UPDATE league_members lm
        SET rank = rm.new_rank
        FROM ranked_members rm
        WHERE lm.id = rm.id;
    END LOOP;
END $$;

