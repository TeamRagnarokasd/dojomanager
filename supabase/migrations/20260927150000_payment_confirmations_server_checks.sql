-- ============================================================================
-- Controlli di sicurezza sui pagamenti, come vincolo vero sul database.
--
-- Oggi "prima l'iscrizione annuale, poi il resto" e "dati del genitore
-- completi per i minorenni" sono controlli solo lato Flutter, aggirabili da
-- un altro percorso (SumUp/Satispay diretti, conferma admin manuale, ecc.).
-- Questo trigger li applica a QUALUNQUE riga di payment_confirmations che
-- passa a status = 'confirmed', indipendentemente da come ci arriva.
--
-- Nota: NON applicata — va eseguita manualmente dopo revisione.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_payment_confirmation_before_confirm()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_beneficiary_id uuid;
    v_is_child boolean := false;
    v_birth_date date;
    v_parent_name text;
    v_parent_surname text;
    v_parent_cf text;
    v_age int;
    v_this_plan_name text;
    v_this_is_annual boolean;
    v_has_prior_annual boolean;
BEGIN
    -- 1) Beneficiario effettivo del pagamento (adulto/minorenne autoregistrato
    --    in user_profiles, oppure un figlio in child_profiles).
    v_beneficiary_id := COALESCE(NEW.beneficiary_profile_id, NEW.user_id);

    IF v_beneficiary_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.child_profiles WHERE id = v_beneficiary_id
    ) INTO v_is_child;

    -- 2) Dati del genitore/tutore, SOLO per i minorenni autoregistrati in
    --    user_profiles (i child_profiles sono già coperti dai dati
    --    dell'account del genitore che li gestisce). Blocca sempre, anche
    --    per il pagamento dell'iscrizione annuale stessa.
    IF NOT v_is_child THEN
        SELECT birth_date, parent_guardian_name, parent_guardian_surname,
               parent_guardian_codice_fiscale
        INTO v_birth_date, v_parent_name, v_parent_surname, v_parent_cf
        FROM public.user_profiles
        WHERE id = v_beneficiary_id;

        IF v_birth_date IS NOT NULL THEN
            v_age := EXTRACT(YEAR FROM AGE(CURRENT_DATE, v_birth_date))::int;

            IF v_age < 18 AND (
                v_parent_name IS NULL OR TRIM(v_parent_name) = ''
                OR v_parent_surname IS NULL OR TRIM(v_parent_surname) = ''
                OR v_parent_cf IS NULL OR TRIM(v_parent_cf) = ''
            ) THEN
                RAISE EXCEPTION 'Prima di poter pagare, il tutore deve compilare i propri dati nel Profilo (nome, cognome e codice fiscale del genitore/tutore).';
            END IF;
        END IF;
    END IF;

    -- 3) Iscrizione annuale prima di tutto il resto — per QUALUNQUE
    --    beneficiario (adulto, minorenne o figlio). Il nome del piano di
    --    questo pagamento si legge da custom_subscription_plans (via
    --    custom_plan_id) o, in assenza, dalla vecchia subscription_plans
    --    (via subscription_plan_id, mantenuta per compatibilità).
    v_this_plan_name := NULL;

    IF NEW.custom_plan_id IS NOT NULL THEN
        SELECT name INTO v_this_plan_name
        FROM public.custom_subscription_plans
        WHERE id = NEW.custom_plan_id;
    END IF;

    IF v_this_plan_name IS NULL AND NEW.subscription_plan_id IS NOT NULL THEN
        SELECT name INTO v_this_plan_name
        FROM public.subscription_plans
        WHERE id = NEW.subscription_plan_id;
    END IF;

    v_this_is_annual := v_this_plan_name IS NOT NULL AND (
        LOWER(v_this_plan_name) LIKE '%iscrizione annuale%'
        OR (LOWER(v_this_plan_name) LIKE '%iscrizione%' AND LOWER(v_this_plan_name) LIKE '%annuale%')
    );

    IF NOT v_this_is_annual THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.payment_confirmations pc
            LEFT JOIN public.custom_subscription_plans csp ON csp.id = pc.custom_plan_id
            LEFT JOIN public.subscription_plans sp ON sp.id = pc.subscription_plan_id
            WHERE pc.status = 'confirmed'
              AND (
                  pc.beneficiary_profile_id = v_beneficiary_id
                  OR (pc.beneficiary_profile_id IS NULL AND pc.user_id = v_beneficiary_id)
              )
              AND (
                  (csp.name IS NOT NULL AND (
                      LOWER(csp.name) LIKE '%iscrizione annuale%'
                      OR (LOWER(csp.name) LIKE '%iscrizione%' AND LOWER(csp.name) LIKE '%annuale%')
                  ))
                  OR (sp.name IS NOT NULL AND (
                      LOWER(sp.name) LIKE '%iscrizione annuale%'
                      OR (LOWER(sp.name) LIKE '%iscrizione%' AND LOWER(sp.name) LIKE '%annuale%')
                  ))
              )
        ) INTO v_has_prior_annual;

        IF NOT v_has_prior_annual THEN
            RAISE EXCEPTION 'Devi prima completare l''iscrizione annuale prima di poter attivare altri piani.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_payment_confirmation_before_confirm
    ON public.payment_confirmations;

CREATE TRIGGER trg_validate_payment_confirmation_before_confirm
    BEFORE INSERT OR UPDATE OF status ON public.payment_confirmations
    FOR EACH ROW
    WHEN (NEW.status = 'confirmed')
    EXECUTE FUNCTION public.validate_payment_confirmation_before_confirm();
