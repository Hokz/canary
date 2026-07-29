# 00 — Heart of Destruction Quest Bible

Package: HOD-02, updated by HOD-03. Read-only audit against `data-otservbr-global/` on branch `ai-dev/hod-02-quest-bible-contracts` (based on `main` @ `baba6c0d7`, which already includes the HOD-01 World Devourer cooldown fix from PR #4).

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
