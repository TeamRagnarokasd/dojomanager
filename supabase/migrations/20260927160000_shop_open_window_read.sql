-- "Shop": banner nel Carrello Sponsor che avvisa l'allievo dell'esistenza di
-- un ordine condiviso già aperto per lo sponsor che sta guardando, prima
-- ancora che lui stesso abbia confermato un carrello. Serve quindi poter
-- leggere `shop_group_windows` (oggi riservata solo agli admin) e contare i
-- partecipanti di una finestra aperta senza esporre gli ordini altrui.
--
-- Idempotente: rieseguibile senza errori (DROP POLICY IF EXISTS + CREATE
-- POLICY, CREATE OR REPLACE FUNCTION).
--
-- NON APPLICATA: solo scritta, come richiesto.

-- ============================================================================
-- 1) Policy di sola SELECT per gli utenti autenticati: possono leggere le
--    finestre con status='aperta' (le altre restano visibili solo
--    all'admin, tramite la policy `shop_group_windows_admin_only` già
--    esistente — le due policy per SELECT si sommano in OR). La query lato
--    app seleziona comunque solo le colonne sponsor_id e closes_at, senza
--    mai chiedere le altre.
-- ============================================================================
DROP POLICY IF EXISTS shop_group_windows_select_open_authenticated ON public.shop_group_windows;
CREATE POLICY shop_group_windows_select_open_authenticated
  ON public.shop_group_windows FOR SELECT TO authenticated
  USING (status = 'aperta');

-- ============================================================================
-- 2) Conteggio partecipanti di una finestra aperta per sponsor, senza
--    esporre gli ordini altrui: un utente normale legge solo le proprie
--    righe in `shop_orders` (RLS `shop_orders_user_select_own`), quindi il
--    conteggio deve passare da una funzione SECURITY DEFINER, come già fa
--    `shop_window_info` per lo stesso motivo.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.shop_open_window_participant_count(p_sponsor_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT count(*)::integer
  FROM public.shop_orders o
  JOIN public.shop_group_windows w ON w.id = o.group_window_id
  WHERE w.sponsor_id = p_sponsor_id
    AND w.status = 'aperta'
    AND o.status IN (
      'in_attesa_gruppo', 'da_pagare', 'pagamento_dichiarato', 'pagato', 'ordinato'
    );
$$;

GRANT EXECUTE ON FUNCTION public.shop_open_window_participant_count(uuid) TO authenticated;
