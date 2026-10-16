// Runs the migration on an in-process Postgres (PGlite) and checks the
// product rules as different signed-in users.
//
//   cd supabase/tests && npm install && npm test
//
// Supabase's auth schema and roles are stubbed: auth.uid() reads the
// `request.jwt.claim.sub` setting, exactly how Supabase exposes the JWT.

import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(here, '..', 'migrations');

const db = new PGlite();
let passed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ok  ${name}`);
  } catch (error) {
    failures.push(name);
    console.log(`  FAIL ${name}\n       ${error.message}`);
  } finally {
    await db.exec('reset role');
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertEqual(actual, expected, message) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${message}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

/** Runs [sql] as the auth user [authId] with the `authenticated` role. */
async function as(authId, sql, params = []) {
  await db.exec('reset role');
  await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [authId ?? '']);
  await db.exec('set role authenticated');
  try {
    return (await db.query(sql, params)).rows;
  } finally {
    await db.exec('reset role');
  }
}

/** Expects [sql] to fail with SQLSTATE [code] (or a message matching it). */
async function expectError(authId, sql, params, code) {
  try {
    await as(authId, sql, params);
  } catch (error) {
    const got = error.code ?? '';
    if (got === code || (error.message ?? '').includes(code)) return error;
    throw new Error(`expected ${code}, got ${got}: ${error.message}`);
  }
  throw new Error(`expected ${code}, but it succeeded`);
}

/** A sign-in with Google or an email code: the email is verified. */
async function signUp(email, fullName = null) {
  const meta = fullName ? { full_name: fullName } : {};
  const { rows } = await db.query(
    'insert into auth.users (email, raw_user_meta_data) values ($1, $2) returning id',
    [email, JSON.stringify(meta)],
  );
  return rows[0].id;
}

async function scalar(authId, sql, params = []) {
  const rows = await as(authId, sql, params);
  return rows[0] ? Object.values(rows[0])[0] : undefined;
}

// --------------------------------------------------------------------------
// Supabase stand-ins, then the migrations
// --------------------------------------------------------------------------

await db.exec(`
  create schema auth;
  create table auth.users (
    id uuid primary key default gen_random_uuid(),
    email text unique,
    phone text unique,
    raw_user_meta_data jsonb not null default '{}'
  );
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon nologin;
  create role authenticated nologin;
  grant usage on schema auth to anon, authenticated;
  grant execute on function auth.uid() to anon, authenticated;
  grant usage on schema public to anon, authenticated;
`);
for (const file of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
  await db.exec(readFileSync(join(migrationsDir, file), 'utf8'));
}

const today = (await db.query('select public.local_today() as d')).rows[0].d.toISOString().slice(0, 10);
const daysAgo = (n) => {
  const d = new Date(`${today}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - n);
  return d.toISOString().slice(0, 10);
};

// Ali creates a group with Hamza (no account yet) and a fund.
const ali = await signUp('Ali.Raza@Gmail.com', 'Ali Raza');
const usman = await signUp('usman@example.com');
const zain = await signUp('zain@example.com');
await as(ali, `select public.update_my_profile('Ali Raza')`);
await as(usman, `select public.update_my_profile('Usman Tariq')`);
await as(zain, `select public.update_my_profile('Zain Abbas')`);
const aliProfile = await scalar(ali, 'select public.current_profile_id()');
const usmanProfile = await scalar(usman, 'select public.current_profile_id()');

const groupId = await scalar(ali, `select public.create_group($1, $2, $3, $4)`, [
  'Gulberg Apartment 4B',
  'Shared flat',
  JSON.stringify([
    { name: 'Hamza Khan', email: 'HAMZA@example.com', phone: '+923211234567', contribution_paisa: 500000 },
    { name: 'Usman Tariq', email: 'usman@example.com' },
  ]),
  500000,
]);

console.log('Roomeez database rules');

