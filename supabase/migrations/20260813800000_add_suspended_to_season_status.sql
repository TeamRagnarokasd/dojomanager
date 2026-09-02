-- Add 'suspended' value to season_status enum
-- This fixes the error: invalid input value for enum season_status: "paused"

ALTER TYPE public.season_status ADD VALUE IF NOT EXISTS 'suspended';
