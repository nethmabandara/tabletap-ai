# TableTap AI: Architecture and decision notes

Sources checked: `jac guide jac-project-kinds`, `jac-by-llm`, `jac-sv-auth`, `jac-sv-multi-user`, `jac-sv-endpoints`, `jac-fullstack-patterns`, `jac-cl-styling` (jac 0.37.25).

## 1. Big picture

One Jac **web-app** project: server, screens and AI in one codebase, served by `jac run` at `http://localhost:8000`.

```
 Guest phone ──┐
 Manager laptop┤                         ┌─ Graph data (saved automatically)
 Kitchen tablet┼──►  TableTap AI (Jac)  ─┼─ Built-in login (manager)
 Music tablet ─┘     one web-app         └─ Claude API (via byLLM) for the 3 agents
```

- **Screens** are Jac client components (JSX in `.jac` files), styled with the theme from `04-ui-ux.md`.
- **Server functions** are `def:pub` (guests, no login) and `def:protect` (manager, login required). Screens call them directly; Jac generates the connection, no glue code.
- **Agents** are `by llm()` functions with typed results and tools.

## 2. Folder plan

**Placement rule (learned in practice):** `pages/` and `ui/` files are compiled into the browser. They may only call `def:pub` / `def:protect` functions. Graph queries, `grant`, seeding and agents live in `core/` modules that the client never imports except for those endpoint functions. Routing is file-based: `pages/index.jac`, `pages/login.jac`, `pages/(auth)/dashboard.jac` (the `(auth)` folder sends logged-out users to /login), `pages/t/[code].jac` (guest table page) — see `jac guide jac-cl-routing`.


```
tabletap-ai/
├── jac.toml              project settings, AI model under [byllm.model]
├── main.jac              app entry: routes to the screens
├── AGENTS.md             rules for Claude Code
├── README.md
├── core/
│   ├── models.jac        nodes, edges, AI result objs (06-data-model.md)
│   ├── seed.jac          starting data (Wet Water menu, tables, songs)
│   ├── menu.jac          menu, publish, sold out
│   ├── orders.jac        cart → order, kitchen status
│   ├── music.jac         song list, requests, votes
│   ├── agents.jac        the 3 agents and their tools
│   ├── theme.jac         colours, fonts, spacing
│   └── *.test.jac        tests (MockLLM for agents)
├── ui/
│   ├── manager.jac       login, menu setup, songs
│   ├── guest.jac         table menu, AI waiter, AI DJ
│   ├── kitchen.jac       kitchen board
│   └── music_screen.jac  singer requests, speaker queue
└── docs/                 this kit + mockups/
```
Keep each file under about 250 lines. Claude Code may adjust names, but keep the split.

## 3. Server functions

| Function | Who | Does |
|---|---|---|
| `get_menu(table_code)` | Guest (`pub`) | Restaurant, table label, published sections and dishes |
| `place_order(table_code, items, allergy_note, via_ai)` | Guest | Creates Order + OrderItems under the Table; rejects sold-out dishes |
| `table_orders(table_code)` | Guest | This table's orders and statuses |
| `ask_waiter(table_code, message, history)` | Guest | Runs the AI Waiter; returns a **plan**, never places an order |
| `ask_dj(table_code, wish, mode)` | Guest | Runs the AI DJ; returns a SongPick (singer) or a vote result (speakers) |
| `send_song_request(table_code, song, artist, message, wish)` | Guest | Saves a SongRequest (max 2 pending per table) |
| `claim_demo_restaurant()` | Manager (`protect`) | Called when the dashboard opens: if no Restaurant exists, creates Wet Water (starting data) on `root.shared`, owned by this manager, + `Manages` edge, with READ/CONNECT grants for guests |
| `read_menu_photos(files)` | Manager | Runs the Menu Setup Agent on uploaded photos; saves a draft |
| `update_dish(...)`, `publish_menu()` | Manager | Review and publish |
| `set_sold_out(dish_id, value)` | Manager (kitchen screen) | Sold-out switch |
| `kitchen_orders()`, `set_order_status(order_id, status)` | Manager (kitchen screen) | Kitchen board |
| `song_list()`, `add_song()`, `remove_song()`, `set_music_mode()` | Manager | Approved list and mode |
| `music_queue()`, `answer_request(id, accept)`, `set_now_playing(song_id)` | Manager (music screen) | Music screen |

## 4. How the three agents work

