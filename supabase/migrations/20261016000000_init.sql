-- =============================================================================
-- Roomeez: initial schema (Phase 2)
--
-- * Money is integer paisa (bigint). Item quantities are integer thousandths.
-- * Clients only get SELECT on tables, filtered by row-level security. Every
--   write goes through the SECURITY DEFINER functions below, which enforce the
--   product rules (see docs/SPEC.md section 7).
-- * Nothing here removes an expense, a contribution or a history row, and
--   triggers block DELETE on them even for privileged roles.
-- * Errors use custom SQLSTATEs so the app can map them:
--     RZ401 not signed in, RZ403 not allowed, RZ404 not found,
--     RZ409 conflict, RZ422 invalid input.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

-- A person. Members added by phone before they sign up get a profile without
-- an auth user; it is linked automatically when they sign up with that number.
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users (id) on delete set null,
  name text not null default '',
  phone text not null unique check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  has_completed_profile boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 80),
  description text check (description is null or length(description) <= 300),
  code text not null unique check (code ~ '^[A-Z0-9]{6,8}$'),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

-- One membership period. Leaving and rejoining creates a new row.
create table public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  profile_id uuid not null references public.profiles (id),
  display_name text not null,
  phone text not null,
  role text not null default 'member' check (role in ('manager', 'member')),
  status text not null default 'active' check (status in ('active', 'left', 'removed')),
  start_date date not null,
  end_date date,
  added_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  check ((status = 'active') = (end_date is null)),
  check (role = 'member' or status = 'active')
);
create unique index group_members_one_active on public.group_members (group_id, profile_id) where status = 'active';
create unique index group_members_one_manager on public.group_members (group_id) where status = 'active' and role = 'manager';
create index group_members_profile on public.group_members (profile_id);

create table public.join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  group_name text not null,
  profile_id uuid not null references public.profiles (id),
  name text not null,
  phone text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  requested_at timestamptz not null default now(),
  decided_by uuid references public.profiles (id),
  decided_at timestamptz
);
create unique index join_requests_one_pending on public.join_requests (group_id, profile_id) where status = 'pending';

-- Items are stored inline as a JSON array of
-- {id, name, quantity_milli, unit_price_paisa}, so an edit is a single row
-- update and the previous version lands in expense_history.
create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  title text not null check (length(trim(title)) between 1 and 80),
  date date not null,
  category text not null check (category in
    ('breakfast', 'lunch', 'dinner', 'groceries', 'household', 'bills', 'transport', 'other')),
  items jsonb not null default '[]'::jsonb check (jsonb_typeof(items) = 'array'),
  quick_amount_paisa bigint check (quick_amount_paisa is null or quick_amount_paisa > 0),
  total_paisa bigint not null check (total_paisa > 0),
  created_by uuid not null references public.profiles (id),
  paid_by uuid references public.profiles (id),
  payment_source text not null check (payment_source in ('personal', 'group_fund')),
  split_among uuid[] not null check (cardinality(split_among) > 0),
  notes text check (notes is null or length(notes) <= 500),
  status text not null default 'active' check (status in ('active', 'voided')),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  voided_at timestamptz,
  void_reason text,
  check ((payment_source = 'group_fund') = (paid_by is null)),
  check ((status = 'voided') = (voided_at is not null))
);
create index expenses_group_date on public.expenses (group_id, date desc);

-- Every edit or void keeps the previous version of the expense.
create table public.expense_history (
  id bigint generated always as identity primary key,
  expense_id uuid not null references public.expenses (id),
  changed_by uuid references public.profiles (id),
  changed_at timestamptz not null default now(),
  action text not null check (action in ('edited', 'voided')),
  previous jsonb not null
);
create index expense_history_expense on public.expense_history (expense_id);

create table public.contributions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  member_profile_id uuid not null references public.profiles (id),
  amount_paisa bigint not null check (amount_paisa > 0),
  date date not null,
  type text not null check (type in ('initial', 'top_up')),
  note text check (note is null or length(note) <= 200),
  recorded_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);
create index contributions_group on public.contributions (group_id, date desc);

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

