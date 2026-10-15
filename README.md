# Roomeez

A shared living expense app for roommates, flatmates and hostel residents.
Members keep one honest, itemized record of shared spending: everyone can see
every expense, only the person who added an expense can edit it, and nothing
is ever erased.

> **Status: UI prototype (Phase 1).** All data is sample data held in memory
> on the device and resets when the app restarts. Login codes are not real
> SMS messages. Permission rules are enforced in the app's mock data layer
> only. **Server-side enforcement (Supabase row-level security) must be in
> place before any real multi-user deployment.**

The product specification is in [docs/SPEC.md](docs/SPEC.md).

## Run it

Requirements: Flutter 3.35+ (Dart 3.9+). Android Studio for Android; Xcode on
a Mac for iOS.

```bash
flutter pub get
flutter run            # pick an Android emulator/device or iOS simulator
```

Checks:

```bash
flutter analyze
flutter test
```

## Trying the prototype

On the welcome screen, tap **Explore with sample users** and pick an account.
You can switch accounts any time from **Profile → Switch sample user**.

| Sample user | Phone | Useful for |
|---|---|---|
| Ali Raza | 0300 1234567 | Manager of *Gulberg Apartment 4B*; regular member of *Hostel Room 12* |
| Hamza Khan | 0321 1234567 | Manager of *Hostel Room 12*; added several apartment expenses |
| Usman Tariq | 0333 1234567 | Regular member |
| Bilal Ahmed | 0345 1234567 | Joined the apartment 6 days ago, so he isn't part of older expenses |

To try sign-up or log-in, use any of those numbers to log in, or any new
Pakistani mobile number to sign up. The verification code is always
**123456**. Signing up with **0307 1234567** (Danish) shows account linking:
a member already added that number to *Hostel Room 12*.

Things to try:

- **Creator-only editing.** As Hamza, open *Electricity bill (LESCO)*: you
  can edit it. As Ali (the manager) or Usman, the same expense is read-only,
  with a note explaining who can change it.
- **Void instead of delete.** As Usman, see the voided *Pizza order*
  duplicate. As the creator of an expense, use ⋮ → *Void expense*.
- **Add an itemized expense.** Totals recalculate as you type; review the
  summary before saving.
- **Joining dates.** Add an expense dated more than a week ago: Bilal is not
  offered as a participant.
- **Join requests.** As Ali or any apartment member, approve Zain's request
  on the Members tab. Or sign up as a new user, join with code `RMZ4B7`, and
  use *Simulate approval by a member*.
- **Remove a member / leave a group.** As Ali, remove a member from the
  Members tab; their past expenses stay. Leave the group from Group
  settings, and the manager role passes on.
- **Reports.** Reports tab → pick a period → *Generate report* → *Share PDF*
  or *Print / Save*. The PDF is created on the device.

## Rules the code enforces

| Rule | Where |
|---|---|
| Only an expense's creator (while an active member) can edit or void it, including over the group manager | `PermissionPolicy`, mock repositories, tests |
| No delete action, icon, swipe or repository method anywhere | `test/no_delete_policy_test.dart` scans `lib/` |
| Non-members (and former members) can't read a group's records | mock repositories, tests |
| Money is integer paisa; quantities are integer thousandths | `core/utils/money.dart`, `core/utils/quantity.dart` |
| Expenses are shared only by people who were members on that date | `ExpenseValidator`, `MockExpenseRepository` |

## Project structure

```text
lib/
  app/                 app widget, router, routes, theme, provider wiring
  core/                utilities (money, dates, phone), errors, shared widgets
  data/
    models/            User, Group, GroupMember, JoinRequest, Expense, Contribution...
    repositories/      interfaces the UI depends on
    services/          permissions, validation, balances, reports, PDF, join codes
    mock/              PROTOTYPE ONLY: in-memory store, sample data, mock repos
  features/            auth, home, groups, expenses, members, contributions, reports, profile
test/                  unit, repository and widget tests
docs/SPEC.md           product specification
```

The UI talks only to the repository interfaces in `lib/data/repositories/`.
`lib/app/providers.dart` is the single place that wires in the mock
implementations, so connecting the real backend doesn't change any screen.

Tech: Flutter, Riverpod (state), go_router (navigation), intl (formatting),
pdf + printing (reports), share_plus (sharing the join code).

## Roadmap

- **Phase 2: Supabase backend.** PostgreSQL schema; row-level security for
  membership and creator-only edits; no DELETE grant on expenses; a trigger
  keeping `created_by` immutable; phone OTP auth; an edit history table; SQL
  views for reports and balances. Then replace the mock repositories.
- **Phase 3: Release.** Push notifications (join requests, new expenses),
  offline support, Urdu translation (and a Unicode font for Urdu text in
  PDFs), Play Store and TestFlight builds.

## Known limitations

- Data resets on restart (in-memory mock store).
- No real SMS or server: the code `123456` always works.
- PDF text is limited to Latin characters; other scripts show as `?`.
- iOS builds require a Mac with Xcode.
