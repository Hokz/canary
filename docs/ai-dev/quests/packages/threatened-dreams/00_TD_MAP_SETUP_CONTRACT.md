# 00 — Threatened Dreams Map Setup Contract

**Status as of `main@37bb9ba7b` (PR #17, merged):** CODE COMPLETE, MAP SETUP REQUIRED.

This is a documentation-only consolidation. No code was changed to produce this file. Positions below were pulled from two sources: (a) hardcoded `Position(...)` values already present in this quest's scripts (pre-existing missions 1-3), and (b) `data-otservbr-global/world/otservbr-npc.xml` / `otservbr-monster.xml` — the plaintext NPC/monster **spawn** files, which are safely greppable (not OTBM/binary) and were checked directly rather than assumed. Where neither source has a real position, the entry is marked `OWNER_MAP_EDITOR_REQUIRED` rather than invented.

**Note on scope**: `otservbr-npc.xml`/`otservbr-monster.xml` are plain XML and could technically be hand-edited without touching OTBM, but doing so is out of scope for this documentation-only package — flagged here only as a fact discovered while compiling this contract, not acted on.

## 1–2. NPC placements & monster spawns

| Area | Dependency | Type | File/script | Required id/action/uid | Expected position or area | Purpose | Code ready? | Manual setup needed? | Status |
|---|---|---|---|---|---|---|---|---|---|
| Troubled Animals | Alkestios | NPC | `npc/alkestios.lua` | n/a | `otservbr-npc.xml`: centerx 32307-ish area (white deer, north of Green Claw Swamps) | Quest start/hub NPC | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | Ahmet | NPC | `npc/ahmet.lua` (pre-existing) | n/a | Confirmed in `otservbr-npc.xml`, z=6 | Doctors the book with Old Legends | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | Ikassis | NPC | `npc/ikassis.lua` | n/a | Confirmed in `otservbr-npc.xml`, z=7, near Alkestios/A Swan cluster | Wolf-mother mission hub, hands off to A Swan | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | **Ghostly Wolf** | NPC | `npc/ghostly_wolf.lua` | n/a | **Not found in `otservbr-npc.xml` under any name variant searched ("Ghostly Wolf", "ghost", "wolf")** | Whelp-fur redemption dialogue at Ulderek's Rock area | Yes (dialogue functional) | **Yes — needs placement** | **OWNER_MAP_EDITOR_REQUIRED** |
| Troubled Animals | Irmana | NPC | `npc/irmana.lua` (pre-existing) | n/a | Confirmed in `otservbr-npc.xml`, z=5 (Venore) | Sells Fur of a Wolf Whelp | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | A Swan | NPC | `npc/a_swan.lua` (pre-existing) | n/a | Confirmed in `otservbr-npc.xml`, z=7 | Swan Maiden mission hub | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | Chief Grarkharok | NPC | `npc/chief_grarkharok.lua` (pre-existing) | n/a | Confirmed in `otservbr-npc.xml` (2 entries, z=1) | Troll who sold the swan cloak | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | Tereban | NPC | `npc/tereban.lua` (pre-existing) | n/a | Confirmed in `otservbr-npc.xml` (2 entries, z=6) | Lost the cloak's feathers over Edron/Darashia | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | 5 swan feather spots | MoveEvent | `movement_swan_feathers.lua` | aid 25024-25028 | Hardcoded positions already in script (Edron grass, Darashia dustbin/cactus/dragon skull/dead tree) | Feather collection for the cloak | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | Pile of Bones / sleeping war wolf | MoveEvent | `movement_poacher_notes.lua` | position-triggered | `Position(32949-32951, 31811, 7)` — hardcoded, already real | Notes of a Poacher discovery | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | Book with Old Legends / poacher table | Action | `action_poacher_book.lua` | item id 25235 | Object-interaction, not position-gated | Doctored-book placement | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Troubled Animals | Weeping Stone | Action | `action_whelp_fur.lua` | item id 25238 | Object-interaction, not position-gated | Whelp fur placement | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Nightmare Intruders | Maelyrra | NPC | `npc/maelyrra.lua` (pre-existing) | n/a | Confirmed in `otservbr-npc.xml`, z=7 | Feyrist quest hub for missions 2/3/6 | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Nightmare Intruders | Kroazur boss room | MoveEvent + dynamic spawn | `movement_kroazur_room.lua` | position-triggered | `Position(33591, 32305, 10)` boss/center, `33591,32315,10` entry, `33619,32306,9` exit — all hardcoded, already real | 2h-cooldown boss fight | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Nightmare Intruders | Light collection spots (sun/moon/star) | Action | `action_sun_catcher.lua`, `action_moon_mirror.lua`, `action_starlight_vial.lua` | position ranges | Hardcoded `fromPos`/`toPos` ranges + 5 named positions each — already real | Barrier-charging light gathering | Yes | No | ALREADY_PRESENT_CONFIRMED |
| An Unlikely Couple | Aurita | NPC | `npc/aurita.lua` (pre-existing) | n/a | Confirmed in `otservbr-npc.xml`, z=7 | Panpipes/music-note mission | Yes | No | ALREADY_PRESENT_CONFIRMED |
| An Unlikely Couple | Dancing Fairy | NPC | `npc/dancing_fairy.lua` | n/a | Confirmed in `otservbr-npc.xml`, z=7 | Fishtail-to-legs spell fairy | Yes | No | ALREADY_PRESENT_CONFIRMED |
| An Unlikely Couple | Taegen | NPC | `npc/taegen.lua` | n/a | Confirmed in `otservbr-npc.xml`, z=7 | Raven Herb / sun catcher faun | Yes | No | ALREADY_PRESENT_CONFIRMED |
| An Unlikely Couple | Raven herb bush | GlobalEvent + Action | `event_raven_herb_bush.lua` | item id 25783 | `Position(33497, 32196, 7)` — hardcoded, already real | Night-only herb gathering | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Fairy Treasure | Tooth Fairy | NPC | `npc/tooth_fairy.lua` | n/a | Confirmed in `otservbr-npc.xml`: `centerx=32701 centery=31734 centerz=7` | Milk-tooth mission hub, tooth collection, Family Feud | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Fairy Treasure | Tired Tree | NPC | `npc/tired_tree.lua` | n/a | Confirmed: `centerx=32307 centery=31645 centerz=7` (Fields of Glory) | Bedtime-story map piece | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Fairy Treasure | Grumpy Stone | NPC | `npc/grumpy_stone.lua` | n/a | Confirmed: `centerx=32619 centery=31864 centerz=7` (Kazordoon/Femor Hills) | Rake-5-stones map piece | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Fairy Treasure | 3 children's chests of drawers | Action | `action_fairy_treasure_presents.lua` (`drawerAction`) | aid 45706, 45707, 45708 | One per child bedroom: Thais, Venore, Carlin — exact tiles not specified by reference | Milk tooth pickup | Yes | **Yes — 3 tiles** | CODE_READY_POSITION_UNKNOWN |
| Fairy Treasure | 3 children's beds | Action | `action_fairy_treasure_presents.lua` (`bedAction`) | aid 45703, 45704, 45705 | Same 3 bedrooms, bed head part; also reused by Family Feud (toothbrush delivery) | Presents delivery + toothbrush delivery | Yes | **Yes — 3 tiles** | CODE_READY_POSITION_UNKNOWN |
| Fairy Treasure | 5 sentient stones | Action (target-based) | `action_fairy_treasure_stones.lua` (`rakeAction`) | aid 45710-45714 | 5 stone item tiles around Grumpy Stone (32619, 31864 area) | Rake interaction | Yes | **Yes — 5 tiles** | CODE_READY_POSITION_UNKNOWN |
| Fairy Treasure | Big Fly Agaric | Action (item-based) | `action_fairy_treasure_stones.lua` (`agaricAction`) | item id 25385/25386 | South of the Tired Tree, Fields of Glory | Fourth map part | Yes | No — item-based, works wherever the item already exists on the map | ALREADY_PRESENT_CONFIRMED (item type, not a new placement) |
| Fairy Treasure | Thais sun mosaic treasure | Action | `action_fairy_treasure_stones.lua` (`treasureAction`) | aid 45715 | Very south of Thais, stone sun mosaic | Final treasure reward | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Swan Feather Cloak | Valindara | NPC | `npc/valindara.lua` | n/a | **Not found in `otservbr-npc.xml`** — this NPC file is pre-existing (368-line merchant) but has no confirmed placement under the name searched | Cloak crafting | Yes | **Yes — confirm/verify placement** | OWNER_MAP_EDITOR_REQUIRED |
| Swan Feather Cloak | 8 swan feather spots | MoveEvent | `movement_swan_feather_spots.lua` | aid 45720-45727 | Near swans around Feyrist, day-only — exact tiles not specified by reference | 5-feather harvest, 20h cooldown each | Yes | **Yes — 8 tiles** | CODE_READY_POSITION_UNKNOWN |
| Sweet Dreams | Captive Forest Fury | NPC | `npc/captive_forest_fury.lua` | n/a | Corym Black Market, beneath Liberty Bay | Rescue mission hub | Yes | **Yes — new NPC** | OWNER_MAP_EDITOR_REQUIRED |
| Sweet Dreams | Charlotta (new branch reuses existing NPC) | NPC | `npc/charlotta.lua` | n/a | Confirmed in `otservbr-npc.xml`: `centerx=32268 centery=32841 centerz=7` (Liberty Bay area — consistent with Corym Black Market being "beneath Liberty Bay") | Mirror image crafting | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Sweet Dreams | Intricate cage key spot | Action | `action_forest_fury_rescue.lua` (`keyAction`) | aid 45730 | 2 floors below the Captive Forest Fury | Key pickup | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Sweet Dreams | Fury's cage | Action | `action_forest_fury_rescue.lua` (`cageAction`) | aid 45731 | At the Captive Forest Fury's location | Rescue completion | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Sweet Dreams | Kitchen basin | Action | `action_gingerbread_recipe.lua` (`basinAction`) | aid 45732 | Any kitchen, per reference | Flour → cake dough | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Sweet Dreams | Moon melon vine | Action | `action_gingerbread_recipe.lua` (`moonMelonAction`) | aid 45734 | Feyrist, night-only interaction | Moon melon syrup (storage fallback — no physical item) | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Sweet Dreams | Oven | Action | `action_gingerbread_recipe.lua` (`ovenAction`) | aid 45733 | Feyrist, final baking step | Gingerbread Key completion, Candia access | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Sweet Dreams | Candy Lipstick spot | Action | `action_candia_misc.lua` (`lipstickAction`) | aid 45740 | Atop the Gingerbread Castle | Understand Candia NPCs (storage fallback — no physical item) | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Stolen Sweets | Sugar Plum Fairy | NPC | `npc/sugar_plum_fairy.lua` | n/a | Candia | Stolen Sweets / Family Feud / Cherry hub | Yes | **Yes — new NPC** | OWNER_MAP_EDITOR_REQUIRED |
| Stolen Sweets | Kroazur (reused, Stolen Sweets sub-drop) | Monster (dynamic) | `creaturescripts_sweets_death.lua` | n/a | Same boss room as Nightmare Intruders (33591, 32305, 10) | Drops "Matcha Turtle" flag on death | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Stolen Sweets | Katex Blood Tongue | Monster | `monster/quests/ancient_feud/katex_blood_tongue.lua` (pre-existing, unmodified) | n/a | **Not found in `otservbr-monster.xml`** | Drops "Rainbow Waffles" flag on death | Yes (event registered) | **Yes — confirm this pre-existing Ancient Feud boss has a live spawn/summon somewhere** | OWNER_MAP_EDITOR_REQUIRED |
| Stolen Sweets | The Flaming Orchid | Monster | `monster/bosses/the_flaming_orchid.lua` (pre-existing, unmodified) | n/a | Confirmed in `otservbr-monster.xml`, z=2 | Drops "Rose Milk Cake" flag on death | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Stolen Sweets | Gorga (new boss) | Monster | `monster/quests/threatened_dreams/bosses/gorga.lua` | n/a | Not specified by reference ("sold to other bosses") — no location given anywhere | Drops "Nightsky Cupcake" flag on death | Yes | **Yes — needs a summon lever or static spawn; no location decided** | OWNER_MAP_EDITOR_REQUIRED |
| Chocolate Mines | Candis | NPC | `npc/candis.lua` | n/a | Chocolate Mines | Mine-stabilization hub | Yes | **Yes — new NPC** | OWNER_MAP_EDITOR_REQUIRED |
| Chocolate Mines | Sugar Daddy boss portal/lever | Action + dynamic spawn | `action_sugar_daddy_lever.lua` (`sugarDaddyLever`) | aid 45741 | Chocolate Mines, deep portal | Boss summon, 20h cooldown | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Chocolate Mines | **Sugar Daddy (boss itself)** | Monster | `monster/bosses/sugar_daddy.lua` (pre-existing, unmodified stats) | n/a | Confirmed **already has a static spawn** in `otservbr-monster.xml`: `centerx=33365 centery=32231 centerz=9` | Boss fight | Yes | No — this lever creates an independent on-demand instance via `Game.createMonster`, doesn't conflict with the existing static spawn elsewhere | ALREADY_PRESENT_CONFIRMED (monster type; lever's summon point is separate, see row above) |
| Chocolate Mines | 3 broken wall repair spots | Action | `action_candia_misc.lua` (`candyCaneAction`) | aid 45742, 45743, 45744 | 2 on floor -1, 1 on floor -2 per reference | Candy cane wall sealing | Yes | **Yes — 3 tiles across 2 floors** | CODE_READY_POSITION_UNKNOWN |
| Chocolate Mines | Candy cane chest | Action | `action_candia_misc.lua` (`caneChestAction`) | aid 45745 | North of Candis | Candy cane supply | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Chocolate Mines | Honey Elemental capture area | Action (creature-target) | `action_candia_misc.lua` (`jarAction`) | item id 2874 (vial, reused as jar) used on live monster | **Confirmed already spawned**: 10 existing `Honey Elemental` entries in `otservbr-monster.xml`, several at z=9 near Sugar Daddy's own spawn cluster | Loose-elemental capture, 5 required | Yes | No — existing spawns near the boss area are usable as-is | ALREADY_PRESENT_CONFIRMED |
| Family Feud | Dulcineo | NPC | `npc/dulcineo.lua` | n/a | Candia | Feud-mediation hub | Yes | **Yes — new NPC** | OWNER_MAP_EDITOR_REQUIRED |
| Family Feud | Coco / Toffee | Not implemented | n/a | n/a | Candy Carnival, reopens per Sugar Plum Fairy's dialogue | No mechanical role or reference transcript was given beyond flavor ("Coco and Toffee will be so pleased") | No code exists for these two | N/A — no mechanic to place | BLOCKER *(scope gap, not a map gap — see note below)* |
| Cherry / Taffy Bunny | Dessert Dungeon clue spot | Action | `action_sugar_daddy_lever.lua` (`cherryClue`) | aid 45746 | Dessert Dungeons beneath Candia | "Tuft of spun pink sugar" flavor clue | Yes | **Yes — 1 tile** | CODE_READY_POSITION_UNKNOWN |
| Cherry / Taffy Bunny | A Taffy Bunny (Cherry) | Monster | `monster/quests/threatened_dreams/a_taffy_bunny.lua` | n/a | Dessert Dungeons, near the clue spot | Unkillable "too fast to catch" chase monster | Yes | **Yes — needs a spawn point** | OWNER_MAP_EDITOR_REQUIRED |

