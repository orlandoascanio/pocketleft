-- Subscription membership is independent of category. Nullable for legacy category inference.
-- Deploy before releasing the Mac Subscriptions feature. Older clients keep their signatures
-- through default arguments and preserve subscription membership when editing payments.
alter table public.recurring add column subscription boolean;

drop function public.pocket_recurring_add(text, numeric, text, text, date, date, int, text, boolean);
drop function public.pocket_recurring_update(text, uuid, numeric, text, text, date, boolean, date, int, text, boolean);

create function public.pocket_recurring_add(
  k text, p_amount numeric, p_label text, p_cadence text, p_start date,
  p_today date default current_date, p_times int default null,
  p_category text default null, p_auto boolean default true, p_subscription boolean default null
) returns json
language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform pocket_check(k);
  insert into recurring (amount, label, cadence, anchor_on, total_count, category, auto, subscription)
  values (round(p_amount, 2), trim(p_label), p_cadence, p_start, p_times, nullif(p_category, ''), coalesce(p_auto, true), p_subscription)
  returning id into new_id;
  perform pocket_post_due(p_today);
  return json_build_object('id', new_id);
end $$;

create function public.pocket_recurring_update(
  k text, p_id uuid, p_amount numeric, p_label text, p_cadence text, p_next date,
  p_active boolean default null, p_today date default current_date, p_left int default null,
  p_category text default null, p_auto boolean default null, p_subscription boolean default null
) returns void
language plpgsql security definer set search_path = public as $$
declare r recurring;
begin
  perform pocket_check(k);
  select * into r from recurring where id = p_id for update;
  if not found then return; end if;
  if p_cadence <> r.cadence or p_next <> (r.anchor_on + pocket_step(r.cadence, r.posted_count))::date then
    update recurring set anchor_on = p_next, posted_count = 0, cadence = p_cadence, total_count = p_left
     where id = p_id;
  else
    update recurring set total_count = case when p_left is null then null else posted_count + p_left end
     where id = p_id;
  end if;
  update recurring
     set amount = round(p_amount, 2), label = trim(p_label),
         active = coalesce(p_active, active), auto = coalesce(p_auto, auto),
         category = case when p_category is null then category else nullif(p_category, '') end,
         subscription = coalesce(p_subscription, subscription)
   where id = p_id;
  perform pocket_post_due(p_today);
end $$;

create or replace function public.pocket_state(k text, p_today date default current_date, p_days int default 30)
returns json
language plpgsql security definer set search_path = public as $$
declare horizon date := p_today + least(greatest(p_days, 1), 400);
begin
  perform pocket_check(k);
  perform pocket_post_due(p_today);
  return json_build_object(
    'subscription_tracking', true,
    'transactions', coalesce((
      select json_agg(t order by t.occurred_on desc, t.created_at desc) from transactions t
    ), '[]'::json),
    'recurring', coalesce((
      select json_agg(x order by x.active desc, x.next_on, x.label) from (
        select r.id, r.amount, r.label, r.cadence, r.active, r.auto, r.category, r.subscription,
               (r.anchor_on + pocket_step(r.cadence, r.posted_count))::date as next_on,
               case when r.total_count is null then null else r.total_count - r.posted_count end as remaining,
               (r.total_count = 1) as once
        from recurring r
        where r.total_count is null or r.posted_count < r.total_count
      ) x
    ), '[]'::json),
    -- overdue = due but not confirmed yet (only rules that wait for confirmation)
    'upcoming', coalesce((
      select json_agg(u order by u.due_on, u.label) from (
        select r.id as recurring_id, r.label, r.amount, r.category, r.auto,
               (r.anchor_on + pocket_step(r.cadence, r.posted_count + g))::date as due_on,
               (r.anchor_on + pocket_step(r.cadence, r.posted_count + g))::date <= p_today as overdue
        from recurring r cross join generate_series(0, 60) g
        where r.active
          and (r.total_count is null or r.posted_count + g < r.total_count)
          and (r.anchor_on + pocket_step(r.cadence, r.posted_count + g))::date <= horizon
      ) u
    ), '[]'::json),
    'presets', coalesce((
      select json_agg(p order by p.sort, p.created_at) from presets p
    ), '[]'::json)
  );
end $$;

create function public.pocket_subscription_set(k text, p_id uuid, p_subscription boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform pocket_check(k);
  update recurring set subscription = p_subscription
   where id = p_id and amount < 0 and total_count is distinct from 1
     and (total_count is null or posted_count < total_count);
  if not found then raise exception 'This repeating expense is no longer available'; end if;
end $$;

revoke execute on function public.pocket_recurring_add(text, numeric, text, text, date, date, int, text, boolean, boolean) from public, anon, authenticated;
revoke execute on function public.pocket_recurring_update(text, uuid, numeric, text, text, date, boolean, date, int, text, boolean, boolean) from public, anon, authenticated;
revoke execute on function public.pocket_subscription_set(text, uuid, boolean) from public, anon, authenticated;
grant execute on function public.pocket_recurring_add(text, numeric, text, text, date, date, int, text, boolean, boolean) to anon;
grant execute on function public.pocket_recurring_update(text, uuid, numeric, text, text, date, boolean, date, int, text, boolean, boolean) to anon;
grant execute on function public.pocket_subscription_set(text, uuid, boolean) to anon;
notify pgrst, 'reload schema';
