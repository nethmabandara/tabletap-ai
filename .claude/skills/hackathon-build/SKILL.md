---
name: hackathon-build
description: Step-by-step procedure for building one TableTap AI user story (IDs like S-01, M-02, G-04, K-01, MU-01) during the hackathon. Use whenever asked to build, add, fix or finish a story or feature.
---

# Build one story

## 1. Understand (2 minutes)
- Find the story ID in `docs/05-user-stories.md`. Read that story and its Given/When/Then tests only.
- Check `docs/03-project-brief.md`: if it is "Should" or "Could" while a "Must" story is unfinished, say so and ask first.
- Look up only the matching nodes in `docs/06-data-model.md`, functions in `docs/07-architecture.md`, and the screen's mockup in `docs/mockups/`.
- Read the relevant `jac guide` pages before writing unfamiliar Jac.
- Look at existing code first. Reuse, don't duplicate.

## 2. Plan (show before coding)
In plain words:
- files to create or change
- new nodes, functions or screens
- how each Given/When/Then test will pass
- how Nethma checks it in the browser
End with the three sections from AGENTS.md "Plan format": Changes from your prompt,
Assumptions and risks, Check it. Before showing the plan, check it yourself against
docs/14-plan-review-card.md and fix any red flag you can.
If more than 2 files change, wait for "ok".

## 3. Build in this order
1. Data (nodes, edges) in `core/models.jac`
2. Server functions (`def:pub` for guests, `def:protect` for the manager)
3. Agent functions in `core/agents.jac` (typed `obj` result, `sem` everywhere, tools that log steps, `try/except`, no temperature)
4. Screen in `ui/`, matching its mockup and the theme
5. Tests in `core/*.test.jac` (`MockLLM` for agents)

## 4. Check
- `jac check .` with zero errors
- `jac test` passes
- Start `jac run --dev main.jac` briefly and confirm the client build compiles with no `✖ Error` lines (E5097/E5101 = server code imported by the client; keep graph queries, grant and agents server-only and call them through def:pub), then stop it
- Ask Nethma to run `jac run` in a second window and click through the story's tests in the browser
- Tick each Given/When/Then line: met, or not met and why

## 5. Report
- **Done:** what now works
- **Check it:** exact steps in the browser
- **Not done:** anything left
- **Commit:** a suggested message like `feat(K-01): kitchen board with status buttons`

## Do not
- Leave a server running yourself
- Build extra features or change unrelated files
- Set `temperature`, hard-code API keys, or show raw errors
- Let the AI save anything before a human confirms