-- The app is PKR-only for now, so "today" is Pakistan's calendar day.
create or replace function public.local_today() returns date
language sql stable as $$
  select (now() at time zone 'Asia/Karachi')::date
$$;

create or replace function public.current_profile_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.profiles where auth_user_id = auth.uid()
$$;

create or replace function public.require_profile() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_id uuid := public.current_profile_id();
begin
  if v_id is null then
    raise exception 'Please log in again.' using errcode = 'RZ401';
  end if;
  return v_id;
end $$;

create or replace function public.is_active_member(p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group and profile_id = public.current_profile_id() and status = 'active'
  )
$$;

-- Whether a person's membership covered a given day (for splitting costs).
create or replace function public.member_covers(p_group uuid, p_profile uuid, p_day date) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group and profile_id = p_profile
      and start_date <= p_day and (end_date is null or end_date >= p_day)
  )
$$;

create or replace function public.normalize_phone(p text) returns text
language sql immutable as $$
  select case when p is null or p = '' then null when left(p, 1) = '+' then p else '+' || p end
$$;

create or replace function public.find_or_create_profile(p_name text, p_phone text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if p_phone is null or p_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'Enter a valid mobile number.' using errcode = 'RZ422';
  end if;
  select id into v_id from public.profiles where phone = p_phone;
  if v_id is null then
    insert into public.profiles (name, phone) values (trim(coalesce(p_name, '')), p_phone)
    returning id into v_id;
  end if;
  return v_id;
end $$;

-- 6 characters without look-alikes (0/O, 1/I/L).
create or replace function public.generate_group_code() returns text
language plpgsql security definer set search_path = public as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.groups where code = v_code);
  end loop;
  return v_code;
end $$;

-- Display name for a member: a registered person's own name wins.
create or replace function public.member_display_name(p_profile uuid, p_given text) returns text
language sql stable security definer set search_path = public as $$
  select case
    when p.auth_user_id is not null and p.has_completed_profile and p.name <> '' then p.name
    else coalesce(nullif(trim(p_given), ''), p.name)
  end
  from public.profiles p where p.id = p_profile
$$;

-- -----------------------------------------------------------------------------
-- Auth: create or link the profile when someone signs up with a phone number
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_phone text := public.normalize_phone(new.phone);
begin
  if v_phone is null then
    return new;
  end if;
  update public.profiles set auth_user_id = new.id where phone = v_phone and auth_user_id is null;
  if not found then
    insert into public.profiles (auth_user_id, phone) values (new.id, v_phone)
    on conflict (phone) do nothing;
  end if;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- -----------------------------------------------------------------------------
-- Integrity triggers: no deletes, immutable ownership, history on change
-- -----------------------------------------------------------------------------

create or replace function public.prevent_delete() returns trigger
language plpgsql as $$
begin
  raise exception 'Records in % can''t be deleted.', tg_table_name using errcode = 'RZ403';
end $$;

create trigger groups_no_delete before delete on public.groups
  for each row execute function public.prevent_delete();
create trigger group_members_no_delete before delete on public.group_members
  for each row execute function public.prevent_delete();
create trigger contributions_no_delete before delete on public.contributions
  for each row execute function public.prevent_delete();
create trigger expense_history_no_change before update or delete on public.expense_history
  for each row execute function public.prevent_delete();

create or replace function public.expenses_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Expenses can''t be deleted. Void it instead.' using errcode = 'RZ403';
  end if;
  if new.id <> old.id or new.group_id <> old.group_id
     or new.created_by <> old.created_by or new.created_at <> old.created_at then
    raise exception 'An expense''s creator and group can''t be changed.' using errcode = 'RZ403';
  end if;
  if old.status = 'voided' then
    raise exception 'Voided expenses can''t be changed.' using errcode = 'RZ403';
  end if;
  insert into public.expense_history (expense_id, changed_by, action, previous)
  values (old.id, public.current_profile_id(),
          case when new.status = 'voided' then 'voided' else 'edited' end,
          to_jsonb(old));
  return new;
end $$;

