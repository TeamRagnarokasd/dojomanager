-- Migration: Split full_name into first_name and last_name
-- Timestamp: 2025-12-06 03:55:37

-- Step 1: Add new columns for first_name and last_name
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT;

-- Step 2: Populate new columns by splitting existing full_name
-- Italian names: typically "Nome Cognome" format
UPDATE user_profiles
SET 
  first_name = CASE 
    WHEN full_name IS NOT NULL AND position(' ' in full_name) > 0 
    THEN TRIM(split_part(full_name, ' ', 1))
    ELSE full_name
  END,
  last_name = CASE 
    WHEN full_name IS NOT NULL AND position(' ' in full_name) > 0 
    THEN TRIM(substring(full_name from position(' ' in full_name) + 1))
    ELSE NULL
  END
WHERE first_name IS NULL;

-- Step 3: Make full_name nullable (for backward compatibility during transition)
ALTER TABLE user_profiles 
ALTER COLUMN full_name DROP NOT NULL;

-- Step 4: Add comment for clarity
COMMENT ON COLUMN user_profiles.first_name IS 'First name (Nome) - separated from full_name';
COMMENT ON COLUMN user_profiles.last_name IS 'Last name (Cognome) - separated from full_name';
COMMENT ON COLUMN user_profiles.full_name IS 'DEPRECATED: Use first_name and last_name instead. Kept for backward compatibility.';

-- Step 5: Create function to auto-sync full_name when first_name or last_name changes
CREATE OR REPLACE FUNCTION sync_full_name()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-populate full_name from first_name + last_name
  NEW.full_name := TRIM(CONCAT(NEW.first_name, ' ', COALESCE(NEW.last_name, '')));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create trigger to maintain backward compatibility
DROP TRIGGER IF EXISTS sync_full_name_trigger ON user_profiles;
CREATE TRIGGER sync_full_name_trigger
  BEFORE INSERT OR UPDATE OF first_name, last_name
  ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_full_name();

-- Step 7: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_first_name ON user_profiles(first_name);
CREATE INDEX IF NOT EXISTS idx_user_profiles_last_name ON user_profiles(last_name);