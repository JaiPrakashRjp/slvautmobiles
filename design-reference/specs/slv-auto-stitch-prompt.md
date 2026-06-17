# SLV Auto Consultant — Stitch UI Generation Prompt

> Paste this whole document into Stitch, or split it by section if Stitch limits prompt length. The colors, typography, and components are **locked** — Stitch should refine layout, spacing, and polish but never deviate from the design system below.

---

## 1. What this app is

Design a clean, professional business app for **SLV Auto Consultant** — a **three-wheeler rickshaw** (auto-rickshaw) business in Bengaluru, India. The app is used internally by the **business owner (Super Admin)** and **staff (Admin)**. Customers never log in; they receive reminders/invoices via WhatsApp and SMS only.

The app has **three operational modules** plus **user management** plus a **login flow**:

1. **Auto Sale System** — selling new and used three-wheeler rickshaws to customers
2. **Loan Management** — giving loans to customers (skipping detailed flows for now; design module entry point only)
3. **Auto Rental Collection** — renting three-wheelers on daily/weekly/monthly basis
4. **User Management** — Super Admin creates and manages staff Admin accounts

Vibe: trustworthy, calm, utility-focused. Not playful, not flashy.

---

## 2. LOCKED design system (do not deviate)

### 2.1 Colors (use these exact hex values)

```
App background      #E0DDD3   warm light grey, every screen background
Primary navy        #1B2A4E   app bar, side rail, primary buttons, headings, bottom nav
Card surface        #F5F3EE   cream off-white, every card, list item, input
Text primary        #0F1A33   on light backgrounds
Text secondary      #6B7280   captions, hints, secondary labels
Text on dark        #FFFFFF   on navy backgrounds
Accent gold         #D4A848   FABs, active-tab indicator, brand accent
Success green       #1F7A4D   verified, paid, on-time
Success tint        #E7F1EA   success badge background
Warning amber       #C8852A   pending, due soon, overdue
Warning tint        #F7EDD9   warning badge background
Danger red          #9E2A2A   delete icons, rejected
Danger tint         #F4DDDD   danger badge background
```

**Rule of thumb:** background navy → text white. Background light → text navy.

### 2.2 Typography

Font: **Inter** (or platform default if Inter unavailable). **Always sentence case** — never ALL CAPS.

```
Display     28px / 700   splash, login title
H1          24px / 600   screen titles
H2          20px / 600   section headers
H3          18px / 500   card titles
Body        16px / 400   default
Body bold   16px / 500   labels
Caption     14px / 400   subtitles, helper text
Small       13px / 500   badges, chips
Tiny        11px / 500   timestamps
```

### 2.3 Reusable components (use IDENTICALLY across every screen)

- **Top app bar** — navy `#1B2A4E` background, white title, optional left back-arrow or hamburger, right side has search icon + notifications bell with red unread-count dot + circular profile avatar.
- **Bottom navigation (phone)** — navy background, 4 tabs (Sales / Loans / Rentals / Management). Active tab has gold `#D4A848` underline. Management tab is only visible for Super Admin role.
- **Side rail (tablet)** — navy column 56dp wide (icons-only) or 200dp wide (icons + labels). Active item has gold `#D4A848` left-border indicator and slightly lighter navy background.
- **Stat card** — cream `#F5F3EE` background, small grey label on top, large 24px number below. Used in 2×2 grid on phone, 1×4 row on tablet.
- **List item card** — cream `#F5F3EE` background, 12dp corner radius, optional circular icon avatar on left, two lines of content middle (bold title + grey subtitle), action button OR status pill on the right.
- **Primary button** — full-width navy `#1B2A4E` fill, white text, 48dp height, 8dp corner radius.
- **Secondary button** — cream `#F5F3EE` background, navy `#1B2A4E` 1dp border, navy text.
- **FAB** — gold `#D4A848` circle, dark `#0F1A33` icon, bottom-right of the screen.
- **"Pending" badge** — amber-tinted pill (`#F7EDD9` bg + `#C8852A` text + small radius). Shown on any item awaiting Super Admin confirmation.
- **Status badges** — pill-shaped with tinted background (`#E7F1EA`/`#F7EDD9`/`#F4DDDD`) and matching darker text color (`#1F7A4D`/`#C8852A`/`#9E2A2A`).
- **Empty state** — centered Tabler outline icon, "No X yet" title, one-line subtitle, gold CTA button.
- **Loading state** — skeleton placeholder cards (grey rounded rectangles).

