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

## Keyword contract

Per the owner's rule: *"Keywords required by common quest spoilers must be accepted exactly."* No keyword list has been provided or found in-repo for either Messenger of Heaven NPC. This section is a placeholder to be filled in once reference text is available:

| Keyword | Source | Expected response | Status |
|---|---|---|---|
| *(none confirmed)* | — | — | `OWNER_REFERENCE_REQUIRED` |

## What this contract does NOT claim

This document does not assert that Messenger of Heaven dialogue is "broken" in the sense of a regression — it asserts the dialogue was **never implemented**, based on the complete absence of any callback registration. This is a missing-content finding, not a bug-fix target, and per the package rules is explicitly **not** a safe fix candidate (writing dialogue without reference text would be inventing it, which is disallowed).
