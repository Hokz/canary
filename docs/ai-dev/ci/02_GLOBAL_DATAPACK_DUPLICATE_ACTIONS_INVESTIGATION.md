# Global Datapack Duplicate Action Registration - Investigative Red Team Pass 01

**Investigation only. No production code was changed as part of this
pass.** Branch `ai-analysis/global-datapack-duplicate-actions-01`,
from `main@4209ba583a4dcb2ae528750dcfeb2e7c0109863a`. PR #38 and PR
#39 were not touched.

## Scope

Exactly the four Action `item_id` duplicate registrations Repository
Audit flagged:

1. `2874` - `data-otservbr-global/scripts/actions/other/fluids.lua` vs
   `data-otservbr-global/scripts/quests/threatened_dreams/action_candia_misc.lua`
2. `3452` - `data-otservbr-global/scripts/actions/tools/rake.lua` vs
   `data-otservbr-global/scripts/quests/threatened_dreams/action_fairy_treasure_stones.lua`
3. `6276` - `data-otservbr-global/scripts/actions/other/baking.lua` vs
   `data-otservbr-global/scripts/quests/threatened_dreams/action_gingerbread_recipe.lua`
4. `12724` - `data-otservbr-global/scripts/quests/a_pirates_tail/action_raid_catapult.lua`
   vs `data-otservbr-global/scripts/quests/the_rookie_guard/mission02_defence.lua`

No fix is implemented or recommended as approved. No `--fail-on-warnings`
weakening, allowlist, suppression, or Repository Audit change was made
or is proposed.

---

## A. Engine / registration semantics

Evidence: `src/lua/creature/actions.hpp` (class `Actions`, the
`useItemMap`/`uniqueItemMap`/`actionItemMap`/`actionPositionMap`
members) and `src/lua/creature/actions.cpp`.

**Storage.** Each of the four id-spaces (plain item id, unique id,
action id, position) is a single `std::map<uint16_t, std::shared_ptr<Action>>`
(or `std::map<Position, ...>`) - at most **one** `Action` object can
ever occupy a given key. There is no list/chain of handlers per key
anywhere in this engine.

**What happens when two Action handlers register the same item id**
(`Actions::registerLuaItemEvent`, `actions.cpp:39-70`): for each item
id in the registering script's id list, `hasItemId(itemId)` is checked
first. If the id is already present in `useItemMap`, the engine:

```cpp
g_logger().warn(
    "[{}] - Duplicate registered item with id: {} in range from id: {}, to id: {}, for script: {}",
    __FUNCTION__, itemId, itemIdVector.at(0), itemIdVector.at(itemIdVector.size() - 1),
    action->getScriptInterface()->getLoadingScriptName());
continue;
```

i.e. logs a `[warning]` naming the **losing** script, and `continue`s
- the second script's `Action` object is never inserted into
`useItemMap` for that id. `setItemId` itself uses `try_emplace`
(`actions.hpp:193-195`), which is also a no-op on an existing key, so
there is no code path anywhere that replaces an already-registered id.
**The first script to register a given item id wins outright; the
second script's registration for that exact id is rejected, not
queued, not merged, not chosen at dispatch time.** (The rejected
script's *other* ids/aids/uids/positions, if any, are unaffected -
rejection is per-id, not per-`Action`-object or per-file.)

The same pattern (first-wins, `continue`/no-op on duplicate, one
`[warning]` naming the loser) applies identically to
`registerLuaUniqueEvent`, `registerLuaActionEvent`, and
`registerLuaPositionEvent` (`actions.cpp:72-161`) - aid/uid/position
duplicates behave the same way, just in their own separate maps.

**Is it "reject", "replace", "preserve first", "keep both", or "load
order dependent"?** All of "reject the second" and "preserve first"
and "load-order dependent" simultaneously: the outcome (one map slot,
one winner) is unconditional and deterministic *given a fixed load
order*, but *which* script's `Action` occupies that slot is entirely a
function of which one's `:register()` call executed first during
startup - see load order below.

