# SLV Auto Consultant — Flutter App Build Specification

> **For:** Claude Code
> **Project:** SLV Auto Consultant Internal Operations App
> **Platform:** Flutter (Android + iOS), responsive for phone and tablet
> **Location:** Bengaluru, India
> **Domain:** Auto-rickshaw resale, loan management, vehicle rental collection

---

## 0. How to use this spec

This document defines the complete app. Build in this order to minimize rework:

1. Project setup + design system (Section 3)
2. Authentication + login (Section 4)
3. Universal role-gate pattern (Section 5) — implement once as a reusable pattern
4. Module 1: User Management (Section 6)
5. Module 2: Auto Resale (Section 7)
6. Module 4: Vehicle Rental (Section 9) — reuses Customer + Vehicle entities
7. Module 3: Loan Management (Section 8) — *note: client will tweak this module's rules; keep flexible*
8. Shared infrastructure: reminders, PDFs, notifications (Sections 11–12)

All four modules share the same role-gate pattern (Section 5). Implement it once and reuse everywhere.

---

## 1. Business context

**The business:** SLV Auto Consultant runs an auto-rickshaw business in Bengaluru. The owner sells new and used auto-rickshaws, gives loans to customers, and rents out vehicles on daily/weekly/monthly terms.

**Who uses the app:**
- **Super Admin** — the business owner. Full power, no approvals needed for own actions.
- **Admin** — staff member(s) helping with day-to-day work. Can do everything but every action requires Super Admin's confirmation.
- **Customer / Renter / Borrower** — does NOT log in. Receives notifications (reminders, invoices, receipts) via WhatsApp and SMS only.

**What the app does:**
- Track auto-rickshaw inventory (vehicles to sell, vehicles to rent)
- Manage customer/renter/borrower profiles with documents
- Track sales, loans, and rentals end-to-end
- Send automated reminders for payments and service due dates
- Calculate penalties automatically when payments are late
- Generate invoices, receipts, loan agreements as PDFs
- Maintain full audit trail of every action

---

## 2. Tech stack

- **Flutter:** latest stable (3.x or higher), Dart 3
- **State management:** `flutter_riverpod`
- **Routing:** `go_router`
- **Backend:** Firebase
  - Firestore for data
  - Firebase Auth for authentication
  - Cloud Functions (Node) for cron jobs (reminders, penalty accrual)
  - Firebase Cloud Messaging (FCM) for in-app notifications
  - Firebase Storage for documents and photos
- **WhatsApp + SMS:** MSG91 or Gupshup (cloud function calls their API)
- **PDF generation:** `pdf` + `printing` packages
- **Image handling:** `image_picker`, `image_cropper`, `cached_network_image`
- **Local cache:** `hive` for offline support
- **Date/time/i18n:** `intl`, `timezone`
- **Phone number:** `intl_phone_field`

**Project structure:**

```
lib/
  core/
    constants/
      colors.dart
      typography.dart
      spacing.dart
    theme/
      app_theme.dart
    utils/
      formatters.dart
      validators.dart
    widgets/
      app_button.dart
      app_card.dart
      app_input.dart
      status_badge.dart
      pending_badge.dart
      empty_state.dart
      responsive_scaffold.dart
  features/
    auth/
    user_management/
    auto_resale/
    loans/
    rentals/
  shared/
    models/
    providers/
    services/
      firestore_service.dart
      notification_service.dart
      pdf_service.dart
      messaging_service.dart
  main.dart
```

---

## 3. Design system

### 3.1 Brand colors

Use exactly these hex values. Define once in `core/constants/colors.dart`.

```dart
class AppColors {
  // Anchor colors (from SLV logo)
  static const Color primaryNavy = Color(0xFF1B2A4E);
  static const Color appBackground = Color(0xFFE0DDD3);

  // Surfaces
  static const Color cardSurface = Color(0xFFF5F3EE);
  static const Color cardSurfaceElevated = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF0F1A33);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Accent
  static const Color accentGold = Color(0xFFD4A848);

  // Status
  static const Color success = Color(0xFF1F7A4D);
  static const Color warning = Color(0xFFC8852A);
  static const Color danger = Color(0xFF9E2A2A);

  // Status tints (for badges and banners)
  static const Color successTint = Color(0xFFE7F1EA);
  static const Color warningTint = Color(0xFFF7EDD9);
  static const Color dangerTint = Color(0xFFF4DDDD);

  // Borders
  static const Color borderLight = Color(0x1F0F1A33);
  static const Color borderMedium = Color(0x3D0F1A33);
}
```

### 3.2 Color usage rules

| Element | Color |
|---|---|
| Screen background | `appBackground` `#E0DDD3` |
| Cards, list items, inputs, dialogs | `cardSurface` `#F5F3EE` |
| App bar | `primaryNavy` `#1B2A4E` |
| Bottom nav / side rail | `primaryNavy` |
| Primary button (filled) | `primaryNavy` bg + white text |
| Secondary button (outline) | `cardSurface` bg + `primaryNavy` border and text |
| Tertiary action / FAB | `accentGold` bg + `textPrimary` text |
| Body text on light bg | `textPrimary` |
| Muted/caption text | `textSecondary` |
| Text on navy bg | white (`textOnDark`) |
| Success badge/banner | `successTint` bg + `success` text |
| Warning/pending badge | `warningTint` bg + `warning` text |
| Danger/overdue badge | `dangerTint` bg + `danger` text |
| Borders/dividers | `borderLight` |

