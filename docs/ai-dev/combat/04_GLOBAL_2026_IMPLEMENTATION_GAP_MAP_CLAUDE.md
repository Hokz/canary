# Canary Global Vocation/Combat Adjustments 2026 — Implementation Gap Map, Pass 04

**READ-ONLY PRODUCTION. IMPLEMENTATION-READINESS ONLY. NO PRODUCTION CHANGES MADE.**

Origin: CLAUDE (Investigative Engineer / Red Team / Evidence Collector). ChatGPT is the exclusive
official-reference interpreter, final auditor, severity classifier, design authority,
implementation-spec author, and merge authority. The contract in section 0 (supplied by ChatGPT) is
treated as authoritative input, not independently reinterpreted. Nothing below is an implementation, a
severity assignment, or an invented Global formula. Where a target value was not supplied, the row is
marked `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` rather than guessed.

## 0. Baseline

- Production baseline: `main @ 4209ba583a4dcb2ae528750dcfeb2e7c0109863a` — verified unchanged (zero production commits since this SHA anywhere in this session; `git log -1 -- src/ data/ data-otservbr-global/` still resolves to `97c8c5502`, the last commit in `main`'s own history).
- Analysis branch: `ai-analysis/combat-root-discovery-claude-01`.
- This document builds directly on `01_COMBAT_ROOT_ARCHITECTURE_CLAUDE_DISCOVERY.md`, `02_COMBAT_TARGETED_EVIDENCE_CLAUDE.md`, and `03_UPSTREAM_COMBAT_DELTA_CLAUDE.md` on this same branch.

## A. General contract — G-001 through G-023

| ID | File(s) | Key | Current value/behavior | Target | Status |
|---|---|---|---|---|---|
| G-001 | `protocolgame.cpp:2706-2722`, `creatures_definitions.hpp:812-816`, `player.hpp:1839` | `FightMode_t`, `parseFightModes` | Combat Modes fully live/selectable (opcode 0xA0 → `playerSetFightModes`); 3-value enum unchanged. Per pass 03, only the 15.25 *wire protocol* stopped sending the byte — server-side mode/formulas fully intact. | Combat Modes no longer available. | `OUTDATED_VALUE` |
| G-002 | `player.cpp:822-833` (`getAttackFactor`) | outgoing damage multiplier | 1.0/0.75/0.5 switch on `fightMode`, feeds 7 live sites in `weapons.cpp`. | Former +20% ATTACK bonus permanently applied (mode-independent). | `OUTDATED_VALUE` |
| G-003 | `data/items/items.xml` shield entries (e.g. steel shield=21, plate shield=17, wooden shield=14) | `defense` attribute | Current shipped values; no in-repo record of a pre-adjustment baseline. | +30% over pre-adjustment baseline. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| G-004 | `data/items/items.xml` spellbook entries (id 3059 etc., defense=14) | `defense` attribute | Current shipped value; no baseline recorded. | +60% over pre-adjustment baseline. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| G-005 | `player.cpp:822-833`, DEFENSE case | attack penalty | `case FIGHTMODE_DEFENSE: return 0.5f;` — permanent 50% penalty whenever selected. | No permanent attack penalty should exist. | `OUTDATED_VALUE` |
| G-006 | `player_wheel.cpp:4033-4086` (`calculateMitigation`) | `fightFactor` | 0.8/1.0/1.2 switch on `fightMode`, multiplies the entire mitigation expression. | Mitigation formula must not depend on combat mode. | `OUTDATED_VALUE` |
| G-007 | `player_wheel.cpp:4033-4086` | equipment weighting | Two linear terms only (`skill*mitigationFactor`, `shieldFactor*defenseValue`); no per-tier/quality curve; armor/absorb% are separate systems untouched by this formula (see section F). | Equipment/weapon type should have substantially greater mitigation impact. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| G-008 | `src/io/io_wheel.cpp:19` (`#define MITIGATION_INCREASE 0.03`) | Dedication per-point mitigation | 0.03% per Promotion Point, used by ~15 slot handlers. | 0.075% per Promotion Point. | `OUTDATED_VALUE` |
| G-009 | `wheel_gems.cpp:34-42,156-158` | Lesser Gem `General_MitigationMultiplier` | `500 * gradeMultiplier` → 5/5.5/6/7.5% at grades 0-3. | 20/22/24/30%. | `OUTDATED_VALUE` |
| G-010 | `monster.cpp:1389-1395` (`Monster::getMitigation`) | monster mitigation | `info.mitigation * getDefenseMultiplier()` (+`DISABLE_MONSTER_ARMOR` fold-in), capped 30.0 (unchanged from pass 01/02). | Increased; exact formula not supplied. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| G-011 | `game.cpp:8746-8753`, `:8959-8981` (`applyCharmRune`) | charm trigger scope | Fires once per affected creature in an AoE hit — no "main target" concept exists anywhere (`mainTarget`/`isMainTarget` grep: zero hits). | Charms should trigger only on the main target of an auto-attack. | `OUTDATED_VALUE` |
| G-012 | `data/scripts/runes/{avalanche,great_fireball,thunderstorm,stone_shower}.lua` | "base power" | None use a base-power constant; each hardcodes its own level/maglevel linear formula. A `SPELL_BASE_POWER` convention exists elsewhere (Monk spells) but isn't applied here. | Base power = 50 for all 4. | `MISSING` |
| G-013 | `data/scripts/runes/explosion.lua:6`, `register_spells.lua:425-429` | `AREA_CIRCLE1X1` | Plus-shape, 5 tiles (center + 4 orthogonal neighbors), not a 3×3 block. | 9-square area. | `OUTDATED_VALUE` |
| G-014 | `data/events/scripts/party.lua:68-79`, `party.cpp:77-94` | group XP multiplier | Quadratic formula: 2 vocations→1.3x (30%), 3→1.6x (60%), 4(party≥4)→2.0x (100%). | 2 vocations=35%, 3=70%. | `OUTDATED_VALUE` |
| G-015 | `data/items/items.xml` item 3051/3088 "energy ring" | absorb-drain mechanic | Purely cosmetic timed ring (vocation/slot gating only); no absorb-then-mana-drain mechanic anywhere; the only comparable mechanism (`CONDITION_MANASHIELD`) is unrelated and not attached to this item. | 2 mana consumed per point of absorbed damage. | `MISSING` |
| G-016 | `data/scripts/runes/{ultimate,intense}_healing_rune.lua` | self-only restriction | Both only reject Monster targets; either can be cast on any other player. | Self-only — must reject non-self player targets too. | `OUTDATED_VALUE` |
| G-017 | `data/items/items.xml`, `data/scripts/actions/items/potions.lua:45-73` | "Superior Mana Potion" | Does not exist. Current roster: mana potion (75-125, no gate), strong (115-185, lvl 50), great (150-250, lvl 80, Sorc/Druid/Pal/Monk), ultimate (425-575, lvl 130, Sorc/Druid only). | New item: 240-360 mana, level 100, Paladin/Monk/Sorcerer/Druid. | `MISSING` |
| G-018 | `potions.lua:48` (item 238 "great mana potion") | vocation restriction | Restricted to Sorc/Druid/Pal/Monk (excludes Knight). | Usable by all vocations. | `OUTDATED_VALUE` |
| G-019 | repo-wide | "Distilled Superior/Ultimate" | Does not exist anywhere (zero hits for "Distilled"). | New items, same effect as base, +50% price, all vocations. | `MISSING` |
| G-020 | repo-wide | vocation "stances" persistence | No "stance" concept exists at all (zero hits); nearest analog (Focus Mastery) is a boolean instant with no elemental/crippling variants or session-persistence logic beyond normal Wheel save/load. | Stances persist across login; no-stance valid; 1 at a time except sorcerer elemental+crippling dual. | `MISSING` |
| G-021/022/023 | `combat.cpp:630-650`, `game.cpp:7917-7920,7992-7995` | Mantra | Covers exactly 4 types (Fire/Ice/Energy/Earth), excludes Holy/Death/LifeDrain/ManaDrain; skips DoT (`if (!condition)`, already matches); runs strictly **before** `blockHit()` (i.e. before all resistance/mitigation layers). | Cover 8 types (add Holy/Death/LifeDrain/ManaDrain); DoT-skip already correct; must apply **after** resistances. | `OUTDATED_VALUE` (2 of 3 sub-requirements mismatched; DoT-exclusion already matches) |

## B. July 7 numeric corrections, July 14, August 4

| ID | File(s) | Current value | Target | Status |
|---|---|---|---|---|
| J7-K-001 | `data/scripts/spells/support/blood_rage.lua:4` | `CONDITION_PARAM_SKILL_MELEEPERCENT = 135` (+35%) | 25% (literal 125) | `OUTDATED_VALUE` (doesn't even match the contract's own flagged "prior/buggy" 30%) |
| J7-K-002 | `player_wheel.cpp:3255` (`checkBattleHealingAmount`) | `amount *= 3` at HP≤30% | ×2 | `OUTDATED_VALUE` (exact match to the flagged bug value) |
| J7-K-003 | `player_wheel.cpp:3017-3023` (`checkCombatMastery`, two-handed branch) | 1200/800/400 bp = 12/8/4% | 14/12/10% | `OUTDATED_VALUE` (matches neither target nor the flagged "buggy" 12/10/8% — a third, more-outdated ladder) |
| J7-K-004 | `data/scripts/spells/healing/wound_cleansing.lua:30` | `spell:mana(40)` | 60 | `OUTDATED_VALUE` |
| J7-K-005 | `.../fair_wound_cleansing.lua:27` | `spell:mana(90)` | 135 | `OUTDATED_VALUE` |
| J7-K-006 | `.../intense_wound_cleansing.lua:30` | `spell:mana(200)` | 300 | `OUTDATED_VALUE` |
| J14-001 | `blood_rage.lua:4`, `condition.cpp:885-895,819-838` | Application pipeline traced end-to-end (`updatePercentSkills`→`updateSkills`→`setVarSkill`→`sendSkills`), fires correctly on both first-cast and re-cast; no wrong-variable/wrong-stat/not-applied bug found. | Blood Rage must actually grant 25%. | `OUTDATED_VALUE` — root-caused entirely to J7-K-001's wrong literal; **no separate application-layer bug exists**; fixing the literal alone suffices |
| J7-P-001 | (not found) | "Divine Defiance" does not exist under this name anywhere; only unrelated dodge mechanic is the vocation-agnostic `General_Dodge` gem (0.28-0.42%, nowhere near 12%). | 12% dodge | `MISSING` |
| J7-P-002 | (not found) | No magic-level-bonus mechanic tied to any "Divine Defiance" identifier. | 6% magic-level bonus | `MISSING` |
| J7-P-003 | `data/scripts/spells/attack/divine_caldera.lua:6-9` | Pure level/maglevel formula, no base-power constant. | Base power 150 | `MISSING` |
| J7-P-004 | `wheel_gems.cpp:410-413` | `DamageIncrease = 5*gradeMultiplier` (max 7.5%); no discrete Augment I/II tiering exists. | "Augment II" +10% | `OUTDATED_VALUE` |
| J7-P-005 | (not found under this name) | "Divine Barrage" doesn't exist; nearest role-analog "Divine Grenade" uses level/maglevel × grade-multiplier {1.3,1.6,2.0}, no base-power constant. | Base power 130 | `MISSING` |
| J7-P-006 | `wheel_gems.cpp:402-405` | Divine Grenade `DamageIncrease = 6*gradeMultiplier` (max 9%); no "Augment I" naming. | "Augment I" 8% | `MISSING` (naming mismatch — see section C note) |
| J7-P-007 | `wheel_gems.cpp:406-409` | Divine Grenade `CriticalExtraDamage = 12*gradeMultiplier` (max 18%); no "Augment II" naming. | "Augment II" 12% | `MISSING` (naming mismatch) |
| J7-P-008 | `data/scripts/spells/support/sharpshooter.lua:31-35` | 140 (+40%) at grade NONE/REGULAR, 145 (+45%) at UPGRADED. | 32% | `OUTDATED_VALUE` |
| J7-S-001 | `player_wheel.cpp:3204-3216` (`checkBeamMasteryDamage`) | Returns 10/12/14 per stage. | 25/40/70% | `OUTDATED_VALUE` |
| J7-S-002 | `data/scripts/spells/attack/great_death_beam.lua` | Level/maglevel additive formula (`level/5+maglevel*5.5..9`), no base-power constant. | Base power 155 | `MISSING` |
| J7-S-003 | `data/scripts/spells/attack/great_energy_beam.lua` | Level/maglevel additive formula (`level/5+maglevel*4..7`), no base-power constant. | Base power 155 | `MISSING` |
| J7-S-004 | (not found) | "Death Echo" does not exist anywhere (zero hits). | Base power 75 | `MISSING` |
| J7-S-005 | (not found) | Same — no Augment II exists for a nonexistent spell. | Augment II 12% | `MISSING` |
| J7-S-006 | (not found) | "Mana Buffer" does not exist for Sorcerer or Druid anywhere. | Multiplier 10 | `MISSING` |
| J7-D-001 | (not found) | "Forked Glacier" does not exist anywhere. | Base power 90 | `MISSING` |
| J7-D-002 | (not found) | "Forked Thorns" does not exist anywhere. | Base power 97 | `MISSING` |
| J7-D-003 | `data/scripts/spells/attack/strong_ice_wave.lua:7-9` | Level/maglevel formula (`level/5+maglevel*4.5+20`..`+7.6+48`), no base-power constant — architecturally different shape than a base-power target. | Base power 140 | `OUTDATED_VALUE`/architecture mismatch |
| J7-D-004 | (not found) | "Mana Buffer" — same as J7-S-006, confirmed absent for Druid too (no separate implementation). | Multiplier 10 | `MISSING` |
| J7-M-001 | `data/scripts/spells/attack/chained_penance.lua:28-35`, `combat.cpp:1750` | `return targets, 3, false` — chainDistance=3, consumed as the initial/hop search radius in `Combat::pickChainTargets`. | Radius 4 | `OUTDATED_VALUE` |
| AUG4-001 | `weapon_proficiency.cpp:124-182`, `items_definitions.hpp:278-300`, `player.cpp:5797-5824` | Shield Slam doesn't exist (see section C), so it has no perk/augment entry to gate. More generally: **neither** perk system in the codebase (weapon-proficiency perks, or item-attribute `Augment_t`) contains **any** two-handed-weapon exclusion logic anywhere — zero `SLOTP_TWO_HAND` checks in either file, despite `Combat Mastery` (`player_wheel.cpp:3015`) already using exactly that pattern for its own unrelated stat split. | Shield Slam perks must not be rollable for two-handed weapons. | `MISSING` |

## C. Release-state vocation mechanics inventory

**Governing note for this whole section**: no numeric targets were supplied for these rows beyond the specific J7-* items already covered in section B — every row below is `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` unless marked `MISSING`. **Naming-resolution flag for ChatGPT**: three Paladin mechanics named in the contract — "Divine Barrage," "Divine Defiance," "Ethereal Barrage" — do not exist under those names anywhere in the codebase. The codebase's actual paladin kit uses "Divine Grenade" (not Divine Barrage) and "Ethereal Spear"/"Strong Ethereal Spear" (not Ethereal Barrage), and has no ability resembling "Divine Defiance" at all (only an unrelated, vocation-agnostic `General_Dodge` gem at 0.28-0.42%). This could mean: (a) these are newer 2026-era abilities genuinely absent from this codebase, (b) the contract's names map onto the existing Divine Grenade/Ethereal Spear mechanics under different naming, or (c) something else. This pass does not guess which — flagged as a resolution question, not resolved here.

### Knight

| Mechanic | File(s) | Current behavior | Status |
|---|---|---|---|
| Blood Rage stance | `data/scripts/spells/support/blood_rage.lua` | Self-buff 10s: +35% melee skill (see J7-K-001), +15% damage received, defense disabled entirely. Mutually exclusive with Protector (shared subid). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Protector stance | `.../protector.lua` | Self-buff 13s: +120% shield skill, -35% damage dealt, -15% damage received. Defense stays enabled. Mutually exclusive with Blood Rage. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Shield Bash | (none found) | Does not exist anywhere in the repository (exhaustive case-insensitive grep, zero hits). | `MISSING` |
| Shield Slam | (none found) | Does not exist anywhere (same exhaustive grep, zero hits). Relevant to AUG4-001 above. | `MISSING` |
| Healing scaling (magic level + shielding) | `wound_cleansing.lua` family, `player_wheel.cpp:3251-3260` | **Two separate, non-combining formulas**: Wound Cleansing scales on level+magicLevel only (shield skill plays no role); Battle Healing (passive proc) scales on `SKILL_SHIELD` only (magic level plays no role). No single formula combines both stats. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` (flagging: no unified formula exists, if one is intended) |
| Front Sweep | `data/scripts/spells/attack/front_sweep.lua`, `wheel_gems.cpp:363-370` | Frontal-wave physical attack; formula explicitly contains a `// TODO: Use New Real Formula instead of an %` comment in the source — the implementation self-admits it's an approximation. Wheel gems add further %damage/%crit. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Chivalrous Challenge | `data/scripts/spells/support/chivalrous_challenge.lua` | Chain-taunt spell, base 5 targets (+wheel bonus), only chains onto ranged/distance monsters (`getTargetDistance()>1`), forces 12s+ melee-range lock. Blocked entirely near reward bosses. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Battle Healing | `player_wheel.cpp:3251-3260,4015-4022` | Passive proc, `shieldSkill*0.2`, ×3 at HP≤30% (target 2, see J7-K-002), ×2 at HP≤60%. | see J7-K-002 |
| Combat Mastery | `player_wheel.cpp:3009-3053` | Two-handed branch: crit-damage ladder (see J7-K-003). Shield/one-handed branch: flat `+30/20/10` defense per stage — no percent-based target was supplied for this second branch. | see J7-K-003 (two-handed); one-handed branch `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |

### Paladin

| Mechanic | File(s) | Current behavior | Status |
|---|---|---|---|
| Stances shipped | `player_wheel.cpp:2926-3004` | Exactly two: "Positional Tactics" (distance-skill ↔ Holy/Healing specialized-magic swap based on nearby monster count) and "Ballistic Mastery" (bolt→crit bonus, arrow→physical/holy % bonus). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Elemental/AoE ammunition | `data/items/items.xml` (all ammo entries) | No ammo item carries any elemental-damage attribute or area-effect property anywhere — every arrow/bolt is a flat physical `attack` value distinguished only by name/shootType. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` (flagging: implied feature not found) |
| Swift Foot | `data/scripts/spells/support/swift_foot.lua` | Self-haste, wheel-grade-gated drawback (NONE=exhaust+pacify, REGULAR=-50% damage-dealt debuff, UPGRADED=no drawback). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Divine Caldera | `data/scripts/spells/attack/divine_caldera.lua`, `wheel_gems.cpp:410-417` | See J7-P-003/004. | see B |
| Divine Barrage | naming mismatch, see governing note | Nearest analog "Divine Grenade" exists with different math shape entirely. | see B (J7-P-005/006/007) |
| Ethereal Barrage augments | naming mismatch, see governing note | Nearest analog "Ethereal Spear"/"Strong Ethereal Spear" (`wheel_gems.cpp:426-441`): DamageIncrease 10/8×grade, CriticalExtraDamage 15/12×grade — no "Augment" terminology anywhere. | `MISSING` (as named) |
| Divine Dazzle | `data/scripts/spells/support/divine_dazzle.lua` | Chain debuff, forces up to 3(+wheel) ranged monsters into melee range for 12s+; blocked near reward bosses. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Sharpshooter | `data/scripts/spells/support/sharpshooter.lua` | See J7-P-008. | see B |

### Sorcerer

| Mechanic | File(s) | Current behavior | Status |
|---|---|---|---|
| Master of Flames/Thunder/Decay | (none found) | Does not exist under any name/synonym anywhere. Nearest unrelated mechanic: "Runic Mastery" (25%-chance free-mana-cost on rune spells) — a different concept entirely. | `MISSING` |
| Sap Strength / Expose Weakness | `data/scripts/spells/support/{sap_strength,expose_weakness}.lua` | Both exist and are fully wired: Sap Strength = -10%(/-20% upgraded) target damage dealt debuff; Expose Weakness = +5% target damage received debuff. Both feed a Drain Body leech-scaling mechanic (`checkDrainBodyLeech`). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Death Echo | (none found) | Does not exist anywhere. | `MISSING` (see J7-S-004/005) |
| Mana Buffer | (none found) | Does not exist for Sorcerer (or Druid). | `MISSING` (see J7-S-006/J7-D-004) |
| Wand mana/range/Strike-imbuement | `data/items/items.xml` wand entries, `imbuements.xml:172-191` | Standard flat mana-cost/range-3 wands; one high-tier wand (id 27457) has a generic 2-slot imbuement (leech/crit/skillboost); "Strike" imbuement itself is a generic critical-damage imbuement with no wand-specific interaction code found anywhere. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Beam Mastery | `player_wheel.cpp:3204-3216` | See J7-S-001. Also grants beam target-count (+3 max) and cooldown reduction (1s/target, max 3s) — unaffected by the numeric target. | see B |
| Lord of Destruction | (none found) | Does not exist anywhere (only an unrelated item name "wand of destruction" coincidentally matches "destruction"). | `MISSING` |
| Focus Mastery | `player_wheel.cpp:3313-3319,3472-3478` | Casting a FOCUS-group spell arms a 12s timer; next qualifying combat instance gets +35 damageMultiplier once the timer elapses. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Energy Wave augments | `data/scripts/spells/attack/energy_wave.lua`, `wheel_gems.cpp:462-490` | Wheel-area upgrade (5x5→wave7) + gem bonuses (cooldown -1s, +5×grade damage, +12×grade crit). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Great Death Beam / Great Energy Beam | `data/scripts/spells/attack/great_{death,energy}_beam.lua` | See J7-S-002/003. | see B |

### Druid

| Mechanic | File(s) | Current behavior | Status |
|---|---|---|---|
| Healing stances | (none found) | No toggle/stance mechanic exists for Druid healing anywhere (exhaustive "stance" grep returns only false-positive substring matches of "distance"/"instance"). | `MISSING` |
| Mana Buffer | (none found) | Same as Sorcerer — does not exist. | `MISSING` (see J7-D-004) |
| Rod mana/range/Strike-imbuement | `data/items/items.xml` rod entries, `imbuements.xml:172-186` | Standard flat mana/range rods (terra/moonlight/glacial); **none of the 3 checked rods have an `imbuementslot` attribute at all** — no Strike (or any) imbuement can currently be applied to a druid rod. | `MISSING` (Strike-interaction sub-claim specifically) |
| Forked Glacier | (none found) | Does not exist anywhere. | `MISSING` (see J7-D-001) |
| Forked Thorns | (none found) | Does not exist anywhere. | `MISSING` (see J7-D-002) |
| Strong Ice Wave | `data/scripts/spells/attack/strong_ice_wave.lua` | See J7-D-003. | see B |
| Blessing of the Grove | `player_wheel.cpp:3133-3159` | Stage-scaled (1-3) healing bonus on other-target heals: +12/18/24% at HP≤30%, +6/9/12% at HP≤60%. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Healing Link | `player_wheel.cpp:3473-3475,3837-3845` | +10 healingLink for "Nature's Embrace"/"Heal Friend" spells specifically (hardcoded name match) → caster self-heals 10% of the outgoing heal. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Terra Wave augment | `data/scripts/spells/attack/terra_wave.lua`, `wheel_gems.cpp:550-557` | Base level/maglevel formula + gem bonuses (+5×grade damage, +12×grade crit). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |

### Monk

| Mechanic | File(s) | Current behavior | Status |
|---|---|---|---|
| Party Virtue bonuses | `player.cpp:13022-13130`, `combat.cpp:740-742` | **Self-only, not party-shared** — grep of `party.cpp` for "Virtue" returns zero matches. Harmony amplifies the caster's own charge bonus; Sustain multiplies the caster's own outgoing healing 1.35x/1.70x; Justice triggers only a stat-refresh with no further bonus found. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` (flagging: contract's framing implies party-wide effect not present in code) |
| Thousand Fist Blows | (none found) | Does not exist anywhere — full Monk attack-spell roster enumerated (12 files), none match this name. | `MISSING` |
| "Way of the Monk" shrine defensive bonus | `data-otservbr-global/scripts/quests/the_way_of_the_monk/shrines.lua`, `combat.cpp:748-759` | Shrine system exists and is fully wired (10 shrines, KV-tracked), but grants only an **offensive** fist-damage multiplier (+5%/+10% per shrine visited, serene-gated) — zero defensive/mitigation bonus exists anywhere tied to this system. | `MISSING` (defensive component specifically) |
| Mass Spirit Mend | `data/scripts/spells/healing/mass_spirit_mend.lua` | Area heal, level/maglevel + Harmony-charge-scaled formula, explicit boss-exclusion allowlist. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Mystic Repulse | `data/scripts/spells/attack/mystic_repulse.lua` | Uses the `SPELL_BASE_POWER=72` skill/attack-factor pattern (the same pattern several MISSING sorcerer/druid spells above lack). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Chained Penance / Spiritual Outburst | `data/scripts/spells/attack/{chained_penance,spiritual_outburst}.lua` | See J7-M-001 (Chained Penance). Spiritual Outburst uses chainDistance=2, separate ability, no target supplied for it. | see B (Chained Penance) |
| Guiding Presence | `party.cpp:308-329` | **Re-confirmed this pass**: shares exactly HALF (`getMantra()/2`) the holder's mantra, not 100% as the contract's framing implies. | `OUTDATED_VALUE` (if 100% is truly intended — flagged, not assumed) |
| Sanctuary | `spells.cpp:26-44,876-883` | Harmony-charge-gated: drops a decaying sanctuary item + 5s buff, `bonus=100+2*harmonies` on damage/healing dealt (max +110% at 5 charges). Deduped via existing-condition check. | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |
| Other Monk wheel augments | `wheel_gems.cpp:316-694` | Full roster enumerated: RevelationMastery ×3, AvatarOfBalance cooldown, SpiritMend healing, SpiritualOutburst/ForcefulUppercut/FlurryOfBlows/GreaterFlurryOfBlows/SweepingTakedown damage+crit, FocusSerenity/FocusHarmony cooldown, MassSpiritMend healing. Notably absent: any gem augment for Chained Penance, Mystic Repulse, Sanctuary, or Guiding Presence (those scale only via harmony/mantra/stage mechanics). | `PRESENT_REFERENCE_TARGET_NOT_SUPPLIED` |

## D. Core combat findings — unchanged confirmation

Re-verified this pass: **zero production commits exist anywhere since `main@4209ba583`** (confirmed via `git log -1 -- src/ data/ data-otservbr-global/`, resolving to `97c8c5502`, a commit already inside `main`'s own history — this session has made no production edits at all). Every finding below is therefore **byte-identical** to its pass-02/03 citation, spot-checked directly this pass:

| Finding | Spot-check this pass | Status |
|---|---|---|
| A002 (armor-only hits consume shared `blockCount`) | `creature.cpp` unchanged (pass 03 already confirmed zero diff vs. upstream too) | UNCHANGED |
| A003 (`DISABLE_MONSTER_ARMOR` double-applies `getDefenseMultiplier`) | `monster.cpp:1391-1393` content unchanged | UNCHANGED |
| A004 (secondary reflection bug — **ChatGPT-confirmed BUG_CONFIRMED**) | `game.cpp:8008` re-grepped this pass: `int32_t reflectPercent = std::ceil(damage.primary.value * secondaryReflectPercent / 100.);` — byte-identical | UNCHANGED |
| A005 (pre-mitigation blockType callback ordering) | `creature.cpp:997,1001` re-grepped this pass: identical line numbers/content | UNCHANGED |
| C008 (`Player::getArmor` casts `armorMultiplier` to int before multiply) | `player.cpp:650` re-grepped this pass: `return armor * static_cast<int32_t>(vocation->armorMultiplier);` — byte-identical | UNCHANGED |
| C012 (native element + imbuement can coexist, overwrite) | not re-diffed this pass (no file-level change possible given zero production commits) | UNCHANGED |
| C013 (`MonsterType:addElement` binding lacks clamp, current data path safe) | not re-diffed this pass (same reasoning) | UNCHANGED |
| C006/C007/C016 (dead/callerless functions) | not re-diffed this pass (same reasoning); this pass independently found a **new** dead-code instance of the same class: `Player::getCombatTacticsMitigation()`'s 0.8/1.0/1.2 table is a confirmed triplicate of `calculateMitigation`'s own inline switch, still zero callers | UNCHANGED + 1 reinforcing observation |

None of these were touched, fixed, or otherwise modified this pass, per the task's explicit instruction.

## F. Mitigation formula — variable inventory only (no replacement formula invented)

**Correction to prior-pass quoted evidence**: this pass re-read `player_wheel.cpp:4033-4086` directly from disk (clean tree, verified) and found `shieldFactor`/`distanceFactor` default to **`1.0f`**, not `0.f` as an earlier sub-agent's quote in this session's own briefing context stated. This is a transcription correction to that one quote, **not evidence of any code change** (zero production commits exist, confirmed in section D). The practical consequence: a character with no shield-slot item AND no weapon-slot item still gets `skill*mitigationFactor/100 * fightFactor * 1.0` mitigation from the shielding-skill term alone — the formula does not zero out entirely for an unequipped character, as the incorrect quote would have implied.

| # | Variable | Current source | Value(s) |
|---|---|---|---|
| 1 | Shielding skill term | `Player::getSkillLevel(SKILL_SHIELD)`, `player.cpp:7330-7359` | Base skill progression via `Vocation::getReqSkillTries` (base 100, per-vocation multiplier 1.1-1.5 from `vocations.xml`); Wheel "Battle Instinct" major-stat bonus added on top; trained via `Player::onBlockHit()` (only on a successful block while shielded). |
| 2 | Defense-value term | `Item::getDefense()`/`getExtraDefense()`, `item.hpp:412-423` | Two-tier: static `items.xml` `defense`/`extradef` attributes, or a per-instance `ItemAttribute_t` override (DB-persisted or GM talkaction only — no imbuement/forge/augment system writes these attributes directly). |
| 3 | Shield factor | `vocation->mitigationPrimaryShield` | Exact per-vocation values tabulated: None/Knight/Elite Knight=2.05, Sorcerer/Druid(+promoted)=2.0, Paladin/Royal Paladin/Monk/Exalted Monk=2.08. |
| 4 | Spellbook factor | **dead-code bug found**: `shield->isSpellBook()`, `item.hpp:124-126` → `ItemParse::parseWeaponType`, `item_parse.cpp:278` | `itemType.spellbook = true` sits behind an inner condition (`stringValue == "spellbook"`) that compares the *outer* already-matched `"weapontype"` string, not the lowercased attribute value — **unreachable, always false**. Every spellbook (ids 3059, 8072-8074, etc.) therefore falls through to the `else` branch and uses `mitigationPrimaryShield` (the ordinary-shield factor), never the intended `mitigationSecondaryShield`, in the currently-running code. |
| 5 | One-handed weapon handling | `player_wheel.cpp:4077-4080` | Contributes only `getExtraDefense()` (additive on top of any shield `defenseValue`) + `mitigationPrimaryShield`; last-write-wins on `shieldFactor` if both a shield and one-handed weapon are equipped (structurally always the case; numerically inert today since both use the same field). |
| 6 | Two-handed melee handling | `player_wheel.cpp:4074-4076` | Full `getDefense()+getExtraDefense()` (an **assignment**, discarding any prior shield `defenseValue` — moot since a shield can't coexist with a two-hander) + `mitigationSecondaryShield` (the "off-hand" factor, not `mitigationPrimaryShield`). |
| 7 | Bow/crossbow handling | `player_wheel.cpp:4072-4073` | **Confirmed gap**: sets only `distanceFactor`; the bow/crossbow's own `getDefense()`/`getExtraDefense()` are never read anywhere in the formula. Confirmed structurally permanent: the ammo-type check precedes the two-handed check in the `if/else if` chain, so a bow/crossbow (both two-handed AND ammo-typed) always takes the ammo branch. |
| 8 | Quiver handling | `player_wheel.cpp:4058-4068` | `isQuiver()` correctly routes to `distanceFactor = mitigationSecondaryShield` (unlike spellbook, no bug here). `defenseValue = shield->getDefense()` runs unconditionally — but **all 8 current quiver items have zero `defense` XML attribute**, so this line is live/reachable but always contributes 0 in practice. |
| 9 | Elemental bond handling | repo-wide grep | Zero references to `elementalBond` anywhere inside `player_wheel.cpp` or the mitigation call chain — confirmed no interaction (it's used only for tooltip text and Monk-spell visual-effect selection). |
| 10 | Vocation factors | `player_wheel.cpp:4059,4061,4073,4076,4079,4083` | Exactly 3 fields read: `mitigationFactor`, `mitigationPrimaryShield`, `mitigationSecondaryShield` — no other vocation field (`defenseMultiplier`, `armorMultiplier`, etc.) is read by this function. |
| 11 | Wheel multiplier | `getMitigationMultiplier()`, `player_wheel.cpp:3833-3835` | `getStat(MITIGATION)/100`; fed by the Lesser Gem `General_MitigationMultiplier` (G-009) and by ~8 separate Wheel node-bonus accumulation sites in `io_wheel.cpp` (each using `MITIGATION_INCREASE`, G-008). Applied as a final percentage bump: `mitigation += mitigation*multiplier/100`. |
| 12 | Monster mitigation | `monster.cpp:1389-1395` | Re-cited only (G-010) — flat Lua stat × `getDefenseMultiplier()`, `DISABLE_MONSTER_ARMOR` fold-in, capped 30.0. |
| 13 | Caps/rounding | `player_wheel.cpp:4083-4084`, `creature.cpp:911-922`, `monster.cpp:1394` | `calculateMitigation` rounds UP to 2 decimals (`ceil(...*100)/100`) with **no min/max cap at all** on the player side, before or after the Wheel multiplier. `Creature::mitigateDamage` floors the resulting *damage* to 0 (not the mitigation value) and excludes `COMBAT_MANADRAIN`/`LIFEDRAIN`/`AGONYDAMAGE`. The 30.0 hard cap exists **only** for `Monster::getMitigation()` — confirmed no equivalent player-side ceiling exists anywhere. |
| 14 | fightMode dependency | `player_wheel.cpp:4039-4054` | Re-confirmed byte-for-byte: 0.8/1.0/1.2 switch, multiplies the entire bracketed expression. A confirmed dead-code triplicate exists at `Player::getCombatTacticsMitigation()` (zero callers, section D), plus a live UI-only decomposition sent to the client in `protocolgame.cpp:5564-5577` for tooltip display that does not feed back into real damage. |

Every one of the 14 rows above is explicitly labeled: **`GLOBAL_2026_EXACT_FORMULA_REQUIRED`** — this pass does not propose, imply, or guess what the 2026 replacement formula should look like. The dead-code spellbook bug (item 4) and the unread-bow-defense gap (item 7) are reported as current-behavior facts about the *existing* formula, not as recommendations for the new one.

## G. Implementation batch plan — proposal only, not implemented

**BATCH 1 — protocol/current-client combat-mode compatibility**
Files: `protocol_profile.hpp`/`.cpp`, `protocolgame.cpp` (`parseFightModes`/`sendFightModes`). Closes: G-001 (protocol-layer half already done upstream per pass 03's `TacticsWithoutFightMode`; Hokz has not adopted it). Independent of the mitigation-formula blocker — pure wire-format work.

**BATCH 2 — exact published numeric/system deltas independent of the unknown mitigation formula**
Files: `blood_rage.lua`, `player_wheel.cpp` (`checkBattleHealingAmount`, `checkCombatMastery`, `checkBeamMasteryDamage`), `wound_cleansing*.lua`, `sharpshooter.lua`, `chained_penance.lua`, `io_wheel.cpp` (`MITIGATION_INCREASE`), `wheel_gems.cpp` (`General_MitigationMultiplier` base constant), `explosion.lua`, `party.lua`/`party.cpp` (group XP), `ultimate_healing_rune.lua`/`intense_healing_rune.lua`, `potions.lua` (item 238 vocation gate). Closes: J7-K-001/002/003/004/005/006, J14-001, J7-S-001, J7-M-001, G-008, G-009, G-013, G-014, G-016, G-018. All are self-contained constant/literal edits with no dependency on section F's blocked mitigation architecture.

**BATCH 3 — Mantra current-Global correction**
Files: `combat.cpp` (`applyMantraAbsorb`), `game.cpp` (`combatBlockHit` call sites, primary+secondary). Closes: G-021/022/023. Two changes: widen the accepted-type check from 4 to 8 types; move the call (and its floor-clamp) to after `target->blockHit()` returns instead of before — flagged as a non-trivial reordering since the reflect-damage calculation immediately downstream reads `blockHit`'s mutated value (interacts with A004's already-confirmed bug in the same function).

**BATCH 4 — core mitigation architecture — BLOCKED**
Blocked in full pending `GLOBAL_2026_EXACT_FORMULA_REQUIRED` (section F). Closes: G-002, G-005, G-006, G-007, G-010 (partially — monster-side target also unsupplied), and the spellbook dead-code bug (item 4) and bow/crossbow-defense gap (item 7) *if* the new formula is meant to fix them rather than intentionally preserve them.

**BATCH 5 — vocation mechanics/value corrections**
Files: all remaining J7-P/-S/-D rows marked `MISSING` (net-new abilities: Divine Defiance, Death Echo, Mana Buffer ×2, Forked Glacier, Forked Thorns, Lord of Destruction, Thousand Fist Blows, Shield Bash, Shield Slam, Master of Flames/Thunder/Decay, Superior/Distilled mana potions, vocation stance system, elemental/AoE ammunition, Energy Ring mechanic, Monk shrine defensive bonus, party-wide Virtue sharing if intended). Closes: the bulk of section C's `MISSING` rows plus their paired B-section numeric targets. Largest batch by scope; strictly depends on the Paladin naming-resolution question (section C governing note) being answered first, since several rows (J7-P-005/006/007) cannot be assigned a file until ChatGPT resolves whether "Divine Barrage" maps to "Divine Grenade" or is genuinely separate net-new content.

**BATCH 6 — validated internal engine bugs**
Files: `game.cpp` (A004 secondary reflect), `creature.cpp` (A002 blockCount, A005 callback ordering), `monster.cpp` (A003 multiplier fold-in), `player.cpp` (C008 armorMultiplier cast), `item_parse.cpp` (the newly-found spellbook-detection dead-code bug, section F item 4 — a NEW finding this pass, not previously in the A00X/C00X registry, recommend registering as a new ID). Closes: all of section D's tracked findings, once ChatGPT authorizes fixes (explicitly not done this pass).

**BATCH 7 — final Combat Sensitivity Lab / regression campaign**
Runs only after Batches 1-6 land. Uses the harness already built and corrected in passes 01/02 (`docs/ai-dev/combat/combat_harness.py`) extended with the finalized 2026 mitigation formula (once supplied) and the corrected Mantra/vocation values, per the owner's own stated sequencing ("large damage/breakpoint tests at the END of the architecture/fidelity work" — explicitly not run this pass, per section K of the task).

## No-authority statement

Every status label above is a factual comparison between the supplied contract and current Canary source, not a severity judgment, not an implementation, and not an independent reinterpretation of Global behavior — the contract in section 0 was treated as given, not verified against any external source by this pass. No production file was modified. No fix was implemented. No batch was executed. All rows remain `Status: UNVALIDATED` pending ChatGPT's independent review; the batch plan in section G is a proposal for ChatGPT's ordering authority, not a commitment.
