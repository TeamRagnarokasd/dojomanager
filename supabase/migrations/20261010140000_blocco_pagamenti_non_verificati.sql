-- Blocca lato server la creazione di righe "pagate" per SumUp/Satispay senza
-- un payment_intents verificato dietro: fino ad oggi un utente poteva
-- inserire direttamente in payment_confirmations (via RPC
-- create_payment_confirmation o insert diretto) e in user_subscriptions con
-- payment_method sumup/satispay senza alcuna verifica — esattamente il
-- percorso usato dal vecchio dialog "hai pagato?" (PaymentConfirmationDialog,
-- ora rimosso dall'app) per attivare un abbonamento con un semplice "sì".
--
-- Il flusso automatico vero (sumup/create-payment, satispay/create-payment,
-- claim_paid_intent, PaidIntentsService) non è mai stato toccato: al momento
-- in cui createBatchPaymentAndReceipts inserisce la riga payment_confirmations,
-- il payment_intents corrispondente è già in status='confirmed' (impostato da
-- claim_paid_intent) con confirmation_id ancora null — è esattamente la riga
-- che il controllo qui sotto richiede. Non cambia nulla per quel flusso.
--
-- Gli incassi amministrativi (contanti, bonifico, ricevute manuali, import,
-- riparazioni SQL) restano invariati: il controllo si disattiva per intero
-- quando is_admin_from_auth() è vero.

create or replace function public.require_verified_intent_for_self_service_payment()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_beneficiary uuid;
  v_has_matching_intent boolean;
begin
  -- Si applica solo a sumup/satispay: contanti, bonifico, carta restano
  -- fuori da questo controllo indipendentemente da chi crea la riga.
  if NEW.payment_method::text not in ('sumup', 'satispay') then
    return NEW;
  end if;

  -- Un admin (o chi ha un ruolo admin-level) può sempre creare/riparare una
  -- riga manualmente — import, correzioni, casi particolari.
  if public.is_admin_from_auth() then
    return NEW;
  end if;

  v_beneficiary := coalesce(NEW.beneficiary_profile_id, NEW.user_id);

  select exists (
    select 1
    from public.payment_intents pi
    where pi.user_id = NEW.user_id
      and pi.provider = NEW.payment_method::text
      and pi.status = 'confirmed'
      and pi.confirmation_id is null
      and pi.amount = NEW.amount
      and coalesce(pi.beneficiary_profile_id, pi.user_id) = v_beneficiary
      and pi.custom_plan_id is not distinct from NEW.custom_plan_id
  ) into v_has_matching_intent;

  if not v_has_matching_intent then
    raise exception
      'Pagamento non verificato: nessun intento di pagamento confermato corrispondente trovato per questo acquisto.';
  end if;

  return NEW;
end;
$function$;

create or replace trigger trg_require_verified_intent_payment_confirmations
  before insert on public.payment_confirmations
  for each row
  execute function public.require_verified_intent_for_self_service_payment();

-- user_subscriptions non ha una colonna payment_method: la riga di
-- attivazione viene sempre creata, nello stesso metodo Dart, subito dopo la
-- riga payment_confirmations corrispondente (stesso beneficiario, stesso
-- piano, stesso giro). Il controllo qui richiede che esista già una
-- payment_confirmations 'confirmed' recente e corrispondente — che per
-- sumup/satispay è già stata validata dal trigger sopra nello stesso
-- inserimento, e per contanti/bonifico è creata da un admin, quindi esentata
-- dalla stessa eccezione is_admin_from_auth().

create or replace function public.require_confirmed_payment_for_subscription()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_has_matching_confirmation boolean;
begin
  if public.is_admin_from_auth() then
    return NEW;
  end if;

  select exists (
    select 1
    from public.payment_confirmations pc
    where pc.status = 'confirmed'
      and pc.created_at >= now() - interval '10 minutes'
      and coalesce(pc.beneficiary_profile_id, pc.user_id) = NEW.user_id
      and pc.custom_plan_id is not distinct from NEW.custom_plan_id
  ) into v_has_matching_confirmation;

  if not v_has_matching_confirmation then
    raise exception
      'Attivazione abbonamento non verificata: nessuna conferma di pagamento corrispondente trovata.';
  end if;

  return NEW;
end;
$function$;

create or replace trigger trg_require_confirmed_payment_user_subscriptions
  before insert on public.user_subscriptions
  for each row
  execute function public.require_confirmed_payment_for_subscription();
