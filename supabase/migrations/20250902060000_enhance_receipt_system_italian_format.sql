-- Location: supabase/migrations/20250902060000_enhance_receipt_system_italian_format.sql
-- Schema Analysis: Existing non_fiscal_receipts table, user_profiles table available
-- Integration Type: Enhancement of existing receipt system for Italian format
-- Dependencies: user_profiles, non_fiscal_receipts (existing tables)

-- Add payment method ENUM for consistent payment types
CREATE TYPE public.payment_method_type AS ENUM ('cash', 'satispay', 'sumup', 'bank_transfer', 'credit_card');

-- Add VAT rate ENUM for Italian tax rates
CREATE TYPE public.vat_rate_type AS ENUM ('0', '4', '5', '10', '22');

-- Enhance existing non_fiscal_receipts table with missing fields for Italian format
ALTER TABLE public.non_fiscal_receipts 
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS customer_tax_code TEXT,
ADD COLUMN IF NOT EXISTS customer_address TEXT,
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS unit_price NUMERIC(10,2),
ADD COLUMN IF NOT EXISTS discount_percentage NUMERIC(5,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS vat_rate public.vat_rate_type DEFAULT '0'::public.vat_rate_type,
ADD COLUMN IF NOT EXISTS vat_amount NUMERIC(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_method public.payment_method_type DEFAULT 'cash'::public.payment_method_type,
ADD COLUMN IF NOT EXISTS validity_start_date DATE,
ADD COLUMN IF NOT EXISTS validity_end_date DATE,
ADD COLUMN IF NOT EXISTS issue_date DATE DEFAULT CURRENT_DATE,
ADD COLUMN IF NOT EXISTS fiscal_notes TEXT;

-- Create organization info table for receipt headers
CREATE TABLE IF NOT EXISTS public.organization_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL DEFAULT 'Team Ragnarok ASD',
    address TEXT NOT NULL DEFAULT 'via giulio bezzi 25, 48026 Russi - RA',
    tax_code TEXT NOT NULL DEFAULT '92100170395',
    phone TEXT,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert default organization info
INSERT INTO public.organization_info (name, address, tax_code) 
VALUES ('Team Ragnarok ASD', 'via giulio bezzi 25, 48026 Russi - RA', '92100170395')
ON CONFLICT DO NOTHING;

-- Create indexes for enhanced queries
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_issue_date ON public.non_fiscal_receipts(issue_date);
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_customer_name ON public.non_fiscal_receipts(customer_name);
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_payment_method ON public.non_fiscal_receipts(payment_method);
CREATE INDEX IF NOT EXISTS idx_non_fiscal_receipts_vat_rate ON public.non_fiscal_receipts(vat_rate);

-- Enable RLS for organization_info
ALTER TABLE public.organization_info ENABLE ROW LEVEL SECURITY;

-- RLS policy for organization_info (admin access only)
CREATE POLICY "admin_manage_organization_info"
ON public.organization_info
FOR ALL
TO authenticated
USING (is_admin_level_user())
WITH CHECK (is_admin_level_user());

-- Create function to generate Italian receipt number
CREATE OR REPLACE FUNCTION public.generate_italian_receipt_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_year INTEGER;
    receipt_count INTEGER;
    receipt_number TEXT;
BEGIN
    -- Get current year
    current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    
    -- Count receipts for current year
    SELECT COALESCE(COUNT(*), 0) + 1 INTO receipt_count
    FROM public.non_fiscal_receipts
    WHERE EXTRACT(YEAR FROM issue_date) = current_year;
    
    -- Format: RicevutaFiscale-YYYY-NNNN (e.g., RicevutaFiscale-2025-0001)
    receipt_number := 'RicevutaFiscale-' || current_year || '-' || LPAD(receipt_count::TEXT, 4, '0');
    
    RETURN receipt_number;
END;
$$;

-- Create function to calculate VAT amount
CREATE OR REPLACE FUNCTION public.calculate_vat_amount(
    subtotal NUMERIC,
    vat_rate TEXT
)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    vat_percentage NUMERIC;
    vat_amount NUMERIC;
BEGIN
    -- Convert vat_rate to numeric percentage
    vat_percentage := vat_rate::NUMERIC;
    
    -- Calculate VAT amount
    IF vat_percentage = 0 THEN
        vat_amount := 0;
    ELSE
        vat_amount := (subtotal * vat_percentage) / 100;
    END IF;
    
    RETURN ROUND(vat_amount, 2);
END;
$$;

-- Create comprehensive function to create Italian receipt
CREATE OR REPLACE FUNCTION public.create_italian_receipt(
    p_created_by UUID,
    p_customer_name TEXT,
    p_description TEXT,
    p_customer_tax_code TEXT DEFAULT NULL,
    p_customer_address TEXT DEFAULT NULL,
    p_quantity INTEGER DEFAULT 1,
    p_unit_price NUMERIC DEFAULT 0,
    p_discount_percentage NUMERIC DEFAULT 0,
    p_vat_rate TEXT DEFAULT '0',
    p_payment_method TEXT DEFAULT 'cash',
    p_validity_start_date DATE DEFAULT NULL,
    p_validity_end_date DATE DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_fiscal_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    receipt_id UUID;
    receipt_number TEXT;
    subtotal NUMERIC;
    discount_amount NUMERIC;
    taxable_amount NUMERIC;
    vat_amount NUMERIC;
    total_amount NUMERIC;
BEGIN
    -- Generate receipt number
    receipt_number := public.generate_italian_receipt_number();
    
    -- Calculate amounts
    subtotal := p_quantity * p_unit_price;
    discount_amount := (subtotal * p_discount_percentage) / 100;
    taxable_amount := subtotal - discount_amount;
    vat_amount := public.calculate_vat_amount(taxable_amount, p_vat_rate);
    total_amount := taxable_amount + vat_amount;
    
    -- Create receipt record
    INSERT INTO public.non_fiscal_receipts (
        receipt_number,
        created_by,
        customer_name,
        customer_tax_code,
        customer_address,
        description,
        quantity,
        unit_price,
        discount_percentage,
        vat_rate,
        vat_amount,
        amount,
        payment_method,
        validity_start_date,
        validity_end_date,
        issue_date,
        notes,
        fiscal_notes,
        status
    ) VALUES (
        receipt_number,
        p_created_by,
        p_customer_name,
        p_customer_tax_code,
        p_customer_address,
        p_description,
        p_quantity,
        p_unit_price,
        p_discount_percentage,
        p_vat_rate::public.vat_rate_type,
        vat_amount,
        total_amount,
        p_payment_method::public.payment_method_type,
        p_validity_start_date,
        p_validity_end_date,
        CURRENT_DATE,
        p_notes,
        p_fiscal_notes,
        'issued'
    ) RETURNING id INTO receipt_id;
    
    RETURN receipt_id;
END;
$$;

-- Insert sample Italian receipts
DO $$
DECLARE
    admin_user_id UUID;
    receipt_id UUID;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_user_id 
    FROM public.user_profiles 
    WHERE role = 'admin' OR role = 'principal_admin' 
    LIMIT 1;
    
    -- Create sample receipt matching the image format
    IF admin_user_id IS NOT NULL THEN
        receipt_id := public.create_italian_receipt(
            p_created_by := admin_user_id,
            p_customer_name := 'Pasquale Casaburo',
            p_description := 'Quota associativa stagione 2023/24',
            p_customer_tax_code := 'CSBPQL96E21F839L',
            p_customer_address := 'Viale Alessandro Manzoni 387, 48122 Ravenna',
            p_quantity := 1,
            p_unit_price := 30.00,
            p_discount_percentage := 0,
            p_vat_rate := '0',
            p_payment_method := 'satispay',
            p_validity_start_date := '2023-08-30',
            p_validity_end_date := '2024-08-29',
            p_fiscal_notes := 'Operazione esente IVA - N2.2'
        );
    END IF;
END $$;