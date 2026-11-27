-- Phone quick entry: show on the phone when an entry has reached the desktop ledger.
-- A desktop picks up new entries on its next sync, so "seen after this entry was saved" means it has it.
-- The main key (usually the Mac that set up sync) now records when it was last seen too, and both are
-- recorded at most every 30 seconds instead of every 5 minutes, so the phone can tell within a sync or two.

alter table public.app_secret add column if not exists last_seen timestamptz;

create or replace function public.pocket_check(k text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  if k is null or length(k) < 16 then
    raise exception 'invalid key' using errcode = '28000';
  end if;
  h := encode(digest(k, 'sha256'), 'hex');
  if exists (select 1 from app_secret where key_hash = h) then
    update app_secret set last_seen = now()
    where key_hash = h and (last_seen is null or last_seen < now() - interval '30 seconds');
    return;
  end if;
  if exists (select 1 from devices where token_hash = h) then
    update devices set last_seen = now() where token_hash = h and last_seen < now() - interval '30 seconds';
    return;
  end if;
  raise exception 'invalid key' using errcode = '28000';
end $$;

-- Adds master_seen: when the main key was last used (null on servers that haven't seen it since this migration).
create or replace function public.pocket_devices(k text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  perform pocket_check(k);
  h := encode(digest(k, 'sha256'), 'hex');
  return json_build_object(
    'master', exists (select 1 from app_secret where key_hash = h),
    'master_seen', (select last_seen from app_secret where id = 1),
    'devices', coalesce((
      select json_agg(json_build_object('id', d.id, 'name', d.name, 'created_at', d.created_at,
                                        'last_seen', d.last_seen, 'this', d.token_hash = h)
                      order by d.last_seen desc)
      from devices d
    ), '[]'::json)
  );
end $$;

-- create or replace keeps the existing grants.
notify pgrst, 'reload schema';
