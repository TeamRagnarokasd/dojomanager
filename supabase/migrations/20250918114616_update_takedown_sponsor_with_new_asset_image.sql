-- Migration: Update Takedown sponsor with new golden logo asset image
-- Date: 2025-09-18

-- Update Takedown sponsor with new asset image path
UPDATE public.sponsors 
SET 
    image_url = 'assets/images/162766-1758195943319.jpg',
    description = 'Partner Ufficiale - Abbigliamento e accessori per arti marziali e sport da combattimento',
    external_url = 'https://takedownshop.com',
    display_order = 1,
    updated_at = CURRENT_TIMESTAMP
WHERE name = 'Takedown';

-- Verify the update was successful
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.sponsors 
        WHERE name = 'Takedown' 
        AND image_url = 'assets/images/162766-1758195943319.jpg'
    ) THEN
        RAISE EXCEPTION 'Failed to update Takedown sponsor image';
    END IF;
    
    RAISE NOTICE 'Successfully updated Takedown sponsor with new golden logo asset image';
END $$;