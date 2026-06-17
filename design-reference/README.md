# SLV Auto Consultant — Design Package

Complete design reference for the SLV Auto Consultant Flutter app (Bengaluru three-wheeler auto-rickshaw business). Hand this folder to Stitch (for UI generation) and Claude Code (for Flutter implementation).

## Contents

### `/wireframes-original/` — Your hand-drawn wireframes (11 files)
The original concept and wireframe screenshots you uploaded. Includes the 3-module overview, auto resale flow notes, rental module notes, the SLV logo, and 6 detailed wireframes covering login, module chooser, Auto Sale, user management, installment view, and Auto Rental main screen.

### `/mockups-phone/` — Phone mockup renderings (18 PNG files)
Visual mockups of every phone screen at ~280×580px. Use these as design references for Stitch generation and as visual confirmation of layout/branding for Claude Code.

Screens included:
1. Login (SLV Automobiles)
2. Module Chooser (3 modules)
3. Auto Sale Welcome
4. Vehicles List (Assigned/Unassigned tabs)
5. Create Vehicle Form
6. Vehicle Detail
7. Customers List
8. Create Customer Form
9. Customer Assign + Payment (Full / Installments toggle)
10. Installment History
11. Rental Main (Rented/Not Rented tabs)
12. Assign Rental (Daily/Weekly/Monthly basis)
13. Weekly Rental History
14. Customer List — Module 3 (Active/Inactive)
15. Customer Detail → Assigned Vehicle
16. Vehicle Detail → Current Renter
17. Vehicle Customer History tab (active + past renters)
18. Vehicle Rental Earnings tab (total earned + per-renter breakdown)

### `/mockups-tablet/` — Tablet mockup renderings (2 PNG files)
Tablet layouts showing the responsive design with side rail + master-detail split.

1. Auto Sale System — master-detail vehicle list with full detail panel
2. Vehicle Detail — Customer History + Rental Earnings side-by-side

### `/specs/` — Specification documents (2 markdown files)
- **`slv-auto-consultant-build-spec.md`** — Complete Flutter build specification for Claude Code. Covers all 4 modules, data models, role-gate pattern, Firestore rules sketch, and a 22-step build checklist.
- **`slv-auto-stitch-prompt.md`** — Comprehensive prompt for Google Stitch UI generation. Covers all 36 screens (18 phone + 18 tablet variants), locked design palette, and 5-round generation workflow.

---

## Design System (locked)

| Token | Value |
|---|---|
| App background | `#E0DDD3` (warm grey, from logo) |
| Primary navy | `#1B2A4E` (buttons, headers — from logo) |
| Card surface | `#F5F3EE` (cream off-white) |
| Text primary | `#0F1A33` |
| Text secondary | `#6B7280` |
| Accent gold | `#D4A848` (FABs, active-tab indicators) |
| Success | `#1F7A4D` (tint `#E7F1EA`) |
| Warning | `#C8852A` (tint `#F7EDD9`) |
| Danger | `#9E2A2A` (tint `#F4DDDD`) |
| Font | Inter, sentence case (never ALL CAPS) |
| Card radius | 12dp |
| Button radius | 8dp |
| Formatting | `₹1,80,000` (Indian), `+91 98765 43210`, `28 Jun 2026` |
| Vehicle imagery | Three-wheeler rickshaw (Bajaj RE) ONLY |

---

## Recommended workflow

1. **Open** `specs/slv-auto-stitch-prompt.md`, paste into Stitch at https://stitch.withgoogle.com to generate the 36 high-fidelity screens.
2. **Reference** the mockups in `mockups-phone/` and `mockups-tablet/` as visual targets while Stitch generates.
3. **Open** `specs/slv-auto-consultant-build-spec.md`, hand to Claude Code in your Flutter project folder.
4. **(Optional)** Connect Stitch MCP to Claude Code via `claude mcp add stitch --api-key YOUR_KEY` so Claude Code can read live design tokens from your Stitch project.
5. Build the app module by module per the 22-step checklist.

---

Generated for SLV Auto Consultant on 02 Jun 2026.
