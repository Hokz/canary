# 08 — Quest QA Checklist (Owner-Facing Template)

This is the template every AI agent must fill out and hand to the project owner before a quest package can be considered tested. Written for a **non-technical reader** — no code, no file paths, no storage names. Copy this template into the specific package's PR description or a companion doc, filled in per-quest.

---

## How to use this checklist (instructions for the owner)

1. Follow each numbered step **in order**, on a real character on a running server.
2. After each step, compare what actually happened to the "Expected result" line.
3. Mark ✅ if it matches, ❌ if it doesn't (write down exactly what happened instead).
4. If you see a red error message in the server console/log (not visible to your character, but visible to whoever runs the server), copy/paste it even if you don't understand it — it's very useful for a fix.
5. Send the filled-in checklist back — that's what triggers the next step (merge, or another fix attempt).

---

## Template — copy per quest

### Quest: `<Quest Name>`

**What this quest is about (1-2 sentences, plain language):**
`<...>`

**What changed in this package:**
`<e.g. "Fixed: talking to the NPC after destroying the Nexus now advances the quest instead of doing nothing.">`

**Where to start:**
- Character level/vocation needed (if any): `<...>`
- Starting position or NPC: `<...>`
- Any items you need beforehand, and where to get them: `<...>`

**Steps to test:**

| # | Action | Expected result | ✅/❌ | Notes |
|---|---|---|---|---|
| 1 | `<e.g. "Talk to Henricus in Thais, say 'hi' then 'mission'">` | `<e.g. "He gives you a flask and tells you to destroy the Shadow Nexus">` | | |
| 2 | `<...>` | `<...>` | | |
| 3 | `<...>` | `<...>` | | |

**Edge cases to also check (if relevant to this fix):**
- `<e.g. "Try this with a second character nearby at the same time — does it still work?">`
- `<e.g. "Try saying the wrong keyword first — does the NPC respond sensibly instead of silence?">`

**Rewards to verify (if any):**
- Item(s) received: `<...>`
- Quest Log entry appears/updates correctly: `<...>` (open your Quest Log in-game and check)

**If something goes wrong:**
- What to note: exact position (coordinates, visible via the in-game "look" or a `/pos`-style command if you have GM access), exact words you said to the NPC, exact error text if any appeared on screen or in server logs.
- Who to report back to: `<the AI agent / session that produced this package>`

---

## Notes for the AI agent filling this out

- Every row in "Steps to test" should be something the owner can literally do with a mouse/keyboard, no interpretation required.
- Use in-game language for expected results ("he gives you a flask", not "storage set to 21").
- If a step requires a state the owner can't reach through normal play (e.g. deep into a 20-mission questline), say so explicitly and either provide a shortcut (if server admin tools allow) or accept that this step needs agent-side verification instead of owner testing.
- Keep the checklist as short as it can be while still covering the actual fix — a 3-step checklist that precisely targets the reported bug is better than a 30-step full quest walkthrough, unless the package is a full new-quest implementation (in which case, walk the whole quest).
- For bug fixes, always include the *original reported repro steps* as the first entries — the owner (and #599/#618 reporters) described these precisely; reuse their wording.
