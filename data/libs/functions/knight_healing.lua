-- Knight healing, 15.25.
--
-- The four Wound Cleansing spells stopped scaling on level and magic level alone. They
-- now take a per-spell Base Power, the 15.25 level contribution, Shielding and Magic
-- Level. Every coefficient the mechanic needs lives in this one table, so tuning it is
-- one edit in one file and no spell script carries a number of its own.
--
-- CONFIDENCE, per value, because they are not all equally proven:
--
--   Base Power (15 / 70 / 225 / 500)      VERIFIED_OFFICIAL. CipSoft's 15.25 vocation
--                                         adjustment information names these.
--   "scales with Magic Level + Shielding" VERIFIED_OFFICIAL. Stated by CipSoft.
--   the level contribution                Player:calculateFlatDamageHealing(), whose
--                                         closed form reproduces the tiered progression
--                                         the engine already documented and which a
--                                         public 15.25 implementation matches.
--   Magic Level coefficients              CORROBORATED for Wound Cleansing (4.0 / 7.95)
--                                         and Fair Wound Cleansing (8.0 / 15.9): this
--                                         datapack already carried exactly those two
--                                         pairs before 15.25, and the reference
--                                         implementation agrees. Bruise Bane and Intense
--                                         Wound Cleansing differ from what was here and
--                                         rest on the reference alone.
--   Shielding coefficients                COMMUNITY_DERIVED_TUNABLE. These are NOT
--                                         published by CipSoft. They come from a public
--                                         15.25 implementation and are a strong lead, not
--                                         a Global constant. Do not present them as
--                                         official.
--
-- Shape:
--   common = B(level) * levels + Shielding * shield + basePower
--   min    = common + MagicLevel * mlMin
--   max    = common + MagicLevel * mlMax     (or min + flatSpread, where the spell has
--                                             a fixed spread rather than a second
--                                             coefficient)
KnightHealing = {}

KnightHealing.spells = {
	["Bruise Bane"] = { basePower = 15, levels = 1, shield = 0.3, mlMin = 0.9, flatSpread = 5 },
	["Wound Cleansing"] = { basePower = 70, levels = 1, shield = 1.0, mlMin = 4.0, mlMax = 7.95 },
	["Fair Wound Cleansing"] = { basePower = 225, levels = 2, shield = 2.5, mlMin = 8.0, mlMax = 15.9 },
	["Intense Wound Cleansing"] = { basePower = 500, levels = 2, shield = 5.0, mlMin = 20.0, mlMax = 40.0 },
}

--- The minimum and maximum a Knight healing spell restores.
--
-- Shielding is read as the EFFECTIVE skill, so a Protector stance and equipment both
-- count - the same source every other 15.25 skill consumer uses.
--
-- @param spellName string key into KnightHealing.spells
-- @param player Player casting it
-- @param magicLevel number the caster's magic level, as the callback receives it
-- @return number, number minimum and maximum healing
function KnightHealing.values(spellName, player, magicLevel)
	local spell = KnightHealing.spells[spellName]
	if not spell then
		error(string.format("KnightHealing.values: no coefficients for %s", tostring(spellName)))
	end

	local shielding = player:getEffectiveSkillLevel(SKILL_SHIELD) or 0
	local common = player:calculateFlatDamageHealing() * spell.levels + shielding * spell.shield + spell.basePower

	local min = common + magicLevel * spell.mlMin
	if spell.flatSpread then
		return min, min + spell.flatSpread
	end

	return min, common + magicLevel * spell.mlMax
end
