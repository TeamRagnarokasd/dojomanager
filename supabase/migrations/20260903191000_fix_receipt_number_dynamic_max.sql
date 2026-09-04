-- Fix: Receipt numbering now dynamically based on MAX receipt number in DB
-- This ensures deleted records don't break the sequence.
-- The next receipt number = MAX(existing number for current year) + 1

CREATE OR REPLACE FUNCTION public.generate_italian_receipt_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_year INTEGER;
    max_number   INTEGER;
    next_number  INTEGER;
    receipt_number TEXT;
BEGIN
    current_year := EXTRACT(YEAR FROM NOW() AT TIME ZONE 'Europe/Rome')::INTEGER;

    -- Find the maximum sequential number already used this year.
    -- Receipt numbers are stored in the format NNN/YYYY (e.g. 007/2026).
    -- We extract the numeric prefix and take the MAX.
    SELECT COALESCE(
        MAX(
            NULLIF(
                REGEXP_REPLACE(
                    SPLIT_PART(receipt_number, '/', 1),
                    '[^0-9]', '', 'g'
                ),
                ''
            )::INTEGER
        ),
        0
    )
    INTO max_number
    FROM public.non_fiscal_receipts
    WHERE receipt_number LIKE '%/' || current_year::TEXT
      AND receipt_number ~ '^\d+/' || current_year::TEXT;

    next_number := max_number + 1;

    -- Format: NNN/YYYY (zero-padded to 3 digits, expands automatically beyond 999)
    receipt_number := LPAD(next_number::TEXT, 3, '0') || '/' || current_year::TEXT;

    RETURN receipt_number;
END;
$$;

-- Ensure authenticated users can still call this function
GRANT EXECUTE ON FUNCTION public.generate_italian_receipt_number() TO authenticated;