### 2.4 Spacing & shape

- Card corners: **12dp**. Button corners: **8dp**. Pill corners: **full radius**.
- Card padding: **16dp**. Screen padding: **16dp** (phone) / **24dp** (tablet).
- Vertical gap between cards in a list: **8dp**.
- Touch target minimum: **48dp**.

---

## 3. THREE-WHEELER RICKSHAW IMAGERY RULE (non-negotiable)

Every time a vehicle appears anywhere (list thumbnail, detail photo, vehicle card, dashboard alert, service tracking — anywhere), use images of **three-wheeler auto-rickshaws** only, specifically Indian-style three-wheeler rickshaws like the **Bajaj RE model**. Three wheels, open-cab design. Yellow body, black-and-yellow body, or green CNG-style body are all acceptable.

**NEVER use cars, four-wheelers, scooters, motorcycles, bikes, or any other vehicle type.** If real photos are unavailable, use stylized illustrations of three-wheeler rickshaws. This is the entire product domain — there is no other vehicle type in this app.

---

## 4. Indian formatting standards (apply everywhere)

- **Currency:** Indian numbering with commas — `₹1,80,000` (one lakh eighty thousand), `₹2,000` (two thousand)
- **Phone numbers:** `+91 98765 43210` (10 digits with country code, space after country code)
- **Dates:** `28 Jun 2026` (day month year, short month name)
- **Indian sample names:** Vijay, Ravi, Suresh, Karthik, Manoj, Imran, Ganesh, Anjali, Lakshmi
- **Vehicle registration:** `KA-01-AB-1234` (Karnataka format)

---

## 5. Phone screens — 375 × 812 px

Generate all 18 phone screens listed below. Each screen must use the locked design system. Sample data shown in each spec is illustrative — keep names and numbers in the Indian style.

### Authentication (5 screens)

**1.1 Splash** — SLV logo centered on `#E0DDD3` background, "SLV Auto Consultant" navy text 24px below, optional three-wheeler rickshaw illustration at bottom.

**1.2 Login** — Logo at top. Card with title "Welcome back" (navy, H2) + subtitle "Sign in to continue" (caption, grey). Mobile-number input with `+91` prefix. Password input with show/hide eye toggle. "Forgot password?" link right-aligned. Full-width navy "Sign in" button. Footer caption: "Don't have an account? Contact Super Admin". Tiny "v1.0.0" at bottom.

**1.3 Forgot password — step 1** — Single mobile-number input. "Send OTP" navy button.

**1.4 Forgot password — step 2** — Six OTP boxes spaced horizontally. "Verify" navy button. "Resend in 30s" greyed link.

**1.5 First-time admin profile** — Change password (current/new/confirm), upload selfie via camera, upload Aadhaar front+back, address text area, signature pad. Sticky bottom "Submit" button. Post-submit: a clock-icon screen titled "Waiting for super admin verification".

### Module entry (1 screen)

**2.1 Choose module** — Navy top bar "Choose Module". Three full-width cards stacked: **Auto Sale System** (with car icon), **Loan Management** (with cash icon), **Auto Rental Collection** (with key icon). Each card has cream background, navy icon, navy bold label, optional one-line tagline.

### Super Admin dashboard (1 screen)

**3.1 Super Admin home** — Top bar showing "Vijay Patel" with shield-check icon and "Super admin" small subtitle. 4 stat cards in 2×2: Available three-wheelers `14`, Active sales `8`, Pending approvals `3` (highlighted in amber-tinted card), Today collected `₹2.75L`. Section heading "Items waiting for your confirmation". 3 list cards each with circular icon, line 1 "Ravi added customer Suresh", line 2 "15 min ago · Aadhaar, DL, photo uploaded", outline "Review" button on right. Gold FAB "+ New sale".

