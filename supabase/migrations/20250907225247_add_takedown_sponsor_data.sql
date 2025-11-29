-- Location: supabase/migrations/20250907225247_add_takedown_sponsor_data.sql
-- Schema Analysis: sponsors table exists with all necessary columns
-- Integration Type: Add initial sponsor data for takedown brand
-- Dependencies: sponsors table (existing), user_profiles table (for created_by)

-- Add initial takedown sponsor data to existing sponsors table
DO $$
DECLARE
    admin_user_id UUID;
    takedown_sponsor_id UUID := gen_random_uuid();
BEGIN
    -- Get an admin user ID for created_by field
    SELECT id INTO admin_user_id 
    FROM public.user_profiles 
    WHERE role IN ('admin', 'principal_admin') 
    LIMIT 1;

    -- If no admin user found, use any user
    IF admin_user_id IS NULL THEN
        SELECT id INTO admin_user_id 
        FROM public.user_profiles 
        LIMIT 1;
    END IF;

    -- Insert takedown sponsor data
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
        takedown_sponsor_id,
        'takedown',
        'Takedown Shop - Abbigliamento e accessori per arti marziali di alta qualità',
        'assets/images/158183-1757284833624.jpg',
        'https://takedownshop.com/',
        'active'::public.sponsor_status,
        1,
        admin_user_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (name) DO NOTHING; -- Avoid duplicate if already exists

    -- Log the sponsor creation
    IF admin_user_id IS NOT NULL THEN
        RAISE NOTICE 'Created takedown sponsor with ID: %', takedown_sponsor_id;
    ELSE
        RAISE NOTICE 'Warning: No user found for created_by field';
    END IF;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error when creating sponsor: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Sponsor with name "takedown" already exists';
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error creating sponsor: %', SQLERRM;
END $$;