# 05 — Quest Implementation Status

**This is a living document.** Update it as part of every quest PR — add/change a row when a quest is implemented, fixed, or its status changes. Do not let this drift out of sync with reality; it is the source of truth [[02_QUEST_ISSUE_618_AUDIT]] and [[09_FIRST_QUEST_PACKAGES_ROADMAP]] both point back to.

Snapshot date: 2026-07-28 (audit pass, static code only — no live-server verification performed).

## Status legend

| Status | Meaning |
|---|---|
| `Exists` | Folder/catalog entry found; not verified live |
| `Confirmed working` | Verified live by a community report or this audit's owner testing |
| `Confirmed broken` | Verified broken, root cause documented |
| `Suspected broken` | Reported broken in issue comments, not yet root-caused |
| `Missing` | No matching folder/catalog entry found |
| `Unknown` | Not yet researched |

## 1. Existing quest folders (`data-otservbr-global/scripts/quests/`, 106 total)

Full folder list as of this audit. Cross-reference against [[02_QUEST_ISSUE_618_AUDIT]] for wiki-name mapping.

```
a_pirates_tail, adventures_of_galthen, alawars_vault, an_uneasy_alliance, assassin_outfit,
barbarian_test, behemoth, bigfoot_burden, chayenne_realm, children_of_the_revolution,
cradle_of_monsters, cults_of_tibia, dangerous_depth, dark_trails, dawnport, deeper_fibula,
deeplings_worldchange, demon_helmet, demon_oak, desert_dungeon_quest, devil_helmet, draconia,
dreamers_challenge_quest, druid_outfits_quest, edron_rope, elemental_spheres, extension_mota,
fathers_burden, feaster_of_souls, ferumbras_ascension, forgotten_knowledge, formogar_mine_hoist,
giant_smithhammer, grave_danger_quest, grimvale, heart_of_destruction, hero_of_rathleton,
hidden_threats, hot_cuisine, hunter_outfits_quest, in_service_of_yalahar, killing_in_the_name_of,
kilmaresh_quest, koshei_the_deathless_quest, krailos, lions_rock, liquid_black, marapur,
mintwallin_quest, mysterious_ornate, no_rest_for_the_wicked, oramond, others, parchment_room,
primal_ordeal_quest, raging_mage_tower, roshamuul_quest, rotten_blood_quest,
rottin_wood_and_married_men, sea_of_light, secret_service, soul_war, soulpit, spike_tasks,
spirit_hunters, svargrond_arena, thais_lighthouse, thais_quest, the_ancient_tombs,
the_annihilator, the_ape_city, the_cursed_crystal, the_djinn_war_quest, the_dream_courts_quest,
the_explorer_society, the_first_dragon, the_gravedigger_of_drefia, the_great_dragon_hunt_quest,
the_hidden_city_of_beregar, the_hunt_for_the_sea_serpent, the_ice_islands_quest,
the_inquisition_quest, the_lost_brother, the_new_frontier, the_order_of_lion, the_outlaw_camp,
the_paradox_tower, the_pits_of_inferno_quest, the_postman_missions_quest, the_primal_ordeal,
the_queen_of_the_banshees, the_rookie_guard, the_secret_library_quest, the_shattered_isles_quest,
the_spike_tasks, the_tainted_soul, the_thieves_guild_quest, the_travelling_trader,
the_way_of_the_monk, their_masters_voice, thieves_guild, threatened_dreams, tibia_tales,
tinder_box_quest_chyllfroest, to_blind_the_enemy_quest, too_hot_to_handle_quest,
tower_defence_quest, triangle_tower_quest, troll_sabotage, unnatural_selection, waterfall,
what_a_foolish_quest, white_pearl, wrath_of_the_emperor
```

Note: `spike_tasks` and `the_spike_tasks` both exist, as do `the_thieves_guild_quest` and `thieves_guild` — check whether these are duplicates, an old/new pair, or legitimately distinct content before any future work touches either.

