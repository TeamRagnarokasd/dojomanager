-- Migration: Add target_discipline column to payment_confirmations table
-- Purpose: Store selected discipline for single course subscriptions
-- Date: 2025-12-25

-- Add target_discipline column (nullable, uses existing discipline_type enum)
ALTER TABLE public.payment_confirmations 
ADD COLUMN target_discipline discipline_type;

-- Add index for efficient filtering by discipline
CREATE INDEX idx_payment_confirmations_target_discipline 
ON public.payment_confirmations(target_discipline);

-- Add comment explaining the column usage
COMMENT ON COLUMN public.payment_confirmations.target_discipline IS 
'Stores the selected discipline for single course subscriptions (Corso Singolo). Used to restrict class bookings to the purchased discipline.';