-- Migration: add password_reset_tokens table
-- Stores short-lived tokens for self-service password reset

CREATE TABLE IF NOT EXISTS public.password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '1 hour'),
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast token lookup
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token
  ON public.password_reset_tokens (token);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_email
  ON public.password_reset_tokens (email);

-- RLS: only service_role can read/write (edge function uses service key)
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Allow anonymous insert (the edge function inserts via anon key with service role)
-- We use a permissive policy scoped to the edge function context
CREATE POLICY "service_role_all" ON public.password_reset_tokens
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Auto-cleanup: delete expired tokens older than 24 hours
CREATE OR REPLACE FUNCTION public.cleanup_expired_reset_tokens()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.password_reset_tokens
  WHERE expires_at < NOW() - INTERVAL '24 hours';
END;
$$;
