-- The Remorseless Corruptor is invulnerable until enough Guilt (see actions_guilt.lua) has been
-- applied to transform it into the vulnerable The Corruptor of Souls.
local remorselessCorruptorHealth = CreatureEvent("RemorselessCorruptorHealth")

function remorselessCorruptorHealth.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if attacker and attacker:isPlayer() then
		return 0, primaryType, 0, secondaryType
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end

remorselessCorruptorHealth:register()
