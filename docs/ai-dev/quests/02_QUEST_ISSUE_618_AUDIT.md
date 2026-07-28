# 02 — Issue #618 Audit: Quests to Implement or Revise

Source: `github.com/opentibiabr/canary/issues/618` ("Quests that need to be developed or revised"), status **OPEN**, created 2019-11-04, last updated 2026-05-01. Labels: `Type: Bug`, `Priority: Low`, `Area: Datapack Global`, `Area: Map Canary`, `Type: Missing Content`, `Stale`.

The issue body is a giant checklist sourced from `tibia.fandom.com/wiki/Quests` (and its `/Version` breakdown), covering essentially **every quest in Tibia's history**, grouped by era (Newbie Islands, Mainland, Exchange, Addon, Outfit). Only one item in the original checklist is ticked done (`Soul War Quest`). The issue also links two related trackers: `#597` (broken Jakundaf dungeon NPCs/quests) and `#599` (many quests broken — see [[03_QUEST_ISSUE_599_FIX_AUDIT]]).

## Methodology

This audit is a **documentation-only cross-reference**, not a live-server verification pass:

1. The wiki checklist (~250 quest entries) was cross-referenced against the **106 existing quest folders** under `data-otservbr-global/scripts/quests/` (full list in [[05_QUEST_IMPLEMENTATION_STATUS]]) and the **51 questlog catalog entries** under `data-otservbr-global/lib/core/quests/catalog/`.
2. A folder/catalog match means **"quest scripts exist in this repo"** — it does **not** mean the quest is bug-free, complete, or reachable end-to-end. Several quests with existing folders are still reported broken (see #599 and the comment-sourced bugs below).
3. Wiki entries with **no matching folder or catalog entry** are classified `Unknown / needs research` — this audit did not attempt to verify these in-game or against map files, since that requires either running a live server or opening `.otbm` map data, both out of scope for a docs-only pass.
4. Full wiki source text is preserved in the GitHub issue itself — this document does not duplicate all ~250 links verbatim; it organizes by classification and status instead.

## Classification taxonomy (as specified by the project owner)

| Code | Meaning |
|---|---|
| Chest | Simple chest/reward quest |
| Exchange | Exchange quest (trade item for item) |
| NPC | NPC dialogue quest (multi-step conversation, no combat/puzzle) |
| Addon | Addon/outfit quest |
| Multi | Multi-mission questline |
| Access | Access quest (unlocks an area) |
| Boss | Boss/arena quest |
| Puzzle | Puzzle/mechanic quest (levers, gems, tile sequences) |
| Daily | Daily/task quest |
| Unknown | Unknown / needs research |

## A. Quests with existing scripts in this repo (verify, don't reimplement)

These wiki entries have a matching folder in `data-otservbr-global/scripts/quests/` and/or a questlog catalog entry. Treat these as **"fix/verify" work, not "implement from scratch."** Status column reflects only what this audit could determine from static code (folder exists / catalog entry exists) — not in-game testing.

| Quest (wiki name) | Folder / catalog match | Class | Notes |
|---|---|---|---|
| The Queen of the Banshees | `the_queen_of_the_banshees` + catalog `001` | Multi | — |
| The Paradox Tower | `the_paradox_tower` + catalog `002` | Puzzle | Comment (2020): "most/all of the tower area is PZ" — needs live check |
| Spike Tasks / Spike Tasks Quest | `spike_tasks`, `the_spike_tasks` + catalog `003` | Daily | Two folders — check for duplication |
| A Father's Burden | `fathers_burden` + catalog `004` | NPC | — |
| Bigfoot's Burden | `bigfoot_burden` + catalog `005` | Multi | — |
| Children of the Revolution | `children_of_the_revolution` + catalog `006` | Multi | — |
| Hot Cuisine Quest | `hot_cuisine` + catalog `009` | NPC | — |
| In Service of Yalahar | `in_service_of_yalahar` + catalog `010` | Multi | — |
| Killing in the Name of... | `killing_in_the_name_of` + catalog `011` | Multi | — |
| Sam's Old Backpack Quest | catalog `013` (no dedicated folder found) | NPC | Verify script location |
| Sea of Light | `sea_of_light` + catalog `014` | Multi | — |
| Secret Service Quest | `secret_service` + catalog `015` | Multi | Comment (2022): "Works" |
| The Ancient Tombs Quest | `the_ancient_tombs` + catalog `016` | Multi | — |
| The Ape City Quest | `the_ape_city` + catalog `017` | Multi | **Known bug**: wrong `item.uid` in `mission9_the_deepest_catacomb_teleport.lua` (see below) |
| The Djinn War (Efreet/Marid) | `the_djinn_war_quest` + catalog `019`/`020` | Multi | — |
| The Hidden City of Beregar | `the_hidden_city_of_beregar` + catalog `021` | Multi | — |
| The Ice Islands Quest | `the_ice_islands_quest` + catalog `022` | Multi | — |
| The Inquisition Quest | `the_inquisition_quest` + catalog `023` | Multi | **Priority fix** — see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 1 |
| The Postman Missions Quest | `the_postman_missions_quest` + catalog `024` | Multi | — |
| The Shattered Isles Quest | `the_shattered_isles_quest` + catalog `025` | Multi | — |
| The Thieves Guild Quest | `the_thieves_guild_quest`, `thieves_guild` + catalog `026` | Multi | **Known bug**: Black Bert checks wrong storage value (see below). Two folders — check for duplication |
| The Travelling Trader Quest | `the_travelling_trader` + catalog `027` | Exchange | — |
| The Explorer Society Quest | `the_explorer_society` + catalog `028` | Multi | Comment (2022): "Works...but still testing" |
| The White Raven Monastery | catalog `030` (no dedicated folder found) | Multi | Verify script location — feeds into Inquisition questline (Henricus references it) |
| Tibia Tales | `tibia_tales` + catalog `031` | Multi | — |
| Unnatural Selection Quest | `unnatural_selection` + catalog `032` | Multi | — |
| What a Foolish Quest | `what_a_foolish_quest` + catalog `033` | NPC | — |
| Wrath of the Emperor Quest | `wrath_of_the_emperor` + catalog `034` | Multi | **Priority fix** — see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 2 |
| Oramond Quest | `oramond` + catalog `035` | Multi | Has sub-quests `probing`, `the_ancient_sewers` |
| Forgotten Knowledge Quest | `forgotten_knowledge` + catalog `036` | Multi | — |
| Cults of Tibia Quest | `cults_of_tibia` + catalog `038` | Multi | — |
| Dangerous Depths Quest | `dangerous_depth` + catalog `039` | Boss | Comment (2020): "none of the bosses work... most missions aren't working" |
| Dawnport Quest | `dawnport` + catalog `041` | NPC | — |
| The Rookie Guard Quest | `the_rookie_guard` + catalog `042` | NPC | — |
| The New Frontier Quest | `the_new_frontier` + catalog `043` | Multi | **Known bug**: Wyrdin dialogue keyword mismatch, Mission 05 (see below) |
| Spirithunters Quest | `spirit_hunters` + catalog `044` | Multi | — |
| Threatened Dreams Quest | `threatened_dreams` + catalog `045` | Multi | Comment (2022): pile-of-bones prop not working; PR `otservbr-global#633` referenced as partial fix — verify merged status |
| Grave Danger Quest | `grave_danger_quest` + catalog `047` | Multi | Has sub-quest `cobra_bastion` |
| The Outlaw Camp Quest | `the_outlaw_camp` + catalog `048` | NPC | — |
| The Secret Library Quest | `the_secret_library_quest` + catalog `049` | Multi | Comment (2022): unclear if fully developed — some chests reward wrong items |
| The Dream Courts Quest | `the_dream_courts_quest` + catalog `050` | Multi | — |
| The Way of the Monk Quest | `the_way_of_the_monk` + catalog `051` | Multi | — |
| Ferumbras' Ascension Quest | `ferumbras_ascension` | Boss/Puzzle | **Long bug report** (2020, pt-BR) — see below |
| Soul War Quest | `soul_war` | Multi/Boss | Only item ticked done in the original checklist |
| Heart of Destruction Quest | `heart_of_destruction` | Boss/Puzzle | **Priority fix** — see [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 3 |
| Kilmaresh Quest | `kilmaresh_quest` | Multi | Comment (2020) asked if developed, unanswered |
| Mintwallin Cyclops Quest | `mintwallin_quest` | Chest | Comment (2020): confirmed working as-is |
| Demon Oak Quest | (folder for "demon_oak" exists — verify exact match) `demon_oak` | Multi | **Known bug**: Oldrak skips 6666-demon requirement, not tracked in questlog |
| Liquid Black Quest | `liquid_black` | Multi | **Known bug**: missing questlog entry after talking to Spectulus; "mine part" reported broken (`canary#589`) |
| Lion's Rock Quest | `lions_rock` | Puzzle | **Known bug**: trial order / scroll-tile activation issues |
| Roshamuul Quest | `roshamuul_quest` | Multi | — |
| Svargrond Arena / Barbarian Arena | `svargrond_arena`, `barbarian_test` | Boss | **Known bug**: Ultimate Challenge reward chests + trophy tile not working |
| Hero of Rathleton Quest | `hero_of_rathleton` | Multi | — |
| Assassin Outfits Quest | `assassin_outfit` | Addon | — |
| Druid Outfits Quest | `druid_outfits_quest` | Addon | — |
| Hunter Outfits Quest | `hunter_outfits_quest` | Addon | — |
| (~55 more folders exist with clear 1:1 wiki-title correspondence) | see [[05_QUEST_IMPLEMENTATION_STATUS]] full folder list | mixed | Full reconciliation is ongoing — treat §05 as the living source of truth |

## B. Specific bug reports pulled from issue comments (not in #599, but reported directly on #618)

These are concrete, actionable reports left by the community over the years. None have been verified live as part of this audit — treat as a research/fix backlog, one item per future quest package where practical.

| Quest | Report | Class | Source |
|---|---|---|---|
| The Ape City | `mission9_the_deepest_catacomb_teleport.lua:17,26` uses wrong `item.uid` (12129/12130 instead of 9257/9258) | Multi | lmachnicvicz, 2020-08-08 |
| The Thieves Guild | Black Bert (`data\npc\scipts\black_bert.lua:100`, path may have moved) checks `Mission08 ~= 8` instead of `~= 3` | Multi | lmachnicvicz, 2020-08-08 |
| Svargrond Barbarian Arena | Weapon reward chests + trophy tile not working in the three Ultimate Challenges | Boss | Ghelter, 2020-11-08 |
| Demon Oak | Oldrak skips the 6666-task-demon requirement when you say "Demon Oak"; quest not tracked in questlog | Multi | AdversarioV, 2022-06-13 (tested on GM char — re-verify on normal player) |
| Liquid Black | Missing questlog entry after talking to Spectulus | Multi | rigis1, 2022-06-23 |
| Liquid Black | "Mine part" not working, referenced `canary#589` | Multi | AdversarioV, 2022-07-14 |
| Lion's Rock | 3-trial order and 4-tile scroll activation may have incorrect ordering requirements vs. wiki (wiki says order shouldn't matter) | Puzzle | rigis1, 2022-06-27 |
| The Secret Library | Some chests give "doors" as rewards instead of intended items (e.g. "ebony piece" in Asura Palace) | Multi | AdversarioV, 2022-07-14 |
| The New Frontier | Mission 05 ("Getting Things Busy") — Wyrdin dialogue rejects all listed keywords (Flatter/Threaten/Impress/Bluff/Reason/Plea) | Multi | matuopm, 2024-01-15 |
| Threatened Dreams | Pile of bones prop beside sleeping wolf non-functional; partial fix referenced in `otservbr-global#633` — status of merge unverified | Multi | AdversarioV, 2022-06-13 |
| Ferumbras' Ascension | Long multi-part report (pt-BR): NPC Mazarius doesn't spawn at documented position; `Lua Script Error` on `plagirath_lever.lua` (`table index is nil` in `setStorageValue`) and `zamulosh_lever.lua` (same error); most left-side doors in the lever room don't open; a boss's `creaturescripts` event reported as unknown despite file/registration existing; colored-tile puzzle (`blue_gem.lua`, `red_gem.lua`, `green_gem.lua`) throws `attempt to index local 'leverFirst'/'leverSecond' (a nil value)` — suggests a shared state table is never initialized before the movement scripts read it | Boss/Puzzle | lurkgabriel, 2020-06-04 |
| Royal Rescue Quest | "Much of the quest does not work, the scripts generate errors and don't follow the quest" (no folder match found in this audit — needs a name-search pass, may be filed under a different internal name) | Unknown | cmaleister, 2019-11-12 |
| Grave Danger | Asked if also broken (no detail given) | Unknown | alisonjf, 2020-04-15 |

## C. Wiki entries with no matching folder or catalog entry — `Unknown / needs research`

The remaining wiki checklist entries (roughly 150+ items, mostly pre-6.1 "classic" Mainland quests, the full Newbie Islands list, and the alphabetic Addon/Outfit lists for post-9.x content) have **no obviously matching folder name** in `data-otservbr-global/scripts/quests/`. This does **not** mean they're unimplemented — some classic quests are wired directly via map action/unique IDs and generic scripts (`actions/other/others/quest_system1.lua`/`quest_system2.lua`, the generic `quest_door.lua`, the generic reward-chest table in `startup/tables/chest.lua`) rather than a dedicated quest folder, so a live-server check is required before assuming any of these are missing.

Representative groups (see the original issue for the full linked list):
- **Newbie Islands** (14 quests: Bear Room, Captain Iglues Treasure, Child of Destiny, Combat Knife, Doublet, Dragon Corpse, Goblin Temple, Katana, Minotaur Hell, Rapier, Sanctuary of the Lizard God, Tutorial, + 2 more) — `Unknown`, likely `Chest`/`NPC` class once researched.
- **Newbie Islands Exchange** (6 quests: Pick, Present, Short Sword, Small Health Potion, Studded Legs, Studded Shield) — `Unknown`, class `Exchange`.
- **Newbie Islands Addon** (2 quests: Citizen/Druid Outfits on Rook) — `Unknown`, class `Addon`.
- **Classic Mainland quests, pre-8.0** (~90 quests: Battle Axe, Blood Herb, Circle Room, Crusader Helmet, ... through Behemoth, Parchment Room, The Queen of the Banshees-era content) — mixed `Chest`/`Multi`/`Puzzle`, needs per-quest research. Note: Blood Herb, Pits of Inferno both reported "Works" per AdversarioV 2022-06-13 comment even though not folder-matched by name in this pass — likely filed under a different folder name (`parchment_room` exists; "Pits of Inferno" matches `the_pits_of_inferno_quest` which *was* missed by the initial fuzzy match — re-run a stricter match before starting implementation work).
- **8.x–9.x Mainland quests** (~60 quests: Barbarian Arena/Test, Formorgar Mines, Ice Islands-adjacent, Nomads Land, Secret Service-adjacent, Waterfall, etc.) — many already matched in section A; remainder `Unknown`.
- **10.x+ Mainland quests** (~35 quests: Cartography 101, Nightmare Teddy, The Great Dragon Hunt, The Lost Brother, The Tainted Souls, Ferumbras' Ascension-adjacent, Krailos, Feaster of Souls, The Order of the Lion, A Pirate's Tail, Adventures of Galthen, Too Hot to Handle, 25 Years of Tibia, Primal Ordeal, Within the Tides) — mostly already matched in section A via folder names (`krailos`, `feaster_of_souls`, `the_order_of_lion`, `a_pirates_tail`, `adventures_of_galthen`, `too_hot_to_handle_quest`, `primal_ordeal_quest`); remainder `Unknown`.
- **11.x–15.x Mainland quests** (~20 quests: Rotten Blood, Dragon Slayer Outfits, 20 Years a Cook, Podzilla, No Rest for the Wicked, Mystery of the Valley, The Way of the Monk-adjacent, Bloody Tusks, Between the Lines, The Roost of the Graveborn, The Order of the Stag, Targuna) — several already matched (`rotten_blood_quest`, `no_rest_for_the_wicked`); remainder `Unknown`.
- **Mainland Exchange Quests** (5: generic Exchange Quests page, Marlin Trophy, Obsidian Knife, The Mermaid Marina, The Sweaty Cyclops) — `Unknown`, class `Exchange`.
- **Mainland Addon Quests** (11: one per vocation, classic outfits) — `Unknown`, class `Addon`.
- **Mainland Outfit Quests** (~40: Afflicted through Yalaharian, post-9.x outfits) — several already matched (`in_service_of_yalahar`, `liquid_black`, `the_inquisition_quest` for Hand of the Inquisition-adjacent, `what_a_foolish_quest`); remainder `Unknown`, class `Addon`.

**Recommendation**: before starting new-quest implementation work from this bucket, re-run a stricter automated name match (this audit's matching was manual and time-boxed) and spot-check 3-5 "Unknown" entries live in-game to calibrate how much of this bucket is actually missing vs. just filed under an unexpected folder/script name.

## Cross-reference: #597 (Jakundaf dungeon)

Issue #618 links `#597` ("Broken Jakundaf dungeon NPCs/quests") as related but unchecked. This audit did not separately investigate #597 — flag for a future audit pass if the owner wants Jakundaf dungeon prioritized.

## Summary counts (approximate, from this audit pass)

| Bucket | Approx. count |
|---|---|
| A — folder/catalog match exists (verify or fix) | ~60 |
| B — specific bug reported in comments | 12 |
| C — no match found, needs research | ~150+ |

These are directional, not exact — see [[05_QUEST_IMPLEMENTATION_STATUS]] for the maintained live count.
