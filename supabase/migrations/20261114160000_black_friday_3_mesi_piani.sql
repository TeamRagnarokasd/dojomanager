-- Black Friday 2026: per ogni corso mensile una versione "3 mesi pagati in una volta con -20%".
-- Il piano promo e' una riga normale di custom_subscription_plans (prezzo, durata, ricevuta,
-- cumulo con il mese gia' attivo seguono la logica esistente) ma e' nascosto nelle liste:
-- l'app lo propone solo quando l'utente sceglie il piano mensile corrispondente.
-- Le righe vengono create SPENTE (is_active=false): si accendono al rilascio dell'app
-- (update custom_subscription_plans set is_active=true where promo_of is not null).
alter table public.custom_subscription_plans
  add column if not exists promo_of uuid references public.custom_subscription_plans(id) on delete cascade,
  add column if not exists promo_ends_at timestamptz;

create unique index if not exists custom_subscription_plans_promo_of_uq
  on public.custom_subscription_plans (promo_of) where promo_of is not null;

insert into public.custom_subscription_plans
  (name, external_url, amount, is_active, created_by, color, duration_months, is_unlimited, entry_count, is_convenzione, promo_of, promo_ends_at)
select b.name || ' - Black Friday 3 mesi', b.external_url, round(b.amount * 3 * 0.8, 2), false, b.created_by, b.color,
       3, false, null, b.is_convenzione, b.id, timestamptz '2026-11-29 00:00:00+01'
from public.custom_subscription_plans b
where b.is_active and b.promo_of is null and coalesce(b.is_unlimited,false) = false
  and b.duration_months = 1 and lower(b.name) not like '%iscrizione%' and lower(b.name) not like '%prova%'
on conflict do nothing;

-- Spegne da sola le promo scadute (controllo ogni ora).
select cron.schedule('promo_plans_expire', '5 * * * *',
  $$update public.custom_subscription_plans set is_active = false where promo_ends_at is not null and promo_ends_at <= now() and is_active$$);
