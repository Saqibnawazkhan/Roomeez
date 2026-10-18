-- Roomeez: let people delete their own account.
--
-- Shared records stay: expenses and contributions are part of each group's
-- history and of everyone's balances, so they keep the person's name.
-- What goes: their group memberships (they leave every group, handing over
-- management like leave_group does), pending join requests, their email and
-- mobile number everywhere, and the sign-in itself. Signing up again later
-- with the same email starts a fresh account.

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := public.require_profile();
  v_uid uuid := auth.uid();
  v_mine public.group_members;
  v_next public.group_members;
begin
  for v_mine in
    select * from public.group_members where profile_id = v_me and status = 'active' for update
  loop
    update public.group_members
    set status = 'left', role = 'member', end_date = public.local_today()
    where id = v_mine.id;
    if v_mine.role = 'manager' then
      select * into v_next from public.group_members
      where group_id = v_mine.group_id and status = 'active'
      order by start_date, created_at, id
      limit 1;
      if v_next.id is not null then
        update public.group_members set role = 'manager' where id = v_next.id;
      end if;
    end if;
  end loop;

  -- Withdrawn requests are stored as declined.
  update public.join_requests set status = 'declined', decided_at = now()
  where profile_id = v_me and status = 'pending';

  update public.group_members set email = null, phone = null where profile_id = v_me;
  update public.join_requests set email = null, phone = null where profile_id = v_me;
  update public.profiles set email = null, phone = null, auth_user_id = null where id = v_me;

  delete from auth.users where id = v_uid;
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
