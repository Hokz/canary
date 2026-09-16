# Weapon Proficiency (Protocol 15.11) - Server Guide

This document explains the Weapon Proficiency system introduced in [PR #3845](https://github.com/opentibiabr/canary/pull/3845), including:

- how it works
- where to edit data
- how `config.lua` changes behavior
- how weapon proficiency source precedence works (protobuf vs `items.xml`)
- common troubleshooting steps

This guide is focused on Canary server behavior.

## 1. Scope of PR #3845 (high level)

Main additions in this PR:

- Weapon Proficiency system (experience, perk selection, mastery, combat effects, persistence)
- New proficiency data files: `data/items/proficiencies/` (one per weapon category)
- New proficiency metadata in assets protobuf (`proficiency_id` in appearances)
- Optional weapon proficiency override in `items.xml` using `<attribute key="proficiency" value="..."/>`
- New catalyst items and helper scripts for adding weapon proficiency XP
- New imbuement-related content (including imbuement scroll flow)

## 2. Core files

Main implementation files:

- `src/creatures/players/components/weapon_proficiency.hpp`
- `src/creatures/players/components/weapon_proficiency.cpp`
- `src/enums/weapon_proficiency.hpp`
- `data/items/proficiencies/` (+ `tools/proficiency_split.py`)
- `src/items/items.cpp` (protobuf proficiency load)
- `src/items/functions/item/item_parse.cpp` (XML proficiency override)
- `src/server/network/protocol/protocolgame.cpp` (window/update packets)
- `src/io/functions/iologindata_load_player.cpp` and `src/io/iologindata.cpp` (load/save persistence)
- `config.lua.dist` + `src/config/configmanager.cpp` (config options)

Related Lua API/scripts:

- `src/lua/functions/creatures/player/player_functions.cpp` (`Player:addWeaponExperience`)
- `src/lua/functions/items/item_type_functions.cpp` (`ItemType:isWeapon`)
- `data/scripts/lib/proficiency_helper.lua`
- `data/scripts/talkactions/god/weapon_proficiency.lua`
- `data-otservbr-global/scripts/actions/object/proficiency_catalyst.lua`
- `data-otservbr-global/scripts/actions/object/greater_proficiency_catalyst.lua`

## 3. Data source precedence for weapon proficiency IDs

Weapon proficiency ID on each item is resolved in this order:

1. Baseline/default from protobuf appearances (`appearances.dat` -> `proficiency_id`)
2. Optional override from `items.xml` (`<attribute key="proficiency" value="..."/>`)

Important:

- protobuf is the default source
- XML has higher precedence when that attribute is present and valid
- if XML attribute is missing, protobuf value remains active

Validation:

- unknown/invalid proficiency IDs are ignored and logged
- item keeps previous valid value (or zero if none is valid)

## 4. Startup and runtime flow

### Startup

1. Server loads every `*.json` under `data/items/proficiencies/` (all 420 proficiencies, `_orphaned.json` included; only the schema file is skipped)
2. Server loads `appearances.dat` and assigns protobuf `proficiency_id` to item types
3. Server loads `items.xml`, optionally overriding per item with `key="proficiency"`

### Reload

`/reload proficiencies` (also `proficiency`, `weaponproficiency`) re-runs step 1,
then reconciles and re-applies every online player. Steps 2 and 3 are not re-run,
so an id that does not yet exist on an item still needs `/reload items`.

### Player load/save

- On login init: weapon proficiency state is loaded from KV scope `weapon-proficiency`
- On save/logout: full state is persisted back to KV

### Gameplay flow

- Equipping left-hand weapon:
  - clears current proficiency-derived cached stats
  - applies selected perks for equipped weapon
  - sends current proficiency status to client
- Unequipping:
  - clears applied proficiency cached stats
  - sends proficiency update

### Combat/xp

- XP is awarded on monster kill, based on:
  - bosstiary rarity
  - bestiary stars
- Perk effects are applied in combat pipeline (crit, elemental crit, bestiary bonus, powerful foe bonus, life/mana gains, skill percentage bonuses, etc.)

## 5. Editing `data/items/proficiencies/`

Proficiencies are split into one file per weapon category — `sword.json`,
`axe.json`, `club.json`, `bow.json`, `crossbow.json`, `wand.json`, `rod.json`,
`fist.json`, `throwing.json` — so a balance pass only opens the file for the
weapons it is about. `_orphaned.json` holds ids that no item currently
references; it is still loaded, so an `items.xml` override can name one of
them, but it is kept apart so those ids do not clutter a real category.

Each file is an object with `Category` and a `Proficiencies` array. Each entry:

- `ProficiencyId` (server-required) — the only real link to a weapon
- `Levels` (server-required array; the server uses array order, not the `Level` field)
- `Levels[].Perks` (array of selectable perks at that level)
- `Name`, `Weapon`, `Version`, `Level`, `TypeName`, `SkillName`, `AugmentName`,
  `Unit` — documentation only, ignored by the server, kept honest by the validator

Basic example:

```json
{
  "$schema": "./proficiencies.schema.json",
  "Category": "Sword",
  "Proficiencies": [
    {
      "ProficiencyId": 999,
      "Name": "Custom Test Profile",
      "Weapon": ["test blade"],
      "Version": 1,
      "Levels": [
        {
          "Level": 1,
          "Perks": [
            { "Type": 0, "TypeName": "ATTACK_DAMAGE", "Value": 1, "Unit": "flat" }
          ]
        }
      ]
    }
  ]
}
```

### Applying a balance change on a running server

```
/reload proficiencies
```

The command re-reads every file under `data/items/proficiencies/` and re-applies
the perks of every online player, so an edit takes effect without a restart and
without anyone relogging.

It is safe to run against a file you just edited by hand: the new data is parsed
into a separate map and only published once every file has parsed. A syntax
error or a malformed entry logs `Failed to reload: Weapon proficiencies` and
leaves the server on the data it already had.

Every online player is reconciled against the new data the same way a login
reconciles them: the experience is clamped to the new maximum, `mastered` is
recomputed, and a stored selection pointing at a level or a perk index your edit
removed is dropped. Nothing faults, and nothing stale is written back by the
next save.

## 5.1 Perk shaping — `data/items/proficiencies/shaping/`

The Summer Update 2026 (15.30) lets a player replace the perk in up to two slots of
a weapon's proficiency tree, then refine, reshape or clear it. All of it is driven by
`shaping.json`: costs, requirements, which effects may be rolled and what each is
worth at every rank. Changing any of that is a data edit followed by
`/reload proficiencies` — never a rebuild.

If the file is absent the feature is simply off, and the server logs
`Weapon proficiency shaping is not configured`. It is loaded and published in the
same step as the proficiency tree, so a broken `shaping.json` leaves *both* the tree
and the previous rules untouched.

### The four operations

| Operation | What it does |
|---|---|
| **Shape** | Replaces the slot's perk with a rolled effect, at rank 0 (its lowest value) |
| **Refine** | Raises that perk's rank one step, up to the option's maximum |
| **Reshape** | Offers `Reshape.OptionCount` alternatives at the current rank; keeping the current one is always allowed |
| **Clear** | Restores the slot to the perk the proficiency file defines |

`Slots` is listed in order from `Slot: 0` and the engine addresses slots by position,
so the order is part of the contract — the loader refuses a file that numbers them
any other way. Per the official behaviour, the first slot needs a proficiency level
and the second needs the weapon mastered.

`Refine.DustCostPerRank` is indexed by the rank being *bought*: entry 3 is the cost
of going from rank 2 to rank 3, and entry 0 is unused. It must be at least as long
as the longest `ValuePerRank`, or the top ranks could never be bought — the validator
fails on that.

`Options[].ValuePerRank` is indexed by rank, entry 0 being what a freshly shaped slot
rolls. Tables may differ in length, so each option carries its own maximum rank.
Values must never decrease as the rank rises. `Weight` is the relative draw chance
and must be above 0.

> The numeric values shipped today are **placeholders** for everything the update
> notes do not state outright. Sourced: two slots, 250 dust at proficiency level 3,
> 1000 dust at mastery, rank 0 on a fresh shape, three reshape options, a rising
> refine curve, protection zone only. Everything else — the refine curve itself, the
> reshape and clear costs, the option list and every value — is waiting on the
> official Perk Shaping Options table.

### How a shaped perk is stored

A normal selection is a `(level, index)` pair and the perk is rebuilt from the
proficiency file on every read, which is what makes `/reload proficiencies` safe. A
shaped perk is not in any file, so it is the one thing stored whole in the player's
KV and read back whole. Two consequences:

- Its enums are validated on load (`hasValidPerkEnums`). A shaped perk that fails
  validation is demoted to a normal selection, so the slot falls back to whatever the
  file defines there rather than applying unchecked values.
- It still has to occupy a slot the file still has. If a balance pass deletes the
  level or the perk it was shaped over, the shaped perk goes with it, exactly like
  any other selection.

### Before committing a balance change

```
python -m tools.proficiency_split validate
```

It checks that every label matches the number it describes, that `SkillId` is a
valid `CipbiaSkills_t` (an invalid one makes the server drop the perk silently),
that `Unit` matches the type, and that any proficiency present in two category
files is identical in both.

### Units

`Unit` tells you how `Value` is read, which is the easiest thing to get wrong:

- `flat` — absolute amount (skill points, mana/life restored, perfect-shot damage, tiles of range)
- `percent` — a fraction, so `0.10` is 10%. Writing `10` means 1000%.
- `milliseconds` — only `SPELL_AUGMENT` with `AugmentType: 6` (cooldown), always negative

### A proficiency used by two categories

A few ids are shared by weapons of different categories (for example the
Inferniarch bow and arbalest, or the replica wands and rods). Those entries are
written in full into both files so each file stands alone. The server keeps the
first file it reads (files are read in sorted order) and skips the rest, so
**the copies must stay identical** — edit both, and let the validator confirm
it. Nothing in the server checks this; `python -m tools.proficiency_split
validate` does, and the Repository Audit CI job runs it on every change to the
data.

Common perk fields:

- `Type` (required)
- `Value` (required)
- optional by perk type:
  - `SkillId`
  - `SpellId`
  - `AugmentType`
  - `DamageType` for specialized magic level perks
  - `ElementId` for elemental hit/critical perks
  - `BestiaryId`
  - `BestiaryName`
  - `Range`

If protobuf references a proficiency ID that does not exist in these files, the protobuf value is ignored. If an XML override references an unknown or invalid proficiency ID, only that override is ignored; any previously loaded valid protobuf value remains active.

## 6. Proficiency bonus type IDs (`Type`)

Defined in `src/enums/weapon_proficiency.hpp`:

- `0` attack damage
- `1` defense bonus
- `2` shield modifier
- `3` skill bonus
- `4` specialized magic level
- `5` spell augment
- `6` bestiary damage bonus
- `7` powerful foe bonus
- `8` critical hit chance
- `9` elemental hit chance
- `10` rune critical hit chance
- `11` auto-attack critical hit chance
- `12` critical extra damage
- `13` elemental critical extra damage
- `14` rune critical extra damage
- `15` auto-attack critical extra damage
- `16` mana leech
- `17` life leech
- `18` mana gain on hit
- `19` life gain on hit
- `20` mana gain on kill
- `21` life gain on kill
- `22` perfect shot damage
- `23` ranged hit chance
- `24` attack range
- `25` skill percentage auto-attack
- `26` skill percentage spell damage
- `27` skill percentage spell healing

## 7. Config options (`config.lua`)

Current options:

- `weaponProficiencyMaxLevels`
- `weaponProficiencyMaxPerksPerLevel`
- `weaponProficiencyGainMultiplier`

Behavior:

- `weaponProficiencyMaxLevels`:
  - hard cap while loading levels from the proficiency files
  - extra levels in JSON are ignored
- `weaponProficiencyMaxPerksPerLevel`:
  - hard cap while loading perks in each level
  - extra perks are ignored
- `weaponProficiencyGainMultiplier`:
  - multiplier applied to gained proficiency XP
  - values `< 0` are clamped to `0`
  - final value is rounded (`llround`)

Practical note about rounding:

- very small base gains can become `0` after multiplier
- example: `1 * 0.33` rounds to `0`

## 8. XP tables and mastery

Current proficiency XP thresholds by weapon category:

- Crossbow table:
  - `600, 8000, 30000, 150000, 650000, 2500000, 10000000, 20000000, 30000000`
- Knight table:
  - `1250, 20000, 80000, 300000, 1500000, 6000000, 20000000, 40000000, 60000000`
- Standard table:
  - `1750, 25000, 100000, 400000, 2000000, 8000000, 30000000, 60000000, 90000000`

Mastery progression logic:

- perk unlock levels use `maxLevel`
- mastery XP tiers use `maxLevel + 2` (bounded by table size)
- max experience uses this mastery tier count

This means proficiency can continue past the last perk-unlock level until mastery cap.

### Base XP gain from monsters

From current code:

- Bestiary stars:
  - `0 -> 1`
  - `1 -> 30`
  - `2 -> 70`
  - `3 -> 100`
  - `4 -> 165`
  - `5 -> 240`
- Bosstiary rarity:
  - `BANE -> 500`
  - `ARCHFOE -> 5000`
  - `NEMESIS -> 15000`

## 9. Client-side vs server-side edits

This system is split between server and client.

Server side controls:

- progression logic
- perk effects
- persistence
- item-to-proficiency assignment

Client side controls:

- UI data/display of proficiencies (client assets)

If you only edit server files, client visuals may not change.
If you only edit client assets, server logic will not change.

For full changes, update both sides and restart/redeploy both.

## 10. Catalysts and scripts

Shared helper:

- `data/scripts/lib/proficiency_helper.lua`
- validates target is a weapon (`ItemType:isWeapon()`)
- applies XP via `Player:addWeaponExperience(experience, weaponId)`

Registered catalyst actions in `data-otservbr-global`:

- `51588` -> `25000` XP
- `51589` -> `100000` XP

If catalyst items exist but do nothing, confirm these action scripts are present and loaded.

## 11. Optional XML override example

Example for forcing a specific proficiency ID on one item:

```xml
<item id="12345" name="my custom weapon">
  <attribute key="proficiency" value="6"/>
</item>
```

Requirements:

- `value` must be a valid `ProficiencyId` in `data/items/proficiencies/`
- server restart/reload needed

## 12. Testing checklist

Use this quick validation flow after changes:

1. Restart server after editing proficiency data/config/item mappings
2. Equip the target weapon and confirm proficiency packet/UI updates
3. Kill monsters and confirm XP gain
4. Select/clear perks from client and confirm persistence
5. Relog and confirm saved state remains
6. If using catalysts, test on a weapon item (not non-weapon)
7. Optional GM test: `/proficiency <xp>` (requires god group)

## 13. Troubleshooting

### "I changed the server and client proficiency data and nothing changed."

Check all of the following:

- weapon actually has a non-zero resolved `proficiencyId`
- ID exists in server `data/items/proficiencies/`
- client assets were also updated/deployed
- server and client were restarted (and client cache refreshed if applicable)
- you are testing with protocol 15.11 path (old protocol path does not process these packets)

### "Catalyst is not adding XP."

Check:

- target item is recognized as weapon (`ItemType:isWeapon()`)
- catalyst action scripts are registered in your datapack
- item ID matches registered catalyst IDs

### "Perks do not apply after selecting."

Check:

- selected level is unlocked by XP
- only one perk per level is allowed
- weapon is equipped so effects are applied to current combat stats

## 14. Notes for maintainers

- `items.xml` override is intentionally optional; protobuf remains default mapping source
- invalid KV proficiency keys are sanitized during load/save
- proficiency state is persisted in KV scope `weapon-proficiency`
- changing `weaponProficiencyMaxLevels` or `weaponProficiencyMaxPerksPerLevel` can truncate loaded definitions from JSON
