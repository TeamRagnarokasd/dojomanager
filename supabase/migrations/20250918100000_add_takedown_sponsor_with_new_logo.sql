-- Location: supabase/migrations/20250918100000_add_takedown_sponsor_with_new_logo.sql
-- Schema Analysis: Sponsors table exists with proper structure and RLS policies
-- Integration Type: Update existing sponsor data with new Takedown logo
-- Dependencies: sponsors table, user_profiles table (for created_by reference)

-- Remove old Takedown sponsor if exists (case insensitive)
DELETE FROM public.sponsors 
WHERE LOWER(name) LIKE '%takedown%';

-- Add/Update Takedown sponsor with new logo
DO $$
DECLARE
    admin_user_id UUID;
    takedown_sponsor_id UUID := gen_random_uuid();
BEGIN
    -- Get admin user ID for created_by field
    SELECT id INTO admin_user_id 
    FROM public.user_profiles 
    WHERE email = 'lutadordeeliteravenna@gmail.com'
    LIMIT 1;

    -- Insert Takedown sponsor with new logo
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
        'Takedown',
        'Partner tecnico ufficiale - Equipaggiamento professionale per arti marziali',
        'assets/images/162743-1758189534738.jpg',
        'https://www.takedown-shop.com',
        'active'::public.sponsor_status,
        1,
        admin_user_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    );

    -- Log success
    RAISE NOTICE 'Takedown sponsor added successfully with new logo image';

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: Admin user not found. Using NULL for created_by';
        INSERT INTO public.sponsors (
            id,
            name,
            description,
            image_url,
            external_url,
            status,
            display_order,
            created_at,
            updated_at
        ) VALUES (
            takedown_sponsor_id,
            'Takedown',
            'Partner tecnico ufficiale - Equipaggiamento professionale per arti marziali',
            'assets/images/162743-1758189534738.jpg',
            'https://www.takedown-shop.com',
            'active'::public.sponsor_status,
            1,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        );
    WHEN unique_violation THEN
        RAISE NOTICE 'Takedown sponsor already exists with this name';
        -- Update existing sponsor with new image
        UPDATE public.sponsors 
        SET 
            image_url = 'assets/images/162743-1758189534738.jpg',
            description = 'Partner tecnico ufficiale - Equipaggiamento professionale per arti marziali',
            external_url = 'https://www.takedown-shop.com',
            status = 'active'::public.sponsor_status,
            display_order = 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE LOWER(name) = 'takedown';
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;

-- Verify the sponsor was added/updated
DO $$
DECLARE
    sponsor_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO sponsor_count
    FROM public.sponsors 
    WHERE LOWER(name) = 'takedown';
    
    IF sponsor_count > 0 THEN
        RAISE NOTICE 'Takedown sponsor verification: SUCCESS - % record(s) found', sponsor_count;
    ELSE
        RAISE NOTICE 'Takedown sponsor verification: FAILED - No records found';
    END IF;
END $$;