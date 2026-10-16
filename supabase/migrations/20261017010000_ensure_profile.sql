-- =============================================================================
-- Roomeez: make sure every signed-in user has a profile
--
-- Normally the on_auth_user_created trigger creates (or links) the profile.
-- This covers the cases it can't: an account that existed before the trigger,
-- or an email that was already linked elsewhere. The app calls it after
-- sign-in whenever no profile is found.
-- =============================================================================

create or replace function public.ensure_my_profile() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_user record;
  v_email text;
begin
  if v_uid is null then
    raise exception 'Please log in again.' using errcode = 'RZ401';
  end if;
  if exists (select 1 from public.profiles where auth_user_id = v_uid) then
    return;
  end if;
  select email, phone, raw_user_meta_data into v_user from auth.users where id = v_uid;
  v_email := public.normalize_email(v_user.email);
  if v_email is not null then
    -- A placeholder (or an older account's profile with no sign-in) takes
    -- this verified email's sign-in.
    update public.profiles set auth_user_id = v_uid where email = v_email and auth_user_id is null;
    if found then
      return;
    end if;
    if exists (select 1 from public.profiles where email = v_email) then
      raise exception 'This email is already used by another account.' using errcode = 'RZ409';
    end if;
    insert into public.profiles (auth_user_id, email, name)
    values (v_uid, v_email,
            coalesce(v_user.raw_user_meta_data ->> 'full_name', v_user.raw_user_meta_data ->> 'name', ''));
    return;
  end if;
  insert into public.profiles (auth_user_id, phone) values (v_uid, public.normalize_phone(v_user.phone));
end $$;

revoke execute on function public.ensure_my_profile() from public, anon;
grant execute on function public.ensure_my_profile() to authenticated;
