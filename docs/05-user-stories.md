# TableTap AI: User stories and "done" tests

Each story has an ID, the priority from the project brief, and Given / When / Then tests. A story is **done** only when every test passes by clicking through the app. Stories marked 🤖 also get an automated `jac test` using `MockLLM`, so tests cost no API credit.

Build order = the order of this file.

---

## S. Setup

**S-01 Starting data (Must)**
As the developer, I want the Wet Water menu and demo songs created when the manager first opens the dashboard, owned by that manager, so the demo always has data and only the manager can change it.
- **Design (decided, from the practice build):** seeding is done by `def:protect claim_demo_restaurant()`, called when the logged-in manager's dashboard opens. It creates the data on `root.shared` owned by that manager, with a `Manages` edge. **Guests never trigger seeding.** Before any manager logs in, table pages show only "Menu coming soon".
- **Given** an empty app, **when** a manager opens the dashboard, **then** the restaurant "Wet Water Resort" exists with 6 sections and 35 dishes with correct LKR prices, owned by that manager.
- **Given** the starting data, **then** tables "Table 1" to "Table 8" exist.
- **Given** the starting data, **then** the approved song list has at least 6 songs.
- **Given** the restaurant already exists, **when** the dashboard opens again, **then** nothing is duplicated.
- **Given** no manager has logged in yet, **when** a guest opens `/t/t5`, **then** only "Menu coming soon" shows (not "invalid link").

---

## M. Manager

**M-01 Sign up and log in (Must)**
As a manager, I want my own account so only I can change my restaurant.
- **Given** the login page, **when** I sign up with a username and password, **then** I land on my dashboard.
- **Given** I'm logged out, **when** I open the dashboard address, **then** I'm sent to the login page.
- **Given** two managers, **when** one logs in, **then** they cannot see or change the other's restaurant.

**M-02 Menu Setup Agent (Must) 🤖**
As a manager, I want to upload photos of my paper menu so the agent builds my digital menu for me.
- **Given** the 3 Wet Water menu photos, **when** I tap "Read my menu", **then** a draft appears with sections, dish names and prices that match the photos.
- **Given** the draft, **then** each dish has tags the agent added (for example Devilled Prawns: Spicy, Contains shellfish; Vegetable Chop Suey: Vegetarian).
- **Given** the agent is unsure about a dish, **then** that row is marked "Please check".
- **While** the agent works, **then** the screen shows its steps (photos read, dishes found, tags added).
- **Given** the AI fails or times out, **then** I see a friendly message and can retry. The app does not crash.

**M-03 Review and publish (Must)**
- **Given** a draft, **when** I edit a dish's name, price or tags, **then** the change is saved.
- **Given** a draft, **when** I tap "Publish menu", **then** guests see the new menu on every table page.
- **Given** nothing is published, **then** guests see "Menu coming soon".

**M-05 Create my restaurant (Should)**
As a new manager, I want to create my own restaurant so I can use the app for my place.
- **Given** I'm logged in and manage no restaurant, **then** the dashboard shows "Create your restaurant" (name, number of tables).
- **When** I create "Cafe Two" with 3 tables, **then** I manage it, guests at its table links see "Menu coming soon", and I land on Menu setup.
- **Given** two restaurants, **then** each manager sees only their own menu, orders and music.
- **Then** table codes are random and never clash between restaurants.

**M-06 Tables & links (Should)**
- **Then** I see each table with its full link and a Copy button (QR code if time allows).

**M-04 Approved song list (Should)**
- **Given** the Music page, **when** I add a song (title and artist), **then** it appears on the approved list.
- **When** I remove a song, **then** it can no longer be voted for.
- **When** I choose a music mode (Off / Live singer / Speakers / Both), **then** the guest Music tab shows only that mode, or is hidden when Off.

---

## G. Guest

**G-01 Open the table page (Must)**
As a guest, I want to open my table's page without an account.
- **Given** the link for Table 5, **when** I open it on a phone, **then** I see "Wet Water Resort" and "Table 5" with the published menu.
- **Given** an unknown table link, **then** I see "This table link isn't valid" instead of an error.

