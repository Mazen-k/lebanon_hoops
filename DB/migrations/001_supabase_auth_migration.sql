-- ============================================================
-- Migration 001: Connect public.users to Supabase Auth
-- ============================================================
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor).
-- Safe to run on existing data — uses ADD COLUMN IF NOT EXISTS
-- and ON CONFLICT to never delete existing rows.
-- ============================================================

-- 1. Allow password_hash to be NULL for Supabase-auth users
--    (existing bcrypt rows are unaffected; new OAuth/magic-link
--    users simply won't have one).
ALTER TABLE public.users
  ALTER COLUMN password_hash DROP NOT NULL;

-- 2. Add auth_id column that links to Supabase's auth.users table.
--    Unique: one Supabase account → one public.users row.
--    ON DELETE SET NULL: deleting the auth account doesn't wipe
--    the fan's card collection / history.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS auth_id UUID
    UNIQUE
    REFERENCES auth.users(id) ON DELETE SET NULL;

-- 3. Trigger function: runs after every INSERT on auth.users.
--    • If the email already exists in public.users (legacy account),
--      it links it by writing auth_id — no other fields changed.
--    • If the email is new, it creates a fresh row.
--    • SECURITY DEFINER bypasses RLS so this always succeeds.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username     TEXT;
  v_phone        TEXT;
  v_team_id      INTEGER;
BEGIN
  -- Derive username from metadata, fall back to email prefix
  v_username := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), ''),
    split_part(NEW.email, '@', 1)
  );

  -- Optional fields passed during signUp
  v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'phone_number', '')), '');

  BEGIN
    IF (NEW.raw_user_meta_data->>'favorite_team_id') IS NOT NULL
       AND (NEW.raw_user_meta_data->>'favorite_team_id') NOT IN ('', 'null')
    THEN
      v_team_id := (NEW.raw_user_meta_data->>'favorite_team_id')::INTEGER;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_team_id := NULL;
  END;

  -- Insert or link existing row
  BEGIN
    INSERT INTO public.users (username, email, phone_number, favorite_team_id, auth_id)
    VALUES (v_username, NEW.email, v_phone, v_team_id, NEW.id)
    ON CONFLICT (email)
      DO UPDATE SET auth_id = EXCLUDED.auth_id;
  EXCEPTION WHEN unique_violation THEN
    -- username already taken by a different account: append short suffix
    INSERT INTO public.users (username, email, phone_number, favorite_team_id, auth_id)
    VALUES (
      v_username || '_' || SUBSTRING(REPLACE(NEW.id::TEXT, '-', ''), 1, 6),
      NEW.email, v_phone, v_team_id, NEW.id
    )
    ON CONFLICT (email)
      DO UPDATE SET auth_id = EXCLUDED.auth_id;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never block Supabase Auth from creating the account
  RETURN NEW;
END;
$$;

-- 4. Attach trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Row-Level Security so the Flutter app can query its own profile
--    directly via the Supabase client (uses the anon/JWT role).
--    The Node.js API connects as the postgres superuser and is
--    NOT affected by RLS at all.
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop first in case this migration is re-run
DROP POLICY IF EXISTS "users_read_own"   ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;

-- Authenticated users can SELECT their own row
CREATE POLICY "users_read_own"
  ON public.users
  FOR SELECT
  TO authenticated
  USING (auth_id = auth.uid());

-- Authenticated users can UPDATE their own row
-- (e.g. changing username / phone from the app later)
CREATE POLICY "users_update_own"
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());