**Rule of thumb:** background navy → white text. Background light → navy text.

### 3.3 Typography

Use `Inter` font (or platform default if Inter not bundled). Define in `core/constants/typography.dart`.

| Style | Size | Weight | Use |
|---|---|---|---|
| Display | 28 | 700 | Splash, login title |
| H1 | 24 | 600 | Screen titles |
| H2 | 20 | 600 | Section headers |
| H3 | 18 | 500 | Card titles |
| Body | 16 | 400 | Default body text |
| Body emphasis | 16 | 500 | Important labels |
| Caption | 14 | 400 | Secondary text |
| Small | 13 | 500 | Badges, chips |
| Tiny | 11 | 500 | Timestamps, hints |

Always **sentence case**. Never ALL CAPS.

### 3.4 Spacing

Base unit = 4dp. Use multiples: 4, 8, 12, 16, 20, 24, 32, 40, 48.

- Screen horizontal padding: 16dp on phone, 24dp on tablet
- Card padding: 16dp
- Vertical spacing between sections: 24dp
- Vertical spacing between cards in a list: 8dp
- Touch target minimum: 48dp

### 3.5 Corner radius

- Cards: 12dp
- Buttons: 8dp
- Inputs: 8dp
- Badges/chips: 6dp (or full radius for pill-shaped status indicators)
- Avatar: 50% (full circle)

### 3.6 Reusable widgets

Build all of these in `core/widgets/`.

**AppButton** with variants:
- `AppButton.primary(label, onPressed)` → navy bg, white text
- `AppButton.secondary(label, onPressed)` → cream bg, navy border and text
- `AppButton.tertiary(label, onPressed)` → gold bg, dark text
- `AppButton.danger(label, onPressed)` → red text on cream bg
- Height 48dp, full width by default, optional `compact` mode for inline use

**AppCard:**
- Background: `cardSurface`, padding 16dp, corner radius 12dp
- Optional 0.5dp border in `borderLight`
- Optional leading avatar, trailing action

**AppInput:**
- Background: `cardSurface`
- Border: 1dp `borderLight`, focuses to `primaryNavy`
- Height: 48dp (single line), auto-grows for multi-line
- Label above, helper text below, error state in danger color

**StatusBadge:**
- Variants: success, warning, danger, neutral
- Used for: vehicle status, sale status, loan status, rental status

**PendingBadge:**
- Amber tint background, amber text, label "Pending"
- Shown on admin's view to mark items awaiting Super Admin confirmation

**EmptyState:**
- Centered icon (Tabler outline icons via icon font)
- Title + subtitle + optional CTA button

**ResponsiveScaffold:**
- Phone (<600dp): bottom nav bar with up to 4 tabs
- Tablet (≥600dp): side navigation rail
- Top app bar with: page title, search icon, notifications bell (with unread count badge), profile avatar menu

### 3.7 Responsive rules

**Breakpoints:**
- Phone: width < 600dp
- Tablet: width ≥ 600dp
- Large tablet: width ≥ 900dp

**Layout shifts:**
- Navigation: bottom bar (phone) → side rail compact (tablet) → side rail expanded (large tablet)
- Lists: single column (phone) → two columns (tablet for inventory/customer lists) → three columns (large tablet)
- Forms: full width (phone) → max 500dp centered (tablet)
- Detail screens: full screen (phone) → master-detail split view (tablet) with list on left, detail on right

Touch targets never below 48dp on either device.

---

## 4. Authentication & Login

### 4.1 Splash screen
- Full screen on `appBackground`
- SLV logo centered (140dp)
- Below logo: "SLV Auto Consultant" in `primaryNavy`, 24px, weight 600
- Auto-routes after 1.5s:
  - Authenticated user → role-based dashboard
  - Not authenticated → login screen

### 4.2 Login screen layout
- Background: `appBackground`
- Logo at top (100dp), 48dp below status bar
- Card (`cardSurface`) in middle of screen, padded 24dp, corner radius 12dp:
  - Title "Welcome back" (H2, primaryNavy)
  - Subtitle "Sign in to continue" (caption, textSecondary)
  - 24dp gap
  - AppInput: "Mobile number" (+91 prefix, 10-digit validation)
  - 12dp gap
  - AppInput: "Password" (with show/hide toggle)
  - 8dp gap
  - "Forgot password?" link (right-aligned, primaryNavy, caption)
  - 24dp gap
  - AppButton.primary "Sign in" (full width)
  - 16dp gap
  - Centered caption: "Don't have an account? Contact Super Admin"
- Footer: "v1.0.0" (tiny, textSecondary, centered at bottom)

