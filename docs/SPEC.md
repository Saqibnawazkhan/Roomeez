# Roomeez: Shared Living Expense App --- MVP Prototype Specification

Version 1.1 (updated 2026-10-15). Section 0 lists the decisions agreed after
the first review; the rest of the document has been updated to match.

## 0. Agreed Changes (v1.1)

| # | Topic | Decision |
|---|---|---|
| 1 | Join approval | **Any active member** can approve or decline a join request. |
| 2 | Manager role | The creator starts as **group manager** (add/remove members, change join code). If the manager leaves, the role passes automatically to the longest-standing active member. |
| 3 | Balances | Show a **simple equal-split balance** per member: `contributions + expenses paid personally - share of expenses`. No settle-up or optimization yet. |
| 4 | Who shares an expense | Each expense stores `splitAmongUserIds`, defaulting to the members whose membership covers the expense date. |
| 5 | Mistaken entries | The creator can **void** an expense (with a reason). Voided expenses stay visible, marked as voided, and are excluded from totals, balances and reports. This is not a delete. |
| 6 | Group fund | Contributions can be added at any time (top-ups), not only at creation. Show the fund's remaining balance. |
| 7 | Quick entry | Item rows are optional: an expense can be **itemized** or a **single amount** (e.g. a utility bill). |
| 8 | Sign-in and account linking | Sign in with **Google** or a **code sent by email** (both verify the email; no SMS cost). A member added by email is linked automatically when that person signs in with it. Phone numbers are optional contact details and never used to sign in or link accounts. Members added without an email are offline members. *(Changed 2026-10-17; was phone + SMS code.)* |
| 9 | Navigation | Home lists groups. Inside a group, the bottom tabs are **Dashboard, Expenses, Reports, Members**; Profile is on the Home app bar. |
| 10 | Database | **Supabase (PostgreSQL)** for the production backend (Phase 2). Firebase is not used. |
| 11 | PDF | A one-page summary generated on the device with the `pdf` package, in the app's neumorphic style: totals, balances, spending by category and the expense list (condensed to daily or monthly totals for long periods). Item details stay in the app. Shared via the OS share sheet. |
| 12 | Edit history | The backend keeps the previous version of an expense on every edit or void (`expense_history`). Writes go through database functions; clients can only read. |


## 1. Project Overview

Build an initial UI prototype for a shared living expense management app
used by roommates, hostel residents, flatmates, and people sharing an
apartment.

The first release is an MVP focused on the core user experience and
testing. Do not add future-phase features unless they are required for
the described workflows.

### Platforms

-   Build the mobile application in **Flutter and Dart**.
-   Support **Android and iOS** from the same Flutter codebase.
-   Do not build a group-owner/admin web dashboard in this phase.
-   A separate developer/operator dashboard may be considered later, but
    it is not part of the current MVP.
-   Keep the code structured so a web dashboard and backend integrations
    can be added later.

### Prototype-first approach

First deliver a polished, navigable UI prototype using realistic sample
data and local/mock state. Keep the data and service layers separated so
a real backend can be connected later without rebuilding the UI.

Do not pretend mock data has been saved to a real server. Clearly
isolate mock repositories and services from production-ready interfaces.

## 2. Product Principles

1.  A group creator is a regular member of the group, not a separate
    super-admin.
2.  All active group members can view the shared group records.
3.  All active group members can add expenses and view reports.
4.  All active group members can add expenses and view shared records, but **only the user who created a particular expense can edit that expense**.
5.  Other members can view the expense details but must not see or access its edit controls.
6.  **There must be no delete action anywhere in the app**. No member, including the group creator, can delete an expense.
7.  The group manager (initially the creator) has a small set of
    additional group-management permissions: remove members and change
    the join code.
8.  All active members can add a person to the group and approve join
    requests.
9.  When a member leaves or is removed, preserve historical expense
    records and their original details.
10. Keep the UI simple, clear, and suitable for a first user test.
11. Do not build advanced features that are explicitly deferred to a
    later phase.

## 3. Core User Journey

### Authentication

-   Welcome screen.
-   Sign up.
-   Log in.
-   Basic profile setup: name and phone number.
-   For the UI prototype, authentication may be mocked; keep screens and
    navigation realistic.