**Exact warning emitted:**
`[registerLuaItemEvent] - Duplicate registered item with id: <id> in range from id: <first>, to id: <last>, for script: <losing script filename>`
(equivalent messages for aid/uid/position, with `[registerLuaActionEvent]`
etc.). This is a `warn`-level log, which is exactly what the reusable
Linux build's `--fail-on-warnings` smoke flag treats as a build
failure (see Ready-CI Correction 02's `SEPARATE_BLOCKER_PENDING_DIRECTOR_SPEC`
note - this pass does not touch that flag or the smoke harness).

**Is behavior deterministic across startup?** Deterministic *for a
fixed, already-built checkout on a fixed filesystem*: the same binary
against the same on-disk directory will produce the same winner every
time it starts, because `std::filesystem::recursive_directory_iterator`
enumerates a directory's entries in whatever order the underlying
filesystem returns them, and that order does not change between runs
absent a filesystem/checkout change. It is **not** deterministic
*across environments* - see next point.

**What determines script load order for these files?**
`src/lua/scripts/scripts.cpp`, `Scripts::loadScripts` (line 80),
invoked from `src/canary_server.cpp:589`
(`g_scripts().loadScripts(datapackFolder + "/scripts", false, false)`)
as a single call covering the entire `data-otservbr-global/scripts/`
tree - `scripts/actions/**` and `scripts/quests/**` are walked in the
same one `std::filesystem::recursive_directory_iterator(dir)` loop
(`scripts.cpp:105`), with no sorting of entries anywhere in this
function or its caller. `std::filesystem::recursive_directory_iterator`'s
enumeration order is not specified by the C++ standard - it reflects
whatever the OS/filesystem's raw directory-entry order is, which can
differ by OS, filesystem type, and even filesystem history (e.g. an
ext4 directory using hashed indexes, or a freshly-cloned checkout vs.
one that had files added/removed over time). **Canary's own loader
performs no alphabetical, path-based, or `actions/`-before-`quests/`
ordering of any kind** - the "first registration wins" rule is applied
to whatever order the filesystem happens to hand back, which this
codebase does not control and does not pin.

**Can one Action handler safely dispatch multiple gameplay contexts
based on target/action id, quest storage, target type, etc.?** Yes -
this is not hypothetical, it is the established pattern already used
inside every one of the eight files read for this investigation:
`fluids.lua`'s own `fluid.onUse` already branches on `target.itemid`
(including a narrow `target.actionid == 2023` graveyard special case
inside the *same* generic fluid handler), and `baking.lua`'s `baking.onUse`
already branches on `item.itemid`/`target.itemid`/oven-tile membership
inside one handler covering nine unrelated item ids. A single `Action`
registered once for a colliding id, with an early narrow predicate
(target name/type, target action id, quest storage) dispatching to
quest-specific logic and falling through to the generic branch
otherwise, is architecturally identical to code already merged and
running in this exact datapack.

