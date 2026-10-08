-- Tracks which app version/build each user's client last reported, and adds
-- the admin-facing RPC to list them highlighting who is behind the current
-- app_version.version_code. The table and report_app_version() already exist
-- on the remote database (created ahead of this migration); the first part
-- below is written idempotently so this migration is safe to re-apply and
-- keeps the schema tracked in version control going forward.

create table if not exists public.app_client_versions (
  user_id uuid primary key references public.user_profiles(id) on delete cascade,
  platform text not null default 'android',
  version_name text,
  build_number integer,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

alter table public.app_client_versions enable row level security;

drop policy if exists app_client_versions_admin_read on public.app_client_versions;
create policy app_client_versions_admin_read on public.app_client_versions
  for select
  to authenticated
  using (
    exists (
      select 1 from public.user_profiles p
      where p.id = auth.uid()
        and p.role = any (array['admin'::public.user_role, 'principal_admin'::public.user_role])
    )
  );

create or replace function public.report_app_version(p_platform text, p_version_name text, p_build integer)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then return; end if;
  insert into public.app_client_versions (user_id, platform, version_name, build_number, last_seen_at)
    values (auth.uid(), coalesce(nullif(p_platform, ''), 'android'), p_version_name, p_build, now())
    on conflict (user_id) do update set
      platform = excluded.platform,
      version_name = excluded.version_name,
      build_number = excluded.build_number,
      last_seen_at = now();
end
$function$;

-- Admin-only list, joined with user_profiles for display name/email,
-- comparing each client's build_number against the current app_version
-- row's version_code — oldest last access first, since that's the most
-- actionable ordering for following up with inactive/stale clients.
create or replace function public.admin_outdated_clients_list()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v jsonb;
  current_version_code integer;
begin
  if not public.is_admin_from_auth() then
    raise exception 'accesso negato';
  end if;

  select version_code into current_version_code from public.app_version limit 1;

  select coalesce(jsonb_agg(x order by x->>'last_seen_at' asc), '[]'::jsonb)
  into v
  from (
    select jsonb_build_object(
      'user_id', up.id,
      'name', up.full_name,
      'email', up.email,
      'platform', acv.platform,
      'version_name', acv.version_name,
      'build_number', acv.build_number,
      'last_seen_at', acv.last_seen_at,
      'outdated', (
        current_version_code is not null
        and acv.build_number is not null
        and acv.build_number < current_version_code
      )
    ) x
    from public.app_client_versions acv
    join public.user_profiles up on up.id = acv.user_id
  ) s;

  return coalesce(v, '[]'::jsonb);
end
$function$;

-- Register the new "Versioni app" admin section, defaulting to off like
-- every other optional section (the principal admin turns it on).
alter table public.admin_section_visibility drop constraint if exists admin_section_visibility_section_key_check;
alter table public.admin_section_visibility add constraint admin_section_visibility_section_key_check
  check (section_key = any (array[
    'administration_asd', 'cash_register', 'receipts', 'team_data', 'deadlines',
    'drive_documents', 'documents_archive', 'attendance_compensation',
    'social_events', 'payment_review', 'compliance_docs', 'letterhead',
    'app_versions'
  ]));

insert into public.admin_section_visibility (section_key, visible_to_admins)
values ('app_versions', false)
on conflict (section_key) do nothing;
