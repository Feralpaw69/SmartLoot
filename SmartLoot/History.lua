-- SmartLoot by feralpaw
-- Loot history: records every roll and who won it, one session per raid /
-- dungeon run. Saved account wide in SmartLootHistoryDB.

local _, ns = ...
local SL = ns.SL

local History = {}
SL.History = History

local time = time
local SESSION_TIMEOUT = 4 * 3600   -- same instance after 4h idle = new run
local MATCH_WINDOW = 15 * 60       -- roll messages older than this are ignored

local function db() return SL.db.history end
local function sessions() return SL.hdb.sessions end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------
local function CurrentZone()
	local inInstance, itype = IsInInstance()
	local d = db()
	if inInstance and itype == "raid" then
		-- tracked
	elseif inInstance and itype == "party" then
		if not d.trackDungeons then return nil end
	elseif not inInstance then
		if not d.trackWorld then return nil end
	else
		return nil -- battlegrounds and arenas
	end
	local name, _, _, diffName, maxPlayers = GetInstanceInfo()
	if not inInstance then
		name = "Open World"
		diffName = date("%d.%m.%Y")
		itype = "world"
	end
	if not diffName or diffName == "" then
		diffName = maxPlayers and maxPlayers > 0 and (maxPlayers .. " Player") or ""
	end
	return name or "Unknown", diffName, itype
end

function History:UpdateRoster(s)
	if not s then return end
	s.players = s.players or {}
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local name, _, _, _, _, class = GetRaidRosterInfo(i)
			if name then s.players[name] = class or s.players[name] or "" end
		end
	else
		local _, class = UnitClass("player")
		s.players[SL.playerName] = class
		for i = 1, GetNumPartyMembers() do
			local name = UnitName("party" .. i)
			local _, pclass = UnitClass("party" .. i)
			if name then s.players[name] = pclass or "" end
		end
	end
end