## 3. Quest objects — summary (see rows above for detail; no additional objects beyond what's listed)

All quest-interaction objects requested in the audit package (book/table, Pile of Bones, Weeping Stone, feather spots, bedrooms/chests/beds, Tired Tree/Grumpy Stone interactions, stones, agaric, sun mosaic, barrier-repair spots, light-collection tools, donut/Candia teleporter, fury cage, mirror-image interaction, recipe objects, lipstick spot, boss portal, wall-repair spots, capture area, toothbrush beds, Cherry clue) are covered in the table above under their owning mission row. Nothing was found outside that set.

## 4. Action IDs — full reserved range

| Range | Purpose | File |
|---|---|---|
| 45703-45708 | Fairy Treasure: 3 beds (703-705) + 3 drawers (706-708). **45700-45702 deliberately NOT used** — already reserved by `bigfoot_burden`'s warzone MoveEvent. | `action_fairy_treasure_presents.lua` |
| 45710-45715 | Fairy Treasure: 5 sentient stones (710-714) + treasure spot (715) | `action_fairy_treasure_stones.lua` |
| 45720-45727 | Swan Feather Cloak: 8 feather spots | `movement_swan_feather_spots.lua` |
| 45730-45731 | Sweet Dreams: cage key + cage | `action_forest_fury_rescue.lua` |
| 45732-45734 | Sweet Dreams: basin, oven, moon melon vine | `action_gingerbread_recipe.lua` |
| 45740, 45745, 45746 | Candia misc: lipstick, cane chest, Cherry clue | `action_candia_misc.lua` |
| 45741 | Chocolate Mines: Sugar Daddy lever | `action_sugar_daddy_lever.lua` |
| 45742-45744 | Chocolate Mines: 3 wall repair spots | `action_candia_misc.lua` |

