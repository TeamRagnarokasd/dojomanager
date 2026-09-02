-- Migration: Add image_consent column to child_profiles
-- This allows tracking whether the guardian accepted the liberatoria immagini

ALTER TABLE public.child_profiles
ADD COLUMN IF NOT EXISTS image_consent BOOLEAN NOT NULL DEFAULT false;