create trigger expenses_guard before update or delete on public.expenses
  for each row execute function public.expenses_guard();

-- -----------------------------------------------------------------------------
-- API: profile
-- -----------------------------------------------------------------------------

create or replace function public.update_my_profile(p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_name text := trim(coalesce(p_name, ''));
begin
  if length(v_name) < 2 or length(v_name) > 60 then
    raise exception 'Enter your full name.' using errcode = 'RZ422';
  end if;
  update public.profiles set name = v_name, has_completed_profile = true where id = v_me;
  update public.group_members set display_name = v_name where profile_id = v_me and status = 'active';
end $$;

-- -----------------------------------------------------------------------------
-- API: groups and membership
-- -----------------------------------------------------------------------------

-- p_members: [{"name": "...", "phone": "+92..."}]
-- p_contributions: [{"phone": "+92...", "amount_paisa": 500000}]
create or replace function public.create_group(
  p_name text,
  p_description text default null,
  p_members jsonb default '[]'::jsonb,
  p_contributions jsonb default '[]'::jsonb
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_me_row public.profiles;
  v_group uuid;
  v_today date := public.local_today();
  v_entry jsonb;
  v_profile uuid;
  v_name text;
  v_amount bigint;
begin
  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Enter a group name.' using errcode = 'RZ422';
  end if;
  select * into v_me_row from public.profiles where id = v_me;

  insert into public.groups (name, description, code, created_by)
  values (trim(p_name), nullif(trim(coalesce(p_description, '')), ''), public.generate_group_code(), v_me)
  returning id into v_group;

  insert into public.group_members (group_id, profile_id, display_name, phone, role, start_date, added_by)
  values (v_group, v_me, v_me_row.name, v_me_row.phone, 'manager', v_today, v_me);

  for v_entry in select x from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as t(x) loop
    v_name := trim(coalesce(v_entry ->> 'name', ''));
    if v_name = '' then
      raise exception 'Every member needs a name.' using errcode = 'RZ422';
    end if;
    v_profile := public.find_or_create_profile(v_name, v_entry ->> 'phone');
    continue when exists (
      select 1 from public.group_members where group_id = v_group and profile_id = v_profile and status = 'active');
    insert into public.group_members (group_id, profile_id, display_name, phone, start_date, added_by)
    values (v_group, v_profile, public.member_display_name(v_profile, v_name), v_entry ->> 'phone', v_today, v_me);
  end loop;

  for v_entry in select x from jsonb_array_elements(coalesce(p_contributions, '[]'::jsonb)) as t(x) loop
    v_amount := (v_entry ->> 'amount_paisa')::bigint;
    continue when v_amount is null or v_amount <= 0;
    select profile_id into v_profile from public.group_members
    where group_id = v_group and phone = v_entry ->> 'phone' and status = 'active';
    continue when v_profile is null;
    insert into public.contributions (group_id, member_profile_id, amount_paisa, date, type, recorded_by)
    values (v_group, v_profile, v_amount, v_today, 'initial', v_me);
  end loop;

  return v_group;
end $$;

-- What a non-member may see about a group before joining: no records.
create or replace function public.find_group_by_code(p_code text)
returns table (group_id uuid, name text, active_member_count int, is_already_member boolean, pending_request_id uuid)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me uuid := public.require_profile();
  v_code text := upper(regexp_replace(coalesce(p_code, ''), '\s', '', 'g'));
  v_group public.groups;
begin
  select * into v_group from public.groups g where g.code = v_code;
  if v_group.id is null then
    raise exception 'No group found with code %. Check the code and try again.', v_code using errcode = 'RZ404';
  end if;
  return query select
    v_group.id,
    v_group.name,
    (select count(*)::int from public.group_members m where m.group_id = v_group.id and m.status = 'active'),
    exists (select 1 from public.group_members m
            where m.group_id = v_group.id and m.profile_id = v_me and m.status = 'active'),
    (select r.id from public.join_requests r
     where r.group_id = v_group.id and r.profile_id = v_me and r.status = 'pending');
end $$;

create or replace function public.request_to_join(p_code text, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_me_row public.profiles;
  v_group public.groups;
  v_id uuid;
  v_name text := trim(coalesce(p_name, ''));
begin
  select * into v_me_row from public.profiles where id = v_me;
  select * into v_group from public.groups where code = upper(regexp_replace(coalesce(p_code, ''), '\s', '', 'g'));
  if v_group.id is null then
    raise exception 'No group found with this code.' using errcode = 'RZ404';
  end if;
  if exists (select 1 from public.group_members
             where group_id = v_group.id and profile_id = v_me and status = 'active') then
    raise exception 'You are already a member of this group.' using errcode = 'RZ409';
  end if;
  select id into v_id from public.join_requests
  where group_id = v_group.id and profile_id = v_me and status = 'pending';
  if v_id is not null then
    return v_id;
  end if;
  insert into public.join_requests (group_id, group_name, profile_id, name, phone)
  values (v_group.id, v_group.name, v_me, coalesce(nullif(v_name, ''), v_me_row.name), v_me_row.phone)
  returning id into v_id;
  return v_id;
end $$;

-- Any active member can approve or decline.
create or replace function public.decide_join_request(p_request uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_req public.join_requests;
begin
  select * into v_req from public.join_requests where id = p_request for update;
  if v_req.id is null then
    raise exception 'Join request not found.' using errcode = 'RZ404';
  end if;
  if not public.is_active_member(v_req.group_id) then
    raise exception 'You can''t review join requests for this group.' using errcode = 'RZ403';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'This request was already handled.' using errcode = 'RZ409';
  end if;
  if p_approve and not exists (
    select 1 from public.group_members
    where group_id = v_req.group_id and profile_id = v_req.profile_id and status = 'active') then
    insert into public.group_members (group_id, profile_id, display_name, phone, start_date, added_by)
    values (v_req.group_id, v_req.profile_id, public.member_display_name(v_req.profile_id, v_req.name),
            v_req.phone, public.local_today(), v_me);
  end if;
  update public.join_requests
  set status = case when p_approve then 'approved' else 'declined' end, decided_by = v_me, decided_at = now()
  where id = p_request;
end $$;

-- Any active member can add a member.
create or replace function public.add_member(p_group uuid, p_name text, p_phone text, p_start_date date)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_name text := trim(coalesce(p_name, ''));
  v_profile uuid;
  v_id uuid;
begin
  if not public.is_active_member(p_group) then
    raise exception 'You can''t add members to this group.' using errcode = 'RZ403';
  end if;
  if length(v_name) < 2 then
    raise exception 'Enter the member''s name.' using errcode = 'RZ422';
  end if;
  if p_start_date is null then
    raise exception 'Choose a joining date.' using errcode = 'RZ422';
  end if;
  v_profile := public.find_or_create_profile(v_name, p_phone);
  if exists (select 1 from public.group_members
             where group_id = p_group and profile_id = v_profile and status = 'active') then
    raise exception '% is already a member of this group.', v_name using errcode = 'RZ409';
  end if;
  insert into public.group_members (group_id, profile_id, display_name, phone, start_date, added_by)
  values (p_group, v_profile, public.member_display_name(v_profile, v_name), p_phone, p_start_date, v_me)
  returning id into v_id;
  update public.join_requests
  set status = 'approved', decided_by = v_me, decided_at = now()
  where group_id = p_group and profile_id = v_profile and status = 'pending';
  return v_id;
end $$;

-- Only the manager can remove someone else. Their expenses are untouched.
create or replace function public.remove_member(p_group uuid, p_member uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_target public.group_members;
begin
  if not exists (select 1 from public.group_members
                 where group_id = p_group and profile_id = v_me and status = 'active' and role = 'manager') then
    raise exception 'Only the group manager can remove other members.' using errcode = 'RZ403';
  end if;
  select * into v_target from public.group_members where id = p_member and group_id = p_group for update;
  if v_target.id is null then
    raise exception 'Member not found.' using errcode = 'RZ404';
  end if;
  if v_target.status <> 'active' or v_target.profile_id = v_me then
    raise exception 'Only the group manager can remove other members.' using errcode = 'RZ403';
  end if;
  update public.group_members
  set status = 'removed', role = 'member', end_date = public.local_today()
  where id = p_member;
end $$;

-- Returns the new manager's name when the manager role passed on.
create or replace function public.leave_group(p_group uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_mine public.group_members;
  v_next public.group_members;
begin
  select * into v_mine from public.group_members
  where group_id = p_group and profile_id = v_me and status = 'active' for update;
  if v_mine.id is null then
    raise exception 'You are not an active member of this group.' using errcode = 'RZ403';
  end if;
  update public.group_members
  set status = 'left', role = 'member', end_date = public.local_today()
  where id = v_mine.id;
  if v_mine.role = 'manager' then
    select * into v_next from public.group_members
    where group_id = p_group and status = 'active'
    order by start_date, created_at, id
    limit 1;
    if v_next.id is not null then
      update public.group_members set role = 'manager' where id = v_next.id;
      return v_next.display_name;
    end if;
  end if;
  return null;
end $$;

create or replace function public.regenerate_group_code(p_group uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_code text;
begin
  if not exists (select 1 from public.group_members
                 where group_id = p_group and profile_id = v_me and status = 'active' and role = 'manager') then
    raise exception 'Only the group manager can change the join code.' using errcode = 'RZ403';
  end if;
  v_code := public.generate_group_code();
  update public.groups set code = v_code where id = p_group;
  return v_code;
end $$;

-- -----------------------------------------------------------------------------
-- API: expenses
-- -----------------------------------------------------------------------------

-- Validates and normalizes an expense payload (not inserted). Mirrors
-- lib/data/services/expense_validator.dart. Payload:
-- {title, date, category, items: [{id?, name, quantity_milli, unit_price_paisa}],
--  quick_amount_paisa, payment_source, paid_by, split_among: [uuid], notes}
create or replace function public.prepare_expense(p_group uuid, p_expense jsonb) returns public.expenses
language plpgsql security definer set search_path = public as $$
declare
  r public.expenses;
  v_item jsonb;
  v_items jsonb := '[]'::jsonb;
  v_total bigint := 0;
  v_pos int := 0;
  v_qty bigint;
  v_price bigint;
  v_name text;
  v_person uuid;
begin
  r.group_id := p_group;
  r.title := trim(coalesce(p_expense ->> 'title', ''));
  if r.title = '' then
    raise exception 'Add a title for the expense.' using errcode = 'RZ422';
  end if;
  if length(r.title) > 80 then
    raise exception 'Keep the title under 80 characters.' using errcode = 'RZ422';
  end if;

  r.date := (p_expense ->> 'date')::date;
  if r.date is null then
    raise exception 'Choose a date.' using errcode = 'RZ422';
  end if;
  if r.date > public.local_today() then
    raise exception 'The date can''t be in the future.' using errcode = 'RZ422';
  end if;

  r.category := p_expense ->> 'category';
  if r.category is null or r.category not in
     ('breakfast', 'lunch', 'dinner', 'groceries', 'household', 'bills', 'transport', 'other') then
    raise exception 'Choose a category.' using errcode = 'RZ422';
  end if;

  if jsonb_typeof(p_expense -> 'items') = 'array' and jsonb_array_length(p_expense -> 'items') > 0 then
    for v_item in select x from jsonb_array_elements(p_expense -> 'items') as t(x) loop
      v_pos := v_pos + 1;
      v_name := trim(coalesce(v_item ->> 'name', ''));
      v_qty := (v_item ->> 'quantity_milli')::bigint;
      v_price := (v_item ->> 'unit_price_paisa')::bigint;
      if v_name = '' then
        raise exception 'Item % needs a name.', v_pos using errcode = 'RZ422';
      end if;
      if v_qty is null or v_qty <= 0 then
        raise exception 'Item % needs a quantity above zero.', v_pos using errcode = 'RZ422';
      end if;
      if v_price is null or v_price < 0 then
        raise exception 'Item % has an invalid price.', v_pos using errcode = 'RZ422';
      end if;
      -- Same rounding as Quantity.lineTotal in the app: half-up to the paisa.
      v_total := v_total + (v_price * v_qty + 500) / 1000;
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'id', coalesce(nullif(v_item ->> 'id', ''), gen_random_uuid()::text),
        'name', v_name,
        'quantity_milli', v_qty,
        'unit_price_paisa', v_price));
    end loop;
    r.quick_amount_paisa := null;
  else
    r.quick_amount_paisa := (p_expense ->> 'quick_amount_paisa')::bigint;
    if r.quick_amount_paisa is not null and r.quick_amount_paisa < 0 then
      raise exception 'The amount can''t be negative.' using errcode = 'RZ422';
    end if;
    v_total := coalesce(r.quick_amount_paisa, 0);
  end if;
  if v_total <= 0 then
    raise exception 'The total must be more than zero.' using errcode = 'RZ422';
  end if;
  r.items := v_items;
  r.total_paisa := v_total;

  r.payment_source := p_expense ->> 'payment_source';
  if r.payment_source = 'personal' then
    r.paid_by := (p_expense ->> 'paid_by')::uuid;
    if r.paid_by is null then
      raise exception 'Choose who paid.' using errcode = 'RZ422';
    end if;
    if not public.member_covers(p_group, r.paid_by, r.date) then
      raise exception 'The payer must have been a member on the expense date.' using errcode = 'RZ422';
    end if;
  elsif r.payment_source = 'group_fund' then
    r.paid_by := null;
  else
    raise exception 'Choose where the money came from.' using errcode = 'RZ422';
  end if;

  select coalesce(array_agg(distinct x::uuid), '{}'::uuid[]) into r.split_among
  from jsonb_array_elements_text(coalesce(p_expense -> 'split_among', '[]'::jsonb)) as t(x);
  if cardinality(r.split_among) = 0 then
    raise exception 'Choose at least one member to share this expense.' using errcode = 'RZ422';
  end if;
  foreach v_person in array r.split_among loop
    if not public.member_covers(p_group, v_person, r.date) then
      raise exception 'Only people who were members on the expense date can share it.' using errcode = 'RZ422';
    end if;
  end loop;

  r.notes := nullif(trim(coalesce(p_expense ->> 'notes', '')), '');
  if length(r.notes) > 500 then
    raise exception 'Keep the note under 500 characters.' using errcode = 'RZ422';
  end if;
  return r;
end $$;

create or replace function public.add_expense(p_group uuid, p_expense jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  r public.expenses;
  v_id uuid;
begin
  if not public.is_active_member(p_group) then
    raise exception 'You can''t add expenses to this group.' using errcode = 'RZ403';
  end if;
  r := public.prepare_expense(p_group, p_expense);
  insert into public.expenses (group_id, title, date, category, items, quick_amount_paisa, total_paisa,
                               created_by, paid_by, payment_source, split_among, notes)
  values (p_group, r.title, r.date, r.category, r.items, r.quick_amount_paisa, r.total_paisa,
          v_me, r.paid_by, r.payment_source, r.split_among, r.notes)
  returning id into v_id;
  return v_id;
end $$;

-- Only the creator, while an active member, can edit. The manager has no
-- extra rights here.
create or replace function public.require_editable_expense(p_expense uuid) returns public.expenses
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_old public.expenses;
begin
  select * into v_old from public.expenses where id = p_expense for update;
  if v_old.id is null or not public.is_active_member(v_old.group_id) then
    raise exception 'Expense not found.' using errcode = 'RZ404';
  end if;
  if v_old.status = 'voided' then
    raise exception 'Voided expenses can''t be changed.' using errcode = 'RZ403';
  end if;
  if v_old.created_by <> v_me then
    raise exception 'Only the person who added this expense can change it.' using errcode = 'RZ403';
  end if;
  return v_old;
end $$;

create or replace function public.update_expense(p_expense uuid, p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_old public.expenses := public.require_editable_expense(p_expense);
  r public.expenses;
begin
  r := public.prepare_expense(v_old.group_id, p_data);
  update public.expenses
  set title = r.title, date = r.date, category = r.category, items = r.items,
      quick_amount_paisa = r.quick_amount_paisa, total_paisa = r.total_paisa,
      paid_by = r.paid_by, payment_source = r.payment_source, split_among = r.split_among,
      notes = r.notes, edited_at = now()
  where id = p_expense;
end $$;

create or replace function public.void_expense(p_expense uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_old public.expenses := public.require_editable_expense(p_expense);
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if v_reason = '' then
    raise exception 'Add a short reason for voiding.' using errcode = 'RZ422';
  end if;
  update public.expenses
  set status = 'voided', voided_at = now(), void_reason = left(v_reason, 200)
  where id = v_old.id;
end $$;

-- -----------------------------------------------------------------------------
-- API: group fund
-- -----------------------------------------------------------------------------

create or replace function public.add_contribution(
  p_group uuid, p_member uuid, p_amount_paisa bigint, p_date date, p_note text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_id uuid;
begin
  if not public.is_active_member(p_group) then
    raise exception 'You can''t record contributions for this group.' using errcode = 'RZ403';
  end if;
  if not exists (select 1 from public.group_members
                 where group_id = p_group and profile_id = p_member and status = 'active') then
    raise exception 'Contributions can only be recorded for active members.' using errcode = 'RZ422';
  end if;
  if p_amount_paisa is null or p_amount_paisa <= 0 then
    raise exception 'Enter an amount above zero.' using errcode = 'RZ422';
  end if;
  if p_date is null or p_date > public.local_today() then
    raise exception 'The date can''t be in the future.' using errcode = 'RZ422';
  end if;
  insert into public.contributions (group_id, member_profile_id, amount_paisa, date, type, note, recorded_by)
  values (p_group, p_member, p_amount_paisa, p_date, 'top_up', nullif(trim(coalesce(p_note, '')), ''), v_me)
  returning id into v_id;
  return v_id;
end $$;

-- -----------------------------------------------------------------------------
-- Row-level security: read access only, for active members
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.join_requests enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_history enable row level security;
alter table public.contributions enable row level security;

create policy "own profile" on public.profiles
  for select to authenticated using (auth_user_id = auth.uid());

create policy "members read group" on public.groups
  for select to authenticated using (public.is_active_member(id));

create policy "members read memberships" on public.group_members
  for select to authenticated using (public.is_active_member(group_id));

create policy "requester or members read join requests" on public.join_requests
  for select to authenticated
  using (profile_id = public.current_profile_id() or (status = 'pending' and public.is_active_member(group_id)));

create policy "members read expenses" on public.expenses
  for select to authenticated using (public.is_active_member(group_id));

create policy "members read expense history" on public.expense_history
  for select to authenticated
  using (exists (select 1 from public.expenses e where e.id = expense_id and public.is_active_member(e.group_id)));

create policy "members read contributions" on public.contributions
  for select to authenticated using (public.is_active_member(group_id));

-- -----------------------------------------------------------------------------
-- Privileges: SELECT on tables; EXECUTE only on the API functions
-- -----------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
grant select on public.profiles, public.groups, public.group_members, public.join_requests,
  public.expenses, public.expense_history, public.contributions to authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.current_profile_id(),
  public.is_active_member(uuid),
  public.update_my_profile(text),
  public.create_group(text, text, jsonb, jsonb),
  public.find_group_by_code(text),
  public.request_to_join(text, text),
  public.decide_join_request(uuid, boolean),
  public.add_member(uuid, text, text, date),
  public.remove_member(uuid, uuid),
  public.leave_group(uuid),
  public.regenerate_group_code(uuid),
  public.add_expense(uuid, jsonb),
  public.update_expense(uuid, jsonb),
  public.void_expense(uuid, text),
  public.add_contribution(uuid, uuid, bigint, date, text)
to authenticated;

-- -----------------------------------------------------------------------------
-- Realtime: the app refreshes a screen when these tables change
-- -----------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table
      public.groups, public.group_members, public.join_requests, public.expenses, public.contributions;
  end if;
end $$;
