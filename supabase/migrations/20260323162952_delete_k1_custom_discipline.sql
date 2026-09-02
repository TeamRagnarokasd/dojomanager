-- Delete K1 custom discipline record directly from custom_disciplines table
DO $$
BEGIN
    DELETE FROM public.custom_disciplines
    WHERE LOWER(name) = 'k1' OR LOWER(name) LIKE '%k1%';
    
    RAISE NOTICE 'K1 discipline deleted successfully from custom_disciplines';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error deleting K1 discipline: %', SQLERRM;
END $$;