**Does returning `false` allow another Action registered to the same
item id to execute, or is that assumption invalid?** **Invalid.**
`Actions::getAction` (`actions.cpp:222-257`) performs exactly one
lookup per id-space (position map, then uid map, then aid map, then
the plain item-id map, then a rune-spell fallback) and returns at most
one `Action` pointer. `Actions::internalUseItem`
(`actions.cpp:259-292`) calls `action->executeUse(...)` on that single
resolved action; if it returns `false` (and the item was not removed
mid-call), execution falls through to the engine's own **built-in,
non-Lua** item-type handling later in the same function (door / bed /
container / depot locker / reward chest, and further cases below what
was read for this pass) - never to a second Lua-registered `Action`
for the same id, because there is no second entry in the map to find.
Every "return false" seen in the eight files investigated below (e.g.
`action_candia_misc.lua`'s `jarAction`, `action_fairy_treasure_stones.lua`'s
`rakeAction`, `action_gingerbread_recipe.lua`'s `doughAction`,
`action_raid_catapult.lua`'s `loadStone`/`lightCatapult`) was written
as if a sibling handler for the same id might still run - that
assumption does not hold in this engine for two Actions sharing one
plain item id.

---

## B. The four duplicate pairs

### 2874

**Registrations:** `fluids.lua:191` -
`fluid:id(2524, 2873, 2874, 2875, 2876, 2877, 2879, 2880, 2881, 2882, 2885, 2893, 2901, 2902, 2903, 2904, 3465, 3477, 3478, 3479, 3480)`
(21 ids, one generic Action). `action_candia_misc.lua:94` -
`jarAction:id(2874)` (this id only, its own `Action` object).

**fluids.lua `fluid.onUse` (`fluids.lua:91-189`):** generic
fluid-container logic shared across ~21 item ids - pouring between
fluid containers, drinking (with per-fluid flavor text and drunk/poison/mana/
health effects), filling from a fountain (`target.itemid == 26076`),
emptying onto the ground as a puddle, and one existing narrow special
case (`item.type == 5 and target.actionid == 2023`, a graveyard
teleport). Every code path ends in `return true` - this handler never
returns `false`.

**action_candia_misc.lua `jarAction.onUse` (`action_candia_misc.lua:71-92`):**
Threatened Dreams Mission06 Honey Elemental capture. Predicate:
`target:isMonster() and target:getName():lower() == "honey elemental"`,
gated by `player:getStorageValue(ThreatenedDreams.Mission06[1]) == 13`.
Outside either condition, returns `false`. Inside it, consumes the jar
and the monster, increments `HoneyElementalCount` (capped at 5), and
advances the mission stage when both `HoneyElementalCount >= 5` and
`CandyCaneCount >= 3`.

**Intended systems:** fluids.lua = the game-wide generic
fill/drink/pour mechanic for the "vial" item class. action_candia_misc.lua
= one narrow step of Threatened Dreams Mission06.

**Overlap:** exactly overlapping in id-space (both claim plain item id
`2874`), but the *contexts* are mutually exclusive by construction -
one requires a live monster target named "Honey Elemental" under a
specific quest storage value; the other is any ordinary fluid-container
interaction. There is no scenario where both branches would have fired
on the same interaction.

**What currently happens at runtime (confirmed, not inferred - see
Section C):** `fluids.lua`'s registration for `2874` wins.
`action_candia_misc.lua`'s `jarAction:id(2874)` registration is
rejected at startup. The Honey Elemental capture mechanic is **entirely
unreachable** for every player, in every game state - the jar item
never resolves to `jarAction` at all, regardless of target or quest
storage.

**What's shadowed/lost:** the entire Honey Elemental capture step of
Threatened Dreams Mission06 (function lost, not partially - see
Section C).

**Minimal preservation design:** add the Honey Elemental predicate as
an early branch inside `fluids.lua`'s existing `fluid.onUse`, using
the same in-function narrow-special-case pattern that function already
uses for the `target.actionid == 2023` graveyard case: check
`target and target:isMonster() and target:getName():lower() == "honey elemental" and player:getStorageValue(ThreatenedDreams.Mission06[1]) == 13`
before the generic fluid-container logic, run the capture logic and
`return true` when it matches, and fall through unchanged to the
existing generic branches otherwise. Single registration of `2874`
(unchanged, still in `fluids.lua`), `action_candia_misc.lua`'s
`jarAction:id(2874)`/`:register()` removed since the logic moves into
`fluids.lua`. **What should happen outside the quest context or when
the target isn't a Honey Elemental:** exactly what happens today when
`fluids.lua` wins - the untouched generic fluid-container behavior.
No new item id is needed or proposed.

### 3452

**Registrations:** `rake.lua:20` - `rake:id(3452)` (this id only).
`action_fairy_treasure_stones.lua:39` - `rakeAction:id(3452)` (this id
only, a separate `Action` object; the same file also registers
`agaricAction`, `combineAction`, `oldMapAction`, and `treasureAction`
on unrelated ids/aids, none of which collide).

**rake.lua `rake.onUse` (`rake.lua:3-18`):** two hardcoded generic
targets - `target.itemid == 11366` (Wrath of the Emperor Mission02
clay) and `target.itemid == 6094` (The Shattered Isles governor's
daughter ring, gated by `Storage.Quest.U7_8.TheShatteredIsles.TheGovernorDaughter == 1`).
Always `return true`, even when neither target matches (silent no-op).

**action_fairy_treasure_stones.lua `rakeAction.onUse` (`:15-37`):**
Threatened Dreams Mission04 - five "sentient stones" placed with map
action ids `45710`-`45714` (`stoneGuards` table, `:1-12`), each mapped
to its own per-stone storage guard
(`ThreatenedDreams.Mission04.Stone1`..`Stone5`). Predicate: `target`
must exist and `target:getActionId()` must be one of `45710`-`45714`.
Returns `false` immediately if not. Inside the gate: checks
`MapGrumpyStone` (already-complete short-circuit) and the specific
stone's own guard storage (anti-repeat), then sets the guard, sends
feedback, and increments a `StonesRaked` counter.

**Intended systems:** rake.lua = generic rake tool used on two
unrelated hardcoded world objects across two different quests
(Wrath of the Emperor, The Shattered Isles). action_fairy_treasure_stones.lua
= one narrow step (5 map-placed stones) of Threatened Dreams Mission04.

**Overlap:** exactly overlapping in id-space, mutually exclusive in
context - `rake.lua` checks `target.itemid` against two fixed ids that
are neither `25446`-`25465` (the stone item range noted in the file
header) nor carry aid `45710`-`45714`; `action_fairy_treasure_stones.lua`
checks only `target:getActionId()`. No target could satisfy both.

**What currently happens at runtime (confirmed):** `rake.lua`'s
registration for `3452` wins; `action_fairy_treasure_stones.lua`'s
`rakeAction:id(3452)` is rejected. The entire 5-stone Threatened
Dreams Mission04 raking step is unreachable - using a rake on any of
the sentient stones falls through to `rake.lua`'s `rake.onUse`, which
doesn't recognize the target's action id at all and silently
`return true`s with no effect, no message, and no storage progress.

**What's shadowed/lost:** the Threatened Dreams Mission04
stone-raking step in its entirety (function lost - see Section C).

**Minimal preservation design:** add
`stoneGuards[target:getActionId()]` as the first check inside
`rake.lua`'s `rake.onUse` (before the two hardcoded `target.itemid`
branches), dispatching into the existing Mission04 logic when it
matches and falling through unchanged to the current two-branch
generic logic otherwise. Single registration of `3452` in `rake.lua`;
`action_fairy_treasure_stones.lua`'s `rakeAction:id(3452)`/`:register()`
removed (its other four Action registrations in that file are
untouched, since none of them collide).

