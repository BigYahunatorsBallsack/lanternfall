--!strict
-- Token bucket per player and remote. Used by Net on the server for every client-to-server remote.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		refillPerSecond: number,
		buckets: { [Player]: { tokens: number, updatedAt: number } },
	},
	RateLimiter
))

-- Allows `count` calls per `perSeconds`, with bursts up to `count`.
function RateLimiter.new(count: number, perSeconds: number): RateLimiter
	return setmetatable({
		capacity = count,
		refillPerSecond = count / perSeconds,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.capacity, updatedAt = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.updatedAt) * self.refillPerSecond)
	bucket.updatedAt = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(self: RateLimiter, player: Player)
	self.buckets[player] = nil
end

return RateLimiter
