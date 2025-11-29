-- Location: supabase/migrations/20251120004910_add_message_recurrence_options.sql
-- Schema Analysis: Extending existing admin_communications table
-- Integration Type: Extension (PARTIAL_EXISTS)
-- Dependencies: admin_communications, user_profiles

-- 1. Add recurrence columns to existing admin_communications table
ALTER TABLE public.admin_communications
ADD COLUMN recurrence_type TEXT DEFAULT 'none',
ADD COLUMN recurrence_days TEXT[], -- For weekly: ['monday', 'wednesday', 'friday']
ADD COLUMN recurrence_day_of_month INTEGER, -- For monthly: 1-31
ADD COLUMN next_scheduled_date TIMESTAMPTZ,
ADD COLUMN is_recurring BOOLEAN DEFAULT false,
ADD COLUMN last_sent_at TIMESTAMPTZ;

-- 2. Add index for scheduled message queries
CREATE INDEX idx_admin_communications_next_scheduled 
ON public.admin_communications(next_scheduled_date) 
WHERE is_recurring = true AND next_scheduled_date IS NOT NULL;

CREATE INDEX idx_admin_communications_recurrence_type 
ON public.admin_communications(recurrence_type) 
WHERE is_recurring = true;

-- 3. Add constraint to ensure valid recurrence configurations
ALTER TABLE public.admin_communications
ADD CONSTRAINT check_valid_recurrence 
CHECK (
    (recurrence_type = 'none' AND recurrence_days IS NULL AND recurrence_day_of_month IS NULL) OR
    (recurrence_type = 'weekly' AND recurrence_days IS NOT NULL AND array_length(recurrence_days, 1) > 0) OR
    (recurrence_type = 'monthly' AND recurrence_day_of_month BETWEEN 1 AND 31)
);

-- 4. Function to calculate next scheduled date for recurring messages
CREATE OR REPLACE FUNCTION public.calculate_next_scheduled_date(
    p_recurrence_type TEXT,
    p_recurrence_days TEXT[],
    p_recurrence_day_of_month INTEGER,
    p_last_sent_at TIMESTAMPTZ
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_next_date TIMESTAMPTZ;
    v_current_date TIMESTAMPTZ := COALESCE(p_last_sent_at, CURRENT_TIMESTAMP);
    v_day_name TEXT;
    v_target_day INTEGER;
BEGIN
    -- For weekly recurrence
    IF p_recurrence_type = 'weekly' AND p_recurrence_days IS NOT NULL THEN
        -- Find next occurrence of specified day
        v_next_date := v_current_date + interval '1 day';
        
        -- Loop through next 7 days to find matching day
        FOR i IN 1..7 LOOP
            v_day_name := lower(to_char(v_next_date, 'Day'));
            v_day_name := trim(v_day_name);
            
            IF v_day_name = ANY(p_recurrence_days) THEN
                RETURN v_next_date;
            END IF;
            
            v_next_date := v_next_date + interval '1 day';
        END LOOP;
    
    -- For monthly recurrence
    ELSIF p_recurrence_type = 'monthly' AND p_recurrence_day_of_month IS NOT NULL THEN
        -- Calculate next month occurrence
        v_target_day := p_recurrence_day_of_month;
        
        -- Start with next month
        v_next_date := date_trunc('month', v_current_date) + interval '1 month';
        
        -- Handle months with fewer days (e.g., February, 30th)
        IF v_target_day > extract(day from (v_next_date + interval '1 month' - interval '1 day'))::INTEGER THEN
            -- Use last day of month if target day exceeds month length
            v_next_date := date_trunc('month', v_next_date) + interval '1 month' - interval '1 day';
        ELSE
            v_next_date := date_trunc('month', v_next_date) + (v_target_day - 1) * interval '1 day';
        END IF;
        
        RETURN v_next_date;
    END IF;
    
    -- Default: no next scheduled date
    RETURN NULL;
END;
$$;

-- 5. Function to send recurring messages (called by scheduled job)
CREATE OR REPLACE FUNCTION public.send_scheduled_recurring_messages()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_message_record RECORD;
    v_messages_sent INTEGER := 0;
    v_next_scheduled TIMESTAMPTZ;
BEGIN
    -- Process all messages due for sending
    FOR v_message_record IN
        SELECT * FROM public.admin_communications
        WHERE is_recurring = true
        AND next_scheduled_date <= CURRENT_TIMESTAMP
        AND status = 'scheduled'
    LOOP
        -- Create new message instance (duplicate with new timestamp)
        INSERT INTO public.admin_communications (
            title, content, target_audience, sender_id, 
            priority, status, recurrence_type, recurrence_days, 
            recurrence_day_of_month, is_recurring
        )
        VALUES (
            v_message_record.title,
            v_message_record.content,
            v_message_record.target_audience,
            v_message_record.sender_id,
            v_message_record.priority,
            'sent',
            'none', -- New instance is not recurring
            NULL,
            NULL,
            false
        );
        
        -- Calculate next scheduled date
        v_next_scheduled := public.calculate_next_scheduled_date(
            v_message_record.recurrence_type,
            v_message_record.recurrence_days,
            v_message_record.recurrence_day_of_month,
            CURRENT_TIMESTAMP
        );
        
        -- Update original recurring message with next schedule
        UPDATE public.admin_communications
        SET 
            last_sent_at = CURRENT_TIMESTAMP,
            next_scheduled_date = v_next_scheduled
        WHERE id = v_message_record.id;
        
        v_messages_sent := v_messages_sent + 1;
    END LOOP;
    
    RETURN v_messages_sent;
END;
$$;

-- 6. Comment on new columns for documentation
COMMENT ON COLUMN public.admin_communications.recurrence_type IS 'Message recurrence pattern: none, weekly, or monthly';
COMMENT ON COLUMN public.admin_communications.recurrence_days IS 'Array of weekday names for weekly recurrence (e.g., [monday, wednesday, friday])';
COMMENT ON COLUMN public.admin_communications.recurrence_day_of_month IS 'Day of month (1-31) for monthly recurrence';
COMMENT ON COLUMN public.admin_communications.next_scheduled_date IS 'Next scheduled send date for recurring messages';
COMMENT ON COLUMN public.admin_communications.is_recurring IS 'Flag indicating if message is set to recur';
COMMENT ON COLUMN public.admin_communications.last_sent_at IS 'Timestamp of last automatic send for recurring messages';