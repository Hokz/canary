# 01 — Heart of Destruction NPC Dialogue Contract

Per project rule: exact NPC dialogue may be used when authorized, but must never be invented. Every dialogue line below is either quoted from the current repository (already-accepted text) or marked `OWNER_REFERENCE_REQUIRED`. No line in this document was invented.

## NPCs involved

| NPC | File | Current dialogue logic |
|---|---|---|
| Messenger of Heaven | `data-otservbr-global/npc/messenger_of_heaven.lua` | **Implemented (HOD-04)** — full keyword chain, see below |
| Lesser Messenger of Heaven | `data-otservbr-global/npc/lesser_messenger_of_heaven.lua` | **None** (unchanged) |

No other NPC file references any Heart of Destruction storage, keyword, or quest name (confirmed via repo-wide grep for `HeartOfDestruction`-related identifiers across `data-otservbr-global/npc/`).

## Messenger of Heaven — full current state (HOD-04: IMPLEMENTED)

**Before HOD-04**: the file registered only standard NPC boilerplate and `FocusModule`, with no `creatureSayCallback`, no `CALLBACK_MESSAGE_DEFAULT`, no keywords, and no `MESSAGE_GREET` — the NPC could not respond to anything.

**Implemented this package**: full 13-keyword conversation tree following the established `KeywordHandler`/`NpcHandler` + topic-gated `elseif` chain pattern already used throughout this codebase (`henricus.lua`, `zizzle.lua`, `wyrdin.lua`). Full detail in the keyword contract table below.

**Status: Implemented.**
**Risk: Low** — purely additive dialogue on a previously-inert NPC; no existing behavior could regress since there was none. See [[09_HOD_SAFE_FIXES_APPLIED]] for the full safe-fix justification.
**Still `OWNER_REFERENCE_REQUIRED`:**
- Exact spoken text for the "yes" step of the shortcut chain (currently implemented as a silent topic-reset — see below)
- Whether this NPC should also grant any access/storage on quest start (investigated this package — no code currently expects this; see [[04_HOD_PORTAL_ACCESS_CONTRACT]])

## Lesser Messenger of Heaven — full current state

Read in full. Same pattern: only `FocusModule`, no `creatureSayCallback`, no keywords, no `MESSAGE_GREET`. The `npcType` is created with the literal name `"Lesser Messenger of Heaven"` (line 2) but `npcConfig.name` is set to the string `internalNpcName` which is `"Messenger of Heaven"` (line 1/5) — i.e., the config name does not match the type name. This is worth noting as a possible latent display/identity inconsistency, but **not being treated as a safe fix in this package** since its correct in-game name/role relative to the main Messenger of Heaven is unconfirmed (could be an intentional "weaker copy" NPC used elsewhere in the room, could be a leftover unused file).

**Status: MISSING (dialogue), UNKNOWN (intended role/relationship to the main NPC).**
**Risk: Medium** — unclear whether this NPC is load-bearing for the quest at all.
**Contract placeholder — `OWNER_REFERENCE_REQUIRED`:** whether this NPC has any dialogue role in the quest, and if so, what.

## Keyword contract — IMPLEMENTED (HOD-04)

HOD-03 could only document the player-side keyword chain; the owner has now supplied Messenger of Heaven's exact spoken lines for every step, and the full conversation is implemented in `data-otservbr-global/npc/messenger_of_heaven.lua`.

**Full chain** (13 keywords, strict linear order, exact transcript order as given): `hi → alive → peril → thing → past → name → ferumbras → damage → stopped → destroying → destroying (again) → heart of destruction → strong`
**Shortcut chain**: `hi → strong → yes` — implemented by allowing `strong` to fire from the initial post-greet state (topic 0) as well as from the natural end of the full chain (topic 11), converging on the same response and topic.

| Player keyword | Required topic | NPC response | Advances to |
|---|---|---|---|
| hi | — (greet) | "Greetings, \|PLAYERNAME\|! It's good to see you alive." (`MESSAGE_GREET`) | topic 0 |
| alive | 0 | "With the world in peril, everyone's life is at stake." | 1 |
| peril | 1 | "The actions of Ferumbras and the sinister minions of the thing from beyond have shattered the world. The thing is worming its way into our reality and its workings will cause further damage." | 2 |
| thing | 2 | 2-line response (name/hold/past) | 3 |
| past | 3 | 2-line response (Yalahari history) | 4 |
| name | 4 | 4-line response (naming/power) | 5 |
| ferumbras | 5 | "Probably his vain plea for ascension has brought upon him a fate worse than hell." | 6 |
| damage | 6 | 2-line response (layers of destruction) | 7 |
| stopped | 7 | 6-line response (avatars/incursions/Heart of Destruction) | 8 |
| destroying (1st) | 8 | "To stop them from devouring reality, the destruction has to be stopped by destroying its heart." | 9 |
| destroying (2nd) | 9 | 6-line response (incursions/masters/tainting) | 10 |
| heart of destruction | 10 | 6-line response (world devourer description) | 11 |
| strong | 0 or 11 | "Your future is still not written because the forces of uncreation are still tearing on reality. For the sake of your world, please hurry!" | 12 |
| yes | 12 | *(no exact text provided — see below)* | 0 |

**Every response line above is the owner's exact provided text, transcribed verbatim** (including preserving the inconsistent presence/absence of trailing "..." markers exactly as given in the reference, rather than normalizing them). No line was paraphrased or invented.

**"yes" — deliberately left silent, not invented.** The owner's reference confirms `yes` is the final step of the shortcut chain, but provides no exact spoken response for it (only `strong`'s line has confirmed text, and the full-chain transcript doesn't show a "yes" step at all). Per the "do not invent" rule, `yes` is implemented as a recognized keyword that closes the conversation (resets topic to 0) **without any invented NPC line**. If the owner supplies exact text for this step, it can be added in a follow-up in one line.

**HOD-05 re-check**: per HOD-05's explicit instruction to only implement "yes" behavior if current repo evidence clearly proves an expected storage/action, this was re-investigated. No such evidence was found — no portal, movement, or catalog script anywhere in the codebase reads a storage that "yes" could plausibly be expected to set (same conclusion, same evidence chain as [[04_HOD_PORTAL_ACCESS_CONTRACT]]'s original finding, re-confirmed rather than assumed stale). The silent topic-reset remains correct and unchanged.

**Case sensitivity**: matching uses `MsgContains`, the same case-insensitive-by-convention helper used throughout this codebase (e.g., `henricus.lua`, `zizzle.lua`) — consistent with the package's case-insensitivity allowance.

**Storage/access behavior**: none implemented. Investigation (this package) confirmed no existing portal/access code checks any storage that Messenger of Heaven could plausibly set — see [[04_HOD_PORTAL_ACCESS_CONTRACT]] for the full evidence chain. Dialogue-only implementation, per package rule 7.

## Lesser Messenger of Heaven — not modified

Re-confirmed this package: `lesser_messenger_of_heaven.lua` still has zero dialogue logic, and nothing in the codebase (no shared storage, no cross-reference, no naming convention beyond the coincidental "Messenger of Heaven" substring) proves it's part of the same start flow as the main Messenger of Heaven NPC. Per the approved scope ("only if current code proves it is part of the same HOD start flow"), it was **not modified**. Still `OWNER_REFERENCE_REQUIRED` if the owner can clarify its role.

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
