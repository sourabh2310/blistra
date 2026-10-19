# Blistra UI Decisions

## Design System
- Font: Claude serif (`var(--font-voice)` / Fraunces) for brand name + headings. Inter for body/UI.
- Accent: `#12B886` (Lagoon teal) — used on CTA button, links, brand mark bg
- Style: **Midnight Glass** — deep dark bg (`#06090F`), frosted glass card for form, subtle teal radial glow behind brand mark
- Dark/light toggle always visible top-right corner

---

## Pages

### 01 — Sign-in screen
- **Style:** Midnight Glass
- **Sample file:** `design/01_signin.html`
- **Layout:** A — Underline fields (matches Register screen style) + OTP inline reveal + Google
- Nav: "Blistra" brand left, "Create account" teal link right
- Heading in Claude serif: "Welcome back." with "back." in teal; subtext: "Sign in to continue."
- **State 1 — Empty:** two underline fields (Email or username / Password + eye toggle); "Forgot password?" right-aligned teal; dimmed "Sign in" CTA; "or" divider; Google button; "New here? Create account" footer
- **State 2 — OTP revealed:** after tapping Sign in with credentials filled, both fields lock/dim; 6-slot OTP grid slides in below with label "Verification code" + sublabel "Sent to [email]"; "Didn't get it? Resend" right; CTA changes to "Verify & sign in" (dimmed until all slots filled)
- **State 3 — OTP complete:** all 6 slots filled (teal); "Verify & sign in" full teal active
- Google button always visible below CTA in all states; "Create account" footer on states 1 + 3

---

### 02 — Welcome screen (first screen on fresh install)
- **Style:** Midnight Glass
- **Sample file:** `design/02_welcome.html`
- **Layout:** D — Minimal
- Background: `#06090F` with teal radial glow top-right + faint glow bottom-left
- Brand row: teal mark + "Blistra" in Claude serif (same as sign-in)
- Eyebrow: "Your personal OS" — 9px, teal `#12B886`, uppercase, tracked
- Heading: "Everything you need. One app." in Claude serif, 36px, `#EEF2F0`; "One app." in teal
- Sub-text: "Planner · Health · Habits / Finance · Diet · Medicines" — 13px, muted dark
- Module dots: row of 6 × 8px circles in module semantic colors
- Primary CTA: "Get started" — `#12B886` filled, r14, full-width
- Secondary: "Have an account? **Sign in**" centered below

---

### 03 — Create Account screen (single-screen registration)
- **Style:** Midnight Glass
- **Sample file:** `design/03_register.html`
- **Layout:** A — All fields visible, scrollable, 3 section labels
- **Replaces:** old screens 03–08 (name, username, email OTP, phone OTP, password, review wizard)
- Nav: brand mark "Blistra" left, "Sign in" teal link right (no back button, no step counter)
- Heading in Claude serif: "Create your account." with "account." in teal; subtext: "Takes about 2 minutes."
- **Section labels** (tiny uppercase muted dividers): "Who are you?" / "Contact" / "Security"
- **Who are you?**
  - First name + Last name in a 2-column underline row
  - Username underline field with `@` prefix; inline "✓ Free" chip when available
- **Contact:**
  - Email underline field + "Send OTP" inline button (right); dims until email entered
  - When OTP sent: email field locks + "✓ Sent" chip; 6-slot OTP grid slides in below the field inline; "Didn't get it? Resend" right-aligned below slots
  - Phone underline field (optional label) with country code pill prefix (flag + code + ▾); "Send OTP" inline button; same inline OTP reveal as email
- **Security:**
  - Password underline field + eye icon; 3-segment strength meter below
  - Confirm password underline field + eye icon; "Passwords match" dot+text below when matched
- "Create account" CTA: dimmed until email verified + passwords match; full teal when ready
- Old files `03_name.html`, `04_username.html`, `05_email_otp.html`, `06_phone_otp.html`, `07_password.html`, `08_review.html` are superseded by this screen

---

