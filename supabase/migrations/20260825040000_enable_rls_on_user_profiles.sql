-- Enable Row Level Security on public.user_profiles
-- This resolves the critical Supabase warning:
-- "Policy exists for disabled RLS" on public.user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
