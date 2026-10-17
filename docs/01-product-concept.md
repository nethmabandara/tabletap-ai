# TableTap AI: Product concept

## One-line pitch
Any restaurant can turn its paper menu into an AI-staffed dining floor in two minutes: an AI waiter that plans a whole table's order, a live kitchen board, and an AI DJ for the music.

## The problem
- Guests feel rushed while a waiter stands waiting, or they wait too long for the waiter to come back.
- Paper menus don't say what's spicy, vegetarian or safe for allergies, so guests ask the same questions every visit, and mistakes happen.
- Planning one order for a group (different diets, a budget) is slow and awkward.
- Small restaurants can't afford custom software, and setting up a digital menu by hand takes hours.
- At restaurants with live music, song requests are shouted across the room or written on napkins.

## Who uses it
| Person | What they want | Screen |
|---|---|---|
| Restaurant manager | Get online fast, control the menu and music | Manager dashboard (login) |
| Guest group at a table | Order at their own pace, safely, within budget | Table page (opened from the table's link or QR code) |
| Kitchen staff | See orders clearly, mark progress and sold-out dishes | Kitchen board |
| Live singer or music staff | Receive song requests, see the speaker queue | Music screen |

## The three agents
| Agent | Goal | Tools it can use | What the human confirms |
|---|---|---|---|
| **Menu Setup Agent** | Turn a menu photo into a complete digital menu | Reads the image, then creates sections and dishes with prices, and adds tags the paper doesn't show: spicy, vegetarian, contains shellfish/nuts/egg/dairy | The manager reviews the draft, fixes mistakes, then publishes |
| **AI Waiter Agent** | Plan an order that fits the table's diets, allergies and budget | `search_menu`, `get_dish`, `check_available`, `cart_total` (the order is placed by code only after the guests confirm) | The guests approve the suggested order before it goes to the kitchen |
| **AI DJ Agent** | Turn a vague music wish into a proper request | Live singer mode: writes a clean request (song, artist, message). Speaker mode: `search_approved_songs`, `vote_song` (only songs the manager approved) | The singer accepts or skips. Speaker votes count only for approved songs |

**Bonus reaction (if time allows):** when the kitchen marks a dish sold out, the waiter agent finds tables that ordered it and suggests a close alternative.

## The "wow" moments (for the demo video)
1. **Two-minute setup:** the manager uploads the real Wet Water Resort menu photo, and 35 dishes appear with prices, sections and tags like "spicy" and "contains shellfish".
2. **Table planning:** a guest types *"We're 4, one vegetarian, one allergic to prawns, about Rs 5000"*, and the waiter agent builds a full order that fits, shows the total and explains its choices. The guests tap Confirm and it appears on the kitchen board.
3. **Music:** *"something romantic, old Sinhala"* goes to the singer's screen as a clean request; in speaker mode, *"upbeat for a birthday"* votes for the best approved song.
4. **(If built) Sold out:** the kitchen marks Devilled Prawns sold out, and that table gets a suggested swap.

## Why Jac
- **Graph data fits a restaurant:** Restaurant → Section → Dish, Restaurant → Table → Order. Nodes and edges, no database setup.
- **`by llm()` with typed outputs:** the menu agent returns a typed `MenuDraft` object, not loose text.
- **`by llm(tools=[...])`:** tool calling is built in, and that's what makes the waiter and DJ agentic.
- **`Image` input:** reading a menu photo is one typed function.
- **Built-in login:** each manager's restaurant lives under their own account, and the public menu is shared with guests.
- **One codebase:** backend, frontend and AI all in Jac (counts toward the 80% rule).
- **`MockLLM`:** tests for the agents run without spending API credit.

## Scope for one day (solo, 8.5 hours)
| Priority | Feature |
|---|---|
| **Must** | Manager login |
| **Must** | Menu Setup Agent: photo to draft menu, review, publish (backup: load the Wet Water menu as starting data) |
| **Must** | Guest table page: browse menu with tags, cart, send order |
| **Must** | AI Waiter Agent with tools and guest confirmation |
| **Must** | Kitchen board: new, preparing, ready, sold-out switch |
| **Should** | AI DJ: live singer requests and music screen |
| **Should** | AI DJ: speaker voting from the manager's approved list |
| **Could** | Sold-out reaction, QR codes per table, dish photo links |
| **Won't** | Payments, taxes and VAT, tips, discounts, feedback, staff PINs, admin approval, multiple languages |
