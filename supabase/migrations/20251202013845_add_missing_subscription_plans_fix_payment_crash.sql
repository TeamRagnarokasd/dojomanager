-- Migration: Add missing subscription plans to fix payment crash for "Doppio corso (in convenzione)"
-- Issue: UI shows plans that don't exist in database, causing payment failures

-- ============================================================================
-- 🎯 PURPOSE: Add missing subscription plans to subscription_plans table
-- ============================================================================
-- PROBLEM: User reports payment failure for "Doppio corso (in convenzione)" plan
-- CAUSE: Frontend displays plans that don't exist in the database
-- SOLUTION: Insert all missing plans with exact names and pricing from UI code

-- ============================================================================
-- 📋 PART 1: Insert Missing Subscription Plans
-- ============================================================================

-- Check if plans already exist and insert only if missing
INSERT INTO public.subscription_plans (
    name, 
    price, 
    plan_type, 
    description, 
    entry_count, 
    is_active,
    sumup_url
) 
SELECT * FROM (
    VALUES
        -- Monthly Plans (plan_type = 'monthly')
        ('Corso Singolo', 60.00, 'monthly'::subscription_plan_type, 
         'Scelta tra MMA o BJJ ogni mese, Grappling e Sambo sempre inclusi', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QHVYXRZR'),
        
        ('Corso Singolo (in convenzione)', 50.00, 'monthly'::subscription_plan_type, 
         'Scelta tra MMA o BJJ ogni mese, Grappling e Sambo sempre inclusi - Tariffa agevolata in convenzione', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QPQ08OQA'),
        
        -- 🚨 CRITICAL FIX: This is the problematic plan that was missing
        ('Doppio corso (in convenzione)', 75.00, 'monthly'::subscription_plan_type, 
         'Accesso a tutte le discipline (BJJ, MMA, Grappling, Sambo) - Tariffa agevolata in convenzione', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QR42R0RH'),
        
        ('Doppio Corso', 95.00, 'monthly'::subscription_plan_type, 
         'Accesso a tutte le discipline (BJJ, MMA, Grappling, Sambo)', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QZLJXISP'),
        
        ('Preparazione Atletica', 30.00, 'monthly'::subscription_plan_type, 
         'Focus su condizionamento fisico, Allenamento personalizzato, Programmi specifici', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QU0R8I0A'),
        
        ('Corso Singolo + Preparazione', 90.00, 'monthly'::subscription_plan_type, 
         'Scelta tra MMA o BJJ ogni mese, Grappling e Sambo sempre inclusi, Preparazione atletica completa', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QQ9F1KED'),
        
        ('Doppio Corso + Preparazione', 120.00, 'monthly'::subscription_plan_type, 
         'Tutte le discipline incluse (BJJ, MMA, Grappling, Sambo, Prep. Atletica), Piano di allenamento completo', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QR5I6ZO7'),
        
        ('Doppio corso + Prep. Atl. (in conv.)', 105.00, 'monthly'::subscription_plan_type, 
         'Tutte le discipline incluse (BJJ, MMA, Grappling, Sambo, Prep. Atletica) - Tariffa agevolata in convenzione', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/QT4LT4XQ'),
        
        -- Annual Plan (plan_type = 'annual')
        ('Iscrizione Annuale', 30.00, 'annual'::subscription_plan_type, 
         'Quota associativa annuale, Accesso agli eventi del team', 
         NULL::integer, TRUE, 'https://pay.sumup.com/b2c/Q0ND0EKY')
) AS new_plans(name, price, plan_type, description, entry_count, is_active, sumup_url)
WHERE NOT EXISTS (
    SELECT 1 FROM public.subscription_plans sp 
    WHERE sp.name = new_plans.name
);

-- ============================================================================
-- 📋 PART 2: Verify Plans Were Added Successfully
-- ============================================================================
-- This comment documents expected results after migration runs
-- Expected: All 9 new plans should be added (2 entry-based plans already exist)
-- Total plans after migration: 11

-- ============================================================================
-- 🔍 VERIFICATION QUERIES (Run manually after migration)
-- ============================================================================
-- Uncomment and run these queries to verify the migration succeeded:

-- Query 1: Check all active subscription plans
-- SELECT name, price, plan_type, is_active FROM public.subscription_plans WHERE is_active = true ORDER BY plan_type, price;

-- Query 2: Verify the critical plan exists
-- SELECT * FROM public.subscription_plans WHERE name = 'Doppio corso (in convenzione)';

-- Query 3: Count plans by type
-- SELECT plan_type, COUNT(*) as plan_count FROM public.subscription_plans WHERE is_active = true GROUP BY plan_type;