### 4.3 Login flow
1. User enters mobile + password → taps Sign in
2. Loading state on button (spinner inside)
3. On success → route to dashboard based on role:
   - Super Admin → SuperAdminDashboard
   - Admin → AdminDashboard
4. On error → inline error below form: "Wrong mobile or password"
5. After 5 failed attempts in 15 minutes → lock out 15 minutes

### 4.4 First-time login (newly created admin)
After Super Admin creates an admin, the admin gets credentials via SMS. On first login:
1. Force change password (current + new + confirm)
2. Force profile completion:
   - Upload selfie (camera)
   - Upload Aadhaar (front + back)
   - Address (multi-line text)
   - Signature (draw on screen or upload image)
3. Submit → profile status becomes "Pending Super Admin Verification"
4. App shows "Waiting for verification" screen until SA approves
5. Once approved, admin enters normal app flow

### 4.5 Forgot password
- Enter mobile → OTP sent via SMS
- Enter OTP → set new password
- Done

### 4.6 Session
- Firebase ID token, auto-refresh
- Auto-logout after 30 days of inactivity
- Biometric login (fingerprint/face) opt-in from second login onwards
- Logout button in profile menu (top right)

---

## 5. Universal role-gate pattern

This is **the most important pattern in the app**. Implement once, reuse everywhere.

### 5.1 The rule

Every state-changing action (create, update, delete, payment record, status change) follows this rule:

- **If actor.role == 'super_admin'** → action takes effect immediately. Status = `active`.
- **If actor.role == 'admin'** → action is created with status = `pending_confirmation`. Super Admin must explicitly confirm before it takes effect.

### 5.2 Data model — every gated entity has these fields

```dart
abstract class GatedEntity {
  String id;
  String createdBy;
  DateTime createdAt;

  String status; // 'pending_confirmation' | 'active' | 'rejected'
  String? confirmedBy;
  DateTime? confirmedAt;
  String? rejectionReason;
}
```

### 5.3 Actions that pass through the gate

In all four modules:
- Create / update customer
- Create / update vehicle
- Create / update / cancel sale (Auto Resale)
- Create / update / cancel / foreclose loan (Loans)
- Create / update / end rental assignment (Rentals)
- Record any payment
- Mark service done
- Close any record
- Waive any penalty

### 5.4 Notification triggers

When an admin creates/updates → FCM notification to Super Admin:
> "Ravi added customer Suresh — Review"

Notification deep-links to the review screen.

When Super Admin confirms → notify the originating admin:
> "Vijay confirmed your customer addition"

When Super Admin rejects → notify with reason:
> "Vijay rejected the sale: Price below cost"

### 5.5 Super Admin's review queue (Dashboard)

The `SuperAdminDashboard` shows:
- Summary cards at top: counts of pending items by type
- List of all pending items sorted by oldest first
- Each list item: actor, action description, summary, timestamp, [Review] button
- Tapping [Review] → opens full entity detail with [Confirm] and [Reject with reason] buttons

### 5.6 Admin's view

When admin creates something:
- Immediate UI feedback: "Submitted. Awaiting Super Admin confirmation."
- The new record appears in their list with a `PendingBadge`
- Admin cannot edit further until SA acts (view-only)
- When SA confirms → badge disappears, record becomes editable
- When SA rejects → red banner with reason; admin can fix and re-submit

### 5.7 Edge cases

- If admin tries to use a customer that is `pending_confirmation` (in a sale, loan, or rental), block it with: "This customer is not yet verified. Wait for Super Admin confirmation."
- If admin tries to record payment against a sale/loan/rental that is `pending_confirmation`, block it.
- If Super Admin deletes an admin's pending item, notify the admin: "Your action was deleted."
- Super Admin can override at any time (force-confirm or force-reject) — log the override in audit trail.

---

## 6. Module 1 — User Management (Super Admin only)

### 6.1 Access
- Only Super Admin sees this module in navigation
- Admin role does NOT see User Management at all

### 6.2 Screens

**6.2.1 User list screen**
- Search bar at top (filter by name or mobile)
- "+ New admin" FAB (gold accent)
- List of admins, each card shows:
  - Avatar + name + mobile
  - Module access chips (Auto Resale / Loans / Rentals)
  - Status: Active | Pending verification | Suspended
  - Actions menu (three-dot): Edit, Suspend, Delete

**6.2.2 Create / edit admin screen**
- Name (text input)
- Mobile (10-digit with +91 prefix)
- Email (optional)
- Temporary password (auto-generated 8-char, user must change on first login)
- Module access checkboxes: Auto Resale / Loans / Rentals (multi-select)
- Save button

Saving creates the admin record and sends SMS with login credentials.

**6.2.3 Admin detail screen**
- Profile: photo, name, mobile, email, joined date
- Module access (editable)
- Activity log: all actions this admin has taken, with timestamps
- "Suspend" button (soft-disable login)
- "Delete" button (hard delete — confirms twice)