## 2. Questlog catalog entries (`data-otservbr-global/lib/core/quests/catalog/`, 51 total)

```
001_the_queen_of_the_banshees, 002_the_paradox_tower, 003_spike_task, 004_a_father_s_burden,
005_bigfoot_s_burden, 006_children_of_the_revolution, 007_factions, 008_friends_and_traders,
009_hot_cuisine, 010_in_service_of_yalahar, 011_killing_in_the_name_of,
012_outfit_and_addon_quests, 013_sam_s_old_backpack, 014_sea_of_light, 015_secret_service,
016_the_ancient_tombs, 017_the_ape_city, 018_the_beginning, 019_the_djinn_war_efreet_faction,
020_the_djinn_war_marid_faction, 021_the_hidden_city_of_beregar, 022_the_ice_islands_quest,
023_the_inquisition, 024_the_postman_missions, 025_the_shattered_isles,
026_the_thieves_guild, 027_the_travelling_trader_quest, 028_the_explorer_society,
029_the_ultimate_challenges, 030_the_white_raven_monastery, 031_tibia_tales,
032_unnatural_selection, 033_what_a_foolish_quest, 034_wrath_of_the_emperor, 035_oramond,
036_forgotten_knowledge, 037_the_first_dragon, 038_cults_of_tibia, 039_dangerous_depths,
040_adventurers_guild, 041_dawnport, 042_the_rookie_guard, 043_the_new_frontier,
044_spirithunters_quest, 045_threatened_dreams, 046_blood_brothers, 047_grave_danger,
048_the_outlaw_camp, 049_the_secret_library, 050_the_dream_courts, 051_the_way_of_the_monk
```

Note: `soul_war`, `heart_of_destruction`, `ferumbras_ascension`, and several other folders in §1 have **no matching questlog catalog entry** in this list — either they use a different questlog mechanism, predate the catalog system, or are missing questlog integration entirely. Worth a targeted check before assuming any of these quests are questlog-complete.

## 3. Priority tracking — issue #599 quests

| Quest | Status | Root cause doc | Fix package |
|---|---|---|---|
| The Inquisition (Shadow Nexus/Henricus) | Suspected broken — hypothesis documented | [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 1 | Package 1 |
| Wrath of the Emperor (Zizzle) | Suspected broken — hypothesis documented | [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 2 | Package 1 |
| Heart of Destruction | Suspected broken — hypothesis documented | [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 3 | Package 1 |

## 4. Tracking — comment-sourced bugs from issue #618

| Quest | Status | Notes |
|---|---|---|
| The Ape City (Mission 9 teleport) | Suspected broken | Wrong `item.uid`, see [[02_QUEST_ISSUE_618_AUDIT]] §B |
| The Thieves Guild (Black Bert) | Suspected broken | Wrong storage comparison value |
| Svargrond Barbarian Arena | Suspected broken | Reward chests + trophy tile |
| Demon Oak | Suspected broken | Skips 6666-demon requirement |
| Liquid Black | Suspected broken | Missing questlog entry + mine part |
| Lion's Rock | Suspected broken | Trial/tile ordering |
| The Secret Library | Suspected broken | Wrong chest rewards |
| The New Frontier (Wyrdin, Mission 05) | Suspected broken | Keyword dialogue rejects all options |
| Threatened Dreams | Suspected broken | Pile of bones prop; partial PR referenced, unverified |
| Ferumbras' Ascension | Suspected broken | Multiple Lua errors reported (lever, gem puzzle, NPC spawn) |
| Mintwallin Cyclops | Confirmed working | 2020 community comment |
| Kilmaresh | Unknown | Question asked in 2020, never answered |

## 5. How to update this document

When a quest package finishes (see [[06_QUEST_IMPLEMENTATION_PROTOCOL]]):
1. Update the relevant row's status.
2. If a new quest folder was created, add it to §1.
3. If a questlog catalog entry was added, add it to §2.
4. Link the PR/commit if useful for future reference (owner will provide, since AI agents don't merge).
5. Keep the snapshot date at the top current.