### 6276

**Registrations:** `baking.lua:66` -
`baking:id(3603, 3604, 3605, 6276, 8018, 8195, 8196, 8198, 30975)` (9
ids, one generic Action; only `6276` collides - `8018` does not,
because `action_gingerbread_recipe.lua` scopes its oven step by aid
`45733`, not by item id `8018`). `action_gingerbread_recipe.lua:54` -
`doughAction:id(6276)` (this id only, a separate `Action` object; the
same file also registers `basinAction`/aid `45732`,
`syrupAction`/ids `8012`+`8013`, `moonMelonAction`/aid `45734`, and
`ovenAction`/aid `45733`, none of which collide with `baking.lua`).

**baking.lua `baking.onUse` (`baking.lua:7-64`):** generic bakery
dispatch across 9 unrelated ids/branches (flour+liquid → dough
variants, dough+garlic, garlic-dough+tray, oven-baking of several
dough types into finished food, sugarcane+wheat, millstone grinding).
The relevant branch: `item.itemid == 6276 and target.itemid == 6574`
(`baking.lua:24-27`, cake dough + bar of chocolate) → transforms both
items down by one charge and grants item `8018` (lump of chocolate
dough), no storage write, no message. Falls to `else return false`
(`:61`) only when none of the `elseif` conditions match at all - the
6276-vs-6574 branch itself is unconditional once entered (no quest
gate).

