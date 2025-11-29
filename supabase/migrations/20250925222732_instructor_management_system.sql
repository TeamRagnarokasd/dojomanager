-- Location: supabase/migrations/20250925222732_instructor_management_system.sql
-- Schema Analysis: Existing user_profiles table with role support, need instructor details
-- Integration Type: PARTIAL_EXISTS - Extending existing schema with instructor profiles
-- Dependencies: user_profiles (existing), discipline_type (existing)

-- 1. Create instructor profiles table to store detailed instructor information
CREATE TABLE public.instructor_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    bio TEXT,
    years_experience INTEGER,
    primary_discipline public.discipline_type NOT NULL,
    disciplines public.discipline_type[] DEFAULT '{}',
    specializations TEXT[] DEFAULT '{}',
    certifications TEXT[] DEFAULT '{}',
    achievements TEXT[] DEFAULT '{}',
    languages TEXT[] DEFAULT '{}',
    profile_image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    availability_schedule JSONB DEFAULT '{}',
    contact_info JSONB DEFAULT '{}',
    social_media JSONB DEFAULT '{}',
    student_testimonials JSONB DEFAULT '[]',
    join_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create indexes for efficient queries
CREATE INDEX idx_instructor_profiles_user_id ON public.instructor_profiles(user_id);
CREATE INDEX idx_instructor_profiles_primary_discipline ON public.instructor_profiles(primary_discipline);
CREATE INDEX idx_instructor_profiles_is_active ON public.instructor_profiles(is_active);
CREATE INDEX idx_instructor_profiles_disciplines ON public.instructor_profiles USING GIN(disciplines);

-- 3. Create instructor specializations lookup table
CREATE TABLE public.instructor_specializations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instructor_id UUID REFERENCES public.instructor_profiles(id) ON DELETE CASCADE,
    specialization TEXT NOT NULL,
    proficiency_level TEXT DEFAULT 'intermediate',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_instructor_specializations_instructor_id ON public.instructor_specializations(instructor_id);

-- 4. Create storage bucket for instructor profile images (public since they're for display)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'instructor-images',
    'instructor-images',
    true, -- Public bucket since instructor photos are for public viewing
    10485760, -- 10MB limit for high-quality instructor photos
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
);

-- 5. Enable RLS for instructor tables
ALTER TABLE public.instructor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instructor_specializations ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies - Using Pattern 4 (Public Read, Private Write) for instructor profiles
-- Everyone can view instructor profiles (for directory display)
CREATE POLICY "public_can_read_instructor_profiles"
ON public.instructor_profiles
FOR SELECT
TO public
USING (is_active = true);

-- Only the instructor can manage their own profile
CREATE POLICY "instructors_manage_own_instructor_profiles"
ON public.instructor_profiles
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Admins can manage all instructor profiles
CREATE POLICY "admins_manage_all_instructor_profiles"
ON public.instructor_profiles
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'principal_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'principal_admin')
    )
);

-- RLS for instructor specializations - Pattern 2 (Simple User Ownership)
CREATE POLICY "users_manage_own_instructor_specializations"
ON public.instructor_specializations
FOR ALL
TO authenticated
USING (
    instructor_id IN (
        SELECT id FROM public.instructor_profiles ip
        WHERE ip.user_id = auth.uid()
    )
)
WITH CHECK (
    instructor_id IN (
        SELECT id FROM public.instructor_profiles ip
        WHERE ip.user_id = auth.uid()
    )
);

-- Public can read specializations for active instructors
CREATE POLICY "public_can_read_instructor_specializations"
ON public.instructor_specializations
FOR SELECT
TO public
USING (
    instructor_id IN (
        SELECT id FROM public.instructor_profiles ip
        WHERE ip.is_active = true
    )
);

-- 7. Storage RLS policies for instructor images (Pattern 2: Public Storage)
-- Anyone can view instructor profile images
CREATE POLICY "public_can_view_instructor_images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'instructor-images');

