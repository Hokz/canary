-- Sharpshooter is a stance as of 15.25. Three things changed besides that:
--
--   - the words are "utori con", not "utito tempo san"; both Paladin stances now
--     share the "utori" prefix
--   - the bonus is +32% Distance Fighting. The changelog announced +40%; the spell
--     table is the shipped value
--   - the paralyse and the healing-group lockout are gone. They were the cost of a
--     short, strong burst; a permanent stance does not carry them, and the update's
--     description lists the skill bonus alone
--
-- The Wheel of Destiny grade branch is gone too: Ethereal Barrage's augments replace
-- Sharpshooter's in this update, so there is no upgraded grade to read.
--
-- NOT matched: the update states the bonus applies to total Distance Fighting,
-- including equipment and other buffs. ConditionAttributes::updatePercentSkills
-- computes every percent skill bonus from getBaseSkill instead, and changing that
-- would move every percent skill bonus in the game at once. Left as base-skill until
-- that is decided on its own.
local function build()
	return Stance.condition(AttrSubId_StanceSharpshooter, function(condition)
		condition:setParameter(CONDITION_PARAM_SKILL_DISTANCEPERCENT, 132)
	end)
end

local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	return Stance.cast(creature, AttrSubId_StanceSharpshooter, Stance.Family.General, build)
end

spell:name("Sharpshooter")
spell:words("utori con")
spell:group("support", "focus")
spell:vocation("paladin;true", "royal paladin;true")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_SHARPSHOOTER)
spell:id(135)
-- Cooldowns: 10s own, 2s Support, 10s on the stance family (secondary group Focus) -
-- the same contract the pre-15.25 Sharpshooter had.
spell:cooldown(10 * 1000)
spell:groupCooldown(2 * 1000, 10 * 1000)
spell:level(20)
spell:mana(250)
spell:isSelfTarget(true)
spell:isAggressive(false)
spell:isPremium(true)

spell:register()
