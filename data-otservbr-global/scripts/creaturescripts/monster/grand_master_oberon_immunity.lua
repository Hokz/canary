-- CRITICAL FIX: this event previously only played a visual effect and returned `true` (unmodified
-- passthrough) - it never actually blocked damage despite being named "immunity" and being the sole
-- mechanism gating Grand Master Oberon's whole debate minigame (grand_master_oberon.lua's onThink
-- heals him to full and registers this event whenever he drops to <=20% HP with Life <= AmountLife,
-- but nothing stopped further damage from immediately dropping him back to <=20% again before a
-- player ever answered a question). Net effect: the boss could be killed by pure DPS alone, cycling
-- through all 3 heal-interruptions without a single correct answer ever being required - directly
-- contradicting the reference's "after fourth correct answer, boss becomes fully mortal" (the fourth
-- <=20% dip only stays lethal because the first three are supposed to be un-damageable until
-- answered correctly). Now genuinely blocks all damage while registered; onSay in
-- grand_master_oberon.lua already unregisters this event on a correct answer, which is the only way
-- to resume damaging him.
local grandMasterOberonImmunity = CreatureEvent("OberonImmunity")

function grandMasterOberonImmunity.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if creature and creature:isMonster() then
		creature:getPosition():sendMagicEffect(CONST_ME_HOLYAREA)
	end
	return 0, primaryType, 0, secondaryType
end

grandMasterOberonImmunity:register()
