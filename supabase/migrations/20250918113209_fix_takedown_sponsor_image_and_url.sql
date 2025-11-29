-- Migration: Fix Takedown sponsor image display and correct URL
-- Purpose: Fix Takedown sponsor image not showing and ensure URL opens takedownshop.com correctly
-- Author: Assistant
-- Date: 2025-09-18 11:32:09

BEGIN;

-- First, check if Takedown sponsor exists and update it, otherwise insert it
INSERT INTO public.sponsors (
    id,
    name,
    description,
    image_url,
    external_url,
    status,
    display_order,
    created_by,
    created_at,
    updated_at
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479', -- Fixed UUID for Takedown
    'Takedown',
    'Abbigliamento e accessori per arti marziali e sport da combattimento',
    'https://dojomanage9222.builtwithrocket.new/assets/images/162741-1758188985237.jpg', -- Use the provided asset image
    'https://takedownshop.com', -- Correct URL with https protocol
    'active'::public.sponsor_status,
    1, -- High priority display order
    (SELECT id FROM public.user_profiles WHERE email = 'lutadordeeliteravenna@gmail.com' LIMIT 1),
    NOW(),
    NOW()
)
ON CONFLICT (name) 
DO UPDATE SET
    description = 'Abbigliamento e accessori per arti marziali e sport da combattimento',
    image_url = 'https://dojomanage9222.builtwithrocket.new/assets/images/162741-1758188985237.jpg',
    external_url = 'https://takedownshop.com',
    status = 'active'::public.sponsor_status,
    display_order = 1,
    updated_at = NOW();

-- Ensure other sponsors have proper display order
UPDATE public.sponsors 
SET 
    display_order = 
        CASE name
            WHEN 'Takedown' THEN 1
            WHEN 'Kanokimonos' THEN 2
            WHEN 'Venum' THEN 3
            ELSE display_order + 10 -- Move others down
        END,
    updated_at = NOW()
WHERE name IN ('Takedown', 'Kanokimonos', 'Venum');

-- Verify the update by selecting the Takedown sponsor
DO $$
DECLARE
    takedown_record RECORD;
BEGIN
    SELECT * INTO takedown_record FROM public.sponsors WHERE name = 'Takedown';
    
    IF takedown_record IS NOT NULL THEN
        RAISE NOTICE 'Takedown sponsor updated successfully:';
        RAISE NOTICE 'ID: %', takedown_record.id;
        RAISE NOTICE 'Name: %', takedown_record.name;
        RAISE NOTICE 'Image URL: %', takedown_record.image_url;
        RAISE NOTICE 'External URL: %', takedown_record.external_url;
        RAISE NOTICE 'Status: %', takedown_record.status;
        RAISE NOTICE 'Display Order: %', takedown_record.display_order;
    ELSE
        RAISE EXCEPTION 'Failed to create or update Takedown sponsor';
    END IF;
END $$;

COMMIT;