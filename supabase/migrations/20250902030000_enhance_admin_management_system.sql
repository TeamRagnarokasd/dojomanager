-- Location: supabase/migrations/20250902030000_enhance_admin_management_system.sql
-- Schema Analysis: Existing tables: user_profiles, admin_activity_log, pending_registrations
-- Integration Type: Addition/Enhancement
-- Dependencies: user_profiles (for foreign key references)

-- Create admin communications table for important announcements
CREATE TABLE public.admin_communications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    target_audience TEXT DEFAULT 'all',
    status TEXT DEFAULT 'sent',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create non-fiscal receipts table
CREATE TABLE public.non_fiscal_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number TEXT NOT NULL UNIQUE,
    created_by UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    notes TEXT,
    status TEXT DEFAULT 'issued',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add profile image URL column to user_profiles
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS profile_image_url TEXT;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_admin_communications_sender_id ON public.admin_communications(sender_id);
CREATE INDEX IF NOT EXISTS idx_admin_communications_target_audience ON public.admin_communications(target_audience);
CREATE INDEX IF NOT EXISTS idx_admin_communications_created_at ON public.admin_communications(created_at);

CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_created_by ON public.non_fiscal_receipts(created_by);
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_receipt_number ON public.non_fiscal_receipts(receipt_number);
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_status ON public.non_fiscal_receipts(status);
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_created_at ON public.non_fiscal_receipts(created_at);

-- Create storage bucket for profile images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-images',
    'profile-images',
    true,
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on new tables
ALTER TABLE public.admin_communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.non_fiscal_receipts ENABLE ROW LEVEL SECURITY;

-- Helper function to check admin level access
CREATE OR REPLACE FUNCTION public.is_admin_level_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() 
    AND up.role IN ('admin', 'principal_admin', 'instructor_admin')
    AND up.is_active = true
)
$$;

-- RLS Policies for admin_communications

-- Admins can manage all communications
CREATE POLICY "admin_manage_communications"
ON public.admin_communications
FOR ALL
TO authenticated
USING (public.is_admin_level_user())
WITH CHECK (public.is_admin_level_user());

-- All authenticated users can read communications targeted to them
-- FIXED: Cast enum to text for proper comparison
CREATE POLICY "users_view_communications"
ON public.admin_communications
FOR SELECT
TO authenticated
USING (
    target_audience = 'all' OR
    target_audience = (
        SELECT role::text FROM public.user_profiles 
        WHERE id = auth.uid()
    ) OR
    sender_id = auth.uid()
);

-- RLS Policies for non_fiscal_receipts

-- Only admins can manage non-fiscal receipts
CREATE POLICY "admin_manage_non_fiscal_receipts"
ON public.non_fiscal_receipts
FOR ALL
TO authenticated
USING (public.is_admin_level_user())
WITH CHECK (public.is_admin_level_user());

-- Storage RLS Policies for profile images

-- Users can view their own images and public images
CREATE POLICY "users_view_profile_images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'profile-images' AND
    (
        (storage.foldername(name))[1] = auth.uid()::text OR
        bucket_id IN (SELECT id FROM storage.buckets WHERE public = true)
    )
);

-- Users can upload images to their own folder
CREATE POLICY "users_upload_profile_images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can update/delete their own images
CREATE POLICY "users_manage_own_profile_images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'profile-images' AND
    owner = auth.uid()
)
WITH CHECK (
    bucket_id = 'profile-images' AND
    owner = auth.uid()
);

CREATE POLICY "users_delete_own_profile_images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'profile-images' AND
    owner = auth.uid()
);

-- Admins can manage all profile images
CREATE POLICY "admins_manage_all_profile_images"
ON storage.objects
FOR ALL
TO authenticated
USING (
    bucket_id = 'profile-images' AND
    public.is_admin_level_user()
)
WITH CHECK (
    bucket_id = 'profile-images' AND
    public.is_admin_level_user()
);

-- Mock data for testing
DO $$
DECLARE
    existing_admin_id UUID;
    comm_id UUID := gen_random_uuid();
    receipt_id UUID := gen_random_uuid();
BEGIN
    -- Get an existing admin user
    SELECT id INTO existing_admin_id 
    FROM public.user_profiles 
    WHERE role IN ('admin', 'principal_admin') 
    LIMIT 1;

    -- Insert sample communication if admin exists
    IF existing_admin_id IS NOT NULL THEN
        INSERT INTO public.admin_communications (id, sender_id, title, content, target_audience)
        VALUES (
            comm_id,
            existing_admin_id,
            'Benvenuti nella nuova gestione amministrativa',
            'Il sistema di gestione amministrativa è stato aggiornato con nuove funzionalità per comunicazioni importanti e gestione ricevute.',
            'all'
        );

        -- Insert sample non-fiscal receipt
        INSERT INTO public.non_fiscal_receipts (id, receipt_number, created_by, description, amount, notes)
        VALUES (
            receipt_id,
            'NF202509020001',
            existing_admin_id,
            'Lezione privata di arti marziali',
            35.00,
            'Lezione individuale di 1 ora - settore combattimento'
        );

        RAISE NOTICE 'Mock data inserted successfully';
    ELSE
        RAISE NOTICE 'No admin user found. Create an admin user first to test the features.';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error inserting mock data: %', SQLERRM;
END $$;