### 6.3 Admin verification (post first login)
- After a newly created admin completes their profile, it appears in Super Admin's pending queue
- Super Admin reviews: photo, Aadhaar, address, signature
- Approves → admin becomes Active
- Rejects → admin must re-submit profile

---

## 7. Module 2 — Auto Resale

### 7.1 Entities

**Vehicle:**
```dart
class Vehicle extends GatedEntity {
  String registrationNumber;
  String chassisNumber;
  String engineNumber;
  String make;
  String model;
  int year;
  String color;
  String type; // 'first_hand' | 'second_hand'
  Map<String, DocumentRef> documents; // rc, permit, fitness, insurance, puc — each with url + expiry date
  List<String> photoUrls; // min 4
  int askingPrice;
  int? costPrice; // only visible to Super Admin
  String inventoryStatus; // 'available' | 'reserved' | 'sold' | 'on_rent'
  DateTime addedAt; // for ageing
}
```

**Customer:**
```dart
class Customer extends GatedEntity {
  String name;
  String mobile;
  String address;
  Map<String, DocumentRef> documents; // aadhaar, pan, drivingLicense, photo
  DateTime? verifiedAt; // set when SA confirms
}
```

**Sale:**
```dart
class Sale extends GatedEntity {
  String customerId;
  String vehicleId;
  int salePrice;
  String paymentMode; // 'full_payment' | 'advance_balance'
  // For full payment:
  int? paymentReceived;
  DateTime? paymentDate;
  String? paymentChannel; // 'cash' | 'upi' | 'bank'
  // For advance + balance:
  int? advanceAmount;
  DateTime? advanceDate;
  int? balanceAmount;
  DateTime? balanceDueDate;
  String? penaltyType; // 'flat_per_day' | 'percent_per_day'
  num? penaltyValue;
  int balancePaidAmount; // running total
  int penaltyAccrued; // calculated daily by cron
  // State:
  String saleStatus; // 'active' | 'closed' | 'cancelled' | 'rejected'
  String? invoiceUrl; // PDF
}
```

**PaymentRecord:**
```dart
class PaymentRecord extends GatedEntity {
  String parentType; // 'sale' | 'loan' | 'rental'
  String parentId;
  int amount;
  String mode; // 'cash' | 'upi' | 'bank'
  DateTime paymentDate;
  // Auto-allocated when system processes:
  int allocatedToPenalty;
  int allocatedToPrincipal;
  String? receiptUrl;
  String? notes;
}
```

### 7.2 Screens

**7.2.1 Auto Resale dashboard**
- Top stats row: Available vehicles count | Active sales count | Pending balance total | Today's collection
- Pending balance alerts: top 5 sales with overdue payments
- "+ New sale" FAB
- Quick links: Vehicles, Customers, Sales

**7.2.2 Vehicle list**
- Filter chips: All | Available | Sold | On Rent
- Search by registration number / chassis
- "+ Add vehicle" FAB
- Each card: photo thumb, registration, make/model, year, status badge, asking price

**7.2.3 Add/edit vehicle**
- Type radio (first/second hand)
- Make, model, year inputs
- Color, registration number, chassis number, engine number
- Asking price
- Cost price (Super Admin only)
- Document uploads (one section per: RC, permit, fitness, insurance, PUC) with file picker + expiry date
- Photo uploads (camera + gallery, min 4)
- Save → gate

**7.2.4 Vehicle detail**
- Photo carousel at top
- Tabs: Details | Documents | History
- Actions based on status:
  - Available → "Sell to customer" or "Rent to user"
  - Sold → "View sale"
  - On rent → "View rental"

**7.2.5 Customer list**
- Filter: All | Verified | Pending
- Search by name / mobile
- "+ Add customer" FAB
- Each card: avatar, name, mobile, verification status

**7.2.6 Add/edit customer**
- Name, mobile (10-digit), address (multi-line)
- Document uploads: Aadhaar (front+back), PAN, Driving License, Photo (camera capture preferred)
- Save → gate

**7.2.7 Customer detail**
- Profile photo + name + mobile + address
- Documents (each with view button)
- History: all sales, loans, rentals this customer has participated in

**7.2.8 Sales list**
- Filter: All | Active | Closed | Cancelled | Rejected
- Sort: by due date | by created date | by amount
- Search by customer name or vehicle registration
- Each card: customer name, vehicle, amount, status badge, due date if applicable

**7.2.9 Create sale (wizard)**
- Step 1: Pick customer (only verified customers shown). "+ New customer" inline.
- Step 2: Pick vehicle (only available vehicles shown).
- Step 3: Pricing
  - Sale price input
  - Payment mode toggle: Full payment | Advance + balance
  - If full: amount received, mode, date
  - If advance+balance: advance amount, balance auto-calculated, due date, penalty type, penalty value
- Step 4: Review and submit
- Save → gate

**7.2.10 Sale detail**
- Customer info card + Vehicle info card
- Payment summary
- For ongoing sales: countdown to due date, current penalty
- Payment history list
- "+ Record payment" button (advance+balance sales)
- "Invoice" button → opens PDF
- More menu: Cancel sale, Print invoice