await test('creator is the manager; members and contributions are recorded', async () => {
  const members = await as(ali, 'select display_name, role, start_date from group_members where group_id = $1 order by display_name', [groupId]);
  assertEqual(members.map((m) => [m.display_name, m.role]), [['Ali Raza', 'manager'], ['Hamza Khan', 'member'], ['Usman Tariq', 'member']], 'members');
  const fund = await scalar(ali, 'select sum(amount_paisa)::int from contributions where group_id = $1', [groupId]);
  assertEqual(fund, 1000000, 'fund total');
  const code = await scalar(ali, 'select code from groups where id = $1', [groupId]);
  assert(/^[A-Z2-9]{6}$/.test(code), `bad code ${code}`);
});

await test('a person added by email is linked when they sign in with that email', async () => {
  const hamza = await signUp('hamza@example.com');
  const groups = await as(hamza, 'select name from groups');
  assertEqual(groups.map((g) => g.name), ['Gulberg Apartment 4B'], 'groups visible to Hamza');
  const profile = await as(hamza, 'select name, email, phone, has_completed_profile from profiles');
  assertEqual(profile, [{ name: 'Hamza Khan', email: 'hamza@example.com', phone: '+923211234567', has_completed_profile: false }], 'placeholder profile');
});

await test('a Google name pre-fills the profile; emails are stored in lower case', async () => {
  const profile = await as(ali, 'select name, email from profiles');
  assertEqual(profile, [{ name: 'Ali Raza', email: 'ali.raza@gmail.com' }], 'Ali profile');
});

await test('phone numbers are optional and never link accounts', async () => {
  // Someone signing in with a phone (old flow) gets a fresh profile, not Hamza's.
  const { rows } = await db.query(`insert into auth.users (phone) values ('923211234567') returning id`);
  assertEqual(await as(rows[0].id, 'select name from groups'), [], 'phone sign-in sees nothing');
  await as(zain, `select public.update_my_profile('Zain Abbas', '+923111234567')`);
  await as(zain, `select public.update_my_profile('Zain Abbas', null)`);
  assertEqual(await scalar(zain, 'select phone from profiles'), null, 'phone cleared');
  await expectError(zain, `select public.update_my_profile('Zain Abbas', '12')`, [], 'RZ422');
});

const hamza = (await db.query(`select id from auth.users where email = 'hamza@example.com'`)).rows[0].id;
const hamzaProfile = await scalar(hamza, 'select public.current_profile_id()');
const split = [aliProfile, hamzaProfile, usmanProfile];
const expense = (overrides = {}) =>
  JSON.stringify({
    title: 'Milk and fruit',
    date: today,
    category: 'groceries',
    items: [
      { name: 'Milk 1L', quantity_milli: 3000, unit_price_paisa: 22000 },
      { name: 'Bananas', quantity_milli: 2000, unit_price_paisa: 18000 },
    ],
    payment_source: 'personal',
    paid_by: aliProfile,
    split_among: split,
    ...overrides,
  });

let aliExpense;
await test('a member adds an itemized expense; the total is computed on the server', async () => {
  aliExpense = await scalar(ali, 'select public.add_expense($1, $2)', [groupId, expense()]);
  const row = (await as(hamza, 'select total_paisa::int as total, created_by, jsonb_array_length(items) as n from expenses where id = $1', [aliExpense]))[0];
  assertEqual(row, { total: 102000, created_by: aliProfile, n: 2 }, 'expense row');
});

await test('quantities with decimals round half-up like the app', async () => {
  const id = await scalar(ali, 'select public.add_expense($1, $2)', [groupId, expense({
    items: [{ name: 'Yogurt', quantity_milli: 1500, unit_price_paisa: 24000 }, { name: 'Odd', quantity_milli: 333, unit_price_paisa: 100 }],
  })]);
  assertEqual(await scalar(ali, 'select total_paisa::int from expenses where id = $1', [id]), 36000 + 33, 'total');
});

