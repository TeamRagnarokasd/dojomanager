-- Fix Team Ragnarok fiscal code from 92100 to 92100170395
-- Update any existing records in gym_info table that may have incorrect fiscal code
-- This migration handles the case where gym_info table might not exist yet

-- Check if gym_info table exists and update if it does
DO $$
DECLARE
    table_exists BOOLEAN;
    record_count INTEGER := 0;
BEGIN
    -- Check if gym_info table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'gym_info'
    ) INTO table_exists;
    
    IF table_exists THEN
        -- Update existing gym_info records with correct fiscal code
        UPDATE public.gym_info 
        SET tax_code = '92100170395',
            updated_at = CURRENT_TIMESTAMP
        WHERE tax_code = '92100' OR (tax_code LIKE '92100%' AND tax_code != '92100170395');
        
        GET DIAGNOSTICS record_count = ROW_COUNT;
        
        -- Ensure the default Team Ragnarok record exists with correct data
        INSERT INTO public.gym_info (name, address, tax_code) 
        VALUES ('TEAM RAGNAROK ASD', 'via giulio bezzi 25, 48026 Russi - RA', '92100170395')
        ON CONFLICT (id) DO UPDATE SET
            tax_code = '92100170395',
            updated_at = CURRENT_TIMESTAMP;
        
        -- Add constraint only if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints 
            WHERE constraint_name = 'check_valid_tax_code' 
            AND table_name = 'gym_info' 
            AND table_schema = 'public'
        ) THEN
            ALTER TABLE public.gym_info
            ADD CONSTRAINT check_valid_tax_code 
            CHECK (length(tax_code) >= 11);
        END IF;
        
        -- Get final count for verification
        SELECT COUNT(*) INTO record_count
        FROM public.gym_info
        WHERE tax_code = '92100170395';
        
        IF record_count > 0 THEN
            RAISE NOTICE 'Successfully updated fiscal code to 92100170395 for % records', record_count;
        ELSE
            RAISE NOTICE 'Warning: No records found with updated fiscal code';
        END IF;
    ELSE
        RAISE NOTICE 'gym_info table does not exist yet. This migration will be handled when the table is created.';
    END IF;
END $$;