### Home screen

After login, show two primary actions: - **Create Group** - **Join
Group**

Also show the user's existing groups if they are already a member of any
groups.

### Create Group

The user enters: - Group name, e.g. "My Apartment". - Optional short
description. - Member details: name and phone number. - Optional initial
group contribution/fund.

On successful creation: - Generate and display a unique-looking group
code, preferably 6--8 alphanumeric characters for the prototype. - Show
a share/copy code action. - Add the creator as a normal member with the
additional ability to add/remove members. - Open the group dashboard.

For the prototype, a generated sample code is acceptable. Keep code
generation behind a service interface so it can be replaced with secure
backend generation later.

### Join Group

The user enters: - Group code. - Their name and phone number, if not
already in their profile.

Show a confirmation/request screen. Model the intended workflow in the
UI: a join request goes to the group, and any active member can approve
or decline it.
For the initial prototype, simulate the request and approval states with
mock data.

Do not expose private group expenses before the user is an approved
member.

## 4. Group Dashboard

Every group member should be able to access the same core group
features.

Show: - Group name and group code. - Member count and member list. -
Total recorded expenses for the selected period. - Optional initial
contribution/fund summary. - Recent expenses. - Quick action to add an
expense. - Actions for Expenses, Members, Reports, and Group Settings. -
A clear date/period filter.

Use a clean, premium, simple design. Prioritize readability over
decorative charts. Ensure the layout works on small Android and iPhone
screens.

## 5. Add Expense

Any active group member can add an expense.

### Required fields

-   Expense title or short description.
-   Date.
-   Category: Breakfast, Lunch, Dinner, Groceries, Household, Bills,
    Transport, Other.
-   One or more item rows.
-   Item name.
-   Quantity.
-   Price per item or line total; make the calculation clear and
    consistent.
-   Total expense amount.
-   Person who added the expense.
-   Person who paid, if different from the person adding it.
-   Payment source: Personal Money or Group Fund.
-   Optional notes.

### Item entry behavior

-   Allow adding multiple items to a single expense.
-   Allow editing item names, quantities, and prices before saving.
-   Recalculate line totals and the overall total immediately.
-   Validate required fields and non-negative valid amounts.
-   Show a clear expense summary before saving.

### Shared visibility

After saving, the new expense should appear in the group's expense list
and dashboard for every member.

For a UI prototype, use a shared in-memory/mock repository so navigation
between screens reflects the same sample state during the prototype
session.

## 6. Expenses List and Expense Details

The expense list should show: - Date. - Expense title/category. -
Amount. - Added by. - Paid by. - Payment source. - Optional item count.

Include basic filters: - Date range. - Category. - Member. - Search by
title or item.

Tapping an expense opens a detailed view showing all items, quantities,
prices, total, payer, creator, date, and notes.

## 7. Expense Ownership, Editing, and No-Delete Security Policy

This is a critical security and product rule.

-   Every expense must store an immutable `createdByUserId` (or equivalent) identifying the authenticated user who originally created it.
-   **Only the original creator of an expense can edit that expense.**
-   The group creator, other group members, and any member-management role must not be able to edit another person's expense.
-   All active group members can view all authorized group expenses, but edit controls must only appear for the original creator of each expense.
-   Example: A creates a PKR 500 expense. A may correct it to PKR 600 or PKR 400. B and C can view the expense, but cannot edit its amount, items, quantity, category, date, or notes.
-   If B or C notices a possible mistake, they must contact A and ask A to make the correction. Do not implement another member's edit request workflow in this MVP.
-   Do not change ownership just because another member paid for the expense. `createdByUserId` and `paidByUserId` are separate fields.
-   If the original creator leaves or is removed from the group, preserve their expense records. Do not silently transfer edit ownership to the group creator or another member.
-   The creator's additional group-management permissions do not override expense ownership.
-   For the prototype, enforce this rule in the UI and mock repository/service layer, and test it using multiple sample users.
-   For a production backend, enforce authorization on the server/database as well. Hiding an edit button in the UI alone is not security. Every update request must verify that the authenticated user is the original creator and an authorized group member.
-   If practical, show an “Edited” label and last-edited timestamp after a successful edit. Preserve the original creator identity.
-   **Do not display a Delete button, delete icon, swipe-to-delete gesture, context-menu delete action, or bulk-delete action anywhere in the app.**
-   Do not implement a delete method for expenses in the repository/API.
-   Do not use dismissible list items that imply deletion.
-   If a record was entered incorrectly, its original creator must edit it instead of deleting it.