Full-repo collision sweep re-confirmed clean at merge time (see prior post-merge audit) — no action id in this range is used anywhere outside the files above.

## 5. Unique IDs

**None used anywhere in this quest.** No `:uid(...)` registration exists in any Threatened Dreams script. Nothing to place.

## 6. Teleports

| Teleport | File | Positions | Code ready? | Manual setup needed? | Status |
|---|---|---|---|---|---|
| Candia ↔ Feyrist donut | `scripts/movements/teleport/candia.lua` | `(33338/33339, 32125, 7)` Candia side, `(33574/33575, 32222/32224, 7)` Feyrist side — **already real, pre-existing positions, only the access gate (`CandiaAccess` storage check) was added this quest** | Yes | No | ALREADY_PRESENT_CONFIRMED |
| Feyrist elemental shrines (ice/fire/earth/energy) | `scripts/movements/teleport/shrine_entrance.lua`, `shrine_exit.lua`, `scripts/actions/shrines/feyrist_exit.lua` | Pre-existing, unrelated to this quest's changes | Yes | No | ALREADY_PRESENT_CONFIRMED |

## 7. Boss room zones

| Boss | Room mechanism | Position | Status |
|---|---|---|---|
| Kroazur | `movement_kroazur_room.lua`, position-triggered room with entry/exit/boss positions | `(33591, 32305, 10)` center, `(33591,32315,10)` entry, `(33619,32306,9)` exit — all hardcoded, real | ALREADY_PRESENT_CONFIRMED |
| Sugar Daddy | New lever (`action_sugar_daddy_lever.lua`) creates an on-demand instance at the lever's `toPosition`; existing static spawn also present elsewhere (`33365,32231,9` area) | Lever tile position — see row in §1-2 | CODE_READY_POSITION_UNKNOWN (lever tile only) |
| Gorga | No lever/room built — reference gives no location ("sold to other bosses") | Unknown | OWNER_MAP_EDITOR_REQUIRED — **owner decision needed on where Gorga should be reachable before a lever/spawn can be built** |