### Admin dashboard (1 screen)

**4.1 Admin home** — Top bar "Ravi Kumar" with user icon, subtitle "Admin · Auto resale". 3 stat cards: Awaiting confirmation `3`, Reminders today `5`, Overdue `1` (red tint). Section "Awaiting super admin confirmation" with 2 cards showing action + amber **Pending** pill on right (read-only, no action button). Section "Reminders today" with one urgent card showing red alert icon and "Call" button. Three quick-action gold FABs at bottom row: "+ Customer", "+ Three-wheeler", "+ Payment".

### Module 1: Auto Sale System (9 screens)

**5.1 Welcome / Auto Sale empty home** — Navy top bar "Auto Sale System". Centered car icon in faded navy, title "Welcome to Auto Sale System", caption "Manage vehicles and customers from the tabs below." Bottom nav with Vehicles | Customers.

**5.2 Vehicles list** — Top bar "Auto Sale System" with right-side gold "+ Create" pill button. Tab pair "Assigned | Unassigned" (Assigned active in navy). Vehicle cards each showing **three-wheeler thumbnail**, "Vehicle no: 1" bold, "Type: First Hand" caption, eye + trash icon buttons. Pagination dots "1 2 3" below. Bottom nav.

**5.3 Add vehicle form** — Navy top bar "Create Vehicle". Fields: Vehicle ID (auto-fill placeholder), Vehicle Number (e.g., KA-01-AB-1234), Purchase Date (calendar picker), Owned Hand dropdown (First Hand / Second Hand), Status row with two pills (verified-green / not-verified-red), Assign to User dropdown. Sticky bottom navy "Create" button.

**5.4 Vehicle detail** — Navy top bar "Vehicle Detail" with edit icon (top-right). **Three-wheeler photo at top** (rounded corners 12dp). Info cards stacked: Vehicle ID, Number, Type, Status (pill), Assigned to (linked to customer). Bottom navy "End / Reassign" button.

**5.5 Customers list** — Top bar "Auto Sale System" with gold "+" button. Tabs "Assigned | Not Assigned". User cards each with avatar circle, "User 1" bold, status pill (Verified green or Not verified red), eye + trash icons. Bottom nav with Vehicles | Customers.

**5.6 Add customer form** — Navy top bar "Create Customer". Two-column row: First Name | Last Name. Two-column row: Age | DOB (calendar picker). Address textarea. Section "Documents" with three outline pills: Aadhaar | DL | PAN (each tappable to upload). Sticky bottom navy "Create" button.

**5.7 Customer detail with assign + payment** — Navy top bar "Customer · Assign". Customer card at top (name, mobile, verified pill). Section "Assign Vehicle" — dropdown to search and pick a three-wheeler. Section "Payment Type" — segmented toggle "Full payment | Installments" (Installments active). If Installments: two-column row Advance `₹5,000` | Per month `₹2,000`. Due date calendar input. Sticky bottom navy "Confirm" button.

**5.8 Installment history (Module 1)** — Navy top bar "User · Installments". User card showing "User no: 1" + "Assigned to Vehicle no: 1". Section "Installments — Reminder & sent" with list rows for each month: amount + green check (paid) or amber "Pending" pill (unpaid). Footer caption: "History of each installment".

**5.9 Vehicle detail with edit** — Same as 5.4 but with the edit icon active state visible.

### Module 3: Auto Rental Collection (8 screens)

**7.1 Rental main — Vehicle tab** — Navy top bar "Auto Rental System" with gold "+" button. Tabs "Rented | Not Rented". Vehicle cards (three-wheeler thumb, registration plate, "Bajaj RE · Three-wheeler" subtitle, eye + trash icons). Bottom nav with Vehicle | Customer.

**7.2 Assign rental form** — Navy top bar "Assign Rental". Customer card (name, verified). Select Vehicle dropdown. **Rental Basis** segmented toggle (Daily | Weekly | Monthly — Weekly highlighted as active). Weekly Rent input (₹ amount with basis suffix). Start Date calendar input. Optional end date toggle. Sticky bottom navy "Confirm Rental" button.