**7.2.11 Record payment**
- Amount input
- Mode radio: cash / UPI / bank transfer
- Date picker (default today)
- Optional notes
- Save → gate
- Preview shows auto-allocation: "₹X to penalty, ₹Y to balance"

### 7.3 Scenarios

1. **Super Admin direct full-payment sale** — instant, no gates. Vehicle marked Sold, invoice sent.
2. **Admin advance+balance sale** — 4 gates total: customer (if new), vehicle (if new), sale, each payment.
3. **Late payment with penalty** — auto-applied daily by cron (Section 11.3).
4. **Partial late payment** — system splits: penalty first, balance second.
5. **Sale cancellation** — admin requests, super admin approves, refund recorded, vehicle returns to Available.
6. **Sale rejection at gate** — super admin rejects with reason, admin can fix and re-submit.
7. **Repeat customer** — search by mobile, reuse verified profile (re-verify if docs expired).

### 7.4 Reminders for Auto Resale
- T-3 days before balance due → reminder to customer (WhatsApp+SMS) + Super Admin + Admin (in-app)
- T-0 (due date) → reminder to all parties
- T+1, T+2, ... → daily reminder + penalty accrual

---

## 8. Module 3 — Loan Management (proposed — client to adjust)

> **Note for client:** This module's flows are my proposal based on standard auto-loan practices in India. Review and tell Claude Code to adjust specifics (interest formula, penalty rules, EMI calculation method) per your business preference.

### 8.1 Business context (assumed)
The owner gives loans to:
- Auto-rickshaw drivers needing capital for vehicle purchase, repair, family needs
- Existing customers from Auto Resale or Rental modules
- Walk-in borrowers (new customers)

### 8.2 Entities

**Loan:**
```dart
class Loan extends GatedEntity {
  String customerId;
  int principal;
  String interestType; // 'flat_rate' (default) | 'reducing_balance'
  double interestRate; // annual %
  int tenureMonths;
  DateTime disbursementDate;
  DateTime firstEmiDueDate; // typically 1 month after disbursement
  int emiAmount; // calculated
  List<EmiRecord> emiSchedule; // one per month
  String penaltyType; // 'flat_per_day' | 'percent_per_day'
  num penaltyValue;
  int totalPaid; // running
  int balanceOutstanding; // calculated
  String loanStatus; // 'draft' | 'active' | 'overdue' | 'closed' | 'foreclosed' | 'defaulted' | 'rejected'
  Collateral? collateral;
  String? guarantorCustomerId;
  String? agreementUrl; // PDF
}
```

**EmiRecord (one per month):**
```dart
class EmiRecord {
  String id;
  String loanId;
  int sequenceNumber; // 1, 2, 3 ...
  DateTime dueDate;
  int amountDue; // = loan.emiAmount
  int amountPaid; // running
  int penaltyAccrued;
  String status; // 'upcoming' | 'due_soon' | 'paid' | 'overdue' | 'partial'
}
```

### 8.3 EMI calculation (flat rate, default)

```
totalInterest = principal × (rate / 100) × (tenureMonths / 12)
totalPayable = principal + totalInterest
emiAmount = totalPayable / tenureMonths
```

Example: ₹50,000 at 12% flat for 12 months
- Total interest = 50,000 × 0.12 × 1 = ₹6,000
- Total payable = ₹56,000
- EMI = ₹4,666.67/month

Round EMI to the nearest rupee; adjust the final EMI to absorb any rounding difference.

### 8.4 The "5-day rule" interpretation
- **5 days before EMI due date** → first friendly reminder (WhatsApp+SMS) to borrower + in-app to SA/Admin
- **On EMI due date** → reminder again
- **1 day after due date** if unpaid → urgent reminder + penalty begins accumulating per loan's penalty rule
- Daily reminders continue until EMI cleared

*(Client may want to interpret "5-day rule" differently — confirm with them before locking.)*

### 8.5 Penalty rules
Owner sets at loan creation:
- Flat: ₹X per day late (e.g., ₹50/day)
- OR Percentage: X% of EMI amount per day late (e.g., 0.1% of EMI per day)

System auto-calculates daily via cron. Super Admin can waive penalty on a specific EMI (admin cannot).

### 8.6 Documents required
- Customer KYC (Aadhaar, PAN, DL, photo) — reused from Customer entity
- Address proof (could be Aadhaar)
- Income proof (optional)
- Loan agreement PDF (auto-generated from template, includes all terms)
- For vehicle-collateral loans: vehicle RC, hypothecation note
- Guarantor KYC if applicable

### 8.7 Screens

**8.7.1 Loans dashboard**
- Stats: Active loans count | Total disbursed | Total outstanding | Overdue EMIs count
- Overdue alerts: top 5 most overdue EMIs
- "+ New loan" FAB

**8.7.2 Loan list**
- Filter: All | Active | Overdue | Closed | Foreclosed | Draft
- Search by customer name / mobile
- Each card: customer, principal, balance outstanding, next EMI due, status