Do not claim production-grade security for a mock-only prototype. Document that server/database authorization must be implemented before real multi-user deployment.

## 8. Group Members and Permissions

### All active members can

-   View group details and members.
-   View all group expenses.
-   Add new expenses.
-   Edit only the expense records they originally created.
-   View group summaries.
-   Generate/download a PDF report in the prototype.
-   Add a member, according to the agreed group behavior.
-   Leave the group, with a confirmation screen.

A member must never be able to edit another member's expense, even if they are the group creator or have permission to manage members.

### Group manager's additional capabilities

The creator is the first group manager. If the manager leaves, the role
passes to the longest-standing active member.

-   Remove/deactivate a member.
-   Generate a new join code.

(Adding members and approving join requests are open to all active
members.)

The creator remains a normal member for expenses and balances. Do not
create a separate owner-only dashboard.

### Add member screen

Fields: - Full name. - Phone number. - Optional membership start date.

The membership start date should be captured in the data model even if
advanced date-based settlement logic is not fully implemented in the
prototype.

### Remove member

-   Provide a "Remove member" action only to the permitted role(s).
-   Show a confirmation dialog.
-   Explain that the member will lose future group access but historical
    expenses remain visible in the group records.
-   Do not delete the member's past expenses.
-   No expense deletion is allowed.

## 9. Initial Contribution

During group creation, allow the user to: - Start without an initial
contribution, or - Record an initial contribution/fund.

Example: - A contributes PKR 5,000. - B contributes PKR 5,000. - C
contributes PKR 5,000. - Total starting fund: PKR 15,000.

For the prototype: - Record the amount per member where sample data is
available. - Clearly distinguish contributions from expenses. - Clearly
label the total as "Initial Contributions" or "Group Fund", not "Total
Expenses". - Do not imply that a fund contribution is an expense. - Show
whether a recorded expense was paid using personal money or the group
fund.

Full reconciliation and complex settlement calculations can be improved
after the prototype has been tested.

## 10. Date Ranges and Member Joining Dates

Capture a member's effective start date. Do not automatically assign
expenses from before that date to the new member.

Example: - A, B, and C are members from October 1 to October 15. - D
joins effective October 16. - The October 1--15 report should not
include D as a participant. - The October 16 onward period can include D
where applicable.

For this prototype, the UI should support selecting a report date range
and display membership start dates. Keep the data model ready for
date-aware financial rules, but do not overbuild advanced period locking
or audit snapshots in this first UI prototype.

## 11. PDF Report UI

Create a Report screen with: - Preset options: Last 10 Days, Last 15
Days, This Month. - Custom start date and end date selection. - Generate
Report button. - Report preview state. - Download/share action in the
prototype, clearly mocked if no actual PDF service is connected.

A report should be designed to include: - Group name and code. - Report
period. - Daily expense list. - Item names, quantities, and prices. -
Expense total. - Added by and paid by. - Initial contribution/fund
summary, if applicable. - Member list and membership dates. - Summary
totals.

The prototype must not claim a real PDF has been generated or sent if
this is only a mocked UI. A real PDF generator can be connected in a
later implementation step.

WhatsApp delivery is not required in this first prototype. A future
version may support native file sharing or WhatsApp Business
integration.

## 12. Suggested Flutter Architecture

Use a maintainable feature-first structure, for example:

``` text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    constants/
    utils/
    widgets/
  features/
    auth/
      screens/
      widgets/
      models/
      repositories/
    home/
    groups/
    members/
    expenses/
    reports/
    profile/
  data/
    mock/
    repositories/
    services/
  main.dart
```

Use reusable widgets and typed models. Keep mock data separate from UI
widgets. Do not put all app logic inside a single screen or `main.dart`.

Recommended entities: - User - Group - GroupMember - JoinRequest -
Expense - ExpenseItem - Contribution - ReportFilter