**action_gingerbread_recipe.lua `doughAction.onUse` (`:38-52`):**
Threatened Dreams Mission06 Gingerbread Key recipe. Predicate:
`target and target:getId() == 6574`, otherwise `return false` - **no
other check**. Consumes `target:remove(1)`/`item:remove(1)` (whole
units, not charge-decrement), grants item `8018`, and sets
`ThreatenedDreams.Mission06.ChocolateDough` (used only to print
"You already have enough chocolate dough." on a repeat use - see
under-gating note below).

**Intended systems:** baking.lua = the game-wide generic bakery
mechanic. action_gingerbread_recipe.lua = the Sweet Dreams /
Gingerbread Key quest chain step that combines cake dough with
chocolate.

**Overlap:** this pair is **not** cleanly mutually exclusive like the
other three - both branches trigger on the *exact same item pair*
(`6276` + `6574`) with no distinguishing quest-context check on either
side for that specific combination. `baking.lua`'s branch has no
storage gate at all (by design - it's meant to be generic), and
`action_gingerbread_recipe.lua`'s `doughAction` also has no storage
gate on entry (see under-gating flag below) even though it is meant to
be quest-specific.

**What currently happens at runtime (confirmed):** `baking.lua`'s
registration for `6276` wins; `action_gingerbread_recipe.lua`'s
`doughAction:id(6276)` is rejected. **Practical impact is partially
mitigated by the overlap noted above**: because `baking.lua`'s own
generic branch already turns `6276` + `6574` into item `8018` via a
different-but-functionally-adjacent mechanism (charge-decrement
transform vs. whole-unit remove), a player following the Gingerbread
Key recipe still *obtains* item `8018` by using cake dough on
chocolate - the concrete quest-progress item shows up either way.
What is genuinely lost is the `ChocolateDough` storage write and its
associated "You already have enough chocolate dough." duplicate-use
message. Checking `ovenAction.onUse` (`action_gingerbread_recipe.lua:117-137`):
it gates only on `SyrupMoonMelon`/`SyrupRaspberry`/`SyrupLemon` and on
physically holding item `8018` - it **never reads `ChocolateDough` at
all** - so the lost storage write does not block quest completion; a
player can simply re-make chocolate dough (via `baking.lua`'s
unlimited generic path) as many times as they want with no "already
have enough" gate.

**Under-gating - flagged separately, not fixed, per instruction.**
`action_gingerbread_recipe.lua`'s `doughAction.onUse` has **no
Threatened Dreams quest-stage check at all** (unlike its sibling
`basinAction`, which correctly gates on
`ThreatenedDreams.Mission06.ForestFuryFreed`). Even if this
registration collision were the only problem and `doughAction` somehow
won the race instead, any player anywhere holding a `6276` and a
`6574` - whether or not they have ever started Threatened Dreams -
would trigger the quest-specific chocolate-dough conversion and write
`ThreatenedDreams.Mission06.ChocolateDough`. This is a pre-existing
gap independent of the registration collision; it is reported here
per the instruction not to silently invent or apply a gate.

**What's shadowed/lost:** the `ChocolateDough` anti-duplication
storage flag and its message only (not the underlying item grant,
which the generic handler already provides for this specific pair) -
this pair is a milder instance of the collision than 2874/3452/12724.

**Minimal preservation design:** fold the `ChocolateDough` storage
write into `baking.lua`'s existing `6276`+`6574` branch (still inside
the generic handler, still one registration of `6276`), so the one
surviving code path produces both the item and the storage
bookkeeping. `action_gingerbread_recipe.lua`'s `doughAction:id(6276)`/`:register()`
removed; its four other registrations in that file are unaffected.
The under-gating question (should this branch require
`ForestFuryFreed` the way `basinAction` does) is a separate decision
for the Director and is not resolved or assumed here.