**7.3 Rental weekly history per customer** — Navy top bar "Rental · Weekly". Customer card showing name, vehicle number plate, "Weekly · ₹2,000" caption. Section "Weekly History" with rows: Week 1 ✓, Week 2 ✓, Week 3 [Due amber pill], Week 4 (Upcoming, faded). Bottom navy "+ Record Payment" button.

**7.4 Customer list (Module 3)** — Navy top bar "Auto Rental System" with gold "+" button. Tabs "Active | Inactive". Customer cards (navy left-border accent) each showing name, vehicle number + basis, weekly/monthly rent amount in navy bold, status pill on right (e.g., "Week 3 due" amber, or "On time" green), eye + trash icons. Bottom nav (Customer tab active).

**7.5 Customer → vehicle link** — Navy top bar "Customer Detail" with edit icon. Customer card (name, mobile, verified). Section "Assigned Vehicle" — card with navy left border showing vehicle plate, "Bajaj RE · Three-wheeler", "Weekly · ₹2,000 · Since 03 Jun" caption. Section "Weekly History" with 3-row list.

**7.6 Vehicle → renter link** — Navy top bar "Vehicle Detail" with edit icon. Vehicle card with **Rented** green-tinted pill on right. Section "Current Renter" — card with navy left border showing renter name, mobile, "Weekly · ₹2,000", "Since 03 Jun 2026". Section "Service" — card showing next service date "15 Aug 2026" with amber "In 75 days" caption. Bottom outline "End Rental" button.

**7.7 Vehicle → customer history** — Same vehicle card at top. Tabs row "Details | Customers | Rentals" (Customers active in navy). List of past renters chronologically: active one at top with navy left-border + green "Active" pill, past renters with grey left-border + grey "Past" pill. Each shows name, basis + amount, period dates.

**7.8 Vehicle → rental earnings** — Same vehicle card. Tabs (Rentals active). Large navy block at top: "Total earned on this vehicle" small white caption, `₹94,000` big white bold, "Across 4 rentals · since May 2025" small. List of per-rental earnings: customer name, period + basis, amount earned in green (current) or navy (past), small "X weeks/months collected" caption.

---

## 6. Tablet variants — 1024 × 768 landscape

Generate a tablet version of **every** screen above. Apply these adaptation rules consistently.

### 6.1 Navigation pattern change
- **Replace** the phone bottom navigation bar **with** a left **side navigation rail**
- Rail width: **56dp** (icons-only, default) or **200dp** (icons + labels, expanded option)
- Rail background: navy `#1B2A4E`
- Top of rail: SLV logo on gold `#D4A848` circular badge
- Nav items: car (Sales), cash (Loans), key (Rentals), settings (Management — Super Admin only). Active item has gold `#D4A848` left-border indicator and slightly lighter navy background.
- Bottom of rail: small profile avatar circle

### 6.2 Layout adaptations

- **Screen horizontal padding:** 24dp (instead of 16dp on phone)
- **Stat cards:** display as a row of 4 across the top (instead of 2×2 grid on phone)
- **List screens:** use **master-detail split view**. List panel on left at 240dp width; detail panel on right filling remaining space. Selected list item has gold `#D4A848` left-border accent.
- **Vehicle list and customer list:** **2-column grid** of cards (instead of single column on phone)
- **Forms:** maximum content width 600dp, centered, with extra whitespace either side
- **Vehicle Detail with Customers + Rentals tabs:** instead of toggling tabs, show both histories **side-by-side in two columns** (literally going sideways). The vehicle header card spans full width across the top, then a 2-column grid below: left = Customer History list, right = Rental Earnings with the navy total block + per-rental list.

### 6.3 Keep identical (do not change)
- All colors (locked in Section 2.1)
- All typography sizes and weights
- All component styles (cards, buttons, badges, pills, FABs)
- All icons and badges
- Touch-target minimum 48dp
- All sample data (Indian names, three-wheeler vehicles)