**8.7.3 New loan screen (wizard)**
- Step 1: Pick or create customer
- Step 2: Loan terms — principal, rate, tenure, interest type
- Step 3: Penalty rule (flat ₹/day or % of EMI)
- Step 4: Collateral (optional toggle, then details)
- Step 5: Guarantor (optional toggle)
- Step 6: Review — shows calculated EMI, total interest, total payable, full schedule preview
- Submit → gate
- On SA approval → status `active`, disbursement marked, agreement PDF generated and sent

**8.7.4 Loan detail**
- Top card: customer + principal + EMI + status badge
- Stats: Paid so far | Balance outstanding | Next EMI due
- EMI schedule list — each EMI shows: number, due date, amount, status, [Record payment] button
- Penalty section: total penalty accrued, breakdown per EMI
- Actions menu: Foreclose loan, Waive penalty (SA only), Print agreement

**8.7.5 Record EMI payment**
- Amount input
- Mode radio
- Date picker (default today)
- Allocation preview: "₹X to penalty, ₹Y to EMI"
- Save → gate

**8.7.6 Foreclose loan**
- Show current outstanding (principal + accrued interest till today)
- Optional foreclosure charge field (% or fixed amount)
- Total foreclosure amount calculated
- Customer pays → record → loan status becomes `foreclosed` → NOC PDF generated and sent

### 8.8 Scenarios

1. **Standard loan disbursement (SA direct)** — instant
2. **Admin-initiated loan** — gate for approval
3. **EMI on-time payment** — record → gate (if admin) → applied → EMI marked paid → if last EMI, loan closes
4. **Late EMI** — cron starts penalty accrual day after due date
5. **Partial EMI payment** — recorded, applied to penalty first, then EMI; status becomes `partial` until cleared
6. **Foreclosure** — customer requests early closure, total calculated, paid, NOC issued
7. **Default** — no payment for 3 consecutive months → status `defaulted` → flagged for SA action
8. **Penalty waiver** — SA only, reason logged in audit trail

### 8.9 Reminders for Loans
- T-5 days before EMI due → first reminder (WhatsApp+SMS)
- T-0 → reminder
- T+1 onwards (until paid) → daily reminder + penalty accrual

---

## 9. Module 4 — Vehicle Rental Collection

### 9.1 Entities

**Renter** — same entity as Customer (shared customer DB).

**Rental:**
```dart
class Rental extends GatedEntity {
  String customerId;
  String vehicleId;
  DateTime assignedDate;
  DateTime startDate;
  DateTime? endDate; // null = open-ended
  String rentalBasis; // 'daily' | 'weekly' | 'monthly'
  int rentAmount; // per the basis (e.g., ₹2000/week)
  int advanceAmount; // refundable security deposit
  String penaltyType;
  num penaltyValue;
  String rentalStatus; // 'active' | 'ended' | 'cancelled' | 'rejected'
  int totalCollected; // running
  DateTime? nextCollectionDue; // calculated based on basis and last collection
}
```

**ServiceRecord (lives on Vehicle):**
```dart
class ServiceRecord extends GatedEntity {
  String vehicleId;
  DateTime serviceDate;
  String? servicedBy; // vendor/garage name
  int cost;
  DateTime nextServiceDueDate; // auto-set: serviceDate + N months, default 3
  String? notes;
}
```

Each vehicle has a `nextServiceDueDate` field (denormalized from the most recent service record) so it can show in lists and trigger reminders without joins.

### 9.2 Screens

**9.2.1 Rentals dashboard**
- Stats: Active rentals | Today's collections | Pending collections | Vehicles available for rent
- Today's collection list: who owes what today
- Service due alerts: vehicles needing service in next 7 days
- "+ Assign vehicle" FAB

**9.2.2 Rental list**
- Filter: All | Active | Ended | Pending
- Search by renter name / vehicle registration
- Each card: vehicle, renter, basis (daily/weekly/monthly), rent, next due

**9.2.3 Assign vehicle (new rental)**
- Step 1: Pick or create renter
- Step 2: Pick available vehicle
- Step 3: Rental terms — basis radio (daily/weekly/monthly), rent amount, advance, start date, end date (optional)
- Step 4: Penalty rule
- Step 5: Review and submit
- Save → gate
- On approval → vehicle status → `on_rent`, first reminder scheduled

**9.2.4 Rental detail**
- Renter info + vehicle info
- Rental terms summary
- Collection history list
- Next collection due: amount + date + days until due
- "+ Record collection" button
- "End rental" button

**9.2.5 Record collection**
- Amount input (defaults to rent amount)
- Mode radio
- Date picker
- Allocate to current cycle / previous outstanding (auto-suggested)
- Save → gate

**9.2.6 End rental**
- Display: total collected, advance held, any pending dues, condition assessment notes (free text)
- Final settlement input: deduct any damages from advance, refund balance
- On submit → vehicle status flips to `available`
- Final settlement receipt PDF generated and sent

**9.2.7 Service tracking (within vehicle detail)**
- Service history list (most recent on top)
- Next service due date shown prominently with countdown
- "+ Log service" button:
  - Service date, cost, vendor (optional), notes
  - Save → gate → on approval, `nextServiceDueDate` auto-set = serviceDate + 3 months (configurable per vehicle)

