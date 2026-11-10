-- Pocket database tests. Everything runs in one transaction that is rolled back,
-- so real data is never touched. Any failed check raises and aborts the run.
-- Run: ./supabase/tests/run.sh
begin;

create function pg_temp.eq(actual anyelement, expected anyelement, what text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: expected %, got %', what, expected, actual;
  end if;
end $$;

-- A known key and an empty ledger, for this transaction only.
update app_secret set key_hash = encode(extensions.digest('test-key-0123456789', 'sha256'), 'hex');
delete from transactions; delete from recurring; delete from presets; delete from devices; delete from pairing;

create temp table t_ctx (k text);
insert into t_ctx values ('test-key-0123456789');

create function pg_temp.k() returns text language sql as $$ select k from t_ctx $$;
create function pg_temp.bal(p_today date) returns numeric language sql as $$
  select coalesce(sum((e->>'amount')::numeric), 0)
  from json_array_elements(pocket_state(pg_temp.k(), p_today)->'transactions') e
$$;
create function pg_temp.next_on(p_label text, p_today date) returns date language sql as $$
  select (e->>'next_on')::date from json_array_elements(pocket_state(pg_temp.k(), p_today)->'recurring') e
  where e->>'label' = p_label
$$;

-- 1. Wrong key is refused
do $$ begin
  perform pocket_state('wrong-key-0123456789');
  raise exception 'FAIL wrong key was accepted';
exception when sqlstate '28000' then null;
end $$;

-- 2. One-time entries and categories
select pocket_add(pg_temp.k(), 100, 'Start', '2026-10-01', 'start');
select pocket_add(pg_temp.k(), -9.99, 'Game', '2026-10-02', 'games');
select pg_temp.eq(pg_temp.bal('2026-10-11'), 90.01::numeric, 'balance after two entries');
select pocket_update(pg_temp.k(), (select id from transactions where label = 'Game'), -9.99, 'Game', '2026-10-02');
select pg_temp.eq((select category from transactions where label = 'Game'), 'games', 'null category keeps it');
select pocket_update(pg_temp.k(), (select id from transactions where label = 'Game'), -9.99, 'Game', '2026-10-02', '');
select pg_temp.eq((select category from transactions where label = 'Game'), null::text, 'empty category clears it');

-- 3. Monthly on the 31st clamps to month end, and stops after 3 payments
select pocket_recurring_add(pg_temp.k(), -5, 'Month end', 'monthly', '2026-01-31', '2026-04-15', 3, 'bills');
select pg_temp.eq((select string_agg(occurred_on::text, ',' order by occurred_on) from transactions where label = 'Month end'),
                  '2026-01-31,2026-02-28,2026-03-31', 'month-end dates');
select pocket_state(pg_temp.k(), '2026-12-31');
select pg_temp.eq((select count(*) from transactions where label = 'Month end'), 3::bigint, 'stops after 3 payments');
select pg_temp.eq((select category from transactions where label = 'Month end' limit 1), 'bills', 'rule category copied');

-- 3b. Quarterly counts 3 months from the anchor (removed again so later balances are unchanged)
select pocket_recurring_add(pg_temp.k(), -30, 'Quarter', 'quarterly', '2025-11-30', '2026-06-01', 3, 'bills');
select pg_temp.eq((select string_agg(occurred_on::text, ',' order by occurred_on) from transactions where label = 'Quarter'),
                  '2025-11-30,2026-02-28,2026-05-30', 'quarterly dates');
delete from transactions where label = 'Quarter';
delete from recurring where label = 'Quarter';

-- 4. Income that waits for confirmation: not logged on its own, shows as overdue,
--    "got it" logs the real amount and date and moves to the next one
select pocket_recurring_add(pg_temp.k(), 750, 'Client', 'monthly', '2026-10-05', '2026-10-11', null, 'pay', false);
select pg_temp.eq((select count(*) from transactions where label = 'Client'), 0::bigint, 'manual income not auto-logged');
select pg_temp.eq((select (e->>'overdue')::boolean from json_array_elements(pocket_state(pg_temp.k(), '2026-10-11')->'upcoming') e
                   where e->>'label' = 'Client' order by e->>'due_on' limit 1), true, 'manual income shows overdue');
select pocket_recurring_settle(pg_temp.k(), (select id from recurring where label = 'Client'), 700, '2026-10-09', '2026-10-11');
select pg_temp.eq((select amount from transactions where label = 'Client'), 700.00::numeric, 'settled with real amount');
select pg_temp.eq((select occurred_on from transactions where label = 'Client'), '2026-10-09'::date, 'settled on real date');
select pg_temp.eq(pg_temp.next_on('Client', '2026-10-11'), '2026-11-05'::date, 'next one after settling');

-- 5. Skip moves on without logging
select pocket_recurring_skip(pg_temp.k(), (select id from recurring where label = 'Client'));
select pg_temp.eq(pg_temp.next_on('Client', '2026-10-11'), '2026-12-05'::date, 'skip moves to the following one');
select pg_temp.eq((select count(*) from transactions where label = 'Client'), 1::bigint, 'skip logs nothing');

-- 6. Paused rules don't log; resuming doesn't back-log the missed ones
select pocket_recurring_add(pg_temp.k(), -20, 'Sub', 'monthly', '2026-10-01', '2026-10-11', null, 'subscriptions');
select pocket_recurring_set_active(pg_temp.k(), (select id from recurring where label = 'Sub'), false, '2026-10-11');
select pocket_state(pg_temp.k(), '2027-01-15');
select pg_temp.eq((select count(*) from transactions where label = 'Sub'), 1::bigint, 'paused rule does not log');
select pocket_recurring_set_active(pg_temp.k(), (select id from recurring where label = 'Sub'), true, '2027-01-15');
select pg_temp.eq((select count(*) from transactions where label = 'Sub'), 1::bigint, 'resume does not back-log');
select pg_temp.eq(pg_temp.next_on('Sub', '2027-01-15'), '2027-02-01'::date, 'resume continues from today');

-- 7. Quick-add presets
select pocket_preset_save(pg_temp.k(), 'Valorant', -1, 9.99, 'games');
select pocket_preset_save(pg_temp.k(), 'Gift', 1, null, 'gift');
select pg_temp.eq(json_array_length(pocket_state(pg_temp.k(), '2026-10-11')->'presets'), 2, 'two presets');
select pg_temp.eq((select sign from presets where label = 'Gift'), 1::smallint, 'income preset sign');
select pocket_preset_delete(pg_temp.k(), (select id from presets where label = 'Gift'));
select pg_temp.eq((select count(*) from presets), 1::bigint, 'preset deleted');

-- 8. Pairing: wrong codes count, the right one gives a working device token, removing it locks it out
create temp table t_pair as select (pocket_pair_start(pg_temp.k())->>'code') as code;
select pg_temp.eq(pocket_pair_finish('000000x', 'Phone')->>'error',
                  case when (select code from t_pair) = '000000' then null else 'wrong' end, 'wrong code refused');
create temp table t_tok as select pocket_pair_finish((select code from t_pair), 'Phone')->>'token' as tok;
select pg_temp.eq((select tok is not null from t_tok), true, 'right code gives a token');
select pg_temp.eq(pocket_pair_finish((select code from t_pair), 'Again')->>'error', 'expired', 'code works only once');
select pocket_state((select tok from t_tok), '2026-10-11');
select pg_temp.eq((select (pocket_devices((select tok from t_tok))->'devices'->0->>'this')::boolean), true, 'device knows itself');
select pocket_device_remove(pg_temp.k(), (select id from devices where name = 'Phone'));
do $$ begin
  perform pocket_state((select tok from t_tok));
  raise exception 'FAIL removed device still has access';
exception when sqlstate '28000' then null;
end $$;

-- 9. Five wrong codes burn the code
create temp table t_pair2 as select (pocket_pair_start(pg_temp.k())->>'code') as code;
select pocket_pair_finish('x', 'Phone') from generate_series(1, 4);
select pg_temp.eq(pocket_pair_finish('x', 'Phone')->>'error', 'too_many', 'fifth wrong code burns it');
select pg_temp.eq(pocket_pair_finish((select code from t_pair2), 'Phone')->>'error', 'expired', 'burned code is dead');

-- 10. Subscription membership is independent of category and older edits preserve it.
create temp table t_subscription as select (pocket_recurring_add(pg_temp.k(), -9.99, 'Cloud subscription',
  'monthly', '2026-11-11', '2026-11-09', null, 'apps', true, true)->>'id')::uuid as id;
select pg_temp.eq((select subscription from recurring where id = (select id from t_subscription)), true, 'subscription marked');
select pocket_recurring_update(pg_temp.k(), (select id from t_subscription), -12.99, 'Cloud subscription',
  'monthly', '2026-11-11', null, '2026-11-09', null, 'apps', true);
select pg_temp.eq((select subscription from recurring where id = (select id from t_subscription)), true, 'older edit keeps membership');
select pocket_subscription_set(pg_temp.k(), (select id from t_subscription), false);
select pg_temp.eq((select subscription from recurring where id = (select id from t_subscription)), false, 'membership removed');
select pg_temp.eq((select category from recurring where id = (select id from t_subscription)), 'apps', 'membership keeps category');
select pg_temp.eq((pocket_state(pg_temp.k(), '2026-11-09')->>'subscription_tracking')::boolean, true, 'server advertises support');
do $$ begin
  perform pocket_subscription_set('wrong-key-0123456789', (select id from t_subscription), true);
  raise exception 'FAIL subscription setter accepted wrong key';
exception when sqlstate '28000' then null;
end $$;

select 'all tests passed' as result;
rollback;