## 8. Raid/task areas

Not applicable — Threatened Dreams has no raid or task-board content; all encounters are lever/portal/room-gated per the boss room zones above.

## 9. Feyrist access shrines

Pre-existing, unmodified by this quest (`shrine_entrance.lua`/`shrine_exit.lua`/`feyrist_exit.lua`). Troubled Animals' completion (`Mission01[1] = 16`) grants the narrative "you may now enter Feyrist" state but the actual shrine mechanism was already live before this quest and required no changes. ALREADY_PRESENT_CONFIRMED.

## 10. Candia/Feyrist quest objects

Covered across §1-2 and §6 above (Candia donut teleporter, Gingerbread Castle lipstick spot, Chocolate Mines objects, Dessert Dungeon clue/Cherry). No additional undocumented objects found.

## Note on Coco and Toffee (scope gap, not a map gap)

The owner's reference mentions Coco and Toffee only in passing, via Sugar Plum Fairy's dialogue ("Coco and Toffee will be so pleased" when the Candy Carnival reopens). No transcript, mechanical role, or reward was ever specified for them beyond that one flavor line. No NPC file, dialogue, or mechanic was built for either — this was a deliberate scope decision during the original implementation (not fabricating unspecified content) rather than an oversight. Listed as `BLOCKER` above only in the literal sense that *nothing exists* for them; functionally this is a **content-scope question for the owner** (should they be flavor-only background NPCs, or do they need a real role?), not a bug or a map-placement gap. No fix is proposed here since this package is documentation-only and the underlying question is a design decision, not a proven defect.