### 9.3 Scenarios

1. **SA-direct vehicle assignment** — instant
2. **Admin-initiated rental** — gate
3. **Weekly/monthly collection on schedule** — collect → gate if admin records
4. **Late collection** — penalty accrues, daily reminders to renter
5. **Mark service done** — gate; next service date auto-updates
6. **End rental, vehicle returns** — final settlement, vehicle becomes Available, can be reassigned
7. **Reassign vehicle** — same vehicle, new renter, fresh rental record

### 9.4 Reminders for Rentals

**Collection reminders depend on rental basis:**
- Daily basis: reminder each morning of due day
- Weekly basis: 1 day before + on due day + daily after if overdue
- Monthly basis: 3 days before + on due day + daily after if overdue

**Service due reminders (in-app to SA/Admin only, not renter):**
- 7 days before next service date → first reminder
- On due date → reminder
- Overdue → daily reminder until service logged

---

## 10. Shared data models

See Sections 7.1, 8.2, 9.1 — collect all model classes into `lib/shared/models/`. All entities extend `GatedEntity` (Section 5.2).

### AppUser entity

```dart
class AppUser {
  String id;
  String name;
  String mobile;
  String? email;
  String role; // 'super_admin' | 'admin'
  List<String> modules; // ['auto_resale', 'loans', 'rentals']
  String? photoUrl;
  String? aadhaarUrl;
  String? signatureUrl;
  String accountStatus; // 'pending_profile' | 'pending_verification' | 'active' | 'suspended'
  DateTime createdAt;
  String createdBy; // super admin's id
}
```

### AppNotification entity

```dart
class AppNotification {
  String id;
  String userId; // recipient
  String type; // 'pending_review' | 'confirmation' | 'rejection' | 'reminder' | 'system'
  String title;
  String body;
  Map<String, dynamic> data; // deep link payload (entity type + id)
  bool read;
  DateTime createdAt;
}
```

### AuditLog entity (for compliance)

```dart
class AuditLog {
  String id;
  String entityType; // 'sale' | 'loan' | 'rental' | 'customer' | etc.
  String entityId;
  String action; // 'created' | 'updated' | 'confirmed' | 'rejected' | 'payment_recorded' | etc.
  String actorId;
  String actorRole;
  DateTime timestamp;
  Map<String, dynamic>? changes; // diff of before/after for updates
  String? reason; // for rejections, waivers, cancellations
}
```

---

## 11. Reminders & notifications

### 11.1 Channels
- **WhatsApp** — primary for customer-facing reminders (via MSG91 / Gupshup API in cloud function)
- **SMS** — fallback for customer-facing reminders (same provider)
- **In-app (FCM)** — for Super Admin and Admin only

### 11.2 WhatsApp templates (need pre-approval from Meta)

Pre-define and submit for approval:
- `payment_reminder` — "Namaste {name}, your payment of ₹{amount} is due on {date}. Please pay to avoid penalty. — SLV Auto Consultant"
- `payment_overdue` — "Reminder: your payment of ₹{amount} was due on {date}. Penalty of ₹{penalty} has been added. Please pay soon. — SLV Auto Consultant"
- `payment_received` — "Thank you {name}! We received ₹{amount} on {date}. Receipt: {pdfLink}"
- `invoice_generated` — "Hello {name}, your invoice for {item} is ready: {pdfLink}"
- `loan_disbursed` — "Your loan of ₹{amount} has been disbursed. Agreement: {pdfLink}"
- `loan_closed` — "Congratulations {name}! Your loan is fully paid. NOC: {pdfLink}"

*Service due reminders are in-app only — never sent to renters.*

### 11.3 Cron jobs (Firebase Cloud Functions)

**Run daily at 9:00 AM IST:**
- For each active sale with pending balance: check if today is T-3, T-0, or past T-0. If past due, accrue penalty per the sale's rule. Send reminders per schedule.
- For each active loan: check each EMI in `due_soon` or `overdue` status. Accrue penalty if applicable. Send reminders.
- For each active rental: check today against `nextCollectionDue`. Send reminder. Accrue penalty if overdue.
- For each vehicle in inventory or on rent: check `nextServiceDueDate`. If within 7 days, send in-app reminder to SA + Admin.

**Run hourly:**
- Refresh notifications for any pending-confirmation items older than 1 hour that haven't been acknowledged by Super Admin.

---

## 12. PDF generation

### 12.1 PDFs to generate
1. Auto Resale **invoice** — on sale activation
2. Auto Resale **receipt** — on each payment confirmation
3. Loan **agreement** — on loan approval
4. Loan EMI **receipt** — on each EMI payment confirmation
5. Loan **NOC** (No Objection Certificate) — on loan closure / foreclosure
6. Rental **agreement** — on rental assignment
7. Rental **receipt** — on each collection confirmation
8. Rental **final settlement** — on rental end
9. Customer **statement** — on demand, full history

