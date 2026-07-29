# 01 — Heart of Destruction NPC Dialogue Contract

Per project rule: exact NPC dialogue may be used when authorized, but must never be invented. Every dialogue line below is either quoted from the current repository (already-accepted text) or marked `OWNER_REFERENCE_REQUIRED`. No line in this document was invented.

## NPCs involved

| NPC | File | Current dialogue logic |
|---|---|---|
| Messenger of Heaven | `data-otservbr-global/npc/messenger_of_heaven.lua` | **None** |
| Lesser Messenger of Heaven | `data-otservbr-global/npc/lesser_messenger_of_heaven.lua` | **None** |

No other NPC file references any Heart of Destruction storage, keyword, or quest name (confirmed via repo-wide grep for `HeartOfDestruction`-related identifiers across `data-otservbr-global/npc/`).

## Messenger of Heaven — full current state

Read in full. The file registers standard NPC boilerplate (`onThink`, `onAppear`, `onDisappear`, `onMove`, `onSay`, `onCloseChannel`, all forwarding to `npcHandler`) and one module:
```lua
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)
```
**There is no `creatureSayCallback`, no `npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, ...)`, and no `keywordHandler:addKeyword(...)` call anywhere in the file.** The NPC will focus on a player who greets it (via `FocusModule`) but has no configured response to any message, including "hi." No `MESSAGE_GREET` is even set.

**Status: MISSING.**
**Risk: High** — if this NPC is the quest's actual starting trigger, no player can start the quest through the documented path at all.
**Contract placeholder — `OWNER_REFERENCE_REQUIRED`:**
- Greeting text
- Required keyword(s) to learn about / start the quest (e.g., "heart", "destruction", "mission" — unknown, do not assume)
- Any storage/KV write that should occur on quest start
- Whether this NPC should also explain the vortex/route mechanic (per the owner's reference, "The NPC explains the threat related to the Heart of Destruction")

## Lesser Messenger of Heaven — full current state

Read in full. Same pattern: only `FocusModule`, no `creatureSayCallback`, no keywords, no `MESSAGE_GREET`. The `npcType` is created with the literal name `"Lesser Messenger of Heaven"` (line 2) but `npcConfig.name` is set to the string `internalNpcName` which is `"Messenger of Heaven"` (line 1/5) — i.e., the config name does not match the type name. This is worth noting as a possible latent display/identity inconsistency, but **not being treated as a safe fix in this package** since its correct in-game name/role relative to the main Messenger of Heaven is unconfirmed (could be an intentional "weaker copy" NPC used elsewhere in the room, could be a leftover unused file).

**Status: MISSING (dialogue), UNKNOWN (intended role/relationship to the main NPC).**
**Risk: Medium** — unclear whether this NPC is load-bearing for the quest at all.
**Contract placeholder — `OWNER_REFERENCE_REQUIRED`:** whether this NPC has any dialogue role in the quest, and if so, what.

## Keyword contract (updated HOD-03)

The owner has now supplied the **exact required keyword chain** (player-side only — Messenger of Heaven's own spoken lines between each keyword are still not available):

**Full chain**: `Hi → Matter → Damage → Stopped → Destroying → Heart of Destruction → Strong → Yes`
**Short alternative chain**: `Hi → Strong → Yes`

| Player keyword | NPC response text | Status |
|---|---|---|
| Hi | Unknown | `OWNER_REFERENCE_REQUIRED` |
| Matter | Unknown | `OWNER_REFERENCE_REQUIRED` |
| Damage | Unknown | `OWNER_REFERENCE_REQUIRED` |
| Stopped | Unknown | `OWNER_REFERENCE_REQUIRED` |
| Destroying | Unknown | `OWNER_REFERENCE_REQUIRED` |
| Heart of Destruction | Unknown | `OWNER_REFERENCE_REQUIRED` |
| Strong | Unknown | `OWNER_REFERENCE_REQUIRED` |
| Yes (final) | Unknown — should trigger cave/vortex access grant | `OWNER_REFERENCE_REQUIRED` |

**Why this still wasn't implemented in HOD-03**: per the package rule (*"Do not invent Messenger of Heaven dialogue... implement keyword acceptance only if... no exact long dialogue is required; otherwise mark OWNER_REFERENCE_REQUIRED"*), having only the player's half of an 8-step conversation is not enough to safely implement the NPC's side. Writing plausible-sounding filler responses for 7 unknown NPC lines would be inventing dialogue, which is explicitly disallowed. **This is now the single most valuable piece of reference text to obtain next** — with Messenger of Heaven's actual spoken lines, HOD-04 (or later) could implement this fully in one pass, following the same proven topic-chain pattern already used elsewhere in this codebase (e.g., `henricus.lua`, `zizzle.lua`).

## Yana — full current state (HOD-03: FIXED this package)

`data-otservbr-global/npc/yana.lua`. Distinct from the two Messenger of Heaven NPCs — Yana is the post-World-Devourer imbuement/token vendor.

**Before HOD-03**: the file contained a literal developer TODO comment (`-- to do: check if Heart of Destruction was killed`) directly above the "worth" keyword handler, meaning the completion check was **never implemented** — every player, regardless of progress, got the same "here's what you need to do" instructional text. That text also only listed 3 of the reference's 8 imbuements, and contained a stray Lua comment marker (`--'Powerful Vampirism'`) that would have displayed literally to players. No `MESSAGE_GREET` was set at all.

**Fixed this package**, using the owner's exact provided dialogue and the existing, already-proven `player:hasAchievement(...)` pattern (used identically elsewhere in the codebase, e.g. `iskan.lua:60`) to gate the branch:
- Added `MESSAGE_GREET`: *"Blessings, |PLAYERNAME|! How may I help you? Do you wish to trade some tokens, prove your worth to receive powerful imbuements, or do you need some information?"* — exact owner text, `|PLAYERNAME|` substituted for the reference's literal "Player" placeholder, consistent with this codebase's greeting convention.
- "worth" keyword now branches on `player:hasAchievement("Ender of the End")`:
  - **True**: exact owner text — *"I see, you disrupted the Heart of Destruction, defeated the World Devourer and bought our world some time. You are truly worthy. ..."* followed by *"You are granted the power to imbue 'Powerful Strike', 'Powerful Epiphany', 'Powerful Void', 'Powerful Vampirism', 'Power Lich Shroud', 'Power Reap', 'Power Dragon Hide' and 'Power Scorch'."*
  - **False**: the pre-existing repo teaser line, with the stray `--` syntax glitch removed and the imbuement list completed to the same 8-item set (previously listed only 3) — this is a factual-accuracy correction to existing repo text, not new invented content, since the full 8-item list is the same list the owner authorized for the success case.
- **No mechanical "access grant" was added.** Checked `data/XML/imbuements.xml` — the "Powerful" imbuement tier is a plain price/percent/duration `<base>` definition (id 3), not gated by any per-player storage or flag anywhere in the engine. There is nothing to mechanically "unlock" — Yana's dialogue is confirmed to be narrative/flavor gating only, matching the reference's own framing ("granted the power to imbue," not "granted a new capability the engine didn't already allow"). Not inventing a new access-control mechanism was a deliberate scope decision, consistent with avoiding unproven boss/mechanic rewrites.

**Status: Implemented (was: broken/incomplete).** **Risk: Low** — text-and-conditional-only change, using an already-proven API pattern, exact owner-authorized text throughout.
