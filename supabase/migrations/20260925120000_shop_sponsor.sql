-- "Sponsor e Shop": allievi caricano lo screenshot del carrello fatto sul
-- sito di uno sponsor convenzionato, un'edge function lo legge con Claude e
-- calcola il prezzo scontato, l'allievo conferma (da solo o unendosi a un
-- gruppo per dividere la spedizione) e paga (Satispay o contanti). L'admin
-- vede gli ordini per finestra/sponsor, l'elenco unito dei prodotti da
-- ordinare e i margini. Tutto è dietro `shop_enabled_for_me()` (flag globale
-- o riga in shop_testers) e non tocca nessuna tabella esistente.
--
-- Idempotente: rieseguibile senza errori (CREATE TABLE IF NOT EXISTS, DROP
-- POLICY IF EXISTS + CREATE POLICY, CREATE OR REPLACE FUNCTION, INSERT ...
-- ON CONFLICT DO NOTHING).

-- ============================================================================
-- 1) shop_sponsor_settings — una riga per sponsor con lo shop attivo.
--    Leggibile da chiunque sia autenticato (serve al banner e al carrello),
--    scrivibile solo da admin.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shop_sponsor_settings (
  sponsor_id uuid PRIMARY KEY REFERENCES public.sponsors(id) ON DELETE CASCADE,
  discount_pct numeric NOT NULL DEFAULT 20,
  shipping_total numeric NOT NULL DEFAULT 20,
  cash_surcharge numeric NOT NULL DEFAULT 5,
  satispay_tag text NOT NULL DEFAULT '@prizzi_d',
  window_days integer NOT NULL DEFAULT 3,
  close_hour integer NOT NULL DEFAULT 12,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.shop_sponsor_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_sponsor_settings_select_authenticated ON public.shop_sponsor_settings;
CREATE POLICY shop_sponsor_settings_select_authenticated
  ON public.shop_sponsor_settings FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS shop_sponsor_settings_admin_write ON public.shop_sponsor_settings;
CREATE POLICY shop_sponsor_settings_admin_write
  ON public.shop_sponsor_settings FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 2) shop_price_list — listino per sponsor. Solo admin: gli allievi non
--    devono mai vedere cost_price. L'edge function la legge con la service
--    role (bypassa RLS).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shop_price_list (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_id uuid NOT NULL REFERENCES public.sponsors(id) ON DELETE CASCADE,
  model_code text,
  description text NOT NULL,
  color text,
  sizes text,
  cost_price numeric NOT NULL,
  retail_price numeric NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_shop_price_list_sponsor ON public.shop_price_list (sponsor_id);

ALTER TABLE public.shop_price_list ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_price_list_admin_only ON public.shop_price_list;
CREATE POLICY shop_price_list_admin_only
  ON public.shop_price_list FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 3) shop_group_windows — finestre di ordine condiviso per sponsor. Accesso
--    diretto solo admin; gli allievi la leggono indirettamente tramite
--    shop_window_info() (SECURITY DEFINER).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shop_group_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_id uuid NOT NULL REFERENCES public.sponsors(id) ON DELETE CASCADE,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closes_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'aperta' CHECK (status IN ('aperta', 'chiusa')),
  closed_early_by_admin boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_shop_group_windows_sponsor_status
  ON public.shop_group_windows (sponsor_id, status);

ALTER TABLE public.shop_group_windows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_group_windows_admin_only ON public.shop_group_windows;
CREATE POLICY shop_group_windows_admin_only
  ON public.shop_group_windows FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 4) shop_orders — un ordine per allievo. L'allievo legge solo le proprie
