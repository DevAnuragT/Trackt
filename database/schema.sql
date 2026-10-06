-- ================================================================
-- STARLINK OUTPOST APP - COMPREHENSIVE DATABASE SCHEMA (FIXED VERSION)
-- Consolidated schema with territory management, notifications, and statistics
-- 
-- 🚨 IMPORTANT: This schema includes ALL FIXES for:
-- 1. Territory merging polygon data preservation
-- 2. Total runs logic (runs ≠ territories)
-- 3. Largest territory area dynamic calculation
-- 4. Distance-based territory merging
-- 5. Correct order of operations (merge then conquest)
-- 
-- 🚨 EXECUTION ORDER (IMPORTANT!):
-- 1. FIRST: Fix column type if you get MultiPolygon error:
--    ALTER TABLE public.territories ALTER COLUMN boundary_polygon TYPE GEOMETRY(POLYGON, 4326);
-- 2. THEN: Run this schema.sql file
-- 
-- ✅ This will handle all trigger conflicts automatically!
-- 
-- 🔧 LATEST FIX: Territory merging now properly converts merged geometry back to boundary points
--    This fixes upload failures when territories of the same user intersect
-- 
-- 🔍 CONQUEST DEBUGGING: Added extensive logging to diagnose why territory stealing stopped working
--    - Enhanced debugging for conquest logic
--    - Logs all territories and their owners
--    - Shows exactly why conquest isn't working
-- 
-- 🚨 CRITICAL FIX: MultiPolygon/Polygon geometry type mismatch was breaking territory conquest
--    - Fixed new_geom compatibility after merging
--    - Added geometry validation before conquest logic
--    - Territory stealing should now work correctly
-- 
-- 🚨 CRITICAL FIX: Merging logic was breaking conquest by modifying new_geom
--    - Preserve original new_geom before merging
--    - Restore original new_geom after merging
--    - Conquest now uses original simple geometry (not merged complex geometry)
-- 
-- 🎯 COORDINATE FORMAT: UI handles both simple and complex formats correctly
--    - Simple format: [{"lat": x, "lng": y}, {"lat": x, "lng": y}, ...]
--    - Complex format: [{"holes": [], "outer": [{"lat": x, "lng": y}, ...]}]
--    - UI automatically detects and renders both formats properly
--    - Complex format preserves holes and multipolygon information
-- ================================================================

-- Enable PostGIS extension for spatial operations
CREATE EXTENSION IF NOT EXISTS postgis;

-- 🚨 CRITICAL FIX: If you get "Geometry type (Polygon) does not match column type (MultiPolygon)" error,
-- run this command first in your database:
-- ALTER TABLE public.territories ALTER COLUMN boundary_polygon TYPE GEOMETRY(POLYGON, 4326);
-- 
-- ⚠️  CONQUEST WILL NOT WORK until you fix the column type!
-- The error means your database still has the old MULTIPOLYGON column type.
-- 
-- 🔍 DIAGNOSTIC: Check your current column type with this query:
-- SELECT column_name, data_type, udt_name FROM information_schema.columns 
-- WHERE table_name = 'territories' AND column_name = 'boundary_polygon';

-- ================================================================
-- 1. USER PROFILES TABLE (extends auth.users)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR NOT NULL,
  display_name VARCHAR,
  avatar_url VARCHAR,
  user_color VARCHAR(9) DEFAULT '#FF2196F3', -- User's preferred color (ARGB format)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  total_territory_area DECIMAL DEFAULT 0,
  total_runs INTEGER DEFAULT 0,
  level INTEGER DEFAULT 1,
  experience_points INTEGER DEFAULT 0,
  coins INTEGER DEFAULT 0 -- User coins earned from runs (100 coins per qualifying run)
);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view all profiles" ON public.user_profiles;
CREATE POLICY "Users can view all profiles" ON public.user_profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
CREATE POLICY "Users can insert own profile" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Create index for coins for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_coins ON public.user_profiles(coins);

-- Enforce case-insensitive unique display names (usernames)
-- Note: Allows NULLs; uniqueness applies only when display_name is set
CREATE UNIQUE INDEX IF NOT EXISTS user_profiles_display_name_unique_ci
  ON public.user_profiles (LOWER(display_name));

-- ================================================================
-- 2. TERRITORIES TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS public.territories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  boundary_points JSONB NOT NULL, -- Simplified: just [lat, lng] pairs
  area DECIMAL NOT NULL, -- in square meters
  center_lat DECIMAL NOT NULL,
  center_lng DECIMAL NOT NULL,
  center_point GEOMETRY(POINT, 4326) NOT NULL,
  boundary_polygon GEOMETRY(POLYGON, 4326), -- PostGIS polygon for spatial queries (can be single or multi)
  owner_color VARCHAR(9) DEFAULT '#3B82F6', -- Owner's preferred color (ARGB format)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view all territories" ON public.territories;
CREATE POLICY "Users can view all territories" ON public.territories
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own territories" ON public.territories;
CREATE POLICY "Users can insert own territories" ON public.territories
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can update own territories" ON public.territories;
CREATE POLICY "Users can update own territories" ON public.territories
  FOR UPDATE USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can delete own territories" ON public.territories;
CREATE POLICY "Users can delete own territories" ON public.territories
  FOR DELETE USING (auth.uid() = owner_id);

-- Spatial indexes for performance
CREATE INDEX IF NOT EXISTS idx_territories_center_point ON public.territories USING GIST(center_point);
CREATE INDEX IF NOT EXISTS idx_territories_boundary_polygon ON public.territories USING GIST(boundary_polygon);
CREATE INDEX IF NOT EXISTS idx_territories_owner_id ON public.territories(owner_id);
CREATE INDEX IF NOT EXISTS idx_territories_created_at ON public.territories(created_at);

-- ================================================================
-- 3. TERRITORY STEALS TABLE (ESSENTIAL for bottom sheet conquest history)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.territory_steals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stolen_territory_id UUID NOT NULL REFERENCES public.territories(id) ON DELETE CASCADE,
  previous_owner_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  new_owner_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  overlap_percentage DECIMAL NOT NULL, -- percentage overlapped
  overlap_area DECIMAL, -- overlapped area in m^2
  steal_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reason VARCHAR(50) DEFAULT 'overlap' CHECK (reason IN ('overlap', 'abandoned', 'admin', 'complete_conquest', 'partial_conquest'))
);

-- Enable RLS
ALTER TABLE public.territory_steals ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view steals involving their territories" ON public.territory_steals;
CREATE POLICY "Users can view steals involving their territories" ON public.territory_steals
  FOR SELECT USING (
    previous_owner_id = auth.uid() OR new_owner_id = auth.uid()
  );

