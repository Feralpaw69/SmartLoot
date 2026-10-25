-- SmartLoot by feralpaw
-- Reads the loot chat messages (works with every client language, the
-- patterns are built from the client's own strings).

local _, ns = ...
local SL = ns.SL

local Parser = {}
SL.Parser = Parser

local MAGIC = "[%^%$%(%)%.%[%]%*%+%-%?]"

-- "%s has selected Need for: %s" -> "^(.+) has selected Need for: (.+)$", { 1, 2 }
-- also handles positional arguments like "%2$s"
local function FormatToPattern(fmt)
	local out, order = {}, {}
	local i, n, auto = 1, #fmt, 0
	while i <= n do
		local c = fmt:sub(i, i)
		if c == "%" then
			local pos, typ = fmt:match("^%%(%d)%$([sd])", i)
			if pos then
				order[#order + 1] = tonumber(pos)
				out[#out + 1] = (typ == "d") and "(%d+)" or "(.+)"
				i = i + 4
			else
				local typ2 = fmt:match("^%%([sd])", i)
				if typ2 then
					auto = auto + 1
					order[#order + 1] = auto
					out[#out + 1] = (typ2 == "d") and "(%d+)" or "(.+)"
					i = i + 2
				elseif fmt:sub(i + 1, i + 1) == "%" then
					out[#out + 1] = "%%"
					i = i + 2
				else
					out[#out + 1] = "%%"
					i = i + 1
				end
			end
		elseif c:find(MAGIC) then
			out[#out + 1] = "%" .. c
			i = i + 1
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
	return "^" .. table.concat(out) .. "$", order
end
Parser.FormatToPattern = FormatToPattern

-- kind, roll type, argument roles. Order matters: the more specific strings first.
local DEFS = {
	{ "LOOT_ROLL_PASSED_SELF_AUTO", "choice", 0, { "item" }, true },
	{ "LOOT_ROLL_PASSED_AUTO", "choice", 0, { "player", "item" } },
	{ "LOOT_ROLL_PASSED_AUTO_FEMALE", "choice", 0, { "player", "item" } },
	{ "LOOT_ROLL_NEED_SELF", "choice", 1, { "item" }, true },
	{ "LOOT_ROLL_GREED_SELF", "choice", 2, { "item" }, true },
	{ "LOOT_ROLL_DISENCHANT_SELF", "choice", 3, { "item" }, true },
	{ "LOOT_ROLL_PASSED_SELF", "choice", 0, { "item" }, true },
	{ "LOOT_ROLL_NEED", "choice", 1, { "player", "item" } },
	{ "LOOT_ROLL_GREED", "choice", 2, { "player", "item" } },
	{ "LOOT_ROLL_DISENCHANT", "choice", 3, { "player", "item" } },
	{ "LOOT_ROLL_PASSED", "choice", 0, { "player", "item" } },
	{ "LOOT_ROLL_ROLLED_NEED", "rolled", 1, { "roll", "item", "player" } },
	{ "LOOT_ROLL_ROLLED_GREED", "rolled", 2, { "roll", "item", "player" } },
	{ "LOOT_ROLL_ROLLED_DE", "rolled", 3, { "roll", "item", "player" } },
	{ "LOOT_ROLL_YOU_WON", "won", nil, { "item" }, true },
	{ "LOOT_ROLL_WON", "won", nil, { "player", "item" } },
	{ "LOOT_ROLL_ALL_PASSED", "allpassed", nil, { "item" } },
	{ "LOOT_ITEM_SELF_MULTIPLE", "received", nil, { "item", "count" }, true },
	{ "LOOT_ITEM_SELF", "received", nil, { "item" }, true },
	{ "LOOT_ITEM_MULTIPLE", "received", nil, { "player", "item", "count" } },
	{ "LOOT_ITEM", "received", nil, { "player", "item" } },
	{ "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "pushed", nil, { "item", "count" }, true },
	{ "LOOT_ITEM_PUSHED_SELF", "pushed", nil, { "item" }, true },
	{ "LOOT_ITEM_PUSHED_MULTIPLE", "pushed", nil, { "player", "item", "count" } },
	{ "LOOT_ITEM_PUSHED", "pushed", nil, { "player", "item" } },
}

local patterns
local function Build()
	patterns = {}
	for _, d in ipairs(DEFS) do
		local fmt = _G[d[1]]
		if type(fmt) == "string" and fmt ~= "" then
			local pattern, order = FormatToPattern(fmt)
			patterns[#patterns + 1] = { pattern = pattern, order = order, kind = d[2], rollType = d[3], roles = d[4], self = d[5] }
		end
	end
end

local function ExtractLink(text)
	if not text then return nil end
	return text:match("(|c%x+|Hitem:.-|h.-|h|r)") or text
end

-- Returns a table { kind, rollType, player, link, roll, count } or nil
function Parser:Parse(msg)
	if not patterns then Build() end
	for _, p in ipairs(patterns) do
		local caps = { msg:match(p.pattern) }
		if caps[1] ~= nil then
			local args = {}
			for ci, ai in ipairs(p.order) do
				args[ai] = caps[ci]
			end
			local info = { kind = p.kind, rollType = p.rollType }
			for ai, role in ipairs(p.roles) do
				info[role] = args[ai]
			end
			if p.self then info.player = SL.playerName or UnitName("player") end
			info.link = ExtractLink(info.item)
			info.roll = tonumber(info.roll)
			info.count = tonumber(info.count) or 1
			if info.link and info.link:find("|Hitem:") and info.player ~= nil then
				return info
			elseif info.link and info.link:find("|Hitem:") and info.kind == "allpassed" then
				return info
			end
		end
	end
end

SL:On("CHAT_MSG_LOOT", function(_, msg)
	if not SL.db then return end
	local info = Parser:Parse(msg)
	if SL.debug then
		if info then
			SL:Print("|cff999999[debug] " .. info.kind .. " - " .. tostring(info.player) .. " - " .. tostring(info.link)
				.. (info.roll and (" - roll " .. info.roll) or "") .. "|r")
		else
			SL:Print("|cff999999[debug] not recognised: " .. msg:gsub("|", "||") .. "|r")
		end
	end
	if not info then return end
	if info.player then
		local _, class = UnitClass(info.player)
		info.class = class
	end
	if SL.Roll and SL.Roll.OnLootMessage then SL.Roll:OnLootMessage(info) end
	if SL.History and SL.History.OnLootMessage then SL.History:OnLootMessage(info) end
	if SL.WinFX and SL.WinFX.OnLootMessage then SL.WinFX:OnLootMessage(info) end
end)