All three follow the same pattern from `jac guide jac-by-llm`:
1. A function with **typed inputs**, a **typed `obj` result**, and **`sem` descriptions** for the function, each input and each result field.
2. `by llm(...)` replaces the body. With `tools=[...]`, Jac runs the **ReAct loop** automatically: the model thinks, calls a tool, reads the result, repeats, then answers.
3. Tools are normal Jac functions with their own `sem` lines. Each tool also **adds a line to a "steps" list**, which the screen shows as "What I checked".
4. Wrapped in `try/except`. On failure the screen gets a friendly message, never a crash.
5. Results are **suggestions**. Saving happens only after the human confirms.

### Menu Setup Agent
- **Input:** the uploaded menu photos as `Image` values (`Image` accepts a path, URL or bytes; needs a vision-capable model).
- **Output:** `MenuDraft` (restaurant name, list of `DishDraft` with section, name, price, veg, spicy, allergens, `confident`).
- **Tools:** none needed for reading. After the result, our code saves each dish with `needs_check = not confident`.
- **Steps shown:** "Read 3 photos", "Found 6 sections", "Extracted 35 dishes", "Tagged 9 spicy · 8 vegetarian", "2 need your check".
- **Backup:** if photo reading fails on the day, the starting data already holds the menu. A second agent call can still **tag** the existing dishes from text, so the demo keeps an agent moment.

### AI Waiter Agent (the star)
- **Input:** the guest's message, the table code, and the conversation so far (for "no fish please" follow-ups).
- **Output:** `WaiterPlan` (items with qty and reason, total, summary, warnings).
- **Tools:**
  | Tool | Returns |
  |---|---|
  | `search_menu(query, veg_only, exclude_allergens, max_price)` | Matching dishes that are not sold out |
  | `get_dish(name)` | Full details of one dish |
  | `check_available(names)` | Which of these dishes are sold out |
  | `cart_total(items)` | Exact total in rupees (computed by code, not by the AI) |
- **Safety checks in code after the AI answers:** remove any sold-out dish, remove any dish whose allergens match the request, recompute the total with `cart_total`. If something was removed, add a warning line.
- **Confirm:** "Confirm & send" calls `place_order` with exactly the plan's items and the allergy note.

### AI DJ Agent
- **Live singer mode:** `SongPick` from the wish (song, artist, short message). No tools needed. The guest taps "Send to singer" → `send_song_request`.
- **Speaker mode:** tool `search_approved_songs(query)` returns only the manager's list. Our code checks the pick is on the list (`from_approved_list`), then adds the table's Vote (one per table per song). If nothing fits, no vote and the list is shown.

## 5. Live updates
The kitchen board, music screen and guest order status **ask the server every 3 seconds** (polling). This is simple and reliable for a demo. Streaming is possible in Jac (`jac guide jac-sv-streaming`) but not needed.

## 6. AI model and cost
- Set in `jac.toml` under `[byllm.model]` (`default_model = ...`), with the API key from the `ANTHROPIC_API_KEY` environment variable.
- **Planned model:** a fast, cheap Claude model for the waiter and DJ, and a vision-capable model for the menu photos. The exact model names, and whether byLLM's settings work with them (earlier we saw `claude-haiku-5-5` reject the `temperature` setting), are decided by the **spike (document 8)**.
- **Credit:** USD 5. Tests use `MockLLM`, so only real demo runs spend credit.

## 7. Decision notes

| # | Decision | Why | Rejected option |
|---|---|---|---|
| D1 | One web-app, not separate service apps | Fewer moving parts for one person in one day; `try/except` gives the AI fallback | Separate AI service like tiny_jacyac's scoring service (more setup) |
| D2 | Kitchen and music screens use the manager's login | No PIN system needed; still secure | Staff PINs (TableTap feature, later) |
| D3 | Guest cart lives on the guest's screen until "Send order" | No half-finished carts in the database | Shared table cart across phones (TableTap feature, later) |
| D4 | Polling every 3 s | Simple, works everywhere | Streaming/websockets |
| D5 | Prices as whole rupees (`int`) | The menu has no cents; avoids rounding issues | Decimals |
| D6 | AI returns `obj`s; code saves nodes after confirmation | Guide's advice; humans stay in control | AI writing nodes directly |
| D7 | Totals and safety filters computed by code, not by the AI | AI can make maths or allergy mistakes; code can't | Trusting the AI's total |
| D8 | Starting data with the real Wet Water menu | Demo always works, even if the photo agent fails | Empty app |
| D9 | Styling through Jac's theme / Tailwind setup (`jac-cl-styling`) | Keeps the code at least 80% Jac | Large separate CSS files |
| D10 | Host on Jac Hammer if time allows, otherwise demo locally | Encouraged by organizers; not required | Other hosting |