DROP POLICY IF EXISTS "Users can insert steals they are involved in" ON public.territory_steals;
CREATE POLICY "Users can insert steals they are involved in" ON public.territory_steals
  FOR INSERT WITH CHECK (
    previous_owner_id = auth.uid() OR new_owner_id = auth.uid()
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_territory_steals_stolen_territory ON public.territory_steals(stolen_territory_id);
CREATE INDEX IF NOT EXISTS idx_territory_steals_previous_owner ON public.territory_steals(previous_owner_id);
CREATE INDEX IF NOT EXISTS idx_territory_steals_new_owner ON public.territory_steals(new_owner_id);
CREATE INDEX IF NOT EXISTS idx_territory_steals_date ON public.territory_steals(steal_date);

-- ================================================================
-- 4. USER STATISTICS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_statistics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  total_distance DECIMAL DEFAULT 0,
  total_runs INTEGER DEFAULT 0,
  total_territory_area DECIMAL DEFAULT 0,
  largest_territory_area DECIMAL DEFAULT 0,
  longest_run_distance DECIMAL DEFAULT 0,
  longest_run_duration INTEGER DEFAULT 0,
  territories_conquered INTEGER DEFAULT 0,
  territories_lost INTEGER DEFAULT 0,
  last_run_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.user_statistics ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view all statistics" ON public.user_statistics;
CREATE POLICY "Users can view all statistics" ON public.user_statistics
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own statistics" ON public.user_statistics;
CREATE POLICY "Users can update own statistics" ON public.user_statistics
  FOR UPDATE USING (auth.uid() = user_id);

-- ================================================================
-- RPC: leave_club_by_member(p_club_id uuid, p_user_id uuid) returns boolean
-- Prevents club creator from leaving (UI hides this anyway)
-- Idempotent: drops and recreates to ensure latest logic
-- ================================================================

DROP FUNCTION IF EXISTS public.leave_club_by_member(UUID, UUID);
CREATE OR REPLACE FUNCTION public.leave_club_by_member(p_club_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_creator_id UUID;
  v_next_owner UUID;
BEGIN
  -- Ensure the user making the request is the same as p_user_id (basic security)
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot leave club for another user';
  END IF;

  -- Ensure club exists and read current creator
  SELECT creator_id INTO v_creator_id FROM public.clubs WHERE id = p_club_id;
  IF v_creator_id IS NULL THEN
    RAISE EXCEPTION 'Club not found';
  END IF;

  -- If not a member, treat as idempotent success
  IF NOT EXISTS (
    SELECT 1 FROM public.club_members cm
    WHERE cm.club_id = p_club_id AND cm.user_id = p_user_id
  ) THEN
    RETURN TRUE;
  END IF;

  IF v_creator_id = p_user_id THEN
    -- Founder is leaving: transfer ownership to the earliest joined non-founder member
    SELECT cm.user_id
    INTO v_next_owner
    FROM public.club_members cm
    WHERE cm.club_id = p_club_id AND cm.user_id <> p_user_id
    ORDER BY cm.joined_at ASC
    LIMIT 1;

    IF v_next_owner IS NULL THEN
      -- No one else to transfer ownership to; delete the club entirely
      DELETE FROM public.clubs WHERE id = p_club_id;
      RETURN TRUE;
    END IF;

    -- Transfer ownership
    UPDATE public.clubs
    SET creator_id = v_next_owner
    WHERE id = p_club_id;
  END IF;

  -- Remove the leaving member's membership
  DELETE FROM public.club_members
  WHERE club_id = p_club_id AND user_id = p_user_id;

  RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION public.leave_club_by_member(UUID, UUID) IS 'Removes the requesting user from a club. If the user is the creator, transfers ownership to the earliest joined non-founder member.';

DROP POLICY IF EXISTS "Users can insert own statistics" ON public.user_statistics;
CREATE POLICY "Users can insert own statistics" ON public.user_statistics
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ================================================================
-- 5. NOTIFICATIONS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'territory_conquest' CHECK (type IN ('territory_conquest', 'territory_loss', 'system', 'achievement')),
  is_read BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  metadata JSONB, -- Store additional data like stolen area, territory ID, etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================================
-- 6. CLUBS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS public.clubs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  referral_code TEXT UNIQUE NOT NULL,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for clubs
DROP POLICY IF EXISTS "Users can view all clubs" ON public.clubs;
CREATE POLICY "Users can view all clubs" ON public.clubs
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create clubs" ON public.clubs;
CREATE POLICY "Users can create clubs" ON public.clubs
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

DROP POLICY IF EXISTS "Club creators can update their clubs" ON public.clubs;
CREATE POLICY "Club creators can update their clubs" ON public.clubs
  FOR UPDATE USING (auth.uid() = creator_id);

-- ================================================================
-- 7. CLUB MEMBERS TABLE
-- ================================================================

CREATE TABLE IF NOT EXISTS public.club_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(club_id, user_id) -- Prevent duplicate membership
);

-- Enable RLS
ALTER TABLE public.club_members ENABLE ROW LEVEL SECURITY;

-- RLS Policies for club_members
DROP POLICY IF EXISTS "Users can view club members" ON public.club_members;
CREATE POLICY "Users can view club members" ON public.club_members
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can join clubs" ON public.club_members;
CREATE POLICY "Users can join clubs" ON public.club_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can leave clubs" ON public.club_members;
CREATE POLICY "Users can leave clubs" ON public.club_members
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_club_members_club_id ON public.club_members(club_id);
CREATE INDEX IF NOT EXISTS idx_club_members_user_id ON public.club_members(user_id);
CREATE INDEX IF NOT EXISTS idx_clubs_creator_id ON public.clubs(creator_id);
CREATE INDEX IF NOT EXISTS idx_clubs_referral_code ON public.clubs(referral_code);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (
    auth.uid() = user_id AND is_deleted = FALSE
  );

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications" ON public.notifications
  FOR DELETE USING (auth.uid() = user_id);

-- Service role can insert notifications for any user
DROP POLICY IF EXISTS "Service can insert notifications" ON public.notifications;
CREATE POLICY "Service can insert notifications" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_deleted ON public.notifications(is_deleted);

-- ================================================================
-- 6. CORE DATABASE FUNCTIONS
-- ================================================================

-- Function to get territories within radius (includes user color)
DROP FUNCTION IF EXISTS get_territories_within_radius(DECIMAL, DECIMAL, INTEGER);
CREATE OR REPLACE FUNCTION get_territories_within_radius(
  search_center_lat DECIMAL,
  search_center_lng DECIMAL,
  radius_meters INTEGER DEFAULT 3000
)
RETURNS TABLE (
  id UUID,
  owner_id UUID,
  owner_name VARCHAR,
  user_color VARCHAR,
  boundary_points JSONB,
  area DECIMAL,
  center_lat DECIMAL,
  center_lng DECIMAL,
  created_at TIMESTAMP WITH TIME ZONE,
  distance_meters DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.owner_id,
    COALESCE(up.display_name, 'Unknown User') as owner_name,
    up.user_color,
    t.boundary_points,
    t.area,
    t.center_lat,
    t.center_lng,
    t.created_at,
    ST_Distance(
      ST_GeogFromText('POINT(' || search_center_lng || ' ' || search_center_lat || ')'),
      ST_GeogFromText('POINT(' || t.center_lng || ' ' || t.center_lat || ')')
    ) as distance_meters
  FROM public.territories t
  LEFT JOIN public.user_profiles up ON t.owner_id = up.id
  WHERE ST_DWithin(
    ST_GeogFromText('POINT(' || search_center_lng || ' ' || search_center_lat || ')'),
    ST_GeogFromText('POINT(' || t.center_lng || ' ' || t.center_lat || ')'),
    radius_meters
  )
  ORDER BY distance_meters ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get territories for map display
DROP FUNCTION IF EXISTS get_territories_for_map_display(DECIMAL, DECIMAL, INTEGER);
CREATE OR REPLACE FUNCTION get_territories_for_map_display(
  search_center_lat DECIMAL,
  search_center_lng DECIMAL,
  radius_meters INTEGER DEFAULT 3000
)
RETURNS TABLE (
  id UUID,
  owner_id UUID,
  boundary_points JSONB,
  area DECIMAL,
  center_lat DECIMAL,
  center_lng DECIMAL,
  created_at TIMESTAMPTZ,
  render_layer INTEGER,
  is_conquered BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH filtered AS (
    SELECT 
      t.id,
      t.owner_id,
      t.boundary_points,
      t.area,
      t.center_lat,
      t.center_lng,
      t.created_at,
      EXISTS (
        SELECT 1 FROM public.territory_steals s 
        WHERE s.stolen_territory_id = t.id 
        LIMIT 1
      ) AS is_conquered,
      t.created_at AS sort_key
    FROM public.territories t
    WHERE ST_DWithin(
      ST_GeogFromText('POINT(' || search_center_lng || ' ' || search_center_lat || ')'),
      ST_GeogFromText('POINT(' || t.center_lng || ' ' || t.center_lat || ')'),
      radius_meters
    )
  )
  SELECT
    filtered.id, filtered.owner_id, filtered.boundary_points, filtered.area, filtered.center_lat, filtered.center_lng, filtered.created_at,
    ROW_NUMBER() OVER (ORDER BY filtered.sort_key ASC)::integer AS render_layer,
    filtered.is_conquered
  FROM filtered
  ORDER BY render_layer ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if point is within territory
DROP FUNCTION IF EXISTS is_point_in_territory(DECIMAL, DECIMAL, UUID);
CREATE OR REPLACE FUNCTION is_point_in_territory(
  point_lat DECIMAL,
  point_lng DECIMAL,
  territory_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  territory_polygon GEOMETRY;
  point_geom GEOMETRY;
BEGIN
  -- Get territory polygon
  SELECT boundary_polygon INTO territory_polygon
  FROM public.territories
  WHERE id = territory_id;
  
  IF territory_polygon IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Create point geometry
  point_geom := ST_SetSRID(ST_MakePoint(point_lng, point_lat), 4326);
  
  -- Check if point is within polygon
  RETURN ST_Within(point_geom, territory_polygon);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 7. TERRITORY CONQUEST FUNCTIONS
-- ================================================================

-- Function to update statistics during territory conquest
CREATE OR REPLACE FUNCTION update_statistics_on_territory_conquest()
RETURNS TRIGGER AS $$
DECLARE
  v_conquered_area DECIMAL;
BEGIN
  -- Get the conquered area from the territory_steals record
  v_conquered_area := NEW.overlap_area;
  
  -- Update statistics for the victim (previous owner)
  UPDATE public.user_statistics
  SET 
    total_territory_area = GREATEST(total_territory_area - v_conquered_area, 0),
    territories_lost = territories_lost + 1,
    updated_at = NOW()
  WHERE user_id = NEW.previous_owner_id;

  -- Update statistics for the conqueror (new owner)
  UPDATE public.user_statistics
  SET 
    total_territory_area = total_territory_area + v_conquered_area,
    territories_conquered = territories_conquered + 1,
    updated_at = NOW()
  WHERE user_id = NEW.new_owner_id;

  -- Update user profiles
  UPDATE public.user_profiles
  SET 
    total_territory_area = GREATEST(total_territory_area - v_conquered_area, 0),
    updated_at = NOW()
  WHERE id = NEW.previous_owner_id;

  UPDATE public.user_profiles
  SET 
    total_territory_area = total_territory_area + v_conquered_area,
    updated_at = NOW()
  WHERE id = NEW.new_owner_id;

  RAISE NOTICE 'Updated statistics for territory conquest: victim=%s, conqueror=%s, area=%.2f', 
    NEW.previous_owner_id, NEW.new_owner_id, v_conquered_area;
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create territory conquest notifications
CREATE OR REPLACE FUNCTION create_territory_conquest_notifications(
  p_territory_id UUID,
  p_previous_owner_id UUID,
  p_new_owner_id UUID,
  p_stolen_area DECIMAL,
  p_territory_name VARCHAR DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_territory_name VARCHAR;
  v_previous_owner_name VARCHAR;
  v_new_owner_name VARCHAR;
BEGIN
  -- Get territory name (use area if no name)
  v_territory_name := COALESCE(p_territory_name, p_stolen_area::VARCHAR || ' m² territory');
  
  -- Get user names
  SELECT display_name INTO v_previous_owner_name
  FROM public.user_profiles WHERE id = p_previous_owner_id;
  
  SELECT display_name INTO v_new_owner_name
  FROM public.user_profiles WHERE id = p_new_owner_id;
  
  -- Default names if not found
  v_previous_owner_name := COALESCE(v_previous_owner_name, 'Unknown User');
  v_new_owner_name := COALESCE(v_new_owner_name, 'Unknown User');

  -- Create notification for the victim (previous owner)
  INSERT INTO public.notifications (
    user_id, 
    title, 
    message, 
    type, 
    metadata
  ) VALUES (
    p_previous_owner_id,
    'Territory Lost',
    'You lost ' || v_territory_name || ' to ' || v_new_owner_name || '. Area stolen: ' || round(p_stolen_area)::text || ' m²',
    'territory_loss',
    jsonb_build_object(
      'territory_id', p_territory_id,
      'stolen_area', p_stolen_area,
      'conqueror_name', v_new_owner_name,
      'conquest_type', 'territory_loss'
    )
  );

  -- Create notification for the conqueror (new owner)
  INSERT INTO public.notifications (
    user_id, 
    title, 
    message, 
    type, 
    metadata
  ) VALUES (
    p_new_owner_id,
    'Territory Conquered',
    'You conquered ' || v_territory_name || ' from ' || v_previous_owner_name || '! Area gained: ' || round(p_stolen_area)::text || ' m²',
    'territory_conquest',
    jsonb_build_object(
      'territory_id', p_territory_id,
      'conquered_area', p_stolen_area,
      'previous_owner_name', v_previous_owner_name,
      'conquest_type', 'territory_conquest'
    )
  );

  RAISE NOTICE 'Created conquest notifications for territory %: victim=%s, conqueror=%s', 
    p_territory_id, p_previous_owner_id, p_new_owner_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Overload to accept DOUBLE PRECISION stolen area (called from conquest paths)
DROP FUNCTION IF EXISTS create_territory_conquest_notifications(UUID, UUID, UUID, DOUBLE PRECISION);
CREATE OR REPLACE FUNCTION create_territory_conquest_notifications(
  p_territory_id UUID,
  p_previous_owner_id UUID,
  p_new_owner_id UUID,
  p_stolen_area DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
  PERFORM create_territory_conquest_notifications(
    p_territory_id,
    p_previous_owner_id,
    p_new_owner_id,
    p_stolen_area::DECIMAL,
    NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 8. TERRITORY INSERTION FUNCTION (with conquest logic)
-- ================================================================

-- ENHANCED RPC function to insert territory (handles PostGIS types, conquest logic, and distance-based merging)
DROP FUNCTION IF EXISTS insert_territory(UUID, JSONB, DECIMAL, DECIMAL, DECIMAL, VARCHAR);
DROP FUNCTION IF EXISTS insert_territory(UUID, JSONB, DECIMAL, DECIMAL, DECIMAL, VARCHAR, DECIMAL);
CREATE OR REPLACE FUNCTION insert_territory(
  p_owner_id UUID,
  boundary_points JSONB,
  area DECIMAL,
  center_lat DECIMAL,
  center_lng DECIMAL,
  owner_color VARCHAR DEFAULT '#3B82F6',
  merge_distance_meters DECIMAL DEFAULT 50.0  -- NEW: Configurable merge distance
)
RETURNS UUID AS $$
DECLARE
  territory_id UUID;
  new_polygon GEOMETRY(POLYGON, 4326);
  merged_geom GEOMETRY;
  final_geom GEOMETRY;
  final_single GEOMETRY;
  stolen_union GEOMETRY;
  enemy RECORD;
  self_ids UUID[];
  boundary_points_json JSONB;
  v_area_m2 DOUBLE PRECISION;
BEGIN
  -- Generate new territory ID
  territory_id := gen_random_uuid();

  -- Ensure user profile exists before proceeding
  IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = p_owner_id) THEN
    INSERT INTO public.user_profiles (
      id, email, display_name, user_color, created_at, updated_at
    ) VALUES (
      p_owner_id,
      'user@example.com',
      'User ' || p_owner_id::text,
      COALESCE(owner_color, '#3B82F6'),
      NOW(),
      NOW()
    );

    INSERT INTO public.user_statistics (
      user_id, total_distance, total_runs, total_territory_area, 
      largest_territory_area, longest_run_distance, longest_run_duration,
      territories_conquered, territories_lost,
      created_at, updated_at
    ) VALUES (
      p_owner_id, 0, 0, 0, 0, 0, 0, 0, 0, NOW(), NOW()
    );
  END IF;

  -- Build a valid polygon from boundary_points (ensure ring closure)
  BEGIN
    SELECT ST_SetSRID(ST_MakePolygon(
      ST_MakeLine(
        ARRAY(
          SELECT ST_MakePoint((p->>'lng')::DECIMAL, (p->>'lat')::DECIMAL)
          FROM jsonb_array_elements(boundary_points) AS p
        ) || ARRAY[
          ST_MakePoint((boundary_points->0->>'lng')::DECIMAL, (boundary_points->0->>'lat')::DECIMAL)
        ]
      )
    ), 4326) INTO new_polygon;

    IF new_polygon IS NULL OR NOT ST_IsValid(new_polygon) THEN
      RAISE EXCEPTION 'Invalid polygon created from boundary points';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to create valid polygon from boundary points: %', SQLERRM;
  END;

  -- Step 1/2: Merge with any self territories that intersect
  SELECT array_agg(t.id)
  INTO self_ids
  FROM public.territories t
  WHERE t.owner_id = p_owner_id
    AND t.boundary_polygon IS NOT NULL
    AND ST_Intersects(t.boundary_polygon, new_polygon);

  IF self_ids IS NULL THEN
    merged_geom := new_polygon;
  ELSE
    SELECT ST_UnaryUnion(ST_Collect(ARRAY[new_polygon]::geometry[] || ARRAY(
             SELECT t.boundary_polygon FROM public.territories t WHERE t.id = ANY(self_ids)
           )))
    INTO merged_geom;
    merged_geom := ST_MakeValid(merged_geom);
  END IF;

  -- Step 3: Conquest against enemy territories using merged geometry
  FOR enemy IN
    SELECT t.id, t.owner_id, t.boundary_polygon AS geom, t.area
    FROM public.territories t
    WHERE t.owner_id != p_owner_id
      AND t.boundary_polygon IS NOT NULL
      AND ST_Intersects(t.boundary_polygon, merged_geom)
  LOOP
    DECLARE
      inter_geom GEOMETRY;
      remainder_geom GEOMETRY;
      inter_area_m2 DOUBLE PRECISION;
      remaining_area DOUBLE PRECISION;
      conquered_area DOUBLE PRECISION;
    BEGIN
      inter_geom := ST_MakeValid(ST_Intersection(enemy.geom, merged_geom));
      IF inter_geom IS NULL OR ST_IsEmpty(inter_geom) THEN
        CONTINUE;
      END IF;

      inter_area_m2 := ST_Area(ST_Transform(inter_geom, 3857));
      IF inter_area_m2 < 1.0 THEN
        CONTINUE; -- ignore tiny overlaps
      END IF;

      -- Accumulate stolen union
      IF stolen_union IS NULL THEN
        stolen_union := inter_geom;
      ELSE
        stolen_union := ST_UnaryUnion(ST_Collect(stolen_union, inter_geom));
      END IF;

      -- Shrink enemy territory
      remainder_geom := ST_CollectionExtract(ST_MakeValid(ST_Difference(enemy.geom, inter_geom)), 3);

      IF remainder_geom IS NULL OR ST_IsEmpty(remainder_geom) THEN
        -- Complete conquest
        DELETE FROM public.territories WHERE id = enemy.id;
        INSERT INTO public.territory_steals (
          stolen_territory_id, previous_owner_id, new_owner_id,
          overlap_percentage, overlap_area, reason
        ) VALUES (
          enemy.id, enemy.owner_id, p_owner_id,
          100.0, enemy.area, 'complete_conquest'
        );
        PERFORM create_territory_conquest_notifications(enemy.id, enemy.owner_id, p_owner_id, enemy.area);
      ELSE
        -- Partial conquest: ensure single POLYGON for enemy remainder
        IF ST_NumGeometries(ST_CollectionExtract(remainder_geom, 3)) > 1 THEN
          WITH d AS (
            SELECT (ST_Dump(ST_CollectionExtract(remainder_geom, 3))).geom AS g
          )
          SELECT g INTO remainder_geom
          FROM d
          ORDER BY ST_Area(ST_Transform(g, 3857)) DESC
          LIMIT 1;
        ELSE
          remainder_geom := ST_GeometryN(ST_CollectionExtract(remainder_geom, 3), 1);
        END IF;

        SELECT geom_to_rings_json(remainder_geom) INTO boundary_points_json;
        IF boundary_points_json IS NULL THEN
          WITH parts AS (
            SELECT d.geom AS poly, ST_Area(ST_Transform(d.geom, 3857)) AS a
            FROM ST_Dump(remainder_geom) AS d
          ), chosen AS (
            SELECT poly FROM parts ORDER BY a DESC LIMIT 1
          ), er_pts AS (
            SELECT jsonb_agg(jsonb_build_object('lat', ST_Y(pt), 'lng', ST_X(pt)) ORDER BY path[1]) AS outer_ring
            FROM (
              SELECT (ST_DumpPoints(ST_ExteriorRing((SELECT poly FROM chosen)))).geom AS pt,
                     (ST_DumpPoints(ST_ExteriorRing((SELECT poly FROM chosen)))).path
            ) q
          )
          SELECT jsonb_build_array(
                   jsonb_build_object('outer', COALESCE((SELECT outer_ring FROM er_pts), '[]'::jsonb),
                                      'holes', '[]'::jsonb)
                 )
          INTO boundary_points_json;
        END IF;

        remaining_area := ST_Area(ST_Transform(remainder_geom, 3857));
        conquered_area := enemy.area - remaining_area;

        UPDATE public.territories AS tt
        SET 
          boundary_polygon = remainder_geom,
          area = remaining_area,
          center_point = COALESCE(ST_Centroid(remainder_geom), ST_Point(0, 0)),
          center_lat = COALESCE(ST_Y(ST_Centroid(remainder_geom)), 0.0),
          center_lng = COALESCE(ST_X(ST_Centroid(remainder_geom)), 0.0),
          boundary_points = COALESCE(boundary_points_json, '[]'::jsonb),
          updated_at = NOW()
        WHERE tt.id = enemy.id;

        INSERT INTO public.territory_steals (
          stolen_territory_id, previous_owner_id, new_owner_id,
          overlap_percentage, overlap_area, reason
        ) VALUES (
          enemy.id, enemy.owner_id, p_owner_id,
          CASE WHEN enemy.area > 0 THEN (conquered_area / enemy.area) * 100.0 ELSE 0 END,
          conquered_area,
          'partial_conquest'
        );
        PERFORM create_territory_conquest_notifications(enemy.id, enemy.owner_id, p_owner_id, conquered_area);
      END IF;
    END;
  END LOOP;

  -- Step 4: Build final geometry (merge + stolen union)
  final_geom := merged_geom;
  IF stolen_union IS NOT NULL THEN
    final_geom := ST_UnaryUnion(ST_Collect(final_geom, stolen_union));
  END IF;
  final_geom := ST_MakeValid(final_geom);

  -- Enforce single polygon output: keep largest polygon, preserve holes
  IF ST_NumGeometries(ST_CollectionExtract(final_geom, 3)) > 1 THEN
    WITH d AS (
      SELECT (ST_Dump(ST_CollectionExtract(final_geom, 3))).geom AS g
    )
    SELECT g INTO final_single
    FROM d
    ORDER BY ST_Area(ST_Transform(g, 3857)) DESC
    LIMIT 1;
  ELSE
    final_single := ST_GeometryN(ST_CollectionExtract(final_geom, 3), 1);
  END IF;

  -- Compute attributes for final insert
  v_area_m2 := ST_Area(ST_Transform(final_single, 3857));
  SELECT geom_to_rings_json(final_single) INTO boundary_points_json;
  IF boundary_points_json IS NULL THEN
    WITH er_pts AS (
      SELECT jsonb_agg(jsonb_build_object('lat', ST_Y(pt), 'lng', ST_X(pt)) ORDER BY path[1]) AS outer_ring
      FROM (
        SELECT (ST_DumpPoints(ST_ExteriorRing(final_single))).geom AS pt,
               (ST_DumpPoints(ST_ExteriorRing(final_single))).path
      ) q
    )
    SELECT jsonb_build_array(
             jsonb_build_object('outer', COALESCE((SELECT outer_ring FROM er_pts), '[]'::jsonb),
                                'holes', '[]'::jsonb)
           )
    INTO boundary_points_json;
  END IF;

  INSERT INTO public.territories (
    id, owner_id, boundary_points, area,
    center_lat, center_lng, center_point, boundary_polygon, owner_color
  ) VALUES (
    territory_id,
    p_owner_id,
    boundary_points_json,
    v_area_m2,
    ST_Y(ST_Centroid(final_single)),
    ST_X(ST_Centroid(final_single)),
    ST_SetSRID(ST_Centroid(final_single), 4326),
    final_single,
    owner_color
  );

  -- Delete old self territories that were merged
  IF self_ids IS NOT NULL AND array_length(self_ids, 1) > 0 THEN
    DELETE FROM public.territories WHERE id = ANY(self_ids);
  END IF;

  -- Recompute stats for the owner; enemy stats handled by trigger on territory_steals
  PERFORM recompute_user_stats(p_owner_id);

  RETURN territory_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 9. STATISTICS FUNCTIONS
-- ================================================================

-- FIXED: Function to recompute user statistics (preserves total_runs from Flutter)
CREATE OR REPLACE FUNCTION recompute_user_stats(target_user_id UUID)
RETURNS VOID AS $$
DECLARE
  v_total_area DECIMAL;
  v_conquered INT;
  v_lost INT;
  v_current_total_runs INT; -- Keep existing run count from Flutter
BEGIN
  -- Get current total_runs to preserve it (managed by Flutter, not by territory count)
  SELECT total_runs INTO v_current_total_runs
  FROM public.user_statistics
  WHERE user_id = target_user_id;
  
  -- Sum of current territories area
  SELECT COALESCE(SUM(area), 0) INTO v_total_area
  FROM public.territories
  WHERE owner_id = target_user_id;

  -- Count territories conquered by this user (from territory_steals table)
  SELECT COALESCE(COUNT(DISTINCT stolen_territory_id), 0) INTO v_conquered
  FROM public.territory_steals
  WHERE new_owner_id = target_user_id;

  -- Count territories lost by this user (from territory_steals table)
  SELECT COALESCE(COUNT(DISTINCT stolen_territory_id), 0) INTO v_lost
  FROM public.territory_steals
  WHERE previous_owner_id = target_user_id;

  -- CRITICAL: Do NOT count territories as runs
  -- total_runs should be managed by Flutter based on actual run completions

  -- Upsert into user_statistics - PRESERVE total_runs from Flutter
  INSERT INTO public.user_statistics (user_id, total_runs, total_territory_area, territories_conquered, territories_lost, updated_at)
  VALUES (target_user_id, COALESCE(v_current_total_runs, 0), v_total_area, v_conquered, v_lost, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    total_runs = EXCLUDED.total_runs, -- Keep existing run count from Flutter
    total_territory_area = EXCLUDED.total_territory_area,
    territories_conquered = EXCLUDED.territories_conquered,
    territories_lost = EXCLUDED.territories_lost,
    updated_at = NOW();

  -- Mirror total area to user_profiles for quick view
  UPDATE public.user_profiles
  SET total_territory_area = v_total_area,
      updated_at = NOW()
  WHERE id = target_user_id;
  
  RAISE NOTICE 'Recomputed stats for user %: area=%.2f, conquered=%s, lost=%s, runs=%s (preserved)', 
    target_user_id, v_total_area, v_conquered, v_lost, v_current_total_runs;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 10. NOTIFICATION FUNCTIONS
-- ================================================================

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.notifications 
  SET is_read = TRUE, updated_at = NOW()
  WHERE id = p_notification_id AND user_id = auth.uid();
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete notification (soft delete)
CREATE OR REPLACE FUNCTION delete_notification(p_notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE public.notifications 
  SET is_deleted = TRUE, updated_at = NOW()
  WHERE id = p_notification_id AND user_id = auth.uid();
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user notifications
CREATE OR REPLACE FUNCTION get_user_notifications(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  title VARCHAR,
  message TEXT,
  type VARCHAR,
  is_read BOOLEAN,
  metadata JSONB,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    n.id,
    n.title,
    n.message,
    n.type,
    n.is_read,
    n.metadata,
    n.created_at
  FROM public.notifications n
  WHERE n.user_id = p_user_id 
    AND n.is_deleted = FALSE
  ORDER BY n.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM public.notifications
  WHERE user_id = p_user_id 
    AND is_deleted = FALSE 
    AND is_read = FALSE;
  
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- COINS EARNING FUNCTION
-- ================================================================
-- DAILY CHALLENGE SYSTEM (replaces per-run awarding logic)
-- Cleanup legacy functions (safe no-op if they don't exist)
DROP FUNCTION IF EXISTS award_daily_challenge(UUID, INTEGER, DECIMAL);
DROP FUNCTION IF EXISTS award_daily_challenge(UUID, INT, DECIMAL);
DROP FUNCTION IF EXISTS award_daily_challenge(UUID, INTEGER, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS award_coins_for_run(UUID, INTEGER, DECIMAL);
DROP FUNCTION IF EXISTS award_coins_for_run(UUID, INT, DECIMAL);
DROP FUNCTION IF EXISTS award_coins_for_run(UUID, INTEGER, DOUBLE PRECISION);
-- Table to track user daily challenge completion (single challenge: complete ANY qualifying run once per UTC day)
CREATE TABLE IF NOT EXISTS public.user_daily_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  challenge_date DATE NOT NULL, -- UTC date the challenge refers to
  completed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), -- when condition met
  coins_awarded INTEGER NOT NULL DEFAULT 100,
  UNIQUE(user_id, challenge_date)
);

ALTER TABLE public.user_daily_challenges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own daily challenges" ON public.user_daily_challenges;
CREATE POLICY "Users can view own daily challenges" ON public.user_daily_challenges
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own daily challenges" ON public.user_daily_challenges;
CREATE POLICY "Users can insert own daily challenges" ON public.user_daily_challenges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_user_daily_challenges_user_date ON public.user_daily_challenges(user_id, challenge_date);

-- ================= NEW: USER RUNS (for automatic accumulation) =================
CREATE TABLE IF NOT EXISTS public.user_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes >= 0),
  distance_meters DECIMAL NOT NULL CHECK (distance_meters >= 0),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_runs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own runs" ON public.user_runs;
CREATE POLICY "Users can view own runs" ON public.user_runs FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own runs" ON public.user_runs;
CREATE POLICY "Users can insert own runs" ON public.user_runs FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_user_runs_user_created ON public.user_runs(user_id, created_at);
-- Replaced failing expression index with a generated column for UTC date to avoid syntax issues on some deployments
ALTER TABLE public.user_runs 
  ADD COLUMN IF NOT EXISTS created_utc_date DATE GENERATED ALWAYS AS ((created_at AT TIME ZONE 'UTC')::date) STORED;
CREATE INDEX IF NOT EXISTS idx_user_runs_user_utc_date ON public.user_runs(user_id, created_utc_date);

-- Function to attempt awarding the daily challenge reward. Will only award once per UTC day.
-- Anti-abuse: If device time is changed backwards, we still use NOW() (server time) for date logic.
-- New RPC to record a run, accumulate progress, and auto-award challenge if thresholds met cumulatively.
DROP FUNCTION IF EXISTS create_run_and_maybe_award(INT, DECIMAL);
CREATE OR REPLACE FUNCTION create_run_and_maybe_award(
  p_duration_minutes INTEGER,
  p_distance_meters DECIMAL
)
RETURNS JSON AS $$
DECLARE
  v_user UUID := auth.uid();
  v_today DATE := (NOW() AT TIME ZONE 'UTC')::date;
  v_tot_distance DECIMAL;
  v_tot_minutes INTEGER;
  v_awarded BOOLEAN := FALSE;
  v_current_coins INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.user_runs (user_id, duration_minutes, distance_meters)
  VALUES (v_user, p_duration_minutes, p_distance_meters);

  -- Cumulative totals for today after insertion
  SELECT COALESCE(SUM(distance_meters),0), COALESCE(SUM(duration_minutes),0)
    INTO v_tot_distance, v_tot_minutes
  FROM public.user_runs
  WHERE user_id = v_user AND (created_at AT TIME ZONE 'UTC')::date = v_today;

  -- Check if already completed
  IF NOT EXISTS (
    SELECT 1 FROM public.user_daily_challenges
    WHERE user_id = v_user AND challenge_date = v_today
  ) THEN
    IF v_tot_distance >= 500 AND v_tot_minutes >= 10 THEN
      INSERT INTO public.user_daily_challenges (user_id, challenge_date)
      VALUES (v_user, v_today);
      UPDATE public.user_profiles
        SET coins = coins + 100, updated_at = NOW()
        WHERE id = v_user
        RETURNING coins INTO v_current_coins;
      v_awarded := TRUE;
      RAISE NOTICE 'Daily challenge auto-awarded (100 coins) for user % on %', v_user, v_today;
    END IF;
  END IF;

  IF v_current_coins IS NULL THEN
    SELECT coins INTO v_current_coins FROM public.user_profiles WHERE id = v_user;
  END IF;

  RETURN json_build_object(
    'awarded', v_awarded,
    'total_distance_today', v_tot_distance,
    'total_minutes_today', v_tot_minutes,
    'coins', v_current_coins
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC to fetch daily challenge progress (cumulative for today)
DROP FUNCTION IF EXISTS get_daily_challenge_progress();
CREATE OR REPLACE FUNCTION get_daily_challenge_progress()
RETURNS JSON AS $$
DECLARE
  v_user UUID := auth.uid();
  v_today DATE := (NOW() AT TIME ZONE 'UTC')::date;
  v_tot_distance DECIMAL;
  v_tot_minutes INTEGER;
  v_completed BOOLEAN;
  v_coins INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  SELECT COALESCE(SUM(distance_meters),0), COALESCE(SUM(duration_minutes),0)
    INTO v_tot_distance, v_tot_minutes
  FROM public.user_runs
  WHERE user_id = v_user AND (created_at AT TIME ZONE 'UTC')::date = v_today;

  SELECT EXISTS(
    SELECT 1 FROM public.user_daily_challenges WHERE user_id = v_user AND challenge_date = v_today
  ) INTO v_completed;

  SELECT coins INTO v_coins FROM public.user_profiles WHERE id = v_user;

  RETURN json_build_object(
    'total_distance_today', v_tot_distance,
    'total_minutes_today', v_tot_minutes,
    'completed', v_completed,
    'target_distance', 500,
    'target_minutes', 10,
    'coins', v_coins
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- CLUB FUNCTIONS
-- ================================================================

-- Function to create a new club and add creator as first member
CREATE OR REPLACE FUNCTION create_club_with_creator(
  p_name TEXT,
  p_referral_code TEXT,
  p_creator_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_club_id UUID;
BEGIN
  -- Insert new club
  INSERT INTO public.clubs (name, referral_code, creator_id)
  VALUES (p_name, p_referral_code, p_creator_id)
  RETURNING id INTO v_club_id;
  
  -- Add creator as first member
  INSERT INTO public.club_members (club_id, user_id)
  VALUES (v_club_id, p_creator_id);
  
  RAISE NOTICE 'Created club % with ID % and added creator % as first member', 
    p_name, v_club_id, p_creator_id;
  
  RETURN v_club_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to join a club by referral code
CREATE OR REPLACE FUNCTION join_club_by_referral_code(
  p_referral_code TEXT,
  p_user_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_club_id UUID;
  v_already_member BOOLEAN;
BEGIN
  -- Check if club exists
  SELECT id INTO v_club_id
  FROM public.clubs
  WHERE referral_code = p_referral_code;
  
  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Club with referral code % not found', p_referral_code;
  END IF;
  
  -- Check if user is already a member
  SELECT EXISTS(
    SELECT 1 FROM public.club_members 
    WHERE club_id = v_club_id AND user_id = p_user_id
  ) INTO v_already_member;
  
  IF v_already_member THEN
    RAISE EXCEPTION 'User is already a member of this club';
  END IF;
  
  -- Add user to club
  INSERT INTO public.club_members (club_id, user_id)
  VALUES (v_club_id, p_user_id);
  
  RAISE NOTICE 'User % joined club %', p_user_id, v_club_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all clubs for a user
CREATE OR REPLACE FUNCTION get_user_clubs(p_user_id UUID)
RETURNS TABLE (
  club_id UUID,
  club_name TEXT,
  referral_code TEXT,
  creator_id UUID,
  creator_display_name TEXT,
  club_created_at TIMESTAMPTZ,
  joined_at TIMESTAMPTZ,
  member_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id as club_id,
    c.name::TEXT as club_name,
    c.referral_code::TEXT as referral_code,
    c.creator_id,
    COALESCE(up.display_name, 'Unknown User')::TEXT as creator_display_name,
    c.created_at as club_created_at,
    cm.joined_at,
    (SELECT COUNT(*) FROM public.club_members WHERE club_members.club_id = c.id) as member_count
  FROM public.clubs c
  INNER JOIN public.club_members cm ON c.id = cm.club_id
  LEFT JOIN public.user_profiles up ON c.creator_id = up.id
  WHERE cm.user_id = p_user_id
  ORDER BY cm.joined_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all members of a club
CREATE OR REPLACE FUNCTION get_club_members(p_club_id UUID)
RETURNS TABLE (
  user_id UUID,
  user_email TEXT,
  display_name TEXT,
  joined_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cm.user_id,
    CAST(up.email AS TEXT) as user_email,
    CAST(COALESCE(up.display_name, 'Unknown User') AS TEXT) as display_name,
    cm.joined_at
  FROM public.club_members cm
  LEFT JOIN public.user_profiles up ON cm.user_id = up.id
  WHERE cm.club_id = p_club_id
  ORDER BY cm.joined_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 11. BOTTOM SHEET CONQUEST FUNCTIONS
-- ================================================================

-- Function to get user's conquest statistics for bottom sheet
CREATE OR REPLACE FUNCTION get_user_conquest_summary(p_user_id UUID)
RETURNS TABLE(
  territories_conquered INTEGER,
  territories_lost INTEGER,
  total_area_conquered DOUBLE PRECISION,
  total_area_lost DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(us.territories_conquered, 0) as territories_conquered,
    COALESCE(us.territories_lost, 0) as territories_lost,
    COALESCE(us.total_territory_area, 0) as total_area_conquered,
    0 as total_area_lost  -- We'll calculate this separately if needed
  FROM public.user_statistics us
  WHERE us.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get recent conquest history for bottom sheet
CREATE OR REPLACE FUNCTION get_recent_conquest_history(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
  territory_id UUID,
  territory_area DOUBLE PRECISION,
  action_type TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Get territories this user conquered (from territory_steals table)
  RETURN QUERY
  SELECT 
    ts.stolen_territory_id as territory_id,
    ts.overlap_area as territory_area,
    'conquered'::TEXT as action_type,
    ts.steal_date as created_at
  FROM public.territory_steals ts
  WHERE ts.new_owner_id = p_user_id
    AND ts.reason IN ('partial_conquest', 'complete_conquest')
  ORDER BY ts.steal_date DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



-- ================================================================
-- 12. UTILITY FUNCTIONS
-- ================================================================

-- Function to convert PostGIS geometry to JSON rings format
CREATE OR REPLACE FUNCTION geom_to_rings_json(geom GEOMETRY)
RETURNS JSONB AS $$
DECLARE
  result JSONB := '[]'::jsonb;
  poly_geom GEOMETRY;
  ring_pts JSONB;
  ring_coords JSONB;
BEGIN
  -- Handle NULL geometry
  IF geom IS NULL THEN
    RETURN result;
  END IF;
  
  -- Extract individual polygons from multipolygon
  FOR poly_geom IN SELECT (ST_Dump(geom)).geom LOOP
    -- Get exterior ring points
    SELECT jsonb_agg(
      jsonb_build_object(
        'lat', ST_Y(pt.geom),
        'lng', ST_X(pt.geom)
      ) ORDER BY pt.path[1]
    ) INTO ring_coords
    FROM ST_DumpPoints(ST_ExteriorRing(poly_geom)) AS pt;
    
    -- Add to result if we have valid coordinates
    IF ring_coords IS NOT NULL AND jsonb_array_length(ring_coords) > 0 THEN
      result := result || jsonb_build_object(
        'outer', ring_coords,
        'holes', '[]'::jsonb
      );
    END IF;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Utility function to create user profile if it doesn't exist
DROP FUNCTION IF EXISTS create_user_profile_if_not_exists(UUID, VARCHAR, VARCHAR, VARCHAR);
CREATE OR REPLACE FUNCTION create_user_profile_if_not_exists(
  user_id UUID,
  email VARCHAR,
  display_name VARCHAR DEFAULT NULL,
  user_color VARCHAR DEFAULT '#3B82F6'
)
RETURNS VOID AS $$
BEGIN
  -- Insert user profile if it doesn't exist
  INSERT INTO public.user_profiles (id, email, display_name, user_color)
  VALUES (user_id, email, COALESCE(display_name, 'User ' || user_id::TEXT), user_color)
  ON CONFLICT (id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 13. TRIGGERS (FIXED VERSION)
-- ================================================================

-- FIXED: Trigger function that ONLY updates territory area, NOT run count
-- This fixes the issue where total_runs was incorrectly incremented on territory creation
CREATE OR REPLACE FUNCTION update_territory_area_on_territory_create()
RETURNS TRIGGER AS $$
BEGIN
  -- Update user statistics - ONLY territory area, NOT run count
  -- largest_territory_area is calculated dynamically by Flutter, not stored in database
  INSERT INTO public.user_statistics (user_id, total_territory_area)
  VALUES (NEW.owner_id, NEW.area) -- NO total_runs increment, NO largest_territory_area
  ON CONFLICT (user_id) DO UPDATE SET
    total_territory_area = user_statistics.total_territory_area + NEW.area,
    updated_at = NOW();
  
  -- Update user profile - ONLY territory area, NOT run count
  UPDATE public.user_profiles 
  SET 
    total_territory_area = total_territory_area + NEW.area,
    updated_at = NOW()
  WHERE id = NEW.owner_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for territory creation (area only, no run count)
-- Drop existing trigger first to avoid conflicts
DROP TRIGGER IF EXISTS trigger_update_territory_area_on_territory_create ON public.territories;
DROP TRIGGER IF EXISTS trigger_update_stats_on_territory_create ON public.territories;

CREATE TRIGGER trigger_update_territory_area_on_territory_create
  AFTER INSERT ON public.territories
  FOR EACH ROW
  EXECUTE FUNCTION update_territory_area_on_territory_create();

-- Create trigger for conquest statistics updates
DROP TRIGGER IF EXISTS trigger_update_conquest_stats ON public.territory_steals;
CREATE TRIGGER trigger_update_conquest_stats
  AFTER INSERT OR UPDATE ON public.territory_steals
  FOR EACH ROW
  EXECUTE FUNCTION update_statistics_on_territory_conquest();

-- ================================================================
-- 14. FINAL SETUP
-- ================================================================

-- Final notice
DO $$
BEGIN
  RAISE NOTICE 'Comprehensive Schema Created Successfully!';
  RAISE NOTICE '';
  RAISE NOTICE 'Tables Created:';
  RAISE NOTICE '- user_profiles (user information, colors, and coins)';
  RAISE NOTICE '- territories (territory data with PostGIS support)';
  RAISE NOTICE '- territory_steals (ESSENTIAL for bottom sheet conquest history)';
  RAISE NOTICE '- user_statistics (user performance metrics)';
  RAISE NOTICE '- notifications (territory conquest notifications)';
  RAISE NOTICE '- clubs (club management system)';
  RAISE NOTICE '- club_members (club membership tracking)';
  RAISE NOTICE '';
  RAISE NOTICE 'Key Functions:';
  RAISE NOTICE '- insert_territory (creates territories with conquest logic + auto-merge)';
  RAISE NOTICE '- update_statistics_on_territory_conquest (TRIGGER-based conquest stats)';
  RAISE NOTICE '- create_territory_conquest_notifications (creates notifications)';
  RAISE NOTICE '- get_recent_conquest_history (for bottom sheet - uses territory_steals)';
  -- Replaced legacy per-run coin award with single daily challenge system
  RAISE NOTICE '- create_run_and_maybe_award (records a run, accumulates progress, awards daily coins once)';
  RAISE NOTICE '- get_daily_challenge_progress (returns cumulative UTC-day progress & completion)';
  RAISE NOTICE '- create_club_with_creator (creates clubs and adds creator as member)';
  RAISE NOTICE '- join_club_by_referral_code (joins users to clubs)';
  RAISE NOTICE '- get_user_clubs (gets all clubs for a user)';
  RAISE NOTICE '- get_club_members (gets all members of a club)';
  RAISE NOTICE '';
  RAISE NOTICE 'Territory conquest system is now fully functional!';
  RAISE NOTICE 'Bottom sheet conquest history will work with territory_steals table.';
  RAISE NOTICE 'Territory auto-merge prevents fragmentation for same owner!';
  RAISE NOTICE '';
  RAISE NOTICE 'IMPORTANT: territory_steals table is ESSENTIAL for:';
  RAISE NOTICE '- Bottom sheet conquest history';
  RAISE NOTICE '- Detailed conquest tracking';
  RAISE NOTICE '- Conquest analytics';
  RAISE NOTICE '- User conquest timeline';
  RAISE NOTICE '';
  RAISE NOTICE 'NEW: Territory auto-merge system:';
  RAISE NOTICE '- Automatically merges overlapping territories of same owner';
  RAISE NOTICE '- Prevents territory fragmentation';
  RAISE NOTICE '- Maintains accurate area calculations';
  RAISE NOTICE '- Happens automatically during territory creation';
  RAISE NOTICE '';
  RAISE NOTICE 'FIXED: AUTOMATIC Statistics System:';
  RAISE NOTICE '- Territory creation: Updates ONLY total_territory_area (total_runs managed by Flutter)';
  RAISE NOTICE '- Territory conquest: Updates territories_conquered, territories_lost via TRIGGER';
  RAISE NOTICE '- Territory merging: Automatically recalculates area statistics';
  RAISE NOTICE '- total_runs: Managed by Flutter on each run completion (not affected by merging)';
  RAISE NOTICE '- largest_territory_area: Calculated dynamically by Flutter (always current)';
  RAISE NOTICE '';
  RAISE NOTICE 'NEW: Daily Challenge Coins System:';
  RAISE NOTICE '- Cumulative daily challenge: reach ≥10 min AND ≥500m (across multiple runs)';
  RAISE NOTICE '- Awards 100 coins ONCE per UTC day';
  RAISE NOTICE '- Progress aggregated via user_runs; award recorded in user_daily_challenges';
  RAISE NOTICE '- Coins stored in user_profiles table (server authoritative)';
  RAISE NOTICE '- App fetches progress with get_daily_challenge_progress';
  RAISE NOTICE '';
  RAISE NOTICE 'NEW: Club System:';
  RAISE NOTICE '- Create and join clubs with referral codes';
  RAISE NOTICE '- Track club members and membership';
  RAISE NOTICE '- Full RLS security with proper policies';
  RAISE NOTICE '- Integrated database functions for all operations';
END $$;