### 09 — Profile welcome screen (post account creation)
- **Style:** Midnight Glass
- **Sample file:** `design/09_profile_welcome.html`
- **Layout:** C — Minimal full-bleed headline with topic pills
- No back button, no step counter (fresh start after account creation)
- Large central teal radial glow behind content
- Eyebrow: "Welcome to Blistra 🎉" — teal, small uppercase
- Heading in Claude serif: "Hey [name], let's set up your profile." — "your profile." in teal
- Subtext: "Takes 2 minutes. Helps us personalise Health, Diet and Habits for you."
- Topic pills row: 📸 Photo · 🎂 Birthday · ⚖️ Height & weight · 🎯 Goals — teal tinted
- CTA: "Complete profile →" full teal
- Below CTA: "Do this later" — muted text link

---

### 10 — Profile setup screen (Profile Step 1 of 2)
- **Style:** Midnight Glass
- **Sample file:** `design/10_profile_setup.html`
- **Layout:** C — Avatar inline with name, underline DOB field, gender chips
- Back button top-left, "Profile 1 of 2" top-right, progress bar at 50%
- Heading in Claude serif: "Your profile." with "profile." in teal; subtext below
- **Avatar row:** 72px circle (dashed teal border, teal initial letter); camera badge bottom-right; name + "Tap to add photo" teal link alongside
- **Date of birth field:** underline field; label + "Tap to select" hint + 📅 calendar icon right
  - Tap opens a **bottom sheet** (`#0C1520`, r20 top corners):
    - Month/grid calendar picker (7-col grid, selected day filled teal circle)
    - Month nav: ‹ Month Year › header
    - "Enter manually" link top-right → switches to 3-box manual entry (Day / Month / Year) in same sheet; "Use calendar" link to switch back
    - Manual format hint: "DD / MMM / YYYY"
    - "Confirm" CTA at bottom of sheet
- **Gender:** 4 chips (Male / Female / Non-binary / Prefer not to say); selected chip has teal bg tint + teal border
- Continue CTA: dimmed until DOB + gender both set; full teal when complete
- **State 4** (fully complete): avatar shows photo check, DOB field shows date value in teal ✓, gender chip selected, Continue active

---

### 11 — Health setup screen (Profile Step 2 of 2)
- **Style:** Midnight Glass
- **Sample file:** `design/11_health_setup.html`
- **Layout:** B — Underline fields + activity chips + goal chips
- Back button top-left, "Profile 2 of 2" top-right, progress bar at 75% → fills to 100% when complete
- Heading in Claude serif: "Your health." with "health." in teal; subtext: "Used for Health, Diet & Habits modules."
- **Height field** (underline): label teal when active; value 28px bold; unit shown inline ("cm" or "ft"); cm ↔ ft toggle pill right-aligned
- **Weight field** (underline): same pattern; kg ↔ lbs toggle pill
- **Activity level:** section label + 4 horizontal chips: 🛋 Sedentary / 🚶 Light / 🏋 Moderate / 🏃 Very active — single select, selected = teal chip
- **Goals:** section label + "Pick any that apply" hint + 6 multi-select chips: 💪 Build muscle / 🏃 Lose weight / 😴 Better sleep / ❤️ Heart health / 🧘 Reduce stress / ⚡ More energy
- "Finish setup →" CTA: dimmed until height + weight + activity all set; goals optional; full teal when ready

---

### 12 — Done / Setup complete screen
- **Style:** Midnight Glass
- **Sample file:** `design/12_done.html`
- **Layout:** A — Checkmark glow + stats row
- No nav, no back button, no step counter (terminal screen)
- Large central teal radial glow (360px) behind content; smaller glow bottom-left + top-right
- **Module dots:** row of 6 × 10px circles in module semantic colors (Planner, Health, Medicines, Diet, Habits, Finance)
- **Checkmark ring:** 80px circle, teal border + teal bg tint, `✓` at 36px, teal box-shadow glow
- Eyebrow: "You're all set!" — teal, small uppercase
- Heading in Claude serif: "Blistra is ready for you." — "ready" in teal
- Subtext: "Your profile is complete. All modules are unlocked."
- **Stats row:** frosted glass pill card — 3 stats: 6 Modules / ∞ Possibilities (teal) / 100% Done — separated by faint vertical dividers
- CTA: "Go to Blistra →" full teal, r14, full-width, pinned to bottom

---

<!-- Add more pages below as they are finalized -->
