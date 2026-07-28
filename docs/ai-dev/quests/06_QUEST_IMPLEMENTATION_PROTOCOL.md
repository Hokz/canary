# 06 — Quest Implementation Protocol

Binding process for any AI agent implementing or fixing a quest in this repository, after this docs+audit package is approved. This protocol assumes the reader has read [[00_QUEST_FACTORY_DIRECTOR_BRIEF]] and [[01_QUEST_ARCHITECTURE_AUDIT]].

## 1. Before starting any quest work

1. Check [[05_QUEST_IMPLEMENTATION_STATUS]] for the quest's current status. If it says `Exists` but not `Confirmed`, do not assume it's broken or working — verify first.
2. Check [[04_QUEST_STORAGE_REGISTRY]] for any existing storage/KV keys for this quest.
3. Read the quest's existing files fully (if any) before writing anything — many "broken" quests turn out to have correct logic and a bug elsewhere (see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 1 and Bug 3, where the obvious suspect code was actually fine).
4. If working from a TibiaWiki reference, read [[07_QUEST_NPC_DIALOGUE_PROTOCOL]] before writing any NPC dialogue.

## 2. Reproduce before you fix

**Never write a fix based only on static code reading.** The #599 audit found that the two most "obvious" storage-mismatch hypotheses (Bugs 1 and 3) did not hold up under closer static inspection — the real bug required either live reproduction or much deeper tracing. Concretely:
- If you have access to a running dev server, reproduce the reported bug exactly as described (same steps, same NPC dialogue keywords, same positions).
- If you don't have server access, say so explicitly in your output and mark the fix as **unverified** — do not claim a fix is confirmed working.
- Capture the exact Lua console error (if any) — many quest bugs throw silent errors visible only in the server console, not to the player.

## 3. Scope discipline

- Fix or implement **one quest (or one clearly-scoped package, per [[09_FIRST_QUEST_PACKAGES_ROADMAP]]) at a time.** Do not bundle unrelated quests into one PR.
- Do not refactor adjacent code "while you're in there." If you notice an unrelated issue, note it in [[05_QUEST_IMPLEMENTATION_STATUS]] or as a new entry in [[02_QUEST_ISSUE_618_AUDIT]] §B instead of fixing it inline.
- Respect the existing file layout convention (see [[01_QUEST_ARCHITECTURE_AUDIT]] §1, §11) — new quest scripts go in `data-otservbr-global/scripts/quests/<quest_name>/`, named `<type>_<description>.lua`.
- New quest work uses KV (`player:questKV`); fixes to existing legacy-storage quests may touch `Storage.*` per [[04_QUEST_STORAGE_REGISTRY]] Rule 3.

## 4. Storage/KV discipline

Follow [[04_QUEST_STORAGE_REGISTRY]] in full. Minimum checklist for any PR touching storage:
- [ ] No duplicate storage created (searched existing registry first).
- [ ] Per-player state uses per-player storage/KV, never `GlobalStorage`/`Game.setStorageValue` (unless genuinely world-scoped — justify in the PR).
- [ ] Mission-state keys vs. mechanism keys (puzzle/boss/access/cooldown) are kept in separate sub-tables per Rule 6.
- [ ] Registry doc ([[04_QUEST_STORAGE_REGISTRY]]) updated in the same PR.

## 5. Questlog integration

If the quest is meant to appear in the in-game Quest Log:
- [ ] A questlog catalog entry exists under `data-otservbr-global/lib/core/quests/catalog/` (see [[01_QUEST_ARCHITECTURE_AUDIT]] §3 for the module shape).
- [ ] `missionId` is unique across all quests (the catalog loader validates this at startup — a collision will be caught, but check before relying on that).
- [ ] `startStorageId`/`storageId` values point at the actual storage/KV keys the quest scripts use — a catalog entry that references the wrong key will silently never show progress.

## 6. NPC dialogue

Follow [[07_QUEST_NPC_DIALOGUE_PROTOCOL]] in full, especially:
- Always add a fallback/default branch for unhandled state (the #599 audit found this exact gap caused the Zizzle bug).
- Paraphrase wiki dialogue; don't copy verbatim.

## 7. Boss/access work

If the quest involves a boss room or gated access:
- Prefer the `BossLever` library (`data/libs/functions/boss_lever.lua`) over hand-rolled storage-gated portals — it has built-in zone occupancy and cooldown handling that avoids the class of bug found in Heart of Destruction (see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 3).
- If extending an existing hand-rolled system instead of migrating it (smaller, safer change for a bug fix), document why in the PR and flag the quest for a future migration in [[05_QUEST_IMPLEMENTATION_STATUS]].

## 8. Testing and handoff to the project owner

- Every quest package must produce an **owner-facing test checklist** using the template in [[08_QUEST_QA_CHECKLIST]] — plain language, concrete positions/items/messages, no code terms.
- The AI agent does not consider a quest "done" until either (a) it personally verified the fix on a live dev server, or (b) it has handed the owner a complete, unambiguous test checklist and is waiting on their result.
- Do not mark a quest `Confirmed working` in [[05_QUEST_IMPLEMENTATION_STATUS]] until the owner (or the agent, with server access) has actually tested it — a compiling/error-free script is not the same as a working quest.

## 9. Git discipline

- Work on a dedicated branch per package (or per quest, for larger packages) — do not mix multiple quest packages in one branch.
- Do not commit until the owner has reviewed the change (unless the owner has explicitly pre-authorized autonomous commits for a specific package — see the "Autonomous implementation allowed" column in [[09_FIRST_QUEST_PACKAGES_ROADMAP]]).
- Never push or open a PR without explicit approval for that specific change.
- Commit messages should reference the issue (#599, #618) and the specific quest, e.g. `fix: Zizzle (Wrath of the Emperor) missing dialogue fallback (#599)`.

## 10. Rollback readiness

Every quest PR should be revertible independently:
- Keep quest packages scoped so a single `git revert` undoes exactly one package's changes.
- If a fix changes a shared library (`BossLever`, `quest_reward_common.lua`, the questlog runtime) rather than quest-specific files, call this out explicitly — shared-library changes have a wider blast radius and need extra owner scrutiny (see risk/rollback columns in [[09_FIRST_QUEST_PACKAGES_ROADMAP]]).

## 11. Definition of done for a quest package

- [ ] Code changes scoped to the package's quest(s) only.
- [ ] [[04_QUEST_STORAGE_REGISTRY]] updated if storage/KV changed.
- [ ] [[05_QUEST_IMPLEMENTATION_STATUS]] updated with new status.
- [ ] Owner-facing QA checklist produced ([[08_QUEST_QA_CHECKLIST]] template).
- [ ] If NPC dialogue was written, [[07_QUEST_NPC_DIALOGUE_PROTOCOL]] compliance confirmed (no verbatim copy).
- [ ] No unrelated files touched.
- [ ] Owner has tested and approved (or explicit autonomous-implementation authorization was granted for this package).
