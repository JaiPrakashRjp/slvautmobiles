# SLV Auto Consultant

Internal operations app for **SLV Auto Consultant**, a three-wheeler auto-rickshaw
business in Bengaluru. Phone + tablet responsive, Android + iOS (and runnable on
web for quick review). Internal use only — the owner is **Super Admin**, staff are
**Admin**; customers never log in.

## Modules

1. **Auto Sale System** — vehicle inventory, customer KYC, sale (full or advance +
   installments), installment history.
2. **Auto Rental Collection** — rent autos daily/weekly/monthly, track collections,
   per-vehicle earnings and renter history, service-due tracking.
3. **Loan Management** — flat-rate EMI loans, schedule, penalty accrual, foreclosure
   with NOC.
4. **User Management** — Super Admin creates Admins, grants module access, verifies
   them, and reviews every pending Admin action.

## Role-gate (the core pattern)

Every create/update/delete flows through one rule (`lib/services/gate.dart`):

- **Super Admin** action → takes effect immediately (`status: active`, shown as
  *Verified*).
- **Admin** action → held `pending_confirmation` (shown as *Not verified* / *Pending
  approval*) until the Super Admin **approves** or **rejects with a reason**.

The Super Admin's review queue (**User management → Pending approvals**) aggregates
pending items from every module.

> Try it: sign in with username **`admin`** to act as staff (actions go pending);
> any other username signs you in as the **Super Admin**.

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.19+ / Dart 3.3+ |
| State | Provider (`ChangeNotifier` view models + services) |
| Persistence | `shared_preferences` (theme) |
| Fonts | `google_fonts` → Inter |
| Theming | `ThemeExtension<AppColors>` — `context.colors.*` everywhere |
| Routing | `MaterialApp` home + `Navigator.push` |
| PDF | `pdf` + `printing` (invoice, NOC) |
| Deep links | `url_launcher` (WhatsApp / SMS) |

**Mock-first.** Every service is an abstract interface with a `MockXxxService`
implementation backed by in-memory seed data. Firebase (Firestore / Auth / Storage /
Functions) is **Phase 7** — swap each mock for a Firestore implementation behind the
same interface without touching view models.

## Project layout

```
lib/
  controllers/   app-wide ChangeNotifiers (theme, auth)
  theme/         AppColors (ThemeExtension) + AppTheme
  utils/         spacing, radius, text styles, responsive, formatters, validators
  models/        plain-Dart entities (+ GatedEntity mixin, enums)
  services/      abstract + Mock services, role gate, notifications, PDF, reminders
  viewmodels/    one ChangeNotifier per screen
  screens/       auto_sale/ · rental/ · loan/ · users/ + splash, sign-in, chooser
  widgets/       buttons, cards, fields, pills, tabs, dialogs, role-gate banner…
design-reference/  build spec + 18 phone / 2 tablet mockups + wireframes
```

## Running it

```bash
flutter pub get

# Web (no JDK needed) — quickest way to review:
flutter run -d chrome

# Android / iOS (needs a JDK 17 + device/emulator):
flutter run
```

> **Android note:** building an APK needs a JDK on `JAVA_HOME` (JDK 17 recommended).
> This repo analyzes clean and its widget tests pass; only the Gradle/APK packaging
> step needs Java installed.

```bash
flutter analyze   # static analysis (clean)
flutter test      # smoke + navigation tests
```

## Deviations from the original build spec — and why

The build-instructions file and the bundled `build-spec.md` disagreed on a few
foundational choices. The **build-instructions file is authoritative** ("EXACT — do
not deviate"), so:

- **Provider**, not Riverpod (state management).
- **Navigator**, not go_router (routing).
- **shared_preferences**, not Hive (local persistence).
- Folder layout follows the instructions' `screens/widgets/viewmodels/services/...`
  tree, not the spec's `core/features` tree.
- Module build order: Auto Sale → Rental → Loan → Users.

Other deliberate calls:

- **Self-contained Rental data.** The rental module's mock owns its renters and
  rentable vehicles so the demo matches mockups 11–18 exactly without entangling the
  Auto Sale seed. Phase 7 unifies these on the shared Firestore collections.
- **Mobile field added to Create Customer.** Mockup 08 omits it, but the assign-sale
  screen and notifications require a phone number (and the spec mandates it).
- **Login uses username/password** to match mockup 01 (the spec described
  mobile+OTP; that arrives with Firebase Auth in Phase 7).

## Status

Phases 1–6 complete (foundations, all four modules, notifications + PDFs) on the mock
layer. Phase 7 (Firebase wiring) is the remaining work.
