# Roomeez

A shared living expense app for roommates, flatmates and hostel residents.
Members keep one honest, itemized record of shared spending: everyone can see
every expense, only the person who added an expense can edit it, and nothing
is ever erased.

The product specification is in [docs/SPEC.md](docs/SPEC.md).

**Status:** Phase 2. The app runs in one of two modes:

- **Demo mode** (default): sample data in memory on the phone, resets on
  restart, sign-in code is always `123456`. Good for trying the UI.
- **Supabase mode:** real accounts (Google or an emailed code), data saved in a
  Supabase Postgres database, rules enforced by the database, and live
  updates between phones.

## Run it

Requirements: Flutter 3.35+ (Dart 3.9+). Android Studio for Android; Xcode on
a Mac for iOS.

```bash
flutter pub get
flutter run                                              # demo mode
flutter run --dart-define-from-file=supabase.env.json    # Supabase mode
```

Checks:

```bash
flutter analyze
flutter test
cd supabase/tests && npm install && npm test             # database rules
```

## Connecting Supabase

1. **Create a project** at [supabase.com](https://supabase.com). The Mumbai
   (South Asia) region is closest to Pakistan.
2. **Create the database.** Run every file in `supabase/migrations/`, in
   name order, in the dashboard's *SQL Editor*, or use the CLI:
   ```bash
   supabase login
   supabase link --project-ref YOUR-PROJECT-REF
   supabase db push
   ```
3. **Turn on sign-in:**
   - *Google:* create a Web and an Android OAuth client in Google Cloud
     (Android: package `com.roomeez.roomeez` + your signing key's SHA-1),
     then in *Authentication → Sign In / Providers → Google* enable it and
     add the Web client ID and secret.
   - *Email code:* in *Authentication → Emails*, make the *Magic Link* and
     *Confirm signup* templates show `{{ .Token }}`. Supabase's built-in
     email only reaches your own team's addresses, so connect a free SMTP
     service (e.g. Resend) under *Authentication → Emails → SMTP Settings*.
4. **Add your keys:** copy `supabase.env.example.json` to
   `supabase.env.json` (it is git-ignored) and fill in the *Project URL* and
   *Publishable key* from *Project Settings → API Keys*, and the Google
   *Web client ID* as `GOOGLE_WEB_CLIENT_ID`. The publishable key
   is meant to be in the app; the database's row-level security decides what
   each user can see and do. Never put the secret / service-role key in the
   app.
5. Run with `flutter run --dart-define-from-file=supabase.env.json`.

Realtime updates are switched on by the migration (it adds the tables to the
`supabase_realtime` publication).

## How the backend enforces the rules

Clients can only **read** tables, and only rows of groups they are an active
member of (row-level security). Every change goes through a database
function that checks who is calling:

| Rule | Enforced by |
|---|---|
| Only an expense's creator, while an active member, can edit or void it. The group manager gets no extra rights over expenses. | `update_expense` / `void_expense` functions |
| Expenses, contributions, memberships and history can't be deleted; triggers block it even from the dashboard's SQL editor | no DELETE privilege + `prevent_delete` / `expenses_guard` triggers |
| An expense's creator and group can never change; a voided expense is locked | `expenses_guard` trigger |
| Every edit and void keeps the previous version | `expense_history` table, filled by the trigger |
| Non-members and former members can't read a group's records | row-level security policies |
| Only the manager removes members or changes the join code; any member adds members or approves join requests | `remove_member`, `regenerate_group_code`, `add_member`, `decide_join_request` |
| Expenses are shared only by people who were members on that date | `prepare_expense` |
| Totals are computed on the server from the items (integer paisa) | `prepare_expense` |
| Someone added by email joins the group when they sign in with that email; phone numbers are optional and never link accounts | `on_auth_user_created` trigger |

The same rules are mirrored in the app (`PermissionPolicy`,
`ExpenseValidator`) so screens only show actions that will succeed.
`supabase/tests/db.test.mjs` runs the migration on an in-process Postgres
(PGlite) and checks each rule as different users.

## Trying demo mode

On the welcome screen, tap **Try the demo** and pick an account. Switch any
time from **Profile → Switch demo user**.

| Demo user | Email | Useful for |
|---|---|---|
| Ali Raza | ali.raza@gmail.com | Manager of *Gulberg Apartment 4B*; regular member of *Hostel Room 12* |
| Hamza Khan | hamza.khan@gmail.com | Manager of *Hostel Room 12*; added several apartment expenses |
| Usman Tariq | usman.tariq@gmail.com | Regular member |
| Bilal Ahmed | bilal.ahmed@gmail.com | Joined the apartment 6 days ago, so he isn't part of older expenses |

You can also use *Continue with email* with any address (code `123456`):
`danish.iqbal@gmail.com` shows how someone added by email joins their group
when they first sign in.

Things to try: open *Electricity bill (LESCO)* as Hamza (editable) and as Ali
(read-only); void one of your own expenses from its ⋮ menu; approve Zain's
join request on the Members tab; generate a report and share the PDF.

## Project structure

```text
lib/
  app/                 app widget, router, theme, config, provider wiring
  core/                utilities (money, dates, phone), errors, shared widgets
  data/
    models/            User, Group, GroupMember, JoinRequest, Expense, Contribution...
    repositories/      interfaces the UI depends on
    services/          permissions, validation, balances, reports, PDF
    mock/              demo mode: in-memory store, sample data, mock repositories
    supabase/          Supabase mode: repositories, row mapping, live queries
    backend.dart       picks the set of repositories
  features/            auth, home, groups, expenses, members, contributions, reports, profile
supabase/
  migrations/          database schema, rules and functions
  tests/               database rule tests (Node + PGlite)
test/                  Dart unit, repository and widget tests
docs/SPEC.md           product specification
```

Screens only use the repository interfaces; `main.dart` chooses demo or
Supabase repositories at startup.

Tech: Flutter, Riverpod, go_router, intl, pdf + printing, share_plus,
supabase_flutter.

## Roadmap

- **Phase 3: Sign-in and notifications.** Google and email-code sign-in
  (done; phone numbers are optional contact details), then push
  notifications for join requests, new and changed expenses.
- **Phase 4: New UI.** Redesign based on the owner's design references.
- **Phase 5: Urdu and release.** Urdu translation (and a Unicode font for
  Urdu in PDFs), Play Store and App Store publishing.

## Known limitations

- PDF text is limited to Latin characters; other scripts show as `?`.
- "Today" on the server is Pakistan time (the app is PKR-only for now).
- iOS builds require a Mac with Xcode.