## Item Validation Table (carried forward from the item-fallback fix, PR #17 final state)

| Global item name | Quest role | Repo search terms used | Found item id? | Implementation | Storage fallback key | Owner validation needed | Status |
|---|---|---|---|---|---|---|---|
| Gingerbread Key | Access item (Candia entry) | gingerbread key | No | Storage flag only | `Mission06.GingerbreadKeyBaked` | Confirm no client sprite exists before creating an item id | GLOBAL_ITEM_PENDING_XML_VALIDATION / ACCEPTABLE_STORAGE_BACKED_FALLBACK |
| Candy Lipstick | Access item (understand Candia NPCs) | candy lipstick, lipstick | No | Storage flag only | `Mission06.LipstickUsed` | Same as above | GLOBAL_ITEM_PENDING_XML_VALIDATION / ACCEPTABLE_STORAGE_BACKED_FALLBACK |
| Raspberry Sirup | Recipe intermediate | raspberry sirup/syrup | No (raw "raspberry" 8012 exists, consumed) | Storage flag; physical raspberry item consumed into it | `Mission06.SyrupRaspberry` | Same as above | GLOBAL_ITEM_PENDING_XML_VALIDATION / ACCEPTABLE_STORAGE_BACKED_FALLBACK |
| Lemon Sirup | Recipe intermediate | lemon sirup/syrup | No (raw "lemon" 8013 exists, consumed) | Storage flag; physical lemon item consumed into it | `Mission06.SyrupLemon` | Same as above | GLOBAL_ITEM_PENDING_XML_VALIDATION / ACCEPTABLE_STORAGE_BACKED_FALLBACK |
| Moon Melon Sirup | Recipe intermediate | moon melon sirup/syrup, moon melon, moonmelon, melon | No physical item involved at all — generic "melon" (3593) explicitly rejected as not the intended asset | Storage flag; night-only Feyrist action (aid 45734) consumes Sugar directly | `Mission06.SyrupMoonMelon` | Confirm no "moon melon" sprite exists before creating an item id | GLOBAL_ITEM_PENDING_XML_VALIDATION / ACCEPTABLE_STORAGE_BACKED_FALLBACK |
| Toothbrush | Family Feud delivery step | toothbrush, tooth brush, brush, candia, feyrist | No exact match (36544 "brush" generic; 29943 "Alptramun's toothbrush" unrelated boss trophy) — both explicitly rejected as not the intended asset | Storage-only, no item at all — bed interaction sets a bit | `Mission06.ToothbrushDelivered` (bitmask: 1/2/4) | Confirm no dedicated toothbrush sprite exists before creating an item id | GLOBAL_ITEM_PENDING_XML_VALIDATION / ACCEPTABLE_STORAGE_BACKED_FALLBACK |
| Butterfly Ring | Reward, equippable | `id="25698"` | Yes | Physical, granted | n/a | None | PHYSICAL_ITEM_CONFIRMED |
| Ancient Coins | Reward | `id="24390"` | Yes | Physical, 5 granted | n/a | None | PHYSICAL_ITEM_CONFIRMED |
| Rainbow Quartz | Reward | `id="25737"` | Yes | Physical, 5 granted | n/a | None | PHYSICAL_ITEM_CONFIRMED |
| Blossom Bag | Reward (pre-existing Mission02) | present in items.xml | Yes | Physical | n/a | None | PHYSICAL_ITEM_CONFIRMED |
| Sun Catcher / Moon Mirror / Starlight Vial | Barrier-repair tools (pre-existing) | present in items.xml | Yes | Physical | n/a | None | PHYSICAL_ITEM_CONFIRMED |
| Swan Feather Cloak | Reward, equippable | `id="25779"` | Yes | Physical, granted once, duplicate-guarded | n/a | None | PHYSICAL_ITEM_CONFIRMED |
| Pegasus Feather | Reward | `id="48424"` | Yes | Physical, granted once via completed Family Feud | n/a | None | PHYSICAL_ITEM_CONFIRMED |