### 12.2 PDF design
- A4 size
- SLV logo at top-left
- Document title centered, primary navy
- Business details (name, address, GST if applicable) below logo
- Customer details
- Transaction details in a table
- Total / amount in larger size, navy
- Terms & conditions (small print at bottom for agreements)
- Authorized signature line (Super Admin's stored signature image)
- Footer: "Generated on {date} via SLV Auto app"

Use the `pdf` package. Generate on-device, upload to Firebase Storage, share URL via WhatsApp template.

---

## 13. Edge cases & error states

Build these UI states for every list and detail screen:

- **Empty state** — no data yet. Show icon + CTA: "No customers yet. Add your first customer." with "+ Add customer" button.
- **Loading state** — skeleton placeholders for cards.
- **Error state** — failed to load. Show "Couldn't load. Try again." with retry button.
- **No internet** — banner at top: "You're offline. Showing cached data." Continue showing cached data; queue any actions taken.
- **Action pending sync** — small clock icon on items created/edited offline that haven't yet synced.

---

## 14. Build sequence (concrete checklist for Claude Code)

Execute in order:

1. [ ] Initialize Flutter project, set up Firebase (Firestore, Auth, Functions, FCM, Storage)
2. [ ] Add packages: riverpod, go_router, pdf, printing, image_picker, intl, hive, intl_phone_field
3. [ ] Define `AppColors`, `AppTypography`, `AppSpacing` constants
4. [ ] Build `AppTheme` light theme using the design system
5. [ ] Build reusable widgets: `AppButton`, `AppCard`, `AppInput`, `StatusBadge`, `PendingBadge`, `EmptyState`
6. [ ] Build `ResponsiveScaffold` with bottom-nav (phone) and side-rail (tablet) variants
7. [ ] Implement splash + login + forgot-password screens
8. [ ] Implement first-time-login profile completion flow
9. [ ] Build `GatedEntity` base class + role-gate provider (Section 5)
10. [ ] Build `SuperAdminDashboard` with pending review queue
11. [ ] Build `AdminDashboard` with awaiting-confirmation view and reminders feed
12. [ ] Build User Management module (Section 6)
13. [ ] Build Customer + Vehicle entities (shared between Auto Resale and Rentals)
14. [ ] Build Auto Resale module (Section 7) end-to-end
15. [ ] Build Vehicle Rental module (Section 9) end-to-end
16. [ ] Build Loan Management module (Section 8) end-to-end
17. [ ] Build cron jobs in Cloud Functions: daily reminders + penalty accrual (Section 11.3)
18. [ ] Build PDF templates and `pdf_service.dart` (Section 12)
19. [ ] Integrate MSG91 / Gupshup for WhatsApp + SMS
20. [ ] Add empty states, error states, offline indicators
21. [ ] Test on phone (small + medium) and tablet (10-inch)
22. [ ] Audit log review — make sure every state change writes to AuditLog

---

## 15. Notes for Claude Code

- Always check the actor's role before any state-changing action — see Section 5
- Implement the gate pattern as a reusable mixin/wrapper, not copy-pasted per module
- Currency: format as `₹1,80,000` using `intl` package's `NumberFormat.currency(locale: 'en_IN', symbol: '₹')`
- Dates: display as `28 Jun 2026` (day month year). In lists, use relative time ("2 hours ago", "yesterday", "3 days ago"). Use `timeago` package.
- Time zone: lock to `Asia/Kolkata` (IST) via `timezone` package
- Phone numbers: store as `+91XXXXXXXXXX`, display as `+91 XX-XXXX-XXXX`
- Image uploads: compress to max 1200px on longest side, JPEG quality 80
- All searches must work offline (use local Hive cache)
- Every confirmable action writes one row to `AuditLog`
- Never expose Super Admin's `costPrice` field to Admin users — enforce at Firestore security rule level too

---

## 16. Firestore security rules (sketch)

```
// Only Super Admin can read costPrice
match /vehicles/{vehicleId} {
  allow read: if request.auth != null;
  // costPrice field gets filtered out for non-SA via field-level rules or a redacted view
  allow write: if request.auth.token.role == 'super_admin'
    || (request.auth.token.role == 'admin' && request.resource.data.status == 'pending_confirmation');
}

// Only Super Admin can write to /users
match /users/{userId} {
  allow read: if request.auth.token.role == 'super_admin' || request.auth.uid == userId;
  allow write: if request.auth.token.role == 'super_admin';
}

// Only Super Admin can change status from pending_confirmation → active
match /sales/{saleId} {
  allow update: if request.auth.token.role == 'super_admin'
    || (request.auth.token.role == 'admin'
        && resource.data.createdBy == request.auth.uid
        && resource.data.status != 'pending_confirmation');
}
```

(Claude Code: implement full security rules covering every collection per the role-gate pattern.)

---

**End of specification.** Total scope: 4 modules + auth + user management + shared infrastructure. Estimated build time with Claude Code: 2–3 weeks of focused work.

When iterating, build module by module. Validate each module against the scenarios listed in its section before moving to the next.
