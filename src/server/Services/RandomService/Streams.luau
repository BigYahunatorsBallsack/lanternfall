--!strict
-- Seeded random streams as plain data (DESIGN.md section 15, Brotato: separate streams for shop, drops, spawns and
-- combat; since B4). Every name (and player key) gets its own generator with a seed derived from the run seed, so
-- rolls in one system (a shop reroll) never shift the rolls of another (enemy spawns), and a run seed replays the
-- same rolls. Owned by RandomService; unit tested in tests/RandomStreams.spec.luau.

-- The generator a stream hands out: Roblox's Random in the game, anything with the same methods in tests.
export type Generator = {
	NextNumber: (self: any, min: number?, max: number?) -> number,
	NextInteger: (self: any, min: number, max: number) -> number,
}

local MAX_SEED = 2 ^ 31 - 2

local Streams = {}
Streams.__index = Streams

export type Streams = typeof(setmetatable(
	{} :: {
		seed: number,
		names: { [string]: boolean },
		factory: (seed: number) -> Generator,
		cache: { [string]: { [number]: Generator } },
	},
	Streams
))

-- 32-bit FNV-1a of a text, turned into a seed 1..2^31-2. The multiplication by the FNV prime 2^24 + 403 is split
-- so it stays exact in double precision.
function Streams.hash(text: string): number
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (bit32.lshift(hash, 24) + hash * 403) % 4294967296
	end
	return hash % MAX_SEED + 1
end

-- Streams for one run. `names` lists the allowed stream names; `factory` makes a generator from a seed.
function Streams.new(seed: number, names: { string }, factory: (seed: number) -> Generator): Streams
	local allowed = {}
	for _, name in names do
		allowed[name] = true
	end
	return setmetatable({ seed = seed, names = allowed, factory = factory, cache = {} }, Streams)
end

-- The generator of stream `name`, for one player if `key` (their UserId) is given. The same name and key always
-- return the same generator within a run.
function Streams.get(self: Streams, name: string, key: number?): Generator
	local byKey = self.cache[name]
	if not byKey then
		assert(self.names[name], `Unknown random stream {name}`)
		byKey = {}
		self.cache[name] = byKey
	end
	local index = key or 0
	local generator = byKey[index]
	if not generator then
		generator = self.factory(Streams.hash(`{self.seed}/{name}/{index}`))
		byKey[index] = generator
	end
	return generator
end

return Streams
