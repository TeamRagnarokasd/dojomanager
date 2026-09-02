-- Migration: Add target_discipline_2 column to payment_confirmations table
-- Purpose: Store second selected discipline for Doppio Corso subscriptions
-- Date: 2025-01-01

-- Add target_discipline_2 column (nullable, uses existing discipline_type enum)
ALTER TABLE public.payment_confirmations 
ADD COLUMN target_discipline_2 discipline_type;

-- Add index for efficient filtering by second discipline
CREATE INDEX idx_payment_confirmations_target_discipline_2 
ON public.payment_confirmations(target_discipline_2);

-- Add comment explaining the column usage
COMMENT ON COLUMN public.payment_confirmations.target_discipline_2 IS 
'Stores the second selected discipline for Doppio Corso subscriptions. Used when user selects two different disciplines (e.g., BJJ + MMA).';

