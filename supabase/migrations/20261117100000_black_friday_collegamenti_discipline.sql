-- I piani Black Friday (promo_of) non avevano collegamenti alle discipline in
-- discipline_custom_plan_associations: la prenotazione li ignorava ("Nessun abbonamento valido").
-- Copia i collegamenti dal piano mensile di base. Gia' applicata sul DB il 17/11/2026.
insert into public.discipline_custom_plan_associations (discipline_name, custom_plan_id)
select a.discipline_name, p.id
from public.custom_subscription_plans p
join public.discipline_custom_plan_associations a on a.custom_plan_id = p.promo_of
where p.promo_of is not null
  and not exists (select 1 from public.discipline_custom_plan_associations x
                  where x.custom_plan_id = p.id and x.discipline_name = a.discipline_name);