**G-02 Browse the menu (Must)**
- **Then** dishes are grouped by section in the manager's order.
- **Then** each dish shows name, price in Rs and its tags (Vegetarian, Spicy, Contains shellfish...).
- **Given** a dish is sold out, **then** it's greyed out with "Sold out today" and has no + button.

**G-03 Cart and send order (Must)**
- **When** I tap + on a dish, **then** it's added to the table's cart and the bottom bar shows the item count and total.
- **When** I change quantity or remove a dish, **then** the total updates.
- **When** I tap "Send order" and confirm, **then** the order appears on the kitchen board, and my page shows its status (Sent → Preparing → Ready).

**G-04 AI Waiter Agent (Must) 🤖**
As a guest group, I want to describe our needs so the AI waiter plans an order that fits.
- **Given** the message *"We're 4, one vegetarian, one allergic to prawns, about Rs 5000"*, **when** I send it, **then** I get a suggested order where:
  - no dish contains prawns or shellfish,
  - there are at least 2 vegetarian dishes, so the vegetarian guest gets a full meal,
  - the total is Rs 5,000 or less,
  - no sold-out dish is included.
- **Then** the "What I checked" box lists the tools the agent used (search, availability, total).
- **Then** each suggestion has a short reason.
- **When** I tap "Change" and type *"no fish please"*, **then** the agent replaces fish dishes and recalculates.
- **When** I tap "Confirm & send", **then** exactly those dishes go to the kitchen as one order with the note "Allergy: shellfish (prawns)".
- **Nothing** is sent to the kitchen without my confirmation.
- **Given** the AI fails, **then** I see "The AI waiter is busy right now. You can still add dishes from the menu."

**G-05 AI DJ: live singer request (Should) 🤖**
- **Given** live singer mode, **when** I type *"something romantic, old Sinhala"* and tap "Ask the AI DJ", **then** I see a request card with a song, artist and short message.
- **When** I tap "Send to singer", **then** it appears on the music screen within a few seconds.
- **Then** I see whether the singer accepted or skipped it.
- **Given** my table already has 2 waiting requests, **then** I can't send a third.

**G-06 AI DJ: speaker vote (Should) 🤖**
- **Given** speaker mode, **when** I type *"upbeat for a birthday"*, **then** the agent picks the best match **from the approved list only**, and when I tap "Vote for this" my table's vote is added (the AI never votes by itself).
- **Given** nothing on the list matches, **then** the agent says so and shows the list, and no vote is added.
- **Then** my table can vote only once per song.

---

## K. Kitchen

**K-01 Kitchen board (Must)**
- **Given** a new order, **then** it appears in "New" with table number, dishes, quantities, notes and any allergy note, oldest first.
- **When** I tap "Start preparing", **then** it moves to "Preparing" and the guest sees "Preparing".
- **When** I tap "Mark ready", **then** it moves to "Ready" and the guest sees "Ready".
- The board refreshes by itself at least every 5 seconds.

**K-02 Sold out (Must)**
- **When** I mark a dish sold out, **then** guests see it greyed out, and the AI waiter never suggests it.
- **When** I mark it available again, **then** it can be ordered again.

**K-03 Sold-out reaction (Could) 🤖**
- **Given** Table 5 has Devilled Prawns in a "New" order, **when** the kitchen marks it sold out, **then** Table 5 sees a suggested swap from the AI waiter and can accept or decline.

---

## MU. Music screen

**MU-01 Singer requests (Should)**
- **Then** requests appear oldest first with song, artist, table, message and the guest's original wish.
- **When** the singer taps Accept or Skip, **then** the guest sees the result.

**MU-02 Speaker queue (Should)**
- **Then** approved songs are ranked by votes.
- **When** staff tap "Now playing" on a song, **then** it shows as Now playing and its votes reset to 0.

---

## Q. Quality (applies to everything)
- `jac check` passes with no errors.
- `jac test` passes, including the 🤖 agent tests with `MockLLM`.
- Every screen matches its mockup in `docs/mockups/` closely.
- No raw error messages ever reach the screen.
- At least 80% of the code in the repository is Jac.
