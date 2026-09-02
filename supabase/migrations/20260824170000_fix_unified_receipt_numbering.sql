-- Fix: Unified sequential receipt numbering for ALL non-fiscal receipts
-- All receipts (admin-created and auto-generated) share the same sequential counter
-- Format: NNN/YYYY (e.g. 001/2026, 002/2026, ...)

-- Add a dedicated sequence for receipt numbers (per year)
-- We use a table-based counter to support per-year reset
CREATE TABLE IF NOT EXISTS public.receipt_number_counter (
    year INTEGER NOT NULL,
    last_number INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (year)
);

-- Allow admin and authenticated users to use this counter
ALTER TABLE public.receipt_number_counter ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_manage_receipt_counter"
ON public.receipt_number_counter
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Replace generate_italian_receipt_number with sequential NNN/YYYY format
CREATE OR REPLACE FUNCTION public.generate_italian_receipt_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_year INTEGER;
    next_number INTEGER;
    receipt_number TEXT;
BEGIN
    current_year := EXTRACT(YEAR FROM NOW() AT TIME ZONE 'Europe/Rome')::INTEGER;

    -- Upsert: increment counter for current year atomically
    INSERT INTO public.receipt_number_counter (year, last_number)
    VALUES (current_year, 1)
    ON CONFLICT (year) DO UPDATE
        SET last_number = receipt_number_counter.last_number + 1
    RETURNING last_number INTO next_number;

    -- Format: NNN/YYYY (zero-padded to 3 digits)
    receipt_number := LPAD(next_number::TEXT, 3, '0') || '/' || current_year::TEXT;

    RETURN receipt_number;
END;
$$;

-- Grant execute to authenticated users (needed for auto-generated receipts)
GRANT EXECUTE ON FUNCTION public.generate_italian_receipt_number() TO authenticated;

-- Seed the counter with the current max receipt count for 2026
-- so existing receipts don't conflict with new ones
INSERT INTO public.receipt_number_counter (year, last_number)
SELECT 
    EXTRACT(YEAR FROM created_at AT TIME ZONE 'Europe/Rome')::INTEGER AS year,
    COUNT(*) AS last_number
FROM public.non_fiscal_receipts
WHERE EXTRACT(YEAR FROM created_at AT TIME ZONE 'Europe/Rome') = EXTRACT(YEAR FROM NOW() AT TIME ZONE 'Europe/Rome')
GROUP BY EXTRACT(YEAR FROM created_at AT TIME ZONE 'Europe/Rome')::INTEGER
ON CONFLICT (year) DO UPDATE
    SET last_number = EXCLUDED.last_number;
