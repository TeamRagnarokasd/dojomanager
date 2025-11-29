-- 🎯 FIX 1: ADD TAX_CODE COLUMN TO USER_PROFILES
-- This migration adds the missing tax_code column that causes the payment crash
-- It's separate from codice_fiscale to provide English-friendly API access

-- Step 1: Add tax_code column (nullable for backward compatibility)
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS tax_code TEXT;

-- Step 2: Migrate existing codice_fiscale data to tax_code
UPDATE public.user_profiles 
SET tax_code = codice_fiscale 
WHERE codice_fiscale IS NOT NULL AND tax_code IS NULL;

-- Step 3: Create index for tax_code lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_tax_code 
ON public.user_profiles(tax_code);

-- Step 4: Add comment explaining the column
COMMENT ON COLUMN public.user_profiles.tax_code IS 
'Italian fiscal code (Codice Fiscale) - English alias for API compatibility. Used in receipt generation.';

-- Step 5: Create trigger to sync tax_code and codice_fiscale bidirectionally
CREATE OR REPLACE FUNCTION sync_tax_code_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- If tax_code is updated, sync to codice_fiscale
  IF NEW.tax_code IS DISTINCT FROM OLD.tax_code THEN
    NEW.codice_fiscale := NEW.tax_code;
  END IF;
  
  -- If codice_fiscale is updated, sync to tax_code
  IF NEW.codice_fiscale IS DISTINCT FROM OLD.codice_fiscale THEN
    NEW.tax_code := NEW.codice_fiscale;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Attach trigger to user_profiles
DROP TRIGGER IF EXISTS sync_tax_code_trigger ON public.user_profiles;
CREATE TRIGGER sync_tax_code_trigger
  BEFORE INSERT OR UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_tax_code_fields();

-- Step 7: Update RLS policies to allow users to update their own tax_code
-- Modify existing policy to include tax_code
DROP POLICY IF EXISTS users_update_own_basic_info ON public.user_profiles;
CREATE POLICY users_update_own_basic_info ON public.user_profiles
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid() AND 
    NOT (role_title IS DISTINCT FROM (SELECT role_title FROM public.user_profiles WHERE id = auth.uid()))
  );