-- Only admins can upload instructor images
CREATE POLICY "admins_upload_instructor_images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'instructor-images'
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'principal_admin')
    )
);

-- Admins can manage instructor images
CREATE POLICY "admins_manage_instructor_images"
ON storage.objects
FOR ALL
TO authenticated
USING (
    bucket_id = 'instructor-images'
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'principal_admin')
    )
)
WITH CHECK (
    bucket_id = 'instructor-images'
    AND EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid() 
        AND up.role IN ('admin', 'principal_admin')
    )
);

-- 8. Create function to update instructor profile updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_instructor_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_instructor_profiles_updated_at
    BEFORE UPDATE ON public.instructor_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_instructor_profiles_updated_at();

-- 9. Mock data for testing (this will be removed after admin adds real instructors)
DO $$
DECLARE
    admin_user_id UUID;
    instructor1_profile_id UUID := gen_random_uuid();
    instructor2_profile_id UUID := gen_random_uuid();
    instructor3_profile_id UUID := gen_random_uuid();
BEGIN
    -- Get the existing admin user
    SELECT id INTO admin_user_id 
    FROM public.user_profiles 
    WHERE role IN ('admin', 'principal_admin') 
    AND is_active = true 
    LIMIT 1;

    -- Only create sample data if we have an admin user
    IF admin_user_id IS NOT NULL THEN
        -- Sample instructor profiles for testing
        INSERT INTO public.instructor_profiles (
            id, user_id, bio, years_experience, primary_discipline, disciplines, 
            specializations, certifications, achievements, languages, is_active, join_date
        ) VALUES (
            instructor1_profile_id, admin_user_id, 
            'Esperto di Brazilian Jiu-Jitsu con oltre 15 anni di esperienza nell insegnamento. Specializzato in tecniche di guardia e submission grappling.',
            15, 'bjj'::public.discipline_type, 
            ARRAY['bjj', 'grappling']::public.discipline_type[],
            ARRAY['Guard Work', 'Submissions', 'Competition Training'],
            ARRAY['Cintura Nera 3º Dan BJJ - Gracie Academy', 'Instructor Certificate IBJJF'],
            ARRAY['Campione Europeo IBJJF 2019 - Peso Medio', 'Campione Nazionale Grappling 2017-2020'],
            ARRAY['Italiano', 'Inglese', 'Portoghese'],
            true, '2018-03-15'
        ), (
            instructor2_profile_id, admin_user_id,
            'Ex-fighter professionista MMA con vasta esperienza in SAMBO Combat. Specialista in tecniche di striking e grappling per MMA.',
            20, 'mma'::public.discipline_type,
            ARRAY['mma', 'sambo']::public.discipline_type[],
            ARRAY['Striking', 'SAMBO Throws', 'MMA Conditioning'],
            ARRAY['Master of Sport in SAMBO - Russia', 'Professional MMA Fighter License'],
            ARRAY['Pro MMA Record: 12 vittorie, 3 sconfitte', 'Campione Russo SAMBO Combat 2015'],
            ARRAY['Russo', 'Inglese', 'Italiano'],
            true, '2019-01-20'
        ), (
            instructor3_profile_id, admin_user_id,
            'Maestro internazionale di SAMBO Sport e Combat. Medaglia di bronzo ai Mondiali SAMBO 2016.',
            18, 'sambo'::public.discipline_type,
            ARRAY['sambo']::public.discipline_type[],
            ARRAY['Russian Throws', 'Ground Control', 'SAMBO Competition Prep'],
            ARRAY['International SAMBO Master - FIAS', 'Certified SAMBO Referee Level A'],
            ARRAY['Medaglia di Bronzo Mondiali SAMBO 2016', 'Campione Europeo SAMBO Sport 2014-2015'],
            ARRAY['Russo', 'Inglese'],
            true, '2020-09-10'
        );

        RAISE NOTICE 'Sample instructor profiles created successfully for testing';
    ELSE
        RAISE NOTICE 'No admin user found. Sample instructor data not created.';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating sample data: %', SQLERRM;
END $$;