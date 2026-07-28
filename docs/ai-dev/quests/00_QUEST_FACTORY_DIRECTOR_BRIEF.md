# 00 — Quest Factory Director Brief

Status: Docs + Audit phase only. No quest code has been implemented or modified as part of this package.

## 1. Purpose

This directory (`docs/ai-dev/quests/`) is the control center for an AI-assisted workflow that implements and fixes Tibia-style quests inside the Canary server (`opentibiabr/canary`). It exists because:

- The project owner is **non-technical**: he defines priorities, provides references (TibiaWiki BR, in-game testing), and approves results — but does not read Lua/C++ diffs directly.
- Quest work touches live gameplay content (NPC dialogue, storages, map action/unique IDs, boss mechanics). Mistakes are easy to make silently (e.g. a wrong storage value breaks a quest without throwing any Lua error) and hard for a non-technical owner to catch without a checklist.
- AI agents need a **repeatable, auditable process** so that quest work can scale beyond one conversation, one agent, or one session without losing consistency (naming, storage ranges, testing rigor).

## 2. Roles

**Project owner (human, non-technical)**
- Sets priorities: which quest package to work on next.
- Supplies references: TibiaWiki BR pages, screenshots, personal quest knowledge.
- Tests in-game on a running server and reports pass/fail against the checklist in [[08_QUEST_QA_CHECKLIST]].
- Approves the final result before merge (reviews the owner-facing summary, not the diff).
- Never expected to read Lua, run the audit pipeline, or resolve storage conflicts personally.

**AI agent (Lead Autonomous Developer / Quest Factory contributor)**
- Runs the audit pipeline described here before touching any quest.
- Follows [[06_QUEST_IMPLEMENTATION_PROTOCOL]] for every implementation or fix.
- Follows [[07_QUEST_NPC_DIALOGUE_PROTOCOL]] for anything that writes NPC dialogue.
- Updates [[04_QUEST_STORAGE_REGISTRY]] and [[05_QUEST_IMPLEMENTATION_STATUS]] as part of every quest PR — never leaves them stale.
- Produces an owner-facing test checklist ([[08_QUEST_QA_CHECKLIST]]) for every package, written in plain language (positions, expected messages, expected items) — not code terms.
- Never merges, pushes, or force-actions anything the owner hasn't approved.

## 3. What this package is (and is not)

**Is:**
- A documentation and audit set describing how quests currently work in this repository, what's broken, what's missing, and how to work on quests safely going forward.
- A storage registry proposal to prevent collisions in future quest work.
- A prioritized roadmap for the first 10 quest packages.

**Is not:**
- Quest code. No `src/`, Lua scripts, NPC files, map files, or `schema.sql` were modified to produce this package.
- A guarantee that every listed bug/quest is fully diagnosed — several findings in [[03_QUEST_ISSUE_599_FIX_AUDIT]] are architectural hypotheses that need **live-server confirmation** before a fix is written.
- Final on scope — [[02_QUEST_ISSUE_618_AUDIT]] and [[05_QUEST_IMPLEMENTATION_STATUS]] are living documents; update them as reality changes.

## 4. Source references

1. Issue tracker — quests to implement/revise: `github.com/opentibiabr/canary/issues/618`
2. Issue tracker — quests that are broken: `github.com/opentibiabr/canary/issues/599` (closed, but the underlying bugs were never confirmed fixed in-repo — see [[03_QUEST_ISSUE_599_FIX_AUDIT]])
3. TibiaWiki BR (`tibiawiki.com.br`) / TibiaWiki Fandom — functional reference for quest flow, missions, NPCs, rewards, item positions. **Functional reference only** — see legal rule below.
4. This repository's own quest implementations (`data-otservbr-global/`) — the primary source of truth for how a "done" quest looks in this codebase.

## 5. Legal / product rule (binding on every future quest PR)

- Public quest wiki pages (TibiaWiki BR, TibiaWiki Fandom) may be used as a **functional reference**: quest steps, mission order, required items, NPC roles, reward tables, map positions.
- **Do not copy long proprietary dialogue or copyrighted quest text verbatim.**
- NPC dialogue must be **functionally faithful** to the quest flow but **paraphrased or written originally**, unless the repository already contains accepted text for that line (i.e. don't rewrite existing accepted NPC scripts just to "improve" wording).
- This rule applies to every future quest implementation/fix PR, not just this audit package. See [[07_QUEST_NPC_DIALOGUE_PROTOCOL]] for the concrete process.

## 6. Guardrails carried over from the audit phase

These are the constraints this specific docs+audit package was built under. They are not necessarily permanent rules for all future work (see [[06_QUEST_IMPLEMENTATION_PROTOCOL]] for what *is* permanent), but they explain why this package looks the way it does:

- No `src/` changes.
- No production Lua script changes (`data/`, `data-otservbr-global/`, `data-canary/`).
- No map file changes.
- No `schema.sql` changes.
- No refactors, no unrelated formatting.
- No commits, no pushes, no PR opened — the owner reviews this package first.

## 7. How to navigate this package

| Doc | Purpose |
|---|---|
| [[00_QUEST_FACTORY_DIRECTOR_BRIEF]] | This file — roles, rules, navigation |
| [[01_QUEST_ARCHITECTURE_AUDIT]] | How quests are actually built in this repo today |
| [[02_QUEST_ISSUE_618_AUDIT]] | Categorized backlog of quests to implement/revise |
| [[03_QUEST_ISSUE_599_FIX_AUDIT]] | Root-cause audit of the 3 priority broken quests |
| [[04_QUEST_STORAGE_REGISTRY]] | Storage/KV naming and range conventions, anti-collision rules |
| [[05_QUEST_IMPLEMENTATION_STATUS]] | Live tracking: what's done, broken, missing |
| [[06_QUEST_IMPLEMENTATION_PROTOCOL]] | Step-by-step process an AI agent must follow to implement/fix a quest |
| [[07_QUEST_NPC_DIALOGUE_PROTOCOL]] | Rules for writing NPC dialogue safely and legally |
| [[08_QUEST_QA_CHECKLIST]] | Owner-facing in-game test checklist template |
| [[09_FIRST_QUEST_PACKAGES_ROADMAP]] | The first 10 quest packages, in priority order |

## 8. Recommended first move

Start with [[09_FIRST_QUEST_PACKAGES_ROADMAP]] Package 1 (the three #599 fixes), because:
- They're explicitly prioritized by the project owner.
- They're bug fixes to *existing* content, not new implementations — smaller blast radius.
- Their root causes are already partially diagnosed in [[03_QUEST_ISSUE_599_FIX_AUDIT]], so the next AI session can go straight to live-server verification instead of re-discovering the code.
