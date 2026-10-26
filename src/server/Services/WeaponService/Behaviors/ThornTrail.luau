--!strict
-- Thorn Trail (DESIGN.md section 6): while the owner is up, a thorn patch (`radius`) is dropped under them whenever
-- they moved dropSpacing studs from the last one, or when no patch of theirs is left under them. Each patch lies for
-- `duration` seconds. Every tickInterval all enemies on any patch take damage, each enemy once per tick however many
-- patches it stands on. Patches already on the floor keep hurting while the owner is down. No cooldown: the trail is
-- always on. Effect: "Drop" with id, center, radius and duration. Behavior for WeaponService/Arsenal; drawn by
-- WeaponRenderer/Visuals/ThornTrail.

local Arsenal = require(script.Parent.Parent.Arsenal)

type Patch = {
	x: number,
	z: number,
	radius: number,
	expiresAt: number, -- server time
}

local found: { number } = {}
local tickHits: { [number]: boolean } = {}

local ThornTrail = {}

local function patchesOf(weapon: Arsenal.Weapon): { Patch }
	local patches = weapon.state.patches
	if not patches then
		patches = {}
		weapon.state.patches = patches
	end
	return patches
end

local function drop(weapon: Arsenal.Weapon, ctx: Arsenal.Context, patches: { Patch })
	local stats = weapon.stats
	local patch: Patch = { x = ctx.x, z = ctx.z, radius = stats.radius, expiresAt = ctx.now + stats.duration }
	table.insert(patches, patch)
	while #patches > stats.maxPatches do
		table.remove(patches, 1)
	end
	ctx:emit(weapon, {
		kind = "Drop",
		id = ctx:nextId(),
		x = patch.x,
		z = patch.z,
		radius = patch.radius,
		duration = stats.duration,
	})
end

function ThornTrail.step(weapon: Arsenal.Weapon, ctx: Arsenal.Context, dt: number)
	local stats = weapon.stats
	local state = weapon.state
	local patches = patchesOf(weapon)
	local now = ctx.now

	for index = #patches, 1, -1 do
		if patches[index].expiresAt <= now then
			table.remove(patches, index)
		end
	end

	if ctx.active then
		local last = patches[#patches]
		if not last or (last.x - ctx.x) ^ 2 + (last.z - ctx.z) ^ 2 >= stats.dropSpacing ^ 2 then
			drop(weapon, ctx, patches)
		end
	end

	-- Ticks run on their own clock, so the first one comes one interval after the first patch.
	if #patches == 0 then
		state.tickLeft = nil
		return
	end
	local tickLeft: number = (state.tickLeft or stats.tickInterval) - dt
	if tickLeft > 0 then
		state.tickLeft = tickLeft
		return
	end
	state.tickLeft = math.max(tickLeft, -dt) + stats.tickInterval
	for _, patch in patches do
		local count = ctx:queryCircle(patch.x, patch.z, patch.radius, found)
		for i = 1, count do
			local id = found[i]
			if not tickHits[id] then
				tickHits[id] = true
				ctx:hit(weapon, id)
			end
		end
	end
	table.clear(tickHits)
end

return ThornTrail
