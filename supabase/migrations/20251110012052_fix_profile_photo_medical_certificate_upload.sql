-- Fix Profile Photo and Medical Certificate Upload Issues
-- Create medical certificates bucket for private document storage

-- Create medical-certificates bucket (PRIVATE)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'medical-certificates',
    'medical-certificates', 
    false,  -- PRIVATE for security
    10485760, -- 10MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- RLS policy for medical certificates - users can only access their own files
-- Drop existing policy if it exists, then create new one
DROP POLICY IF EXISTS "users_manage_own_medical_certificates" ON storage.objects;
CREATE POLICY "users_manage_own_medical_certificates" ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'medical-certificates' AND owner = auth.uid())
WITH CHECK (bucket_id = 'medical-certificates' AND owner = auth.uid());

-- Ensure profile-images bucket has correct RLS policies
-- Drop existing policy if it exists, then create new one
DROP POLICY IF EXISTS "users_manage_own_profile_images" ON storage.objects;
CREATE POLICY "users_manage_own_profile_images" ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'profile-images' AND owner = auth.uid())
WITH CHECK (bucket_id = 'profile-images' AND owner = auth.uid());

-- Add medical certificate URL column to user profiles if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'medical_certificate_url'
    ) THEN
        ALTER TABLE user_profiles ADD COLUMN medical_certificate_url text;
    END IF;
END $$;

-- Add medical certificate expiry date column
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'medical_certificate_expiry'
    ) THEN
        ALTER TABLE user_profiles ADD COLUMN medical_certificate_expiry date;
    END IF;
END $$;

-- Update medical certificate status for existing users with status 'approved'
UPDATE user_profiles 
SET medical_certificate_status = 'approved' 
WHERE medical_certificate_status = 'pending' 
AND status = 'approved' 
AND role = 'principal_admin';

-- Function to update user profile photo
CREATE OR REPLACE FUNCTION update_user_profile_photo(
    user_id_param uuid,
    image_url_param text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    -- Check if user exists and is authenticated
    IF user_id_param != auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non autorizzato');
    END IF;

    -- Update profile image URL
    UPDATE user_profiles 
    SET 
        profile_image_url = image_url_param,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = user_id_param;

    -- Check if update was successful
    IF FOUND THEN
        result := jsonb_build_object(
            'success', true, 
            'message', 'Foto profilo aggiornata con successo',
            'profile_image_url', image_url_param
        );
    ELSE
        result := jsonb_build_object('success', false, 'message', 'Utente non trovato');
    END IF;

    RETURN result;
END;
$$;

-- Function to upload medical certificate
CREATE OR REPLACE FUNCTION update_user_medical_certificate(
    user_id_param uuid,
    certificate_url_param text,
    expiry_date_param date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
BEGIN
    -- Check if user exists and is authenticated
    IF user_id_param != auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non autorizzato');
    END IF;

    -- Update medical certificate
    UPDATE user_profiles 
    SET 
        medical_certificate_url = certificate_url_param,
        medical_certificate_expiry = expiry_date_param,
        medical_certificate_status = 'pending',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = user_id_param;

    -- Check if update was successful
    IF FOUND THEN
        result := jsonb_build_object(
            'success', true, 
            'message', 'Certificato medico caricato con successo',
            'certificate_url', certificate_url_param,
            'status', 'pending'
        );
    ELSE
        result := jsonb_build_object('success', false, 'message', 'Utente non trovato');
    END IF;

    RETURN result;
END;
$$;

-- Function to get user upload status
CREATE OR REPLACE FUNCTION get_user_upload_status(user_id_param uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result jsonb;
    user_data record;
BEGIN
    -- Check if user exists and is authenticated
    IF user_id_param != auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non autorizzato');
    END IF;

    -- Get user upload status
    SELECT 
        profile_image_url,
        medical_certificate_url,
        medical_certificate_status,
        medical_certificate_expiry
    INTO user_data
    FROM user_profiles 
    WHERE id = user_id_param;

    -- Check if user exists
    IF FOUND THEN
        result := jsonb_build_object(
            'success', true,
            'profile_image_url', user_data.profile_image_url,
            'medical_certificate_url', user_data.medical_certificate_url,
            'medical_certificate_status', user_data.medical_certificate_status,
            'medical_certificate_expiry', user_data.medical_certificate_expiry
        );
    ELSE
        result := jsonb_build_object('success', false, 'message', 'Utente non trovato');
    END IF;

    RETURN result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_user_profile_photo TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_medical_certificate TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_upload_status TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_medical_certificate_status 
ON user_profiles (medical_certificate_status) 
WHERE medical_certificate_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_medical_certificate_expiry 
ON user_profiles (medical_certificate_expiry) 
WHERE medical_certificate_expiry IS NOT NULL;

-- Comment for documentation
COMMENT ON FUNCTION update_user_profile_photo IS 'Updates user profile photo with proper authentication check';
COMMENT ON FUNCTION update_user_medical_certificate IS 'Updates user medical certificate with proper authentication check';
COMMENT ON FUNCTION get_user_upload_status IS 'Gets user upload status including profile photo and medical certificate';