--!strict
-- Where leaderboard scores live (Paket 18): Roblox OrderedDataStores, or a table in this server's memory (tests, Studio
-- without API access). Both keep the highest score per key. Used by LeaderboardService.

local Scores = {}

export type Row = { key: string, score: number }

export type Backend = {
	submit: (storeName: string, key: string, score: number) -> (), -- keeps the higher score; may yield and throw
	top: (storeName: string, count: number) -> { Row }, -- highest first
	get: (storeName: string, key: string) -> number?,
	canRead: () -> boolean, -- read budget left for single reads (friends)
}

function Scores.memory(): Backend
	local stores: { [string]: { [string]: number } } = {}
	return {
		submit = function(storeName, key, score)
			local store = stores[storeName] or {}
			stores[storeName] = store
			store[key] = math.max(store[key] or 0, score)
		end,
		top = function(storeName, count)
			local rows = {}
			for key, score in stores[storeName] or {} do
				table.insert(rows, { key = key, score = score })
			end
			table.sort(rows, function(a, b)
				return if a.score == b.score then a.key < b.key else a.score > b.score
			end)
			while #rows > count do
				table.remove(rows)
			end
			return rows
		end,
		get = function(storeName, key)
			local store = stores[storeName]
			return if store then store[key] else nil
		end,
		canRead = function()
			return true
		end,
	}
end

function Scores.dataStore(): Backend
	local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
	local DataStoreService = game:GetService("DataStoreService")
	local function store(name: string): OrderedDataStore
		return DataStoreService:GetOrderedDataStore(name)
	end
	return {
		submit = function(storeName, key, score)
			store(storeName):UpdateAsync(key, function(old: number?)
				if old and old >= score then
					return nil -- keep the better score
				end
				return score
			end)
		end,
		top = function(storeName, count)
			local pages = store(storeName):GetSortedAsync(false, count)
			local rows = {}
			for _, entry in pages:GetCurrentPage() do
				table.insert(rows, { key = entry.key, score = entry.value })
			end
			return rows
		end,
		get = function(storeName, key)
			return store(storeName):GetAsync(key)
		end,
		canRead = function()
			local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync)
			return budget >= Config.Leaderboards.minReadBudget
		end,
	}
end

return Scores