### 6.4 Per-screen tablet notes (highlights)

- **Login (1.2)** — Card centered horizontally on screen, max width 480dp. Logo above card. Form fields full width within card.
- **Super Admin home (3.1)** — Stats as 1×4 row. Below, a master-detail layout: left panel shows pending items list (320dp wide), right panel shows the selected pending item's full review screen with [Confirm] / [Reject with reason] buttons.
- **Vehicles list (5.2)** — Master panel shows the vehicle cards as a 1-column list with thumbnails. Detail panel shows the selected vehicle's full detail view (Section 5.4 / 5.9).
- **Vehicle detail (5.4 / 7.6)** — Hero photo on the left half, info cards in a 2-column grid on the right half.
- **Vehicle history tabs (7.7 / 7.8)** — Side-by-side two-column layout (described in 6.2).
- **Rental weekly history (7.3)** — Master panel: list of weeks. Detail panel: payment recording form pre-filled with that week's amount.

---

## 7. How to run this in Stitch

Stitch produces best results when prompts are batched. Use this workflow:

### Round 1 — Generate the core 6 phone screens (anchor the design system)

Paste sections 1–4 of this document, plus screens **1.2 (Login)**, **2.1 (Module Chooser)**, **3.1 (Super Admin home)**, **5.2 (Vehicles list)**, **5.4 (Vehicle detail)**, **7.7 (Vehicle → customer history)**.

> Generate these 6 phone screens (375 × 812). Use the locked design system. Three-wheeler rickshaw imagery only.

### Round 2 — Lock the theme across the 6 generated screens

Multi-select all 6 generated screens (Shift + Click). Then:

> Apply this exact theme to all selected screens: app background `#E0DDD3`, primary navy `#1B2A4E`, card surface `#F5F3EE`, accent gold `#D4A848`. Inter font, sentence case, 12dp card radius, 8dp button radius. Make every app bar and bottom navigation identical across all screens.

### Round 3 — Generate the remaining phone screens by module

Paste section 5 of this document, ask for batches:

> Generate the remaining Auto Sale screens (5.1, 5.3, 5.5, 5.6, 5.7, 5.8, 5.9) following my design system. Three-wheeler imagery wherever a vehicle appears.

> Generate all Module 3 screens (7.1 through 7.8) following my design system.

> Generate the authentication screens (1.1, 1.3, 1.4, 1.5).

> Generate the Admin home (4.1).

### Round 4 — Generate all tablet variants

Multi-select the generated phone screens, then paste section 6:

> Create tablet (1024 × 768 landscape) versions of all selected screens. Replace bottom navigation with a left side navigation rail. Use master-detail split for list+detail screens. Stat cards as a 1×4 row. Vehicle and customer lists as 2-column grids. For the Vehicle detail history screen, show the customer history and rental earnings side-by-side in two columns. Keep all colors and components identical.

### Round 5 — Polish and consistency pass

> Audit all phone and tablet screens for consistency. Same app bar height, same card padding, same button heights, same font sizes, same FAB placement. Where any inconsistency exists, align with the most-polished example.

---

## 8. If Stitch slips up

If any screen has the wrong colors, wrong vehicle type, or wrong layout, point at it and say:

> This is wrong. Use a **three-wheeler auto-rickshaw** (Bajaj RE style, three wheels, open cab) — not a car/scooter/motorcycle. Use the locked palette: app background `#E0DDD3`, primary `#1B2A4E`, cards `#F5F3EE`. Regenerate.

Repeat as needed until every screen passes the audit.

---

## 9. Export

Once all phone + tablet screens look right:

1. Export every screen as PNG (or get the Figma file)
2. Save them into a folder `design-reference/` inside your Flutter project
3. Hand them to Claude Code with: *"Build this Flutter app following the spec in SPEC.md and matching the UI in `design-reference/`."*

That gives Claude Code both the rules (spec) and the visual reference (Stitch exports).

---

**End of prompt.** Total scope: 18 phone screens + 18 tablet variants. Estimated Stitch generation time: 4–6 batches.