await test('the creator can edit; the edit is marked and history keeps the old version', async () => {
  await as(ali, 'select public.update_expense($1, $2)', [aliExpense, expense({ items: [{ name: 'Milk 1L', quantity_milli: 4000, unit_price_paisa: 22000 }] })]);
  const row = (await as(ali, 'select total_paisa::int as total, edited_at is not null as edited from expenses where id = $1', [aliExpense]))[0];
  assertEqual(row, { total: 88000, edited: true }, 'after edit');
  const history = await as(hamza, `select action, (previous->>'total_paisa')::int as before from expense_history where expense_id = $1`, [aliExpense]);
  assertEqual(history, [{ action: 'edited', before: 102000 }], 'history');
});

await test('another member cannot edit or void someone else\'s expense', async () => {
  await expectError(hamza, 'select public.update_expense($1, $2)', [aliExpense, expense()], 'RZ403');
  await expectError(hamza, 'select public.void_expense($1, $2)', [aliExpense, 'mine now'], 'RZ403');
});

await test('the manager cannot edit someone else\'s expense either', async () => {
  const hamzaExpense = await scalar(hamza, 'select public.add_expense($1, $2)', [groupId, expense({ paid_by: hamzaProfile })]);
  await expectError(ali, 'select public.update_expense($1, $2)', [hamzaExpense, expense()], 'RZ403');
  assertEqual(await scalar(ali, 'select created_by from expenses where id = $1', [hamzaExpense]), hamzaProfile, 'owner unchanged');
});

await test('nobody can write tables directly or delete anything', async () => {
  await expectError(ali, `update expenses set total_paisa = 1 where id = $1`, [aliExpense], '42501');
  await expectError(ali, `delete from expenses where id = $1`, [aliExpense], '42501');
  await expectError(ali, `insert into contributions (group_id, member_profile_id, amount_paisa, date, type, recorded_by) values ($1, $2, 1, $3, 'top_up', $2)`, [groupId, aliProfile, today], '42501');
  // Even the database owner is blocked by the triggers.
  try {
    await db.query('delete from expenses where id = $1', [aliExpense]);
    throw new Error('owner delete succeeded');
  } catch (error) {
    assert((error.code ?? '') === 'RZ403', `owner delete: ${error.code} ${error.message}`);
  }
  try {
    await db.query('update expenses set created_by = $2 where id = $1', [aliExpense, hamzaProfile]);
    throw new Error('ownership change succeeded');
  } catch (error) {
    assert((error.code ?? '') === 'RZ403', `ownership change: ${error.code} ${error.message}`);
  }
});

await test('voiding keeps the record visible and locks it', async () => {
  const id = await scalar(ali, 'select public.add_expense($1, $2)', [groupId, expense({ title: 'Duplicate' })]);
  await as(ali, 'select public.void_expense($1, $2)', [id, 'Entered twice']);
  const row = (await as(hamza, 'select status, void_reason from expenses where id = $1', [id]))[0];
  assertEqual(row, { status: 'voided', void_reason: 'Entered twice' }, 'voided row');
  await expectError(ali, 'select public.update_expense($1, $2)', [id, expense()], 'RZ403');
});

await test('non-members see nothing and cannot add expenses', async () => {
  assertEqual(await as(zain, 'select id from expenses'), [], 'expenses visible to Zain');
  assertEqual(await as(zain, 'select id from group_members'), [], 'members visible to Zain');
  await expectError(zain, 'select public.add_expense($1, $2)', [groupId, expense()], 'RZ403');
});

await test('validation: future dates, empty split, zero totals', async () => {
  await expectError(ali, 'select public.add_expense($1, $2)', [groupId, expense({ date: '2999-01-01' })], 'RZ422');
  await expectError(ali, 'select public.add_expense($1, $2)', [groupId, expense({ split_among: [] })], 'RZ422');
  await expectError(ali, 'select public.add_expense($1, $2)', [groupId, expense({ items: [], quick_amount_paisa: 0 })], 'RZ422');
  await expectError(ali, 'select public.add_expense($1, $2)', [groupId, expense({ title: '  ' })], 'RZ422');
});

