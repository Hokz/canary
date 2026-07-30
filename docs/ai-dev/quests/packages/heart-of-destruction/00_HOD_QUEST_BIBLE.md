# 00 — Heart of Destruction Quest Bible

Package: HOD-02, updated by HOD-03, HOD-04, HOD-05, HOD-FULL. Audit + implementation against `data-otservbr-global/` on branch `ai-dev/hod-full-complete-implementation` (based on `main`, which includes HOD-01 through HOD-05).

## HOD-FULL update summary — full autonomous implementation pass

Unlike HOD-01 through HOD-05 (which deliberately deferred anything requiring invented text or new architecture), HOD-FULL was explicitly authorized by the owner to implement functional systems now, marking exact text as TODO rather than blocking the quest. This package implements every previously-deferred system except the two that are genuinely impossible without a map editor (which now have supporting code + exact placement instructions) and one large-scale code-quality refactor that was judged too risky to rush.

**Newly implemented this package**:
- **Outer vortex access system** — rotation, permanent-access kill tracking, entrance gating. Code-complete; **needs 3 action ids placed on the map** before it's reachable (see [[04_HOD_PORTAL_ACCESS_CONTRACT]] MAP SETUP section).
- **Destructive charges system** — Frenzy/Charged Disruption/Overcharged Disruption kills grant charges (inferred classification, documented); World Devourer repeat-entry now spends 5, using the owner's exact provided text as the denial message.
- **Questlog catalog** — 7-mission entry created with functional (TODO-marked) text, registered and ready.
- **Final battle timing** — mini-boss phase timers changed from 30 to 45 minutes, matching the reference's stated total (a disclosed judgment call on how the 45 minutes splits across phases).
- **Messenger of Heaven "yes"** — now grants the vortex-gating `CaveAccess` storage, with a short TODO-marked placeholder line instead of staying silent.

**Deliberately NOT implemented this package** (see [[09_HOD_SAFE_FIXES_APPLIED]] for full reasoning):
- **Boss-defeat credit attribution hardening** (room-presence vs. participation) — still requires new tracking architecture; attempting this hastily inside an already-large package risked breaking three already-working boss fights simultaneously without live testing between changes.
- **Undeclared-Lua-global hardening** (~20 globals across 6 files) — explicitly flagged in every prior package as needing incremental, individually-tested work; doing it inside this already-large package would compound risk on risk.

No C++ `src/` changes were made or needed — every system above was achievable with the same Lua APIs already used successfully elsewhere in this quest (storages, KV cooldowns, `CreatureEvent`, `GlobalEvent`, `MoveEvent`, the catalog system).

## HOD-05 update summary