Use stable IDs for entities and references between them. Store money as
integer minor units (e.g. paisa) or another exact decimal
representation; avoid floating-point arithmetic for monetary totals.

For the initial prototype, local/mock repositories are acceptable. Keep
repository interfaces so the production backend can be connected later.
The chosen backend is **Supabase (PostgreSQL)**: row-level security for
creator-only edits, no DELETE grant on expenses, a trigger keeping
`created_by` immutable, and SQL views for reports and balances.

## 13. UI and Visual Design

Create a modern, polished, trustworthy finance utility app.

Requirements: - Mobile-first layouts for iOS and Android. - Consistent
typography and spacing. - Clear labels and readable amounts. - Clean
cards and simple lists. - Accessible color contrast. - Good empty,
loading, validation, and error states. - Consistent bottom navigation or
navigation structure. - Confirmation dialogs for leaving/removing
members. - No cluttered dashboard. - No delete controls anywhere. - Use
realistic sample names, expenses, dates, and PKR values. - Avoid making
the prototype look like a generic admin panel.

Navigation: Home lists the user's groups (with Create / Join actions and
Profile in the app bar). Inside a group, the bottom navigation is
Dashboard, Expenses, Reports, Members. Group settings open from the
dashboard app bar.

## 14. MVP Scope --- Included

-   Flutter Android/iOS UI.
-   Mocked sign-up/login flow.
-   Create Group.
-   Join Group by code.
-   Simulated join request/approval.
-   Group dashboard.
-   Member list.
-   Add member and remove/deactivate member flows.
-   Optional initial contributions and later top-ups.
-   Add itemized or single-amount expenses.
-   Edit expense records (creator only).
-   Void a mistaken expense (creator only; stays visible).
-   Simple equal-split member balances.
-   No delete action anywhere.
-   Expense history and basic filters.
-   Date-range report configuration.
-   PDF preview/share UI, mocked if necessary.
-   Realistic sample data.
-   Basic navigation and form validation.

## 15. Explicitly Deferred

Do not build these now unless needed to demonstrate the core UI: -
Developer/operator web dashboard. - Full production backend. - Automated
WhatsApp report delivery. - OCR receipt scanning. - AI features. -
Complex recurring expenses. - Advanced budgeting. - Multi-currency
support beyond PKR. - Advanced financial settlement optimization. -
Immutable period snapshots and advanced audit tooling. - Analytics-heavy
dashboards. - Subscription/payment plans.

Keep the architecture extensible, but do not spend the first iteration
implementing these future ideas.

## 16. Acceptance Checklist

The first prototype is ready for user testing when:

-   [ ] The app launches and navigation works.
-   [ ] Sign-up/login screens can be traversed.
-   [ ] A user can create a group and see a group code.
-   [ ] A user can open the join flow and simulate a request.
-   [ ] The group dashboard displays members and sample totals.
-   [ ] A user can add an expense with multiple items.
-   [ ] Item totals and expense totals recalculate correctly.
-   [ ] A newly added expense appears in the expense list.
-   [ ] A user can open and edit an expense.
-   [ ] There is no delete action or delete gesture anywhere.
-   [ ] Group member management screens work as a prototype.
-   [ ] Initial contributions are visually distinct from expenses.
-   [ ] Report date filters can be selected.
-   [ ] Report preview and share/download UI can be demonstrated.
-   [ ] The app works on Android and iOS layouts.
-   [ ] Mock data and UI code are separated cleanly.
-   [ ] The README explains how to run the Flutter app.

## 17. Instructions to the Coding Agent

Start by inspecting the existing project. Do not overwrite existing work
without understanding it.

Then: 1. Summarize the planned screens and navigation. 2. Create the
Flutter project structure if required. 3. Implement the theme and
reusable UI components. 4. Build the core flows incrementally. 5. Use
mock data and repositories for this prototype. 6. Verify all navigation
and form interactions. 7. Search the entire project for delete actions
and ensure none are present for expenses. 8. Run formatting, static
analysis, and tests that are available in the environment. 9. Fix errors
before declaring completion. 10. Update the README with setup and run
instructions.

Prioritize a working, polished, testable prototype over adding
unrequested future features.