await test('join by code: preview without records, any member approves', async () => {
  const code = await scalar(ali, 'select code from groups where id = $1', [groupId]);
  const preview = (await as(zain, 'select * from public.find_group_by_code($1)', [code.toLowerCase()]))[0];
  assertEqual([preview.name, preview.active_member_count, preview.is_already_member], ['Gulberg Apartment 4B', 3, false], 'preview');
  const request = await scalar(zain, 'select public.request_to_join($1, $2)', [code, 'Zain Abbas']);
  assertEqual(await scalar(zain, 'select public.request_to_join($1, $2)', [code, 'Zain Abbas']), request, 'same pending request');
  assertEqual((await as(hamza, `select name from join_requests where status = 'pending'`)).map((r) => r.name), ['Zain Abbas'], 'members see request');
  await as(usman, 'select public.decide_join_request($1, true)', [request]);
  assertEqual(await scalar(zain, 'select count(*)::int from expenses'), 4, 'Zain sees all 4 expenses after approval');
  const start = await scalar(zain, `select start_date from group_members where profile_id = public.current_profile_id()`);
  assertEqual(start.toISOString().slice(0, 10), today, 'joined today');
});

await test('someone who joined later cannot share an earlier expense', async () => {
  const zainProfile = await scalar(zain, 'select public.current_profile_id()');
  await expectError(ali, 'select public.add_expense($1, $2)', [groupId, expense({ date: daysAgo(3), split_among: [aliProfile, zainProfile] })], 'RZ422');
});

await test('any member can add a member; only the manager removes', async () => {
  const memberId = await scalar(usman, 'select public.add_member($1, $2, $3, $4, $5)', [groupId, 'Bilal Ahmed', 'bilal@example.com', '+923451234567', today]);
  await expectError(hamza, 'select public.remove_member($1, $2)', [groupId, memberId], 'RZ403');
  await as(ali, 'select public.remove_member($1, $2)', [groupId, memberId]);
  const row = (await as(ali, 'select status, end_date is not null as ended from group_members where id = $1', [memberId]))[0];
  assertEqual(row, { status: 'removed', ended: true }, 'removed member');
});

await test('a removed creator keeps their expenses but loses access and edit rights', async () => {
  const usmanExpense = await scalar(usman, 'select public.add_expense($1, $2)', [groupId, expense({ paid_by: usmanProfile })]);
  const usmanMember = await scalar(ali, 'select id from group_members where profile_id = $1 and group_id = $2 and status = $3', [usmanProfile, groupId, 'active']);
  await as(ali, 'select public.remove_member($1, $2)', [groupId, usmanMember]);
  assertEqual(await scalar(ali, 'select created_by from expenses where id = $1', [usmanExpense]), usmanProfile, 'record kept');
  assertEqual(await as(usman, 'select id from expenses'), [], 'no access after removal');
  await expectError(usman, 'select public.update_expense($1, $2)', [usmanExpense, expense()], 'RZ404');
  await expectError(ali, 'select public.update_expense($1, $2)', [usmanExpense, expense()], 'RZ403');
});

await test('when the manager leaves, the longest-standing member takes over', async () => {
  const next = await scalar(ali, 'select public.leave_group($1)', [groupId]);
  assertEqual(next, 'Hamza Khan', 'new manager');
  assertEqual(await scalar(hamza, `select count(*)::int from group_members where role = 'manager' and status = 'active'`), 1, 'one manager');
  assertEqual(await as(ali, 'select id from groups'), [], 'Ali lost access');
});

await test('only the manager can change the join code', async () => {
  const zainOk = await expectError(zain, 'select public.regenerate_group_code($1)', [groupId], 'RZ403');
  assert(zainOk, 'non-manager blocked');
  const code = await scalar(hamza, 'select public.regenerate_group_code($1)', [groupId]);
  assert(/^[A-Z2-9]{6}$/.test(code), 'new code');
});

await test('contributions: active members only, positive amounts', async () => {
  const zainProfile = await scalar(zain, 'select public.current_profile_id()');
  await as(zain, 'select public.add_contribution($1, $2, $3, $4, $5)', [groupId, zainProfile, 300000, today, 'Joining']);
  await expectError(zain, 'select public.add_contribution($1, $2, $3, $4, $5)', [groupId, zainProfile, 0, today, null], 'RZ422');
  await expectError(zain, 'select public.add_contribution($1, $2, $3, $4, $5)', [groupId, aliProfile, 100, today, null], 'RZ422');
});

