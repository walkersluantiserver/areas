-- Disables player versus player combat in areas with the `no_pvp` flag.
-- See `areas:isPvpAllowed` for how overlapping areas are handled.

-- Returns the player responsible for a hit, following projectiles to their
-- shooter. Returns nil if the object doesn't belong to a player (e.g. a mob).
local function getAttackingPlayer(object)
	if not object then
		return nil
	end
	if object:is_player() then
		return object
	end
	local entity = object:get_luaentity()
	if not entity then
		return nil
	end
	-- Fields used for the shooter by the projectiles of MineClone2 and Mineclonia.
	local shooter = entity._shooter or entity._source_object
	if type(shooter) == "userdata" and shooter:is_player() then
		return shooter
	end
	return nil
end

-- A hit is blocked if either player is in a PVP-free area. Checking the attacker
-- too prevents attacking others from within safety without any risk of retaliation.
local function isHitBlocked(victim, source)
	local attacker = getAttackingPlayer(source)
	if not attacker or not victim:is_player() or
			attacker:get_player_name() == victim:get_player_name() then
		return false
	end
	return not areas:isPvpAllowed(victim:get_pos()) or
		not areas:isPvpAllowed(attacker:get_pos())
end

-- Returning `true` from a callback only cancels the engine's default damage.
-- Knockback and game-specific effects come from other callbacks, and Mineclonia
-- even deals its damage in one, so they all must be skipped for a blocked hit.
-- This is done last to include the callbacks of all other mods.
minetest.register_on_mods_loaded(function()
	local callbacks = minetest.registered_on_punchplayers
	for i, callback in ipairs(callbacks) do
		local function wrapped(player, hitter, ...)
			if isHitBlocked(player, hitter) then
				return true
			end
			return callback(player, hitter, ...)
		end
		minetest.callback_origins[wrapped] = minetest.callback_origins[callback]
		callbacks[i] = wrapped
	end
end)

-- MineClone2 and Mineclonia can deal damage without punching (e.g. arrows).
local mcl_damage = rawget(_G, "mcl_damage")
if mcl_damage then
	mcl_damage.register_modifier(function(object, damage, reason)
		if isHitBlocked(object, reason.source or reason.direct) then
			return 0
		end
	end, -math.huge)
end
