-- =============================================================================
-- Roomeez: sign in with Google or an email code (Phase 3)
--
-- People are now identified by a verified email address (Google sign-in or an
-- emailed code). A phone number is optional contact information: it is never
-- used to sign in or to link accounts, because it isn't verified.
--
-- Members added by email join their group automatically when they sign in
-- with that email. Members added without an email are "offline" members:
-- they can share expenses but never get an account linked to them.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Columns
-- -----------------------------------------------------------------------------

alter table public.profiles add column email text unique
  check (email is null or (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'));
alter table public.profiles alter column phone drop not null;
alter table public.profiles drop constraint profiles_phone_key;

alter table public.group_members alter column phone drop not null;
alter table public.group_members add column email text;

alter table public.join_requests alter column phone drop not null;
alter table public.join_requests add column email text;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

create or replace function public.normalize_email(p text) returns text
language sql immutable as $$
  select nullif(lower(trim(coalesce(p, ''))), '')
$$;

create or replace function public.check_contact(p_email text, p_phone text) returns void
language plpgsql immutable as $$
begin
  if p_email is not null and p_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Enter a valid email address.' using errcode = 'RZ422';
  end if;
  if p_phone is not null and p_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'Enter a valid mobile number.' using errcode = 'RZ422';
  end if;
end $$;

-- A member's profile: the account (or placeholder) for an email, or a new
-- offline profile when no email is given.
drop function public.find_or_create_profile(text, text);
create or replace function public.find_or_create_member_profile(p_name text, p_email text, p_phone text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_email text := public.normalize_email(p_email);
  v_phone text := nullif(trim(coalesce(p_phone, '')), '');
  v_id uuid;
begin
  perform public.check_contact(v_email, v_phone);
  if v_email is not null then
    select id into v_id from public.profiles where email = v_email;
    if v_id is null then
      insert into public.profiles (name, email, phone) values (trim(coalesce(p_name, '')), v_email, v_phone)
      returning id into v_id;
    end if;
    return v_id;
  end if;
  insert into public.profiles (name, phone) values (trim(coalesce(p_name, '')), v_phone)
  returning id into v_id;
  return v_id;
end $$;

-- -----------------------------------------------------------------------------
-- Auth: create or link the profile by verified email
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_email text := public.normalize_email(new.email);
  v_name text := coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '');
begin
  if v_email is not null then
    -- A member may have added this email before the person signed up.
    update public.profiles set auth_user_id = new.id where email = v_email and auth_user_id is null;
    if not found then
      insert into public.profiles (auth_user_id, email, name) values (new.id, v_email, v_name)
      on conflict (email) do nothing;
    end if;
    return new;
  end if;
  -- Phone sign-in (no longer used by the app): a fresh profile, never linked.
  if new.phone is not null and new.phone <> '' then
    insert into public.profiles (auth_user_id, phone) values (new.id, public.normalize_phone(new.phone));
  end if;
  return new;
end $$;

-- -----------------------------------------------------------------------------
-- API: profile
-- -----------------------------------------------------------------------------

drop function public.update_my_profile(text);
create or replace function public.update_my_profile(p_name text, p_phone text default null) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_name text := trim(coalesce(p_name, ''));
  v_phone text := nullif(trim(coalesce(p_phone, '')), '');
begin
  if length(v_name) < 2 or length(v_name) > 60 then
    raise exception 'Enter your full name.' using errcode = 'RZ422';
  end if;
  perform public.check_contact(null, v_phone);
  update public.profiles set name = v_name, phone = v_phone, has_completed_profile = true where id = v_me;
  update public.group_members set display_name = v_name, phone = v_phone
  where profile_id = v_me and status = 'active';
end $$;

-- -----------------------------------------------------------------------------
-- API: groups and membership
-- -----------------------------------------------------------------------------

-- p_members: [{"name": "...", "email": "..."?, "phone": "+92..."?, "contribution_paisa": 500000?}]
drop function public.create_group(text, text, jsonb, jsonb);
create or replace function public.create_group(
  p_name text,
  p_description text default null,
  p_members jsonb default '[]'::jsonb,
  p_my_contribution_paisa bigint default 0
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

  insert into public.group_members (group_id, profile_id, display_name, email, phone, role, start_date, added_by)
  values (v_group, v_me, v_me_row.name, v_me_row.email, v_me_row.phone, 'manager', v_today, v_me);
  if coalesce(p_my_contribution_paisa, 0) > 0 then
    insert into public.contributions (group_id, member_profile_id, amount_paisa, date, type, recorded_by)
    values (v_group, v_me, p_my_contribution_paisa, v_today, 'initial', v_me);
  end if;

  for v_entry in select x from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as t(x) loop
    v_name := trim(coalesce(v_entry ->> 'name', ''));
    if v_name = '' then
      raise exception 'Every member needs a name.' using errcode = 'RZ422';
    end if;
    v_profile := public.find_or_create_member_profile(v_name, v_entry ->> 'email', v_entry ->> 'phone');
    continue when exists (
      select 1 from public.group_members where group_id = v_group and profile_id = v_profile and status = 'active');
    insert into public.group_members (group_id, profile_id, display_name, email, phone, start_date, added_by)
    values (v_group, v_profile, public.member_display_name(v_profile, v_name),
            public.normalize_email(v_entry ->> 'email'), nullif(trim(coalesce(v_entry ->> 'phone', '')), ''),
            v_today, v_me);
    v_amount := coalesce((v_entry ->> 'contribution_paisa')::bigint, 0);
    if v_amount > 0 then
      insert into public.contributions (group_id, member_profile_id, amount_paisa, date, type, recorded_by)
      values (v_group, v_profile, v_amount, v_today, 'initial', v_me);
    end if;
  end loop;

  return v_group;
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
  insert into public.join_requests (group_id, group_name, profile_id, name, email, phone)
  values (v_group.id, v_group.name, v_me, coalesce(nullif(v_name, ''), v_me_row.name), v_me_row.email, v_me_row.phone)
  returning id into v_id;
  return v_id;
end $$;

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
    insert into public.group_members (group_id, profile_id, display_name, email, phone, start_date, added_by)
    values (v_req.group_id, v_req.profile_id, public.member_display_name(v_req.profile_id, v_req.name),
            v_req.email, v_req.phone, public.local_today(), v_me);
  end if;
  update public.join_requests
  set status = case when p_approve then 'approved' else 'declined' end, decided_by = v_me, decided_at = now()
  where id = p_request;
end $$;

-- Any active member can add a member. With an email, the person joins
-- automatically when they sign in; without one they are an offline member.
drop function public.add_member(uuid, text, text, date);
create or replace function public.add_member(
  p_group uuid, p_name text, p_email text, p_phone text, p_start_date date
) returns uuid
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
  v_profile := public.find_or_create_member_profile(v_name, p_email, p_phone);
  if exists (select 1 from public.group_members
             where group_id = p_group and profile_id = v_profile and status = 'active') then
    raise exception '% is already a member of this group.', v_name using errcode = 'RZ409';
  end if;
  insert into public.group_members (group_id, profile_id, display_name, email, phone, start_date, added_by)
  values (p_group, v_profile, public.member_display_name(v_profile, v_name), public.normalize_email(p_email),
          nullif(trim(coalesce(p_phone, '')), ''), p_start_date, v_me)
  returning id into v_id;
  update public.join_requests
  set status = 'approved', decided_by = v_me, decided_at = now()
  where group_id = p_group and profile_id = v_profile and status = 'pending';
  return v_id;
end $$;

-- -----------------------------------------------------------------------------
-- Privileges: re-apply after replacing functions (Supabase grants new
-- functions to anon/authenticated by default)
-- -----------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.current_profile_id(),
  public.is_active_member(uuid),
  public.update_my_profile(text, text),
  public.create_group(text, text, jsonb, bigint),
  public.find_group_by_code(text),
  public.request_to_join(text, text),
  public.decide_join_request(uuid, boolean),
  public.add_member(uuid, text, text, text, date),
  public.remove_member(uuid, uuid),
  public.leave_group(uuid),
  public.regenerate_group_code(uuid),
  public.add_expense(uuid, jsonb),
  public.update_expense(uuid, jsonb),
  public.void_expense(uuid, text),
  public.add_contribution(uuid, uuid, bigint, date, text)
to authenticated;