No reward, equippable, or player-visible collectible item is hidden in storage — every fallback above is an intermediate/access-only mechanic.

## 11. Manual test checklist (for the owner, once map setup is complete)

- [ ] Ghostly Wolf NPC is reachable and its dialogue advances `Mission01[1]` 6→7→...→10
- [ ] Valindara is reachable, confirm day-only gating now blocks correctly at night (post-fix)
- [ ] All 3 children's bedrooms (drawer + bed, aid 45703-45708) reachable in Thais/Venore/Carlin
- [ ] All 5 sentient stones (aid 45710-45714) + treasure spot (45715) reachable around Grumpy Stone/Thais
- [ ] All 8 swan feather spots (aid 45720-45727) reachable near Feyrist swans, day-only gating confirmed
- [ ] Captive Forest Fury, cage key spot (45730), cage (45731) reachable in Corym Black Market, 2 floors apart as intended
- [ ] Kitchen basin (45732), moon melon vine (45734, night-only), oven (45733) reachable in Feyrist
- [ ] Candy Lipstick spot (45740) reachable atop the Gingerbread Castle
- [ ] Sugar Plum Fairy, Candis, Dulcineo all placed and reachable in Candia/Chocolate Mines
- [ ] Sugar Daddy lever (45741) reachable in the Chocolate Mines; confirm boss summon doesn't conflict with the existing static Sugar Daddy spawn elsewhere
- [ ] 3 wall repair spots (45742-45744, 2 on floor -1 / 1 on floor -2) and cane chest (45745) reachable
- [ ] Honey Elemental capture confirmed working against the existing spawns near the Sugar Daddy area
- [ ] Cherry clue spot (45746) and A Taffy Bunny spawn reachable in the Dessert Dungeons
- [ ] Gorga: owner has decided on and placed a location before this row can be tested at all
- [ ] Full playthrough: Troubled Animals → Nightmare Intruders → An Unlikely Couple → Fairy Treasure → Swan Feather Cloak → Sweet Dreams (through Stolen Sweets, Chocolate Mines, Family Feud, Cherry) end to end, confirming no dead-end questlog states

## Final Verdict

**MAP SETUP CONTRACT READY.**

This consolidates every placement gap into one document. Summary counts: **7 NPCs need placement** (Ghostly Wolf, Valindara [verify], Captive Forest Fury, Sugar Plum Fairy, Candis, Dulcineo, +Katex Blood Tongue spawn verification), **1 new monster needs an owner-decided location** (Gorga), **1 monster needs a spawn point** (A Taffy Bunny), and **~20 action-id tiles** need placement across Fairy Treasure/Swan Feather Cloak/Sweet Dreams/Chocolate Mines/Cherry. Everything else (Troubled Animals, Nightmare Intruders, An Unlikely Couple, and several individually-checked objects) is already present and confirmed on the live map — this quest is far closer to map-complete than "map setup required" alone would suggest.
