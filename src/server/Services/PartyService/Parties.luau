--!strict
-- Parties of one hub server as pure data (Paket 15): invites, accept/decline, leave, kick, a new leader when the
-- leader leaves, and putting a party back together when its players come back from the run place (tags). A player
-- outside a party plays solo. Owned by PartyService, which feeds it player actions and the clock; no Roblox APIs, so
-- the rules are unit-tested in tests/Parties.spec.luau. Every change bumps `version`.

export type Party = {
	id: number,
	leader: number,
	members: { number }, -- leader first, then in joining order
	tag: string?, -- the id the party carries to the run place and back (PlaceRules tickets)
}

export type Invite = { from: number, to: number, expiresAt: number }

type Tag = { party: Party?, waiting: { number }, leader: number, expiresAt: number }

local Parties = {}
Parties.__index = Parties

export type Parties = typeof(setmetatable(
	{} :: {
		maxSize: number,
		partyOf: { [number]: Party },
		invites: { Invite },
		tags: { [string]: Tag },
		counter: number,
		version: number,
	},
	Parties
))

function Parties.new(maxSize: number): Parties
	return setmetatable({
		maxSize = maxSize,
		partyOf = {},
		invites = {},
		tags = {},
		counter = 0,
		version = 0,
	}, Parties)
end

local function changed(self: Parties)
	self.version += 1
end

local function newParty(self: Parties, leader: number, members: { number }, tag: string?): Party
	self.counter += 1
	local party: Party = { id = self.counter, leader = leader, members = {}, tag = tag }
	table.insert(party.members, leader)
	for _, userId in members do
		if userId ~= leader then
			table.insert(party.members, userId)
		end
	end
	for _, userId in party.members do
		self.partyOf[userId] = party
	end
	return party
end

local function dropInvites(self: Parties, predicate: (Invite) -> boolean)
	for index = #self.invites, 1, -1 do
		if predicate(self.invites[index]) then
			table.remove(self.invites, index)
			changed(self)
		end
	end
end

-- Queries -----------------------------------------------------------------------

-- The player's party, nil when they play solo.
function Parties.get(self: Parties, userId: number): Party?
	return self.partyOf[userId]
end

-- The leader of the player's party; a solo player leads themselves.
function Parties.leaderOf(self: Parties, userId: number): number
	local party = self.partyOf[userId]
	return if party then party.leader else userId
end

-- Everyone who plays with the player (the player alone when solo), leader first.
function Parties.membersOf(self: Parties, userId: number): { number }
	local party = self.partyOf[userId]
	return if party then table.clone(party.members) else { userId }
end

function Parties.isLeader(self: Parties, userId: number): boolean
	return self:leaderOf(userId) == userId
end

-- The newest invite to the player that has not expired.
function Parties.inviteTo(self: Parties, userId: number): Invite?
	for index = #self.invites, 1, -1 do
		local invite = self.invites[index]
		if invite.to == userId then
			return invite
		end
	end
	return nil
end

function Parties.hasInvited(self: Parties, from: number, to: number): boolean
	for _, invite in self.invites do
		if invite.from == from and invite.to == to then
			return true
		end
	end
	return false
end

-- Actions ------------------------------------------------------------------------
-- Each returns ok plus a reason code on failure (texts in PartyService).

function Parties.invite(self: Parties, from: number, to: number, now: number, seconds: number): (boolean, string?)
	if from == to then
		return false, "Self"
	end
	if not self:isLeader(from) then
		return false, "NotLeader"
	end
	if #self:membersOf(from) >= self.maxSize then
		return false, "Full"
	end
	if self.partyOf[to] then
		return false, "TheyAreInParty"
	end
	dropInvites(self, function(invite)
		return invite.from == from and invite.to == to
	end)
	table.insert(self.invites, { from = from, to = to, expiresAt = now + seconds })
	changed(self)
	return true, nil
end