HOD-05 was a completion pass across the seven remaining priority areas (questlog/catalog, destructive charges, Devourer Core, World Devourer access, final battle timing, boss credit attribution, storage hygiene). Outcome: **most areas remain correctly deferred** (each blocked on either owner reference text or genuinely new mechanic design, per the package's own strict safe-fix criteria), **two areas were confirmed already-correct with fresh evidence** (Devourer Core, World Devourer access checks), and **one narrow, low-risk code improvement was applied** (storage hygiene — see below). This is a legitimate outcome, not a stall: several previously-open questions are now closed with concrete evidence instead of remaining open-ended.

**Code change applied**: registered 4 previously-unregistered, collision-free storage numbers (`14334`-`14337` — the final battle's per-player team-tracking flags and the reward-claim flag) as `Storage.HeartOfDestructionFinalBattle.*` in `storages.lua`, and updated the 4 consuming files to use the named constants instead of bare numbers. Values are **unchanged** — this is a pure readability/collision-prevention improvement, not a migration. See [[03_HOD_STORAGE_CONTRACT]] and [[09_HOD_SAFE_FIXES_APPLIED]].

**Confirmed already-correct (no change needed)**:
- Devourer Core (`actions_devourer_access.lua`) — re-verified unchanged since HOD-03, still correctly implements the reference's cooldown-reset mechanic.
- World Devourer access checks (`movements_teleport_heart.lua`) — confirmed it enforces cooldown, checks the Eradicator+Outburst completion flags, and (correctly, since the mechanic doesn't exist) does not check any "charges" value.

**Confirmed still deferred, with sharper reasoning than before**:
- Questlog/catalog entry — blocked on both missing mission text (7 of 8 states) and the missing charges mechanic that the one available exact text (charges message) depends on.
- Destructive charges system — confirmed absent via exhaustive search (zero matches for "charges"/"higher minion"/"Devourer Core" as a mechanic beyond the item itself); requires new architecture and an undetermined monster classification ("higher minion of destruction" is not a term used anywhere in this codebase).
- Final battle timing — confirmed the code implements **two independent 30-minute windows** (mini-boss phase, then a fresh World Devourer phase), not a single 45-minute budget; no single value change would fix this without guessing how the owner's 45 minutes should split across phases.
- Boss credit attribution — confirmed still room-presence-based; a real fix requires new damage/participation tracking architecture, which doesn't exist anywhere in this quest today.

## HOD-03 update summary

HOD-03 incorporated a much more detailed owner-provided functional reference (level/premium requirements, exact reward list, exact Messenger of Heaven keyword chain, exact Yana dialogue, per-boss mechanic descriptions, the World Devourer "destructive charges" system, and mount/egg drop notes). Two significant corrections to HOD-02's findings resulted:

1. **The reward chest is fully correct, not partially missing.** All 7 item names were cross-referenced against `items.xml` and match the reference exactly (Spying Eye, Vibrant Egg, Folded Void Carpet, Mysterious Remains, 20 Crystal Coins, 5 Gold Tokens, Energetic Backpack container). "Powerful imbuement access" was never missing from the chest — it's correctly handled as a separate post-quest NPC interaction (Yana), matching the reference's own structure. See [[06_HOD_REWARD_CONTRACT]].
2. **`actions_devourer_access.lua` is not a bug.** Item 23686 is named "devourer core" in `items.xml`, confirming this file correctly implements the reference's "Player can also use Devourer Core to reset the cooldown" mechanic. HOD-02's "possibly inverted logic" flag is retracted. See [[05_HOD_BOSS_MECHANICS_CONTRACT]].

New genuine gap found this pass: **Yana's "worth" dialogue branch was an unfinished draft** — the file contains a literal `-- to do: check if Heart of Destruction was killed` comment, meaning the completion check was never implemented, the imbuement list was incomplete (3 of 8 items), and a stray Lua comment marker (`--`) had leaked into the player-visible string. This was fixed in this package — see [[09_HOD_SAFE_FIXES_APPLIED]].

New genuine gap confirmed missing: the **"5 destructive charges" World Devourer entry-gate system** described in the reference (separate from the cooldown/Devourer Core mechanics) does not exist anywhere in the codebase — no charge-counter storage, no "higher minion of destruction" kill tracking. Documented as a future package, not implemented here (would require new mechanic design, excluded from this package's safe-fix scope).

## Reference status

- **Primary reference** (`tibiawiki.com.br/wiki/Heart_of_Destruction_Quest`): inaccessible, HTTP 403 (attempted twice across two sessions, not retried further per instruction).
- **Alternate references** (`tibia.fandom.com/wiki/Heart_of_Destruction_Quest` and `/Spoiler`): inaccessible, HTTP 402 (attempted once each this session).
- **Working reference**: the project owner's pasted functional summary (this conversation, prior turn), used throughout this package as the authoritative expected-behavior baseline. Where this package's findings go beyond that summary, they are pure repository evidence (file:line), not invented.
- Any expected behavior not covered by the owner's summary and not derivable from code is marked `OWNER_REFERENCE_REQUIRED` in the relevant contract file rather than guessed.

## 1. What this quest is, structurally

Heart of Destruction is a six-boss endgame questline (Anomaly, Realityquake, Rupture, Eradicator, Outburst, World Devourer) reached through a sequence of lever-gated puzzle rooms. Per the owner's reference: three first-tier bosses (Anomaly, Realityquake, Rupture) are reached via rotating outdoor "vortex" portals in Ankrahmun, Svargrond, and Zao, each requiring a one-time 10-kill unlock against a themed extra-dimensional creature; defeating all three first-tier bosses unlocks Eradicator and Outburst; defeating those unlocks the final boss, World Devourer.

## 2. Confirmed implementation reality (repository evidence)

The actual code implements a **different, simpler access model** than the owner's reference describes for the outer layer, while the **inner boss-room layer matches the reference closely**:

| Layer | Reference describes | Repository implements |
|---|---|---|
| Quest start | Talk to Messenger of Heaven | **NPC exists but has zero dialogue logic** — see [[01_HOD_NPC_DIALOGUE_CONTRACT]] |
| Outer access | Rotating vortex in 3 cities, 2-hour rotation | **Not found anywhere in the codebase** — see [[04_HOD_PORTAL_ACCESS_CONTRACT]] |
| Permanent route unlock | Kill 10 themed creatures per route | **Not found anywhere in the codebase** — see [[04_HOD_PORTAL_ACCESS_CONTRACT]] |
| First-tier boss levers (Anomaly/Rupture/Realityquake) | Path-specific minigame before each boss | **Implemented**, using `BossLever` + a bespoke pre-boss minigame per path — see [[05_HOD_BOSS_MECHANICS_CONTRACT]] |
| Boss unlock chain (3 first-tier → Eradicator/Outburst → World Devourer) | Sequential unlock | **Implemented**, storage-flag-gated — see [[04_HOD_PORTAL_ACCESS_CONTRACT]] |
| Boss room rules (5 players, 15 min, cleanup) | Matches | **Implemented and matches** for the first-tier rooms — see [[05_HOD_BOSS_MECHANICS_CONTRACT]] |
| Cooldowns (20h normal, 13d20h World Devourer) | Matches | **Implemented and matches** — 20h confirmed via server default config for all `BossLever` bosses; World Devourer's 13d20h fixed in PR #4 — see [[05_HOD_BOSS_MECHANICS_CONTRACT]] |
| Reward | Energetic Backpack + items + currency + achievement + imbuement access | **Mostly implemented**; imbuement access not found — see [[06_HOD_REWARD_CONTRACT]] |
| Questlog | Mission tracking visible in Quest Log | **Not implemented** — reserved storage table is empty, no catalog entry — see [[02_HOD_QUESTLOG_CONTRACT]] |

## 3. Path-to-boss mapping (corrected from an earlier same-session finding)

Cross-referencing the pre-boss minigame monster themes against the owner's reference resolved the exact mapping:

| Owner-reference city | Owner-reference boss | Pre-boss minigame (repo) | Minigame lever file |
|---|---|---|---|
| Ankrahmun | Anomaly | Charger / Overcharge | `actions_charges_lever.lua` |
| Zao | Rupture | Crackler / polarity-tile vortex | `actions_cracklers_lever.lua` + `movements_vortex_crackler.lua` |
| Svargrond | Realityquake | Unstable Spark | `actions_sparks_lever.lua` (spawns "Unstable Spark"); boss lever itself is `actions_foreshock.lua` (Realityquake's boss is internally named "Foreshock"/"Aftershock" in its two-phase fight) |

## 4. Files inventoried this pass

- 38 quest scripts under `data-otservbr-global/scripts/quests/heart_of_destruction/` — all read in full or in representative depth across this and the prior gap-analysis session.
- 25 monster files under `data-otservbr-global/monster/quests/heart_of_destruction/` — enumerated, not individually read (combat stats out of scope; mechanics traced via the action/creaturescript files that reference them).
- `data-otservbr-global/npc/messenger_of_heaven.lua` and `lesser_messenger_of_heaven.lua` — both read in full.
- `data/libs/functions/boss_lever.lua` — read in full to settle the cooldown-mechanism question authoritatively.
- `config.lua.dist` — checked for the server's default boss cooldown value.
- `data-otservbr-global/lib/core/storages.lua` — both the `GlobalStorage.HeartOfDestruction` block and the empty `Storage.Quest.U10_94.HeartOfDestruction` reservation.
- `data-otservbr-global/lib/core/quests/catalog/` — confirmed no Heart of Destruction entry among the (now 51+) catalog files.
- `data-canary/` — confirmed no Heart of Destruction or Messenger of Heaven equivalent exists.

Two files live in the HOD quest folder but are **not actually part of this quest**: `movements_teleport.lua` (a generic Edron/Kazordoon/Ankrahmun/Svargrond/Farmine hub-teleport network, unrelated map connectivity) and `movements_ice_crack.lua` (uses `GlobalStorage.IceCrack`, an unrelated mechanic). Noted so future work doesn't mistake them for HOD logic.

## 5. Reading order for the rest of this package

1. [[01_HOD_NPC_DIALOGUE_CONTRACT]] — Messenger of Heaven gap, keyword contract
2. [[02_HOD_QUESTLOG_CONTRACT]] — missing quest log integration
3. [[03_HOD_STORAGE_CONTRACT]] — full storage/KV inventory, registration gaps, undeclared-global risk
4. [[04_HOD_PORTAL_ACCESS_CONTRACT]] — vortex/portal access model, missing outer layer
5. [[05_HOD_BOSS_MECHANICS_CONTRACT]] — per-boss mechanics, room rules, cooldowns (corrected findings)
6. [[06_HOD_REWARD_CONTRACT]] — reward comparison
7. [[07_HOD_QA_GAMEPLAY_CHECKLIST]] — owner-facing test steps
8. [[08_HOD_IMPLEMENTATION_BREAKDOWN]] — future PR scoping
9. [[09_HOD_SAFE_FIXES_APPLIED]] — what this package did and did not change in code
