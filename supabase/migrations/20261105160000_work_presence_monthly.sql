-- Presenze e compensi: riepilogo MESE PER MESE di buoni pasto e rimborso km.
-- Stessa regola di work_presence_summary (un giorno = un buono pasto;
-- 1 viaggio al giorno, 2 se almeno una presenza di quel giorno ha extra_trip),
-- ma raggruppata per mese. Solo lettura: non modifica nessun dato.

create or replace function public.work_presence_monthly(p_year integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_year int := coalesce(p_year, extract(year from current_date)::int);
  v_uid uuid; v_voucher numeric; v_km numeric; v_rate numeric;
begin
  if not public.can_access_admin_section('attendance_compensation') then
    raise exception 'accesso negato';
  end if;
  select value::uuid into v_uid from work_settings where key='work_instructor_user_id';
  select value::numeric into v_voucher from work_settings where key='work_meal_voucher_value';
  select value::numeric into v_km from work_settings where key='work_km_round_trip';
  select value::numeric into v_rate from work_settings where key='work_km_rate';

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'month', m,
      'days', days,
      'trips', trips,
      'voucher_total', days * v_voucher,
      'km_total', trips * v_km,
      'km_amount', round(trips * v_km * v_rate, 2)
    ) order by m)
    from (
      select extract(month from presence_date)::int as m,
             count(*)::int as days,
             sum(1 + (case when x then 1 else 0 end))::int as trips
      from (
        select presence_date, bool_or(extra_trip) x
        from instructor_presences
        where user_id = v_uid and status = 'confirmed'
          and extract(year from presence_date) = v_year
        group by presence_date
      ) d
      group by 1
    ) g
  ), '[]'::jsonb);
end $$;

grant execute on function public.work_presence_monthly(integer) to authenticated;
