# TripSync Admin Web Portal (Zero-PII Platform Intelligence)

A modern, privacy-preserving administration dashboard for the **TripSync** platform.

## 🛡️ Core Privacy Guarantee (Zero-PII Architecture)
By system design:
- **No Personal Details**: Administrators **cannot** view user real names, email addresses, phone numbers, avatars, or private chat messages.
- **No Private Trip Content**: Administrators **cannot** inspect trip destinations, itinerary items, or individual expense itemizations.
- **Masked Identifiers**: Users are identified only by anonymized tokens (e.g. `USR-84A1C9`).
- **Aggregated Analytics**: All reports and graphs are computed using MongoDB aggregations (`$group`, `$facet`, `$bucket`).

---

## 🚀 Key Features

1. **Dashboard Overview**:
   - Platform KPI counters: Registered accounts, active ongoing trips, trips created this month with growth % vs last month, and total ecosystem expense volume.
   - Platform activity footprint (chat volume, photos, documents, polls conducted).

2. **Trip Analytics Studio (Requested by User)**:
   - **Monthly Trip Frequency Graph**: Visualizes total trips created per month across all platform users.
   - **Day-by-Day Drill-Down**: When any month is selected (e.g. October), displays a daily progression bar graph (Days 1–31) showing peak trip creation dates.
   - **Multi-parameter Filtering**:
     - Filter by Year (2024, 2025, 2026).
     - Filter by Month (All Year or specific month).
     - Filter by Status (`planning`, `ongoing`, `completed`, `cancelled`).
     - Filter by Trip Type (`Friends`, `Family`, `Business`).
   - Group size distributions (Solo, Small 2–4, Medium 5–8, Large 9+).

3. **Ecosystem Expense Intelligence**:
   - Macro volume of shared group expenses (INR).
   - Category spend allocation (food, travel, accommodation, shopping, etc.).
   - Split type metrics (equal vs custom splits).

4. **Zero-PII User Moderation**:
   - Anonymized user registry with masked IDs (`USR-XXXXXX`), joined date, last login, and trip counts.
   - Account status filtering (`active`, `suspended`, `pending_verification`).
   - Moderation actions: Suspend abusive/bot accounts or reactivate them with zero exposure of personal information.

5. **Report Generation & Export Center**:
   - Generate structured monthly platform audit reports on demand.
   - On-screen summary table with completion ratios, daily trip velocities, and spend volumes.
   - Direct download as **CSV** or print as **PDF**.

6. **Broadcast Announcements**:
   - Send platform announcements and emergency maintenance notices directly to all active mobile users via notifications & real-time Socket.io.

7. **System & Infrastructure Diagnostics**:
   - Node.js runtime status, server uptime, heap & RSS memory utilization, MongoDB driver connection, and collection counts.

---

## 💻 Quick Start Guide

### 1. Start the Backend
```bash
cd backend
npm run dev
```
*(The backend will run on `http://localhost:5000`)*

### 2. (Optional) Seed an Initial Administrator
To create or upgrade an existing account to admin from CLI:
```bash
cd backend
npm run seed:admin admin@tripsync.app Admin@123456
```
*Or simply use the **"Need to setup initial admin? Click here"** link directly on the Admin login page.*

### 3. Start the Admin Web Portal
```bash
cd admin-frontend
npm run dev
```
*(Open your browser at `http://localhost:5173`)*
