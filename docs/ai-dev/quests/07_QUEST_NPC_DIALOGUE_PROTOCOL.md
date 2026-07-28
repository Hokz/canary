# 07 — Quest NPC Dialogue Protocol

Binding rules for any AI agent writing or editing NPC dialogue as part of quest implementation or fix work.

## 1. Legal / product rule (restated from [[00_QUEST_FACTORY_DIRECTOR_BRIEF]] §5)

- TibiaWiki BR and TibiaWiki Fandom may be used as a **functional reference only**: what the NPC needs to say to move the quest forward, what keywords trigger what response, what items/rewards are involved, mission order.
- **Do not copy long proprietary dialogue or copyrighted quest text verbatim.** This applies to full paragraphs of flavor text, not short mechanical phrases.
- Dialogue must be **functionally faithful** — the player must be able to complete the quest by following the same keyword/step logic as the reference — but **paraphrased or written originally**.
- Exception: **if the repository already contains accepted dialogue text for a line**, don't rewrite it just to "improve" it. This rule is about *new* content, not scrubbing existing accepted scripts.
- If in doubt whether a passage is "long" or "proprietary," err toward paraphrasing. A single short trigger phrase ("mission", "yes", item names) is not copyrightable; multi-sentence narrative flavor text is the risk zone.

## 2. Technical framework (from [[01_QUEST_ARCHITECTURE_AUDIT]] §2)

- All NPC dialogue in this repo uses the same framework: `KeywordHandler` + `NpcHandler` (`data/npclib/npc_system/`). There is no alternate/newer framework to choose between — use the existing pattern.
- Standard shape:

```lua
local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
...
local function creatureSayCallback(npc, creature, type, message)
    if not npcHandler:isFocused(creature) then
        return false
    end
    local player = Player(creature)

    if MsgContains(message, "mission") then
        if player:getStorageValue(Storage.Quest.<UpdateTag>.<QuestName>.Questline) == <N> then
            npcHandler:say("...", npc, creature)
            player:setStorageValue(Storage.Quest.<UpdateTag>.<QuestName>.Questline, <N+1>)
        else
            npcHandler:say("Come back when you're ready.", npc, creature) -- ALWAYS have a fallback
        end
    end
end
```

- New quests should prefer `player:questKV(questName)` over raw `Storage.*` keys, per [[04_QUEST_STORAGE_REGISTRY]] Rule 3.

## 3. Mandatory: always write a fallback branch

**This is the single highest-value rule in this document.** [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 2 (Zizzle) traced directly to a dialogue state machine with no `else`/default branch — any player whose storage value didn't match one of the explicitly coded states got complete silence, which is indistinguishable from "the quest is broken" to a player or tester.

Rule: every `if/elseif` chain keyed on quest storage/KV state **must** end with an `else` that gives the player *some* response — even a generic "You haven't started this yet" or "Come back later" — never silence. This applies to both the top-level keyword dispatch (`"mission"`, `"yes"`, `"no"`) and any nested topic/state checks (`npcHandler:getTopic`).

## 4. Dialogue-writing checklist

- [ ] Every state-dependent branch has a fallback (§3).
- [ ] Storage/KV keys referenced match [[04_QUEST_STORAGE_REGISTRY]] conventions — no ad hoc flat names.
- [ ] Dialogue text is paraphrased from the wiki reference, not copy-pasted (§1) — unless reusing existing accepted repo text.
- [ ] Keyword triggers match what the quest reference documents players actually need to say (don't invent new required keywords not in the reference, and don't silently drop documented ones — see The New Frontier / Wyrdin bug in [[02_QUEST_ISSUE_618_AUDIT]] §B where none of six documented keywords worked).
- [ ] `npcHandler:setTopic`/`getTopic` usage is consistent — a topic set but never checked (or checked but never set) is a common source of "nothing happens" bugs.
- [ ] Storage writes happen on the correct branch — verify the mission actually advances only when the player has truly completed the step, not on every visit.
- [ ] If the NPC also needs to react to an item (e.g. handing in a quest item), confirm the item-related callback (`onCreatureSay` item triggers, or a separate `onUse`/`onTradeRequest`) is wired, not just the text keyword.

## 5. When porting an old community-submitted fix (e.g. old GitHub issue snippets)

Several #599/#618 comments include full old-style NPC scripts as "the fix" (see Zizzle in [[03_QUEST_ISSUE_599_FIX_AUDIT]] Bug 2). Before reusing one of these:
- Check whether it references storage keys that no longer exist in this repo's flat/nested form (the Zizzle snippet used `Storage.WrathoftheEmperor.*`, which doesn't exist — the real key is `Storage.Quest.U8_6.WrathOfTheEmperor.*`). Pasting it verbatim will error.
- Treat it as a **logic reference**, not a drop-in replacement — port the intent (e.g. "loosen this exact-equality check", "add this missing branch") into the current file's actual structure and current storage keys.
- Do not silently comment out large blocks of existing dialogue the way the old snippet did — if a branch is genuinely obsolete, understand why before removing it; if it's not obsolete, keep it and add to it.

## 6. Testing dialogue changes

- Dialogue changes must be included in the quest package's owner-facing QA checklist ([[08_QUEST_QA_CHECKLIST]]) with the **exact keywords** the owner should type, in order, and the exact expected response text (or a close paraphrase of it) so the owner can confirm without reading code.
- If the dialogue branches on a storage/KV value the owner can't easily reach through normal play (e.g. deep into a long questline), note in the checklist how to set up that state for testing (in coordination with whoever has server admin access), rather than asking the owner to play through hours of quest first.