### 12724

**Registrations:** `action_raid_catapult.lua:54` -
`loadStone:id(HEAVY_STONE_ID)` where `HEAVY_STONE_ID = 12724` (this id
only; the same file's `stonePile`/aid `45910`, `lightCatapult`/id
`35337`, and `fireCatapult`/aid `45912` do not collide).
`mission02_defence.lua:144` - `heavyStone:id(12724)` (this id only;
the same file's `missionGuide` MoveEvent and `stonePile`/aid `40005`
do not collide - `stonePile` in this file is a different aid,
`40005`, unrelated to `action_raid_catapult.lua`'s own differently-scoped
`stonePile`/aid `45910`).

**action_raid_catapult.lua `loadStone.onUse` (`:41-53`):** A Pirate's
Tail ship-raid catapult loading, one of five identical raid locations.
Predicate: `target and target:getActionId() == CATAPULT_AID (45911)`,
else `return false`. Inside the gate: checks `shipRaidActive()`
(`Game.getStorageValue(GlobalStorage.APiratesTailRaid.Active) == 1`
and `.Type == 3`), consumes the stone, and sets a local
(non-persistent) `catapultLoaded[player:getId()]` flag consumed later
by `fireCatapult`.

**mission02_defence.lua `heavyStone.onUse` (`:122-142`):** The Rookie
Guard Mission02 catapult loading, across four fixed roof catapults.
Predicate: `missionState >= 2 and missionState <= 3 and catapults[item2.actionid]`
where `catapults` maps aids `40006`-`40009` to four named catapult
flags; **no `else`/early `return false` at all** - the function always
falls to an unconditional `return true` (`:141`) regardless of whether
the `if` matched.

**Intended systems:** action_raid_catapult.lua = A Pirate's Tail
Mission01 ship-raid mechanic (5 raid locations, storage-timed raid
window). mission02_defence.lua = The Rookie Guard Mission02 tutorial
catapult-loading mechanic (4 fixed roof catapults, an early
new-player quest).

**Overlap:** exactly overlapping in id-space, mutually exclusive in
context by target action id - A Pirate's Tail's catapults carry aid
`45911`; The Rookie Guard's carry aids `40006`-`40009`. No target
satisfies both. Neither script assumes exclusive *ownership* of the
item in the sense of hardcoding assumptions about the other's
existence, but the collision is the most severe of the four pairs
because of how each side fails:

**What currently happens at runtime (confirmed):**
`mission02_defence.lua`'s registration for `12724` wins;
`action_raid_catapult.lua`'s `loadStone:id(12724)` is rejected. Because
`heavyStone.onUse` has no `return false` path at all, it unconditionally
swallows every use of item `12724` regardless of target - **A Pirate's
Tail's catapult-loading step is not just shadowed but permanently
unreachable with zero possibility of engine fallthrough**, since the
winning handler never returns `false` to reach even the built-in
item-type fallback. (Had the load order gone the other way, the
reverse would also have been total: `loadStone.onUse` returns `false`
for any target whose aid isn't `45911`, which includes every one of
The Rookie Guard's `40006`-`40009` catapults, so Mission02's own
catapult step would be equally dead in that direction, falling through
only to built-in engine handling with no matching item-type case.)
This is a full mutual-exclusion collision - **whichever file loses,
its entire mechanic is completely dead**, not degraded or partially
working.

**What's shadowed/lost:** A Pirate's Tail Mission01's catapult-loading
step, entirely (confirmed direction - see Section C).

**Minimal preservation design:** since item `12724` ("heavy stone")
has no generic, non-quest behavior at all - both files' comments
independently describe it as a raid/quest item reused between the two
quests - there is no natural "generic handler" to consolidate into.
Recommend a single `Action` registered once for `12724` that checks
`target:getActionId()` first: route to A Pirate's Tail logic when it
is `CATAPULT_AID (45911)`, route to The Rookie Guard logic when it is
one of `40006`-`40009`, and preserve a safe default for anything else
(recommend explicit `return false` for the unmatched default, since
that correctly reaches the engine's built-in fallback instead of
`heavyStone`'s current unconditional `true` swallow - noted here as
part of the preservation design, not applied). Files a production
correction would touch: `action_raid_catapult.lua` and
`mission02_defence.lua` (one absorbs the other's function, or a small
shared dispatch is extracted - see Section D).

