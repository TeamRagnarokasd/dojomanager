-- Create function to get dashboard statistics safely
-- This function bypasses RLS policies that reference auth.users

CREATE OR REPLACE FUNCTION public.get_dashboard_statistics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    active_members_count INTEGER;
    pending_approvals_count INTEGER;
    total_events_count INTEGER;
    instructor_count INTEGER;
    sponsor_count INTEGER;
    monthly_revenue NUMERIC;
BEGIN
    -- Check if current user is admin
    IF NOT public.is_admin_from_auth() THEN
        RAISE EXCEPTION 'Accesso negato: solo gli amministratori possono visualizzare le statistiche';
    END IF;

    -- Get active members count
    SELECT COUNT(*) INTO active_members_count
    FROM public.user_profiles
    WHERE is_active = true;

    -- Get pending approvals count
    SELECT COUNT(*) INTO pending_approvals_count
    FROM public.pending_registrations
    WHERE status = 'pending';

    -- Get total events count
    SELECT COUNT(*) INTO total_events_count
    FROM public.schedule_instances;

    -- Get instructor count
    SELECT COUNT(*) INTO instructor_count
    FROM public.user_profiles
    WHERE role IN ('instructor', 'instructor_admin');

    -- Get sponsor count
    SELECT COUNT(*) INTO sponsor_count
    FROM public.sponsors
    WHERE status = 'active';

    -- Get monthly revenue
    SELECT COALESCE(SUM(amount), 0) INTO monthly_revenue
    FROM public.non_fiscal_receipts
    WHERE created_at >= (CURRENT_TIMESTAMP - INTERVAL '30 days');

    -- Return all statistics as JSON
    RETURN jsonb_build_object(
        'activeMemberships', active_members_count,
        'pendingApprovals', pending_approvals_count,
        'totalEvents', total_events_count,
        'instructorCount', instructor_count,
        'sponsorCount', sponsor_count,
        'monthlyRevenue', monthly_revenue
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_dashboard_statistics() TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION public.get_dashboard_statistics() IS 
'Returns dashboard statistics for admin users. Uses SECURITY DEFINER to bypass RLS policies.';

