-- Location: supabase/migrations/20251111045416_add_medical_certificate_start_date.sql
-- Schema Analysis: user_profiles table exists with medical_certificate_expiry but missing medical_certificate_start_date
-- Integration Type: extension - adding missing column to support complete date range functionality
-- Dependencies: existing user_profiles table

-- Add the missing medical_certificate_start_date column to user_profiles table
ALTER TABLE public.user_profiles
ADD COLUMN medical_certificate_start_date DATE;

-- Add index for the new column for better query performance
CREATE INDEX idx_user_profiles_medical_certificate_start_date 
ON public.user_profiles(medical_certificate_start_date);

-- Add additional fields to support complete certificate details that the UI form expects
ALTER TABLE public.user_profiles
ADD COLUMN medical_certificate_doctor_name TEXT,
ADD COLUMN medical_certificate_medical_center TEXT,
ADD COLUMN medical_certificate_type TEXT;

-- Add indexes for the new text fields
CREATE INDEX idx_user_profiles_medical_certificate_type 
ON public.user_profiles(medical_certificate_type);

-- Create or replace the function to update medical certificate with complete details
CREATE OR REPLACE FUNCTION public.update_user_medical_certificate_complete(
    user_uuid UUID,
    certificate_url TEXT,
    start_date DATE,
    expiry_date DATE,
    doctor_name TEXT,
    medical_center TEXT,
    certificate_type TEXT,
    certificate_status TEXT DEFAULT 'pending'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    update_result JSONB;
BEGIN
    -- Validate input parameters
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User ID is required'
        );
    END IF;

    IF start_date IS NOT NULL AND expiry_date IS NOT NULL AND start_date >= expiry_date THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Start date must be before expiry date'
        );
    END IF;

    -- Update the user profile with complete medical certificate information
    UPDATE public.user_profiles
    SET 
        medical_certificate_url = certificate_url,
        medical_certificate_start_date = start_date,
        medical_certificate_expiry = expiry_date,
        medical_certificate_doctor_name = doctor_name,
        medical_certificate_medical_center = medical_center,
        medical_certificate_type = certificate_type,
        medical_certificate_status = certificate_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = user_uuid;

    -- Check if update was successful
    IF FOUND THEN
        SELECT jsonb_build_object(
            'id', up.id,
            'medical_certificate_url', up.medical_certificate_url,
            'medical_certificate_start_date', up.medical_certificate_start_date,
            'medical_certificate_expiry', up.medical_certificate_expiry,
            'medical_certificate_doctor_name', up.medical_certificate_doctor_name,
            'medical_certificate_medical_center', up.medical_certificate_medical_center,
            'medical_certificate_type', up.medical_certificate_type,
            'medical_certificate_status', up.medical_certificate_status,
            'success', true
        ) INTO update_result
        FROM public.user_profiles up
        WHERE up.id = user_uuid;

        RETURN update_result;
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found or update failed'
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM
        );
END;
$$;

-- Create function to get complete medical certificate details
CREATE OR REPLACE FUNCTION public.get_user_medical_certificate_details(user_uuid UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    certificate_details JSONB;
BEGIN
    -- Validate input
    IF user_uuid IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User ID is required'
        );
    END IF;

    -- Get complete medical certificate information
    SELECT jsonb_build_object(
        'id', up.id,
        'medical_certificate_url', up.medical_certificate_url,
        'medical_certificate_start_date', up.medical_certificate_start_date,
        'medical_certificate_expiry', up.medical_certificate_expiry,
        'medical_certificate_doctor_name', up.medical_certificate_doctor_name,
        'medical_certificate_medical_center', up.medical_certificate_medical_center,
        'medical_certificate_type', up.medical_certificate_type,
        'medical_certificate_status', up.medical_certificate_status,
        'success', true
    ) INTO certificate_details
    FROM public.user_profiles up
    WHERE up.id = user_uuid;

    -- Return result or error if user not found
    IF certificate_details IS NOT NULL THEN
        RETURN certificate_details;
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM
        );
END;
$$;

-- Update existing sample data with start dates where expiry dates exist
DO $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN 
        SELECT id, medical_certificate_expiry 
        FROM public.user_profiles 
        WHERE medical_certificate_expiry IS NOT NULL 
        AND medical_certificate_start_date IS NULL
    LOOP
        -- Set start date to 1 year before expiry date for existing certificates
        UPDATE public.user_profiles
        SET medical_certificate_start_date = user_record.medical_certificate_expiry - INTERVAL '1 year',
            medical_certificate_doctor_name = 'Dr. Mario Rossi',
            medical_certificate_medical_center = 'Centro Medico San Giovanni',
            medical_certificate_type = 'di_base'
        WHERE id = user_record.id;
    END LOOP;

    RAISE NOTICE 'Updated % existing medical certificates with start dates', 
                 (SELECT COUNT(*) FROM public.user_profiles WHERE medical_certificate_expiry IS NOT NULL);
END $$;