await test('offline members (no email) can share expenses but never get linked', async () => {
  const memberId = await scalar(hamza, 'select public.add_member($1, $2, $3, $4, $5)', [groupId, 'Danish Iqbal', null, null, today]);
  const danish = await scalar(hamza, 'select profile_id from group_members where id = $1', [memberId]);
  const id = await scalar(hamza, 'select public.add_expense($1, $2)', [groupId, expense({ paid_by: danish, split_among: [hamzaProfile, danish] })]);
  assertEqual(await scalar(hamza, 'select paid_by from expenses where id = $1', [id]), danish, 'paid by offline member');
  await expectError(hamza, 'select public.add_member($1, $2, $3, $4, $5)', [groupId, 'Bad Email', 'not-an-email', null, today], 'RZ422');
});

await test('an older account can be moved to a Google email and still finds its groups', async () => {
  // An account from before email sign-in: profile with a phone, no email.
  const { rows } = await db.query(`insert into auth.users (phone) values ('923099865055') returning id`);
  const oldAuth = rows[0].id;
  await as(oldAuth, `select public.update_my_profile('Roomeez Owner', '+923099865055')`);
  await as(oldAuth, `select public.create_group('Roomies')`);
  // The owner gives that profile their Gmail and frees it from the old sign-in.
  await db.query(`update profiles set email = 'owner@gmail.com', auth_user_id = null where phone = '+923099865055'`);
  const google = await signUp('owner@gmail.com', 'Owner From Google');
  assertEqual((await as(google, 'select name from groups')).map((g) => g.name), ['Roomies'], 'groups after Google sign-in');
  assertEqual(await scalar(google, 'select name from profiles'), 'Roomeez Owner', 'kept the profile');
});

await test('ensure_my_profile repairs a sign-in that has no profile', async () => {
  // A user created while the trigger couldn't attach a profile.
  await db.exec('alter table auth.users disable trigger on_auth_user_created');
  const { rows } = await db.query(`insert into auth.users (email) values ('late@example.com') returning id`);
  await db.exec('alter table auth.users enable trigger on_auth_user_created');
  const late = rows[0].id;
  assertEqual(await as(late, 'select id from profiles'), [], 'no profile yet');
  await as(late, 'select public.ensure_my_profile()');
  await as(late, 'select public.ensure_my_profile()');
  assertEqual(await scalar(late, 'select email from profiles'), 'late@example.com', 'profile created once');
});

await test('signed-out callers are rejected', async () => {
  await expectError(null, 'select public.create_group($1)', ['Nope'], 'RZ401');
});

// Real rows as the API returns them (PostgREST uses the same JSON encoding as
// to_jsonb), used by test/data/supabase_row_mappers_test.dart.
const fixtures = {};
for (const [name, sql] of Object.entries({
  profile: `select to_jsonb(p) as row from profiles p where p.auth_user_id = '${hamza}'`,
  group: `select to_jsonb(g) as row from groups g limit 1`,
  member: `select to_jsonb(m) as row from group_members m where m.status = 'removed' limit 1`,
  joinRequest: `select to_jsonb(r) as row from join_requests r where r.status = 'approved' limit 1`,
  expense: `select to_jsonb(e) as row from expenses e where jsonb_array_length(e.items) = 2 limit 1`,
  voidedExpense: `select to_jsonb(e) as row from expenses e where e.status = 'voided' limit 1`,
  contribution: `select to_jsonb(c) as row from contributions c where c.type = 'top_up' limit 1`,
})) {
  fixtures[name] = (await db.query(sql)).rows[0].row;
}
const fixturesDir = join(here, '..', '..', 'test', 'fixtures');
mkdirSync(fixturesDir, { recursive: true });
writeFileSync(join(fixturesDir, 'supabase_rows.json'), `${JSON.stringify(fixtures, null, 2)}\n`);

console.log(`\n${passed} passed, ${failures.length} failed`);
process.exit(failures.length === 0 ? 0 : 1);
