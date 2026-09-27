-- Compliance: un genitore/tutore che ha creato l'account solo per gestire
-- uno o più figli (child_profiles) e non si è mai iscritto lui stesso non
-- deve comparire tra gli "iscritti da controllare" (conteggio Membri
-- Registrati, chip "Nessun certificato" in Gestione Utenti Sistema): per
-- lui va guardato lo stato dei figli, non il proprio.
--
-- is_self_enrolled_adult(): true se l'utente [p_user_id] risulta lui stesso
-- beneficiario di almeno una prenotazione lezione o di un pagamento adulto
-- confermato. Usa COALESCE(beneficiary_profile_id, user_id) invece del solo
-- user_id, per essere coerente con la correzione già fatta sulle
-- prenotazioni lezioni (class_registrations_beneficiary).
--
-- Idempotente: rieseguibile senza errori (CREATE OR REPLACE FUNCTION).
--
-- NON APPLICATA: solo scritta, come richiesto.

CREATE OR REPLACE FUNCTION public.is_self_enrolled_adult(p_user_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT EXISTS (SELECT 1 FROM public.class_registrations cr WHERE COALESCE(cr.beneficiary_profile_id, cr.user_id) = p_user_id)
     OR EXISTS (SELECT 1 FROM public.payment_confirmations pc WHERE COALESCE(pc.beneficiary_profile_id, pc.user_id) = p_user_id AND pc.beneficiary_type = 'adult' AND pc.status = 'confirmed');
$$;

GRANT EXECUTE ON FUNCTION public.is_self_enrolled_adult(uuid) TO authenticated;