local function Prune(keep)
	local list = sessions()
	-- remove old empty sessions
	for i = #list, 1, -1 do
		local s = list[i]
		if s ~= keep and (not s.items or #s.items == 0) then
			table.remove(list, i)
		end
	end
	while #list > db().maxSessions do
		table.remove(list, 1)
	end
end

-- Returns the session for the current zone; creates one when create is true
function History:GetSession(create)
	local name, diff, itype = CurrentZone()
	if not name then return nil end
	local key = name .. "|" .. diff
	local list = sessions()
	local now = time()
	for i = #list, math.max(1, #list - 5), -1 do
		local s = list[i]
		if s.key == key and s.char == SL.playerName and (now - (s.last or 0)) < SESSION_TIMEOUT and not s.closed then
			return s
		end
	end
	if not create then return nil end
	local s = {
		key = key,
		instance = name,
		difficulty = diff,
		itype = itype,
		char = SL.playerName,
		realm = GetRealmName(),
		start = now,
		last = now,
		items = {},
		players = {},
	}
	table.insert(list, s)
	self:UpdateRoster(s)
	Prune(s)
	SL:Print("Recording loot: " .. name .. (diff ~= "" and (" (" .. diff .. ")") or "") .. "  -  /loot to open the list")
	if SL.HistoryUI then SL.HistoryUI:OnNewSession(s) end
	return s
end

function History:StartNewSession()
	local s = self:GetSession(false)
	if s then s.closed = true end
	local n = self:GetSession(true)
	if n then
		SL:Print("Started a new loot session: " .. n.instance .. " (" .. n.difficulty .. ")")
	else
		SL:Print("You are not in a tracked instance.")
	end
	self:Changed()
end

function History:Changed()
	if SL.HistoryUI then SL.HistoryUI:Refresh() end
end

---------------------------------------------------------------------------
-- Entries
---------------------------------------------------------------------------
local function FindEntry(s, key, test)
	if not s then return nil end
	local now = time()
	for i = 1, #s.items do
		local e = s.items[i]
		if e.source == "roll" and not e.done and e.key == key and (now - e.time) < MATCH_WINDOW and test(e) then
			return e
		end
	end
end

local function Touch(s)
	s.last = time()
end

-- START_LOOT_ROLL
function History:OnRollStart(rollID, rollTime)
	local link = GetLootRollItemLink(rollID)
	if not link or SL:IsIgnored(link) then return end
	local _, _, count, quality = GetLootRollItemInfo(rollID)
	if (quality or 0) < db().minQuality then return end
	local s = self:GetSession(true)
	if not s then return end
	table.insert(s.items, {
		link = link,
		key = SL:ItemKey(link),
		quality = quality,
		count = count or 1,
		time = time(),
		source = "roll",
		rolls = {},
	})
	self:UpdateRoster(s)
	Touch(s)
	self:Changed()
end

function History:OnLootMessage(info)
	if not db().enabled then return end
	if SL:IsIgnored(info.link) then return end
	local s = self:GetSession(false)
	local key = SL:ItemKey(info.link)
	local kind = info.kind

	if kind == "choice" then
		local e = FindEntry(s, key, function(e) return e.rolls[info.player] == nil end)
		if e then
			e.rolls[info.player] = { t = info.rollType, c = info.class }
			if info.class then s.players[info.player] = info.class end
			Touch(s)
			self:Changed()
		end

	elseif kind == "rolled" then
		local e = FindEntry(s, key, function(e)
			local r = e.rolls[info.player]
			return r and r.n == nil
		end) or FindEntry(s, key, function(e) return e.rolls[info.player] == nil end)
		if e then
			local r = e.rolls[info.player] or { t = info.rollType, c = info.class }
			r.n = info.roll
			r.t = r.t or info.rollType
			e.rolls[info.player] = r
			Touch(s)
			self:Changed()
		end

	elseif kind == "won" then
		local e = FindEntry(s, key, function() return true end)
		if e then
			local r = e.rolls[info.player]
			e.winner = info.player
			e.winnerClass = info.class or (r and r.c) or (s.players and s.players[info.player])
			e.winType = r and r.t
			e.winRoll = r and r.n
			e.done = true
			Touch(s)
			self:Changed()
		end

	elseif kind == "allpassed" then
		local e = FindEntry(s, key, function() return true end)
		if e then
			e.done = true
			e.allPassed = true
			Touch(s)
			self:Changed()
		end

	elseif kind == "received" or kind == "pushed" then
		local method = GetLootMethod and GetLootMethod() or ""
		-- "receives item" lines also come from quests and vendors: only use them with master loot
		if kind == "pushed" and method ~= "master" then return end
		local quality = SL:LinkQuality(info.link)
		if quality < db().minQuality then return end
		-- an item seen in the boss loot (master loot) that was not given out yet?
		if s then
			for i = 1, #s.items do
				local e = s.items[i]
				if e.source == "master" and e.pending and e.key == key then
					e.pending = nil
					e.winner = info.player
					e.winnerClass = info.class or (s.players and s.players[info.player])
					e.given = time()
					e.received = true
					Touch(s)
					self:Changed()
					if SL.debug then SL:Print("|cff999999[debug] master loot: " .. info.link .. " -> " .. info.player .. "|r") end
					return
				end
			end
		end
		-- already logged as a won roll?
		if s then
			local now = time()
			for i = #s.items, 1, -1 do
				local e = s.items[i]
				if now - e.time > MATCH_WINDOW then break end
				if e.source == "roll" and e.key == key and e.winner == info.player and not e.received then
					e.received = true
					return
				end
			end
		end
		s = s or self:GetSession(true)
		if not s then return end
		table.insert(s.items, {
			link = info.link,
			key = key,
			quality = quality,
			count = info.count or 1,
			time = time(),
			source = (method == "master") and "master" or "loot",
			rolls = {},
			winner = info.player,
			winnerClass = info.class or (s.players and s.players[info.player]),
			done = true,
			received = true,
		})
		if info.class then s.players[info.player] = info.class end
		Touch(s)
		self:Changed()
		if SL.debug then SL:Print("|cff999999[debug] recorded: " .. info.link .. " -> " .. info.player .. "|r") end
	end
end

-- Master loot: the items in the boss loot are recorded as soon as anyone in
-- the group opens it ("not given yet"); the winner is filled in when the
-- master looter hands the item out.
local seenLoot = {}
function History:OnLootOpened()
	if not db().enabled then return end
	local method = GetLootMethod and GetLootMethod() or ""
	if method ~= "master" then return end
	local guid = (UnitExists("target") and UnitIsDead("target")) and UnitGUID("target") or nil
	local now = time()
	local s
	for slot = 1, GetNumLootItems() do
		local link = GetLootSlotLink(slot)
		if link and not SL:IsIgnored(link) then
			local _, _, _, quality = GetLootSlotInfo(slot)
			quality = quality or SL:LinkQuality(link)
			if quality >= db().minQuality then
				-- the same corpse is opened again and again: remember what was taken
				local id = (guid or "noguid") .. ":" .. slot .. ":" .. link
				local seen = seenLoot[id]
				if not seen or (not guid and now - seen > 600) then
					seenLoot[id] = now
					s = s or self:GetSession(true)
					if not s then return end
					local key = SL:ItemKey(link)
					table.insert(s.items, {
						link = link, key = key, quality = quality, count = 1, time = now,
						source = "master", pending = true, rolls = {},
						from = guid and UnitName("target") or nil,
					})
					Touch(s)
					if SL.debug then SL:Print("|cff999999[debug] boss loot seen: " .. link .. "|r") end
				end
			end
		end
	end
	if s then self:Changed() end
end

-- A session is started as soon as you enter a tracked raid / dungeon
function History:OnZone()
	if not db().enabled then return end
	local inInstance = IsInInstance()
	if not inInstance then return end
	local s = self:GetSession(true)
	if s then self:UpdateRoster(s) end
end

-- Rolls that never got a result (e.g. after a disconnect) are closed
function History:CloseStale()
	local now = time()
	for _, s in ipairs(sessions()) do
		for _, e in ipairs(s.items or {}) do
			if e.source == "roll" and not e.done and (now - e.time) > MATCH_WINDOW then
				e.done = true
			end
		end
	end
end

---------------------------------------------------------------------------
-- Text helpers for the window and reports
---------------------------------------------------------------------------
local TYPE_NAMES = { [0] = "Pass", [1] = "Need", [2] = "Greed", [3] = "Disenchant" }
local TYPE_COLORS = { [0] = "|cff9d9d9d", [1] = "|cff33ff55", [2] = "|cffffd100", [3] = "|cffb380ff" }
History.TYPE_NAMES = TYPE_NAMES
History.TYPE_COLORS = TYPE_COLORS

function History:ResultText(e)
	if e.source == "master" and e.pending then return "|cffff9933Not given yet|r" end
	if e.source == "master" then return "|cff7fb2ffMaster Loot|r" end
	if e.source == "loot" then return "|cffccccccLooted|r" end
	if e.allPassed then return "|cff9d9d9dEveryone passed|r" end
	if e.winner then
		if e.winType then
			return (TYPE_COLORS[e.winType] or "") .. (TYPE_NAMES[e.winType] or "?") .. (e.winRoll and (" " .. e.winRoll) or "") .. "|r"
		end
		return "|cffccccccWon|r"
	end
	if not e.done then return "|cffff9933Rolling...|r" end
	return "|cff9d9d9dNo result|r"
end

function History:Delete(s)
	local list = sessions()
	for i = #list, 1, -1 do
		if list[i] == s then table.remove(list, i) end
	end
	self:Changed()
end

function History:ClearAll()
	wipe(sessions())
	self:Changed()
end

-- Sample raid for the test mode / the options
function History:AddTestSession()
	local now = time()
	local s = {
		key = "test", instance = "Icecrown Citadel (Test)", difficulty = "25 Player (Heroic)", itype = "raid",
		char = SL.playerName, realm = GetRealmName(), start = now - 3 * 3600, last = now, items = {}, test = true,
		players = { Feralpaw = "DRUID", Arthas = "DEATHKNIGHT", Jaina = "MAGE", Thrall = "SHAMAN", Uther = "PALADIN", Sylvanas = "HUNTER", Garrosh = "WARRIOR", Valeera = "ROGUE" },
	}
	local function link(id, fallbackName, quality)
		local _, l = GetItemInfo(id)
		if l then return l end
		local c = ITEM_QUALITY_COLORS[quality]
		return (c and c.hex or "|cffffffff") .. "|Hitem:" .. id .. ":0:0:0:0:0:0:0:80|h[" .. fallbackName .. "]|h|r"
	end
	local data = {
		{ 50363, "Deathbringer's Will", 4, "Feralpaw", "DRUID", 1, 97, { Arthas = { 1, 41 }, Valeera = { 1, 63 }, Jaina = { 0 } } },
		{ 49623, "Shadowmourne", 5, "Arthas", "DEATHKNIGHT", nil, nil, nil, "master" },
		{ 52027, "Conqueror's Mark of Sanctification", 4, "Uther", "PALADIN", 1, 88, { Thrall = { 1, 12 }, Jaina = { 2, 70 } } },
		{ 49908, "Primordial Saronite", 4, "Jaina", "MAGE", 2, 91, { Feralpaw = { 2, 44 }, Arthas = { 2, 9 }, Garrosh = { 0 } } },
		{ 50274, "Shadowfrost Shard", 4, nil, nil, nil, nil, { Arthas = { 0 }, Feralpaw = { 0 } }, "allpassed" },
		{ 34057, "Abyss Crystal", 4, "Sylvanas", "HUNTER", 3, 55, { Feralpaw = { 3, 23 } } },
	}
	for i, d in ipairs(data) do
		local e = {
			link = link(d[1], d[2], d[3]), quality = d[3], count = 1, time = s.start + i * 1500,
			source = (d[9] == "master") and "master" or "roll", rolls = {}, done = true,
			winner = d[4], winnerClass = d[5], winType = d[6], winRoll = d[7], allPassed = d[9] == "allpassed",
		}
		e.key = SL:ItemKey(e.link)
		if d[4] and d[6] then e.rolls[d[4]] = { t = d[6], n = d[7], c = d[5] } end
		for name, r in pairs(d[8] or {}) do
			e.rolls[name] = { t = r[1], n = r[2], c = s.players[name] }
		end
		table.insert(s.items, e)
	end
	table.insert(sessions(), s)
	self:Changed()
	return s
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function History:Init()
	-- old unfinished rolls are only cleaned up when the history is opened
	-- (see HistoryUI), so nothing is walked through at login
	SL:On("START_LOOT_ROLL", function(_, rollID, rollTime)
		if db().enabled then History:OnRollStart(rollID, rollTime) end
	end)
	SL:On("LOOT_OPENED", function() History:OnLootOpened() end)
	-- the instance info is only ready a moment after the loading screen
	local waiter = CreateFrame("Frame")
	waiter:Hide()
	waiter:SetScript("OnUpdate", function(self, elapsed)
		self.t = (self.t or 0) + elapsed
		if self.t > 2 then
			self:Hide()
			History:OnZone()
		end
	end)
	local function Later() waiter.t = 0 waiter:Show() end
	SL:On("PLAYER_ENTERING_WORLD", Later)
	SL:On("ZONE_CHANGED_NEW_AREA", Later)
	SL:On("RAID_ROSTER_UPDATE", function()
		if not db().enabled then return end
		local s = History:GetSession(false)
		if s then History:UpdateRoster(s) end
	end)
end