--    righe; admin tutto. Nessun INSERT/UPDATE diretto per gli allievi: solo
--    tramite le RPC sotto (l'INSERT iniziale lo fa l'edge function con la
--    service role).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shop_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_id uuid NOT NULL REFERENCES public.sponsors(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  screenshot_path text NOT NULL,
  -- Ogni elemento: {"descrizione","model_code","taglia","quantita",
  -- "prezzo_ufficiale","prezzo_allievo","in_listino"}.
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  member_total numeric NOT NULL DEFAULT 0,
  shared boolean NOT NULL DEFAULT false,
  group_window_id uuid REFERENCES public.shop_group_windows(id) ON DELETE SET NULL,
  shipping_share numeric,
  payment_method text CHECK (payment_method IN ('satispay', 'contanti')),
  cash_surcharge_applied numeric NOT NULL DEFAULT 0,
  final_total numeric,
  status text NOT NULL DEFAULT 'da_confermare' CHECK (status IN (
    'da_confermare', 'in_attesa_gruppo', 'da_pagare', 'pagamento_dichiarato',
    'pagato', 'ordinato', 'annullato'
  )),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_shop_orders_user ON public.shop_orders (user_id);
CREATE INDEX IF NOT EXISTS idx_shop_orders_sponsor ON public.shop_orders (sponsor_id);
CREATE INDEX IF NOT EXISTS idx_shop_orders_window ON public.shop_orders (group_window_id);
CREATE INDEX IF NOT EXISTS idx_shop_orders_status ON public.shop_orders (status);

ALTER TABLE public.shop_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_orders_user_select_own ON public.shop_orders;
CREATE POLICY shop_orders_user_select_own
  ON public.shop_orders FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS shop_orders_admin_all ON public.shop_orders;
CREATE POLICY shop_orders_admin_all
  ON public.shop_orders FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 5) shop_order_costs — costo e margine per ordine. Solo admin.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shop_order_costs (
  order_id uuid PRIMARY KEY REFERENCES public.shop_orders(id) ON DELETE CASCADE,
  cost_total numeric NOT NULL DEFAULT 0,
  margin numeric NOT NULL DEFAULT 0
);

ALTER TABLE public.shop_order_costs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_order_costs_admin_only ON public.shop_order_costs;
CREATE POLICY shop_order_costs_admin_only
  ON public.shop_order_costs FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 6) shop_testers — utenti che vedono la funzione anche a flag spento.
--    Ognuno legge la propria riga, solo admin scrive.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shop_testers (
  user_id uuid PRIMARY KEY REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.shop_testers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_testers_self_select ON public.shop_testers;
CREATE POLICY shop_testers_self_select
  ON public.shop_testers FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS shop_testers_admin_write ON public.shop_testers;
CREATE POLICY shop_testers_admin_write
  ON public.shop_testers FOR ALL TO authenticated
  USING (public.is_admin_from_auth())
  WITH CHECK (public.is_admin_from_auth());

-- ============================================================================
-- 7) Flag globale (spento di default — si accende dal DB quando pronto).
-- ============================================================================
INSERT INTO public.app_feature_flags (key, enabled)
VALUES ('shop_sponsor_enabled', false)
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- 8) shop_enabled_for_me(): true se il flag globale è acceso oppure
--    l'utente corrente è in shop_testers.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.shop_enabled_for_me()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT enabled FROM public.app_feature_flags WHERE key = 'shop_sponsor_enabled'),
    false
  )
  OR EXISTS (
    SELECT 1 FROM public.shop_testers st WHERE st.user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.shop_enabled_for_me() TO authenticated;

-- ============================================================================
-- 9) shop_confirm_order — l'allievo conferma il carrello letto dall'edge
--    function. Se condiviso, aggancia (o apre) la finestra dello sponsor.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.shop_confirm_order(p_order_id uuid, p_shared boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%ROWTYPE;
  v_window_id uuid;
  v_window_days integer;
  v_close_hour integer;
  v_shipping_total numeric;
  v_close_date date;
  v_closes_at timestamptz;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Ordine non trovato.';
  END IF;
  IF v_order.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Questo ordine non appartiene all''utente corrente.';
  END IF;
  IF v_order.status <> 'da_confermare' THEN
    RAISE EXCEPTION 'Questo ordine non è più in attesa di conferma.';
  END IF;

  SELECT COALESCE(window_days, 3), COALESCE(close_hour, 12), COALESCE(shipping_total, 20)
  INTO v_window_days, v_close_hour, v_shipping_total
  FROM public.shop_sponsor_settings
  WHERE sponsor_id = v_order.sponsor_id;

  v_window_days := COALESCE(v_window_days, 3);
  v_close_hour := COALESCE(v_close_hour, 12);
  v_shipping_total := COALESCE(v_shipping_total, 20);

  IF p_shared THEN
    SELECT id INTO v_window_id
    FROM public.shop_group_windows
    WHERE sponsor_id = v_order.sponsor_id AND status = 'aperta'
    ORDER BY opened_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_window_id IS NULL THEN
      v_close_date := (now() AT TIME ZONE 'Europe/Rome')::date + (v_window_days - 1);
      v_closes_at := (v_close_date::text || ' ' || v_close_hour || ':00:00')::timestamp
        AT TIME ZONE 'Europe/Rome';

      INSERT INTO public.shop_group_windows (sponsor_id, closes_at, status)
      VALUES (v_order.sponsor_id, v_closes_at, 'aperta')
      RETURNING id INTO v_window_id;
    END IF;

    UPDATE public.shop_orders
    SET shared = true,
        group_window_id = v_window_id,
        status = 'in_attesa_gruppo',
        updated_at = now()
    WHERE id = p_order_id;
  ELSE
    UPDATE public.shop_orders
    SET shared = false,
        shipping_share = v_shipping_total,
        status = 'da_pagare',
        updated_at = now()
    WHERE id = p_order_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.shop_confirm_order(uuid, boolean) TO authenticated;

-- ============================================================================
-- 10) shop_declare_payment — l'allievo dichiara come ha pagato.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.shop_declare_payment(p_order_id uuid, p_method text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%ROWTYPE;
  v_cash_surcharge numeric;
  v_surcharge_applied numeric := 0;
  v_final_total numeric;