---

## C. Load-order / shadowing reproduction

No production files were modified to perform this check. Reproduction
used two static/empirical sources: (1) the engine source reading in
Section A, and (2) the **actual runtime warning log from the
already-executed Linux release build/smoke job on PR #39** (the
`--fail-on-warnings` Global datapack smoke run the Ready-CI Correction
02 pass already surfaced as a separate, out-of-scope blocker) -
reading that log is investigation, not a modification, and no rerun
was triggered for this pass.

**Evidence:** GitHub Actions job `Build - Linux / Compile (linux-release)`,
run `34888171631`, job `104124305939`, repository `Hokz/canary`, PR #39
branch `chore/ci-reliability-blockers-01` (commit `89ad371ee...`).
Every `[registerLuaItemEvent]` "Duplicate registered item" line in
that job's log names the **losing** script (per Section A's exact
warning text). Full set observed, deduplicated:

```
id: 12724  -> loser: action_raid_catapult.lua
id: 2874   -> loser: action_candia_misc.lua
id: 3452   -> loser: action_fairy_treasure_stones.lua
id: 3599   -> loser: action_candia_misc.lua           (OUT OF SCOPE)
id: 3607   -> loser: action_supply_mission.lua         (OUT OF SCOPE)
id: 6276   -> loser: action_gingerbread_recipe.lua
id: 8012   -> loser: action_gingerbread_recipe.lua     (OUT OF SCOPE)
id: 8013   -> loser: action_gingerbread_recipe.lua     (OUT OF SCOPE)
```

This confirms, empirically, for the actual Linux CI environment as of
this pass:

- **2874**: `action_candia_misc.lua` (`jarAction`, Honey Elemental
  capture) loses. `fluids.lua` wins.
- **3452**: `action_fairy_treasure_stones.lua` (`rakeAction`,
  Threatened Dreams Mission04 stones) loses. `rake.lua` wins.
- **6276**: `action_gingerbread_recipe.lua` (`doughAction`, Gingerbread
  Key chocolate dough) loses. `baking.lua` wins.
- **12724**: `action_raid_catapult.lua` (`loadStone`, A Pirate's Tail
  catapult loading) loses. `mission02_defence.lua` wins.

**Important caveat, stated plainly per Section A:** this outcome
reflects the current Linux CI runner's filesystem enumeration order
for this specific checkout, not a rule enforced anywhere in canary's
own code. `std::filesystem::recursive_directory_iterator` order is
implementation-defined and unsorted in this loader; a different OS, a
different filesystem, or a reorganized directory tree could change
which side wins. The **empirical result above is real and current**,
but it is not a guarantee that will hold on every future run.

**Risk classification per id** (severity itself is Director-only;
these are functional-impact classifications only):

- **2874: FUNCTION_LOST.** Confirmed - Honey Elemental capture is
  entirely unreachable in the current build. (The reverse direction,
  if load order flipped, would also be FUNCTION_LOST for the generic
  fluid-container behavior on this one id - either direction is a full
  loss, never a partial one.)
- **3452: FUNCTION_LOST.** Confirmed - the Threatened Dreams Mission04
  5-stone raking step is entirely unreachable in the current build.
- **6276: FUNCTION_LOST, mitigated.** Confirmed the quest-specific
  code path is unreachable, but the winning generic handler happens to
  already produce the same item outcome for this exact pair - the only
  concretely lost behavior is the `ChocolateDough` anti-duplication
  storage flag/message, not quest completion capability. Also carries
  a separately-flagged under-gating issue (see above), independent of
  the registration collision.
