-- Fix generate_italian_receipt_number to use REC-YYYYMMDD-HHMM-SS format
-- instead of RicevutaFiscale-YYYY-NNNN (which was incorrectly labelled as fiscal)

CREATE OR REPLACE FUNCTION public.generate_italian_receipt_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    now_ts TIMESTAMPTZ;
    receipt_number TEXT;
BEGIN
    now_ts := NOW() AT TIME ZONE 'Europe/Rome';

    -- Format: REC-YYYYMMDD-HHMM-SS
    receipt_number := 'REC-'
        || TO_CHAR(now_ts, 'YYYYMMDD')
        || '-'
        || TO_CHAR(now_ts, 'HH24MI')
        || '-'
        || TO_CHAR(now_ts, 'SS');

    RETURN receipt_number;
END;
$$;
