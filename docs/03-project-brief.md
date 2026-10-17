# TableTap AI: Project brief (one-day SOW)

## 1. Summary
Build TableTap AI in Jac during hacking hours on Saturday 17 October 2026 (9:00 AM to 5:30 PM). It is a dine-in restaurant platform where a manager sets up a menu from a photo with an AI agent, guests order through an AI waiter agent, the kitchen follows a live board, and an AI DJ handles music requests. Built solo by Nethma.

## 2. Goals for the day
1. A judge can watch one complete visit: manager setup → AI-planned order → kitchen board.
2. At least two agents clearly **decide and act with tools**, and their steps are visible on screen.
3. The code is at least 80% Jac and passes `jac check` and `jac test`.
4. The demo video and written description are submitted before 5:30 PM.

## 3. In scope (build in this order)
| # | Feature | Priority | Done when |
|---|---|---|---|
| 1 | Project setup, data model, Wet Water menu as starting data | Must | `jac run` serves the app; the menu exists in the graph |
| 2 | Manager login and restaurant creation | Must | A manager can sign up, log in and see their restaurant |
| 3 | Guest table page: menu by section with tags, cart, send order | Must | A guest can order from Table 5 |
| 4 | Kitchen board: new → preparing → ready, sold-out switch | Must | The order appears and its status changes are seen by the guest |
| 5 | **AI Waiter Agent** with tools and confirmation | Must | Diet + allergy + budget request gives a valid order with a total and reasons |
| 6 | **Menu Setup Agent** (photo → draft → review → publish) | Must | The Wet Water photo produces a draft with sections, prices and tags |
| 6b | New manager onboarding (create restaurant, random table codes) and Tables & links page | Should | A second manager creates their own café and its table link works |
| 7 | AI DJ: live singer requests and music screen | Should | A vague wish becomes a request the singer can accept or skip |
| 8 | AI DJ: speaker voting on the approved song list | Should | A wish votes for the best matching approved song, one vote per table per song |
| 9 | Sold-out reaction, celebration mode (birthday requests to the kitchen), table QR codes, dish photo links | Could | Only if items 1 to 8 are done before 3:00 PM |

**Why the waiter comes before the menu agent:** the waiter is the main demo moment, and the menu agent has a ready backup (the Wet Water menu as starting data). If the photo reading gives trouble, the demo still works.

## 4. Out of scope (not on Saturday)
Payments, taxes and VAT, service charge, tips, discounts, guest feedback, staff PINs, counter/waiter screen, admin approval of restaurants, printable QR PDFs, Sinhala and Tamil, phone app store builds, music playback through speakers, song previews.

New ideas during the day go on a "Later" list in the README, not into the build.

## 5. Deliverables (due 5:30 PM)
1. Public GitHub repository, first commit after 9:00 AM, code at least 80% Jac
2. Demo video (about 2 minutes) of the working app
3. Written description, including how Jac and Jaseci tools were used, and that planning documents were prepared beforehand
4. Jac repository starred: github.com/jaseci-labs/jac
5. Encouraged: app hosted on Jac Hammer for judges

## 6. Constraints
- One person, beginner programmer, building with Claude Code
- 8.5 hours, including testing, video and submission
- AI calls use Nethma's own Anthropic API credit (USD 5 limit), so tests use `MockLLM` and live AI calls are kept for real checks and the demo
- Must follow Rule 03: no code written before 9:00 AM

## 7. Risks and backups
| Risk | Backup |
|---|---|
| The model can't read the menu photo, or byLLM settings fail | Found in Friday's spike. On the day: load the Wet Water menu as starting data and show the agent tagging dishes from text |
| AI is slow or fails during the demo | Every AI feature has a fallback message, and ordering still works by tapping dishes |
| Running out of time | Strict build order. Items 1 to 6 alone make a complete demo. Feature freeze at 3:30 PM |
| Jac error that Claude Code can't fix | Ask the Jaseci team on-site; check `jac guide`; roll back with git to the last working commit |
| API credit runs out | `MockLLM` for tests; keep demo runs few; check credit at lunch |
| Laptop or internet trouble | Push to GitHub after every working step; record a rough backup video at 2:30 PM |
