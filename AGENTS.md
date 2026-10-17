# AGENTS.md: rules for AI coding assistants on TableTap AI

You are helping Nethma, a beginner programmer, build **TableTap AI** alone during the EESoc AI Hackathon 2026 (9:00 AM to 5:30 PM). Explain what you do in plain, short English.

## Read first
1. `docs/01-product-concept.md`: what we are building and the 3 agents
2. `docs/03-project-brief.md`: build order, in scope, out of scope
3. `docs/05-user-stories.md`: every feature and its Given/When/Then tests
4. `docs/06-data-model.md` and `docs/07-architecture.md`: nodes, edges, functions, agent design
5. `docs/04-ui-ux.md` and `docs/mockups/*.png`: how every screen must look
Read only the parts you need for the current story.

## Jac
- This project uses the **jac 0.37 binary**. It is self-documenting: run `jac guide` to list guides and `jac guide <name>` to read one **before** writing unfamiliar Jac. Key guides: `jac-essentials`, `jac-core-cheatsheet`, `jac-fullstack-patterns`, `jac-cl-components`, `jac-cl-styling`, `jac-node-edge-patterns`, `jac-sv-auth`, `jac-sv-multi-user`, `jac-sv-endpoints`, `jac-by-llm`, `jac-testing`.
- After **every** edit run `jac check .` and fix all errors before saying anything is done.
- Run `jac test` after changing anything with tests.
- `jac guide --search <keyword>` finds guides by topic; `jac guide <name> --sections` and `--section <slug>` read just one part.
- **Don't leave a server running** (it never finishes). Nethma runs `jac run --dev main.jac` (hot reload) in a second Ubuntu window and restarts it after server-side changes.
- **`jac check` passing is not enough.** It does not build the browser bundle. After every story, start `jac run --dev main.jac` yourself just long enough to confirm it compiles with no `✖ Error` lines, then stop it.
- **Client vs server placement (learned the hard way, 15 Oct):** anything a page or `ui/` file imports is compiled into the browser. Client code must only call `def:pub` / `def:protect` endpoints (Jac bridges them over RPC). Graph queries (`[x -->][?:Node, field]`), `grant`, `AccessLevel`, `root.shared`, seeding and `by llm` agents stay in server-only modules that the client never imports directly. Errors E5097 / E5101 mean server code leaked into the client. See `jac guide jac-codespaces` and `jac-fullstack-patterns`.
- While her server is running, you may test screens with `jac browse open localhost:8000`, then `snapshot`, `click @e5`, `fill '#field' text`, `screenshot`, `close`.
- Do not use old Jac syntax from memory; trust `jac guide` over what you remember.

## AI (byLLM) rules, learned in the spike
- The model is set in `jac.toml` under `[byllm.model]` (`default_model = "claude-haiku-5-5"`); the key comes from `ANTHROPIC_API_KEY`. After adding it, run `jac install` once.
- **Never set `temperature`.**
- Every `by llm` function, parameter, `obj` and field gets a `sem` line. Tools need `sem` on the tool and each parameter.
- AI functions return `obj`s. Copy results into nodes **only after a human confirms**.
- Totals, sold-out checks and allergy filters are computed **by code**, never trusted from the AI.
- Every agent tool appends a short line to a steps list; the screen shows it as "What I checked".
- Wrap every AI call in `try/except` and show a friendly message on failure. The app must still work without AI.
- Tests for agents use `MockLLM` (no API cost). Queue the tool calls **plus one extra final output**. Put `glob llm = MockLLM(...)` **after** the `obj`s it uses.
- Waiter `sem`: choose enough food for the group (about 1½ dishes per person, plus dessert or drinks if the budget allows) and use most of the budget without going over.
- Menu agent `sem`: dishes named Mixed, Seafood or Special may contain shellfish: tag `shellfish` and set `confident = false` unless the menu says otherwise.

## How to work
- **One user story at a time**, in the order of `docs/05-user-stories.md`. Before coding, show a short plan (files, what changes, how each test will pass). Wait for "ok" if more than 2 files change.
- Build the smallest version that passes the story's tests, then stop and report:
  - **Done:** what works
  - **Check it:** exact clicks to test it in the browser
  - **Not done:** anything left
- Suggest a git commit message when a story works, for example `feat(G-04): AI waiter plans orders with tools`.
- Do not add features that are not in the current story. New ideas go to the "Later" list in README.md.
- Keep files under about 250 lines, following the folder plan in `docs/07-architecture.md`.

## Rules that must never break
- **At least 80% of the code is Jac.** Styling goes through Jac (theme file / Tailwind setup per `jac guide jac-cl-styling`), not large separate CSS or JS files.
- **Never** put API keys or passwords in code or files that go to GitHub.
- Never commit `.jac/` build folders or `.env` files (keep them in `.gitignore`).
- No raw error messages on screen.
- Allergy tags are always visible to guests and the kitchen.
- Uploaded files are saved outside the folders `jac run --dev` watches (otherwise the app reloads during uploads).
- Several independent AI calls (e.g. one per photo) run in parallel, with progress shown on screen and the button disabled while working.

## Plan format (always)
Every plan must end with these sections, in simple words, one line per item:
- **Changes from your prompt**: anything you do differently from what was asked, or add, and why.
- **Assumptions and risks**: anything you are guessing or can't test yourself.
- **Check it**: the click-through steps for Nethma in Chrome.

## Live screens
- Guest screens re-check anything the manager can change (music mode, sold out, published menu) in their 3 s refresh, and adapt without a reload.
- While saving, keep the current content on screen and update the changed control straight away; never swap the whole page for a loading state (it makes the page jump).

## Many restaurants, one app
- Never pick "the" restaurant (e.g. the first Restaurant on root.shared). Manager functions find it through the caller's Manages edge; guest functions through the table code.
- Every colour comes from core/theme.jac. No hex or rgba values in pages/ or ui/ (keeps dark mode possible).
- Every button that sends something is disabled while working; the server also refuses an identical order from the same table within 10 seconds.
- Guests see only their table's current session (after "Clear table" the next guests never see old orders). Old data is kept as history, never deleted.