-- Accepts or declines the invite `from` sent to `to`. Accepting joins the inviter's party (or makes one).
function Parties.answer(self: Parties, to: number, from: number, accept: boolean): (boolean, string?)
	if not self:hasInvited(from, to) then
		return false, "NoInvite"
	end
	dropInvites(self, function(invite)
		return invite.from == from and invite.to == to
	end)
	if not accept then
		return true, nil
	end
	if self.partyOf[to] then
		return false, "InParty"
	end
	if not self:isLeader(from) then
		return false, "NoInvite" -- the inviter joined someone else's party meanwhile
	end
	local party = self.partyOf[from]
	if party then
		if #party.members >= self.maxSize then
			return false, "Full"
		end
		table.insert(party.members, to)
		self.partyOf[to] = party
	else
		newParty(self, from, { to }, nil)
	end
	-- other invites to them are void now; a full party's open invites too
	dropInvites(self, function(invite)
		return invite.to == to or (invite.from == from and #self:membersOf(from) >= self.maxSize)
	end)
	changed(self)
	return true, nil
end

-- Leaves the party; a party of one is no party, and the next member leads when the leader leaves.
function Parties.leave(self: Parties, userId: number): (boolean, string?)
	local party = self.partyOf[userId]
	if not party then
		return false, "NotInParty"
	end
	self.partyOf[userId] = nil
	local index = table.find(party.members, userId)
	if index then
		table.remove(party.members, index)
	end
	if party.leader == userId and #party.members > 0 then
		party.leader = party.members[1]
		-- the old leader's invites are void
		dropInvites(self, function(invite)
			return invite.from == userId
		end)
	end
	if #party.members <= 1 then
		for _, member in party.members do
			self.partyOf[member] = nil
		end
		table.clear(party.members)
	end
	changed(self)
	return true, nil
end

function Parties.kick(self: Parties, leader: number, target: number): (boolean, string?)
	local party = self.partyOf[leader]
	if not party or party.leader ~= leader then
		return false, "NotLeader"
	end
	if target == leader or self.partyOf[target] ~= party then
		return false, "NotInParty"
	end
	return self:leave(target)
end

-- The player left the server.
function Parties.remove(self: Parties, userId: number)
	if self.partyOf[userId] then
		self:leave(userId)
	end
	dropInvites(self, function(invite)
		return invite.from == userId or invite.to == userId
	end)
	for _, tag in self.tags do
		local index = table.find(tag.waiting, userId)
		if index then
			table.remove(tag.waiting, index)
		end
	end
end

-- Gives the party a tag (when it leaves for the run place).
function Parties.setTag(self: Parties, userId: number, tag: string)
	local party = self.partyOf[userId]
	if party and party.tag ~= tag then
		party.tag = tag
		changed(self)
	end
end

-- A player came back from the run place with the tag of their party: they join the party with that tag in this
-- server, or form it with the first teammate who is already back (the old leader leads if present).
function Parties.arrive(self: Parties, userId: number, tag: string, leader: number, now: number, seconds: number)
	if self.partyOf[userId] then
		return
	end
	local entry = self.tags[tag]
	if not entry then
		entry = { party = nil, waiting = {}, leader = leader, expiresAt = now + seconds }
		self.tags[tag] = entry
	end
	local party = entry.party
	if party and #party.members > 0 and #party.members < self.maxSize then
		table.insert(party.members, userId)
		self.partyOf[userId] = party
		changed(self)
		return
	end
	local mates = {}
	for _, waiting in entry.waiting do
		if not self.partyOf[waiting] then
			table.insert(mates, waiting)
		end
	end
	if #mates == 0 or (party and #party.members > 0) then
		table.insert(entry.waiting, userId)
		return
	end
	table.insert(mates, userId)
	while #mates > self.maxSize do
		table.remove(mates)
	end
	local first = if table.find(mates, entry.leader) then entry.leader else mates[1]
	entry.party = newParty(self, first, mates, tag)
	table.clear(entry.waiting)
	changed(self)
end

-- Drops expired invites and tags.
function Parties.expire(self: Parties, now: number)
	dropInvites(self, function(invite)
		return invite.expiresAt <= now
	end)
	for tag, entry in self.tags do
		if entry.expiresAt <= now then
			self.tags[tag] = nil
		end
	end
end

return Parties
