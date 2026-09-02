-- Add booking_passpartout column to user_profiles
-- This allows the principal admin to grant a user the ability to book
-- any class without an active subscription.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS booking_passpartout BOOLEAN NOT NULL DEFAULT FALSE;

-- Log the migration
DO $$
BEGIN
  RAISE NOTICE 'booking_passpartout column added to user_profiles';
END $$;
