# TableTap AI: UI/UX pack

Mockup images for every screen are in `docs/mockups/`. Build each screen to look like its mockup. The mockups use placeholder text in [brackets] where real data goes.

## User journeys

**Manager (laptop)**
1. Sign up / log in → 2. Upload menu photos → 3. Watch the Menu Setup Agent's steps → 4. Review the draft table, fix rows marked "Please check" → 5. Publish menu → 6. Add songs to the approved list → 7. Open the kitchen board and music screen on other devices.

**Guest (phone)**
1. Open the table link (Table 5) → 2. Browse the menu by section, see tags → 3. Either add dishes with + or tap "Ask the AI waiter" → 4. Describe the table's needs → 5. Read the agent's steps and suggested order → 6. Confirm & send → 7. Optional: Music tab → ask the AI DJ → send to singer, or vote in speaker mode.

**Kitchen (tablet)**
1. New order appears in "New" with allergy note → 2. Start preparing → 3. Mark ready → 4. Mark a dish sold out when needed.

**Singer / music staff (tablet)**
1. Requests appear oldest first → 2. Accept or Skip → 3. Speaker queue ranked by votes → 4. Tap "Now playing" when the song starts.

## Screen list
| # | Screen | Who | Device | Mockup |
|---|---|---|---|---|
| 1 | Manager: menu setup agent (upload, agent steps, draft table, publish) | Manager | Laptop | `mockups/1-manager-menu-setup.png` |
| 2 | Guest: table menu (sections, tags, + buttons, sold-out, order bar) | Guest | Phone | `mockups/2-guest-menu.png` |
| 3 | Guest: AI waiter (request, "What I checked" steps, suggested order, Confirm & send) | Guest | Phone | `mockups/3-guest-ai-waiter.png` |
| 4 | Guest: AI DJ (live singer / speakers switch, wish box, request card) | Guest | Phone | `mockups/4-guest-ai-dj.png` |
| 5 | Kitchen board (New / Preparing / Ready columns, allergy note) | Kitchen | Tablet | `mockups/5-kitchen-board.png` |
| 6 | Music screen (singer requests, speaker queue by votes, Now playing) | Singer, staff | Tablet | `mockups/6-music-screen.png` |
| — | Login / sign-up | Manager | Laptop | No mockup: simple centered card in the same style |

## UX rules
- **Show the agent's work.** Every agent screen shows a short "What I checked" / "Agent steps" list of the tools it used. This is what judges score as agentic depth.
- **Humans confirm.** Agents suggest; the manager publishes, the guest confirms, the singer accepts.
- **Mobile first** for guest screens (390 px wide). Big touch targets: buttons at least 44 px tall.
- **Allergy information is never hidden.** Shellfish/nut/egg/dairy tags are always visible, and the kitchen card shows the table's allergy note.
- **Friendly errors.** If AI fails: "The AI waiter is busy right now. You can still add dishes from the menu." Never a raw error.
- **Loading states.** Buttons show "Reading your menu…", "Thinking…" and are disabled while busy.

## Style guide (modern, light)
Write these as one theme file in Jac on the day (for example `core/theme.jac` or the Tailwind theme, following `jac guide jac-cl-styling`). Do not create a separate CSS file.

| Token | Value | Use |
|---|---|---|
| `ink` | `#14161A` | Main text, dark buttons, headers on staff screens |
| `muted` | `#5B616B` | Secondary text |
| `body` | `#3D434C` | Body text on white |
| `ground` | `#F4F5F7` | Page background |
| `surface` | `#FFFFFF` | Cards |
| `line` | `#E3E5E8` | Borders |
| `accent` | `#0F766E` | Primary buttons, brand, success |
| `accentSoft` | `#E6F2F1` | Selected nav, "Open"/"Accepted" pills |
| `warn` | `#92400E` on `#FEF3C7` | Spicy tag, "Please check", New column |
| `veg` | `#166534` on `#DCFCE7` | Vegetarian tag, Ready column |
| `allergy` | `#9F1239` on `#FFE4E6` | Contains shellfish / nuts / egg / dairy |
| `info` | `#075985` on `#E0F2FE` | Fish tag, Preparing column |

- **Fonts:** Geist (text) and Geist Mono (prices, agent steps), from Google Fonts.
- **Shape:** cards 14–16 px corner radius, buttons 10–12 px, pills fully round.
- **Spacing:** 8 px steps (8, 12, 16, 24, 32).
- **Icons:** simple line icons, no emoji.