BEGIN
  IF p_method NOT IN ('satispay', 'contanti') THEN
    RAISE EXCEPTION 'Metodo di pagamento non valido.';
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Ordine non trovato.';
  END IF;
  IF v_order.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Questo ordine non appartiene all''utente corrente.';
  END IF;
  IF v_order.status <> 'da_pagare' THEN
    RAISE EXCEPTION 'Questo ordine non è in attesa di pagamento.';
  END IF;

  IF p_method = 'contanti' THEN
    SELECT COALESCE(cash_surcharge, 5) INTO v_cash_surcharge
    FROM public.shop_sponsor_settings
    WHERE sponsor_id = v_order.sponsor_id;
    v_surcharge_applied := COALESCE(v_cash_surcharge, 5);
  END IF;

  v_final_total := v_order.member_total + COALESCE(v_order.shipping_share, 0) + v_surcharge_applied;

  UPDATE public.shop_orders
  SET payment_method = p_method,
      cash_surcharge_applied = v_surcharge_applied,
      final_total = v_final_total,
      status = 'pagamento_dichiarato',
      updated_at = now()
  WHERE id = p_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.shop_declare_payment(uuid, text) TO authenticated;

-- ============================================================================
-- 11) shop_window_info — quota spedizione e chiusura, senza mai esporre i
--     dati degli altri partecipanti.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.shop_window_info(p_order_id uuid)
RETURNS TABLE(closes_at timestamptz, other_participants integer, shipping_share numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%ROWTYPE;
  v_shipping_total numeric;
  v_participants integer;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Ordine non trovato.';
  END IF;
  IF v_order.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Questo ordine non appartiene all''utente corrente.';
  END IF;

  IF v_order.group_window_id IS NULL THEN
    RETURN QUERY SELECT NULL::timestamptz, 0, v_order.shipping_share;
    RETURN;
  END IF;

  SELECT w.closes_at INTO closes_at
  FROM public.shop_group_windows w
  WHERE w.id = v_order.group_window_id;

  SELECT count(*) INTO v_participants
  FROM public.shop_orders
  WHERE group_window_id = v_order.group_window_id
    AND status IN ('in_attesa_gruppo', 'da_pagare', 'pagamento_dichiarato', 'pagato', 'ordinato');

  IF v_participants < 1 THEN
    v_participants := 1;
  END IF;

  SELECT COALESCE(s.shipping_total, 20) INTO v_shipping_total
  FROM public.shop_sponsor_settings s
  WHERE s.sponsor_id = v_order.sponsor_id;
  v_shipping_total := COALESCE(v_shipping_total, 20);

  other_participants := v_participants - 1;
  shipping_share := ROUND(v_shipping_total / v_participants, 2);
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.shop_window_info(uuid) TO authenticated;

-- ============================================================================
-- 12) Chiusura finestra — logica condivisa tra l'azione admin e il cron.
-- ============================================================================
CREATE OR REPLACE FUNCTION public._shop_close_window(p_window_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sponsor_id uuid;
  v_shipping_total numeric;
  v_order_count integer;
  v_share numeric;
BEGIN
  SELECT sponsor_id INTO v_sponsor_id
  FROM public.shop_group_windows
  WHERE id = p_window_id
  FOR UPDATE;

  IF v_sponsor_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(s.shipping_total, 20) INTO v_shipping_total
  FROM public.shop_sponsor_settings s
  WHERE s.sponsor_id = v_sponsor_id;
  v_shipping_total := COALESCE(v_shipping_total, 20);

  SELECT count(*) INTO v_order_count
  FROM public.shop_orders
  WHERE group_window_id = p_window_id AND status = 'in_attesa_gruppo';

  IF v_order_count = 0 THEN
    v_order_count := 1;
  END IF;

  v_share := ROUND(v_shipping_total / v_order_count, 2);

  UPDATE public.shop_orders
  SET shipping_share = v_share,
      status = 'da_pagare',
      updated_at = now()
  WHERE group_window_id = p_window_id AND status = 'in_attesa_gruppo';

  UPDATE public.shop_group_windows
  SET status = 'chiusa'
  WHERE id = p_window_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public._shop_close_window(uuid) FROM PUBLIC, anon, authenticated;

-- Admin: chiude subito una finestra ancora aperta.
CREATE OR REPLACE FUNCTION public.shop_close_window(p_window_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_from_auth() THEN
    RAISE EXCEPTION 'Solo un amministratore può chiudere una finestra.';
  END IF;

  UPDATE public.shop_group_windows
  SET closed_early_by_admin = true
  WHERE id = p_window_id AND status = 'aperta';

  PERFORM public._shop_close_window(p_window_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.shop_close_window(uuid) TO authenticated;

-- Admin: conferma il pagamento dichiarato dall'allievo.
CREATE OR REPLACE FUNCTION public.shop_mark_paid(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_from_auth() THEN
    RAISE EXCEPTION 'Solo un amministratore può confermare il pagamento.';
  END IF;

  UPDATE public.shop_orders
  SET status = 'pagato', updated_at = now()
  WHERE id = p_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.shop_mark_paid(uuid) TO authenticated;

-- Admin: segna l'ordine come ordinato al fornitore.
CREATE OR REPLACE FUNCTION public.shop_mark_ordered(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin_from_auth() THEN
    RAISE EXCEPTION 'Solo un amministratore può segnare l''ordine come ordinato.';
  END IF;

  UPDATE public.shop_orders
  SET status = 'ordinato', updated_at = now()
  WHERE id = p_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.shop_mark_ordered(uuid) TO authenticated;

-- Cron: chiude tutte le finestre 'aperte' scadute.
CREATE OR REPLACE FUNCTION public.shop_close_expired_windows()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_window record;
BEGIN
  FOR v_window IN
    SELECT id FROM public.shop_group_windows
    WHERE status = 'aperta' AND closes_at <= now()
  LOOP
    PERFORM public._shop_close_window(v_window.id);
  END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.shop_close_expired_windows() FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- 13) pg_cron ogni 15 minuti (ri-pianificato in modo idempotente).
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'shop-close-expired-windows';

SELECT cron.schedule(
  'shop-close-expired-windows',
  '*/15 * * * *',
  $$SELECT public.shop_close_expired_windows();$$
);

-- ============================================================================
-- 14) Bucket privato 'shop-carts' — ognuno carica/legge solo la propria
--     cartella user_id/, admin legge tutto.
-- ============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'shop-carts',
  'shop-carts',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS shop_carts_users_manage_own ON storage.objects;
CREATE POLICY shop_carts_users_manage_own
  ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'shop-carts' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'shop-carts' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS shop_carts_admin_read_all ON storage.objects;
CREATE POLICY shop_carts_admin_read_all
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'shop-carts' AND public.is_admin_from_auth());