- **12724: FUNCTION_LOST.** Confirmed - A Pirate's Tail's
  catapult-loading step is entirely and unconditionally unreachable
  (the winning handler never returns `false`, so there isn't even a
  built-in-engine fallback path). This is the most severe of the four
  in terms of totality of loss, though not in terms of ranking
  priority (Director-only).

None of the four is ORDER_DEPENDENT in the sense of "both currently
work, order only affects which"; none is WARNING_ONLY_BUT_BOTH_WORK -
every one of the four has a real, currently-unreachable function
behind it in the present build.

---

## D. Proposed fix shape (non-authoritative, hypotheses only)

| id | Recommended shape | Files a future correction would touch |
|---|---|---|
| 2874 | `CONSOLIDATE_IN_GENERIC_HANDLER` | `fluids.lua` (add narrow Honey Elemental branch); `action_candia_misc.lua` (remove `jarAction`'s `:id(2874)`/`:register()`, and the now-dead `jarAction` function itself) |
| 3452 | `CONSOLIDATE_IN_GENERIC_HANDLER` | `rake.lua` (add `stoneGuards`-driven branch); `action_fairy_treasure_stones.lua` (remove `rakeAction`'s `:id(3452)`/`:register()` and function; its other four registrations stay) |
| 6276 | `CONSOLIDATE_IN_GENERIC_HANDLER` | `baking.lua` (fold `ChocolateDough` storage write into the existing `6276`+`6574` branch); `action_gingerbread_recipe.lua` (remove `doughAction`'s `:id(6276)`/`:register()` and function; its other four registrations stay). Under-gating question left to the Director. |
| 12724 | `EXTRACT_SHARED_DISPATCH_HELPER` | `action_raid_catapult.lua` and `mission02_defence.lua` (one absorbs the other's logic behind a single `target:getActionId()` dispatch, or both delegate to a small shared function) - no generic/non-quest owner exists for this id, so neither `CONSOLIDATE_IN_GENERIC_HANDLER` nor `CONSOLIDATE_IN_QUEST_HANDLER` cleanly applies |

These are hypotheses for the Director's evaluation, not approved
designs, and were not implemented.

---

## E. Scope control

Investigation was held exactly to item ids `2874`, `3452`, `6276`,
`12724`. No other file, quest, or system was modified.

### OUT_OF_SCOPE_BACKLOG

Observed in the same Linux release smoke run's log (`34888171631`,
job `104124305939`), listed only, not investigated:

- Duplicate registered item id `3599` - loser `action_candia_misc.lua`
  (this file also holds the in-scope `jarAction`/2874; `candyCaneAction`
  is the `3599` registrant that lost, competing against some other,
  unidentified script also claiming `3599`).
- Duplicate registered item id `3607` - loser `action_supply_mission.lua`.
- Duplicate registered item ids `8012` and `8013` - loser
  `action_gingerbread_recipe.lua` (`syrupAction`).
- `[MonsterTypeFunctions::luaMonsterTypeOutfit] An unregistered
  creature looktype type with id '1361' was blocked to prevent client
  crash.` - a monster/looktype warning, unrelated to Action
  registration.
- A cluster of `[error] Database not initialized!` /
  `[executeWithinTransaction] Failed to begin transaction` /
  `[saveHouseInfo]` / `[saveAll]` / `Failed to save map.` /
  `Failed to save key-value store.` errors, which read as smoke-harness
  shutdown-sequence noise (server stopping without a live DB
  connection) rather than anything related to Action registration.

None of the above was traced further, fixed, suppressed, or
allowlisted in this pass.

---

## Validation of the investigation branch

- Baseline verified: `origin/main` == `4209ba583a4dcb2ae528750dcfeb2e7c0109863a`
  before branching.
- Branch contains exactly one new file (this report); `git status`
  and `git diff --stat` against `main` confirm no production file, no
  workflow file, and no other doc was modified.
- `git diff --check`: clean.
- No changes to PR #38 or PR #39, no merge, no manual workflow rerun -
  the only external system touched was `gh run view --log` (read-only)
  against an already-completed job.
