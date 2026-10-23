-- SmartLoot by feralpaw
-- Core: saved settings, media, skinning helpers, events, slash commands

local ADDON, ns = ...

local SL = CreateFrame("Frame", "SmartLootCore", UIParent)
ns.SL = SL
_G.SmartLoot = SL

SL.version = GetAddOnMetadata(ADDON, "Version") or "1.0"
SL.media = "Interface\\AddOns\\SmartLoot\\Media\\"
SL.playerName = UnitName("player")

local floor, max, min = math.floor, math.max, math.min
local tinsert = table.insert

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
SL.defaults = {
	general = {
		theme = "black",
		design = 2, -- 1: original look (thin bars), 2: Blizzard look (one frame)
		style = "blizzard", -- "blizzard" (silver rounded border) or "pixel"
		themeBorder = false, -- border in the theme colour (Blizzard style)
		font = "Friz Quadrata",
		fontOutline = "NONE", -- "NONE" (shadow), "OUTLINE", "THICKOUTLINE"
		fontSize = 11,
		texture = "Smooth",
		bgAlpha = 0.9,
		locked = false,
		takeOverElvUI = true,
	},
	loot = {
		enabled = true,
		scale = 1,
		width = 210,
		slotHeight = 28,
		underMouse = false,
		showCount = true,
		qualityGlow = true,
		point = { "TOPLEFT", "UIParent", "TOPLEFT", 80, -240 },
	},
	roll = {
		enabled = true,
		scale = 1,
		width = 300,
		height = 36,
		barHeight = 3,
		spacing = 2,
		growUp = false,
		qualityName = true,
		showItemLevel = true,
		showTimer = true,
		showCounts = true,
		barColor = "quality", -- "quality" or "theme"
		autoGreed = false,
		autoPassDeathcharger = false, -- pass on [Reins of the Naxxramas Deathcharger]
		point = { "TOP", "UIParent", "TOP", 0, -170 },
	},
	win = {
		enabled = true, -- gold emblem when you win a Need roll
		scale = 1,
		sound = true,
		soundFanfare = true,
		soundNice = true, -- needs your own file Media\Sounds\Nice.wav
	},
	history = {
		enabled = true,
		trackDungeons = true,
		trackWorld = false,
		minQuality = 3,
		maxSessions = 60,
		scale = 1,
		point = { "CENTER", "UIParent", "CENTER", 0, 40 },
	},
}

local function CopyDefaults(src, dst)
	if type(dst) ~= "table" then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			if k == "point" then
				if type(dst[k]) ~= "table" then
					dst[k] = { v[1], v[2], v[3], v[4], v[5] }
				end
			else
				dst[k] = CopyDefaults(v, dst[k])
			end
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------
function SL:Print(...)
	local msg = ""
	for i = 1, select("#", ...) do
		msg = msg .. (i > 1 and " " or "") .. tostring((select(i, ...)))
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff7fb2ffSmart|rLoot: " .. msg)
end

---------------------------------------------------------------------------
-- Event dispatcher (several modules may listen to the same event)
---------------------------------------------------------------------------
local handlers = {}
function SL:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		self:RegisterEvent(event)
	end
	tinsert(handlers[event], fn)
end

SL:SetScript("OnEvent", function(self, event, ...)
	local list = handlers[event]
	if list then
		for i = 1, #list do
			-- each part runs on its own: an error in one does not stop the others
			local ok, err = pcall(list[i], event, ...)
			if not ok then
				local handler = geterrorhandler and geterrorhandler()
				if handler then handler(err) end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Media (built-in + LibSharedMedia when another addon provides it)
---------------------------------------------------------------------------
SL.fonts = {
	{ "PT Sans Narrow", SL.media .. "PTSansNarrow.ttf" },
	{ "Expressway", SL.media .. "Expressway.ttf" },
	{ "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
	{ "Arial Narrow", "Fonts\\ARIALN.TTF" },
	{ "Morpheus", "Fonts\\MORPHEUS.TTF" },
	{ "Skurri", "Fonts\\SKURRI.TTF" },
}
SL.textures = {
	{ "Smooth", SL.media .. "Smooth.tga" },
	{ "Minimalist", SL.media .. "Minimalist.tga" },
	{ "Melli", SL.media .. "Melli.tga" },
	{ "Flat", "Interface\\Buttons\\WHITE8X8" },
	{ "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
}

local function GetLSM()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function RegisterLSM()
	local LSM = GetLSM()
	if not LSM then return end
	pcall(LSM.Register, LSM, "font", "SmartLoot PT Sans Narrow", SL.media .. "PTSansNarrow.ttf")
	pcall(LSM.Register, LSM, "font", "SmartLoot Expressway", SL.media .. "Expressway.ttf")
	pcall(LSM.Register, LSM, "statusbar", "SmartLoot Smooth", SL.media .. "Smooth.tga")
end

local function FindMedia(list, kind, name)
	for i = 1, #list do
		if list[i][1] == name then return list[i][2] end
	end
	local LSM = GetLSM()
	if LSM and name then
		local ok, path = pcall(LSM.Fetch, LSM, kind, name, true)
		if ok and path then return path end
	end
	return list[1][2]
end

-- Returns a list of names: built-ins first, then LibSharedMedia entries
function SL:MediaNames(kind)
	local list = (kind == "font") and self.fonts or self.textures
	local names, seen = {}, {}
	for i = 1, #list do
		names[#names + 1] = list[i][1]
		seen[list[i][1]] = true
	end
	local LSM = GetLSM()
	if LSM then
		local ok, lsmList = pcall(LSM.List, LSM, kind == "font" and "font" or "statusbar")
		if ok and type(lsmList) == "table" then
			for _, name in ipairs(lsmList) do
				if not seen[name] and #names < 30 then
					names[#names + 1] = name
					seen[name] = true
				end
			end
		end
	end
	return names
end

function SL:GetFontPath()
	return FindMedia(self.fonts, "font", self.db.general.font)
end

function SL:GetTexturePath()
	return FindMedia(self.textures, "statusbar", self.db.general.texture)
end

---------------------------------------------------------------------------
-- Font strings / status bars that follow the settings
---------------------------------------------------------------------------
SL.fontObjects = {}
SL.barObjects = {}

local function ApplyFont(fs, delta)
	local size = max(6, (SL.db.general.fontSize or 11) + (delta or 0))
	local flags = SL.db.general.fontOutline or "NONE"
	if flags == "NONE" then flags = "" end
	fs:SetFont(SL:GetFontPath(), size, flags)
	if not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
	if flags == "" then
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Creates (or registers) a font string with the addon font
function SL:Text(parent, layer, delta, justify)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs.slDelta = delta or 0
	ApplyFont(fs, fs.slDelta)
	if justify then fs:SetJustifyH(justify) end
	tinsert(self.fontObjects, fs)
	return fs
end

function SL:Bar(bar)
	bar:SetStatusBarTexture(self:GetTexturePath())
	tinsert(self.barObjects, bar)
	return bar
end

function SL:UpdateMedia()
	for _, fs in ipairs(self.fontObjects) do
		ApplyFont(fs, fs.slDelta)
	end
	local tex = self:GetTexturePath()
	for _, bar in ipairs(self.barObjects) do
		bar:SetStatusBarTexture(tex)
		if bar.bg then bar.bg:SetTexture(tex) end
	end
end

---------------------------------------------------------------------------
-- Pixel borders
---------------------------------------------------------------------------
SL.mult = 1
function SL:UpdatePixel()
	local res = GetCVar("gxResolution") or ""
	local h = tonumber(res:match("%d+x(%d+)")) or 768
	local scale = UIParent:GetScale()
	if scale <= 0 then scale = 1 end
	self.mult = 768 / h / scale
end

function SL:IsClassic()
	return self.db and self.db.general.design == 1
end

-- Settings that belong to each design (applied when the design is switched)
SL.designPresets = {
	[1] = { style = "pixel", font = "PT Sans Narrow", fontOutline = "OUTLINE", fontSize = 12, bgAlpha = 0.85,
		roll = { width = 330, height = 24, barHeight = 7, spacing = 6 } },
	[2] = { style = "blizzard", font = "Friz Quadrata", fontOutline = "NONE", fontSize = 11, bgAlpha = 0.9,
		roll = { width = 300, height = 36, barHeight = 3, spacing = 2 } },
}

function SL:SetDesign(n)
	local p = self.designPresets[n]
	if not p then return end
	local g = self.db.general
	g.design = n
	g.style, g.font, g.fontOutline, g.fontSize, g.bgAlpha = p.style, p.font, p.fontOutline, p.fontSize, p.bgAlpha
	for k, v in pairs(p.roll) do self.db.roll[k] = v end
end

function SL:IsPixelStyle()
	return self.db and self.db.general.style == "pixel"
end

-- big: window / bar frames; otherwise small boxes (icons, buttons)
local function Backdrop(big)
	local m = SL.mult
	if SL:IsPixelStyle() then
		return {
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = m,
			insets = { left = m, right = m, top = m, bottom = m },
		}
	end
	-- standard Blizzard frame look (silver rounded tooltip border)
	local edge, inset = 10, 2
	if big then edge, inset = 16, 4 end
	return {
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = edge,
		insets = { left = inset, right = inset, top = inset, bottom = inset },
	}
end

-- Colour of a small box border that has no special colour
function SL:PlainBorderColor()
	if self:IsPixelStyle() then return 0, 0, 0 end
	return 0.6, 0.6, 0.6
end

-- Simple bordered box (used for icons, buttons, panes)
-- r, g, b: border colour (nil = default), a: background alpha
function SL:Border(frame, r, g, b, a)
	frame:SetBackdrop(Backdrop(false))
	frame:SetBackdropColor(0, 0, 0, a or 0.6)
	if r == nil or (r == 0 and g == 0 and b == 0) then
		r, g, b = self:PlainBorderColor()
	end
	frame:SetBackdropBorderColor(r, g, b, 1)
end

-- Places a region inside the border of parent
function SL:Inside(region, parent, pad)
	local p
	if self:IsPixelStyle() then
		p = (pad or 1) * self.mult
	else
		p = parent.slBig and 4 or 3
	end
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", parent, "TOPLEFT", p, -p)
	region:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -p, p)
end

---------------------------------------------------------------------------
-- Themed panels (background gradient + border in the theme colours)
---------------------------------------------------------------------------
SL.skinned = {}
SL.accents = {}

-- inset: inner pane (smaller border that always uses the theme colour,
-- like the panes of the AH addon)
function SL:Skin(frame, inset)
	frame.slBig = not inset
	frame.slInset = inset and true or nil
	frame:SetBackdrop(Backdrop(not inset))
	if not frame.slTint then
		local tint = frame:CreateTexture(nil, "BACKGROUND", nil)
		tint:SetTexture(1, 1, 1, 1)
		frame.slTint = tint
	end
	self:Inside(frame.slTint, frame, 1)
	if not frame.slSkinned then
		frame.slSkinned = true
		tinsert(self.skinned, frame)
	end
	self:ApplyThemeTo(frame)
end

-- kind: "text" (font string colour), "texture" (vertex colour), "line"
function SL:Accent(region, kind, alpha)
	tinsert(self.accents, { region = region, kind = kind or "text", alpha = alpha or 1 })
	if kind == "fade" then
		-- line that fades out to both sides
		region:SetTexture(1, 1, 1, 1)
	end
	self:ApplyAccent(self.accents[#self.accents])
end

function SL:ApplyThemeTo(frame)
	local t = self:GetTheme()
	local a = self.db.general.bgAlpha or 0.85
	frame:SetBackdropColor(t.bottom[1], t.bottom[2], t.bottom[3], a)
	if not frame.slKeepBorder then
		if self:IsPixelStyle() or self.db.general.themeBorder or frame.slInset then
			frame:SetBackdropBorderColor(t.border[1], t.border[2], t.border[3], 1)
		else
			frame:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
		end
	end
	frame.slTint:SetGradientAlpha("VERTICAL",
		t.bottom[1], t.bottom[2], t.bottom[3], a,
		t.top[1], t.top[2], t.top[3], a)
end

function SL:ApplyAccent(entry)
	local c = self:GetTheme().accent
	local r = entry.region
	if entry.kind == "text" then
		if self:IsPixelStyle() then
			r:SetTextColor(c[1], c[2], c[3])
		else
			r:SetTextColor(1, 0.82, 0) -- Blizzard gold
		end
	elseif entry.kind == "fade" then
		-- left half: transparent at the outer edge, bright in the middle
		r:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], 0, c[1], c[2], c[3], entry.alpha)
		if r.slMirror then
			r.slMirror:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], entry.alpha, c[1], c[2], c[3], 0)
		end
	else
		r:SetVertexColor(c[1], c[2], c[3], entry.alpha)
	end
end

-- Header line: bright in the middle, fading to both sides
function SL:FadeLine(parent, height)
	local left = parent:CreateTexture(nil, "ARTWORK")
	local right = parent:CreateTexture(nil, "ARTWORK")
	left:SetHeight(height or 1)
	right:SetHeight(height or 1)
	right:SetTexture(1, 1, 1, 1)
	left.slMirror = right
	self:Accent(left, "fade", 0.9)
	return left, right
end

function SL:ApplyTheme()
	self:UpdatePixel()
	for _, f in ipairs(self.skinned) do
		self:ApplyThemeTo(f)
	end
	for _, e in ipairs(self.accents) do
		self:ApplyAccent(e)
	end
	if self.Roll and self.Roll.RefreshColors then self.Roll:RefreshColors() end
end

---------------------------------------------------------------------------
-- Moving frames and saving positions
---------------------------------------------------------------------------
function SL:SavePosition(frame, store)
	local point, _, relPoint, x, y = frame:GetPoint(1)
	store[1], store[2], store[3], store[4], store[5] = point, "UIParent", relPoint, floor(x + 0.5), floor(y + 0.5)
end

function SL:LoadPosition(frame, store)
	frame:ClearAllPoints()
	frame:SetPoint(store[1] or "CENTER", UIParent, store[3] or "CENTER", store[4] or 0, store[5] or 0)
end

-- moveFrame: the frame that actually moves (may differ from the drag handle)
function SL:MakeDraggable(handle, moveFrame, store, onStop)
	moveFrame:SetMovable(true)
	moveFrame:SetClampedToScreen(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if SL.db.general.locked then return end
		moveFrame:StartMoving()
		moveFrame.slMoving = true
	end)
	handle:SetScript("OnDragStop", function()
		if not moveFrame.slMoving then return end
		moveFrame.slMoving = nil
		moveFrame:StopMovingOrSizing()
		if store then SL:SavePosition(moveFrame, store) end
		if onStop then onStop() end
	end)
end

---------------------------------------------------------------------------
-- Item helpers
---------------------------------------------------------------------------
function SL:QualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

function SL:ClassColor(class)
	local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or RAID_CLASS_COLORS[class])
	if c then return c.r, c.g, c.b end
	return 0.85, 0.85, 0.85
end

function SL:ClassColoredName(name, class)
	local r, g, b = self:ClassColor(class)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name or "?")
end

function SL:ItemString(link)
	return link and link:match("|H(item:[^|]+)|h") or link
end

-- Same item, ignoring the unique id / level fields at the end of the item string
function SL:ItemKey(link)
	local s = self:ItemString(link)
	if not s then return nil end
	local id, ench, g1, g2, g3, g4, suffix = s:match("^item:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	if id then
		return id .. ":" .. suffix
	end
	return s
end

function SL:LinkQuality(link)
	if not link then return 1 end
	local _, _, q = GetItemInfo(link)
	if q then return q end
	local hex = link:match("|c(%x%x%x%x%x%x%x%x)")
	if hex and ITEM_QUALITY_COLORS then
		for i = 0, 7 do
			local c = ITEM_QUALITY_COLORS[i]
			if c and c.hex and c.hex:lower():find(hex:lower(), 1, true) then return i end
		end
	end
	return 1
end

---------------------------------------------------------------------------
-- Auto pass on chosen items (checked by name, so it works in every language
-- the item name is written in)
---------------------------------------------------------------------------
SL.AUTOPASS_DEATHCHARGER = "Reins of the Naxxramas Deathcharger"

-- Items that are never tracked (loot history, reports, win animation).
-- "valor" only as a whole word, so Valorous tier gear is not affected.
SL.IGNORE_PATTERNS = {
	"echo[e]?s? of the necropolis",
	"%f[%a]valor%f[%A]",
}

function SL:IsIgnored(linkOrName)
	if not linkOrName then return false end
	local name = linkOrName:match("%[(.-)%]") or linkOrName
	name = name:lower()
	for _, p in ipairs(self.IGNORE_PATTERNS) do
		if name:find(p) then return true end
	end
	return false
end

function SL:AutoPass(rollID, name)
	if not self.db.roll.autoPassDeathcharger then return false end
	if not name or name:lower() ~= self.AUTOPASS_DEATHCHARGER:lower() then return false end
	RollOnLoot(rollID, 0)
	local link = GetLootRollItemLink(rollID)
	self:Print("Auto pass on " .. (link or name) .. "  (Esc > Interface > SmartLoot > Roll Bars)")
	return true
end

---------------------------------------------------------------------------
-- ElvUI: switch off its loot window / roll bars so they do not show twice
---------------------------------------------------------------------------
function SL:TakeOverElvUI()
	if not self.db.general.takeOverElvUI then return end
	local E = _G.ElvUI and _G.ElvUI[1]
	if type(E) ~= "table" or not E.GetModule then return end
	local ok, M = pcall(E.GetModule, E, "Misc", true)
	if not ok or type(M) ~= "table" or not M.UnregisterEvent then return end
	if self.db.loot.enabled then
		for _, ev in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "OPEN_MASTER_LOOT_LIST", "UPDATE_MASTER_LOOT_LIST" }) do
			pcall(M.UnregisterEvent, M, ev)
		end
		if _G.ElvLootFrame then _G.ElvLootFrame:Hide() end
	end
	if self.db.roll.enabled then
		pcall(M.UnregisterEvent, M, "START_LOOT_ROLL")
		pcall(M.UnregisterEvent, M, "CANCEL_LOOT_ROLL")
		if M.RollBars then
			for _, bar in ipairs(M.RollBars) do bar:Hide() end
		end
	end
	if self.Loot and self.Loot.FixMasterLoot then self.Loot:FixMasterLoot() end
end

---------------------------------------------------------------------------
-- Apply all settings
---------------------------------------------------------------------------
function SL:ApplySettings()
	self:UpdateMedia()
	self:ApplyTheme()
	if self.Loot and self.Loot.UpdateLayout then self.Loot:UpdateLayout() end
	if self.Roll and self.Roll.UpdateLayout then self.Roll:UpdateLayout() end
	if self.HistoryUI and self.HistoryUI.UpdateLayout then self.HistoryUI:UpdateLayout() end
end

function SL:ResetPositions()
	for _, key in ipairs({ "loot", "roll", "history" }) do
		-- copy into the existing table: the drag handlers keep a reference to it
		local d, p = self.defaults[key].point, self.db[key].point
		p[1], p[2], p[3], p[4], p[5] = d[1], d[2], d[3], d[4], d[5]
	end
	if self.Loot and self.Loot.frame then self:LoadPosition(self.Loot.frame, self.db.loot.point) end
	if self.Roll and self.Roll.anchor then self:LoadPosition(self.Roll.anchor, self.db.roll.point) end
	if self.HistoryUI and self.HistoryUI.frame then self:LoadPosition(self.HistoryUI.frame, self.db.history.point) end
	self:Print("Frame positions reset.")
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
SL:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	SmartLootDB = CopyDefaults(SL.defaults, SmartLootDB)
	SL.db = SmartLootDB
	-- design 2: Blizzard frame style; move old settings that were still on the old defaults
	if (SL.db.designVersion or 1) < 2 then
		local g, r = SL.db.general, SL.db.roll
		if g.font == "PT Sans Narrow" then g.font = "Friz Quadrata" end
		if g.fontSize == 12 then g.fontSize = 11 end
		if r.width == 330 then r.width = 300 end
		if r.height == 24 then r.height = 36 end
		if r.barHeight == 7 then r.barHeight = 3 end
		if r.spacing == 6 then r.spacing = 2 end
		if g.bgAlpha == 0.85 then g.bgAlpha = 0.9 end
		SL.db.designVersion = 2
	end
	-- the cheer sound was removed and "Nice" is on by default now
	if not SL.db.win.niceDefault then
		SL.db.win.soundNice = true
		SL.db.win.soundCheer = nil
		SL.db.win.niceDefault = true
	end
	-- Design 1 uses the original roll bars
	if SL.db.general.design == 1 and SL.RollClassic then
		SL.Roll = SL.RollClassic
	end
	SmartLootHistoryDB = SmartLootHistoryDB or {}
	SmartLootHistoryDB.sessions = SmartLootHistoryDB.sessions or {}
	SL.hdb = SmartLootHistoryDB
	SL:UpdatePixel()
	RegisterLSM()
end)

SL:On("PLAYER_LOGIN", function()
	SL.playerName = UnitName("player")
	if SL.Loot then SL.Loot:Init() end
	if SL.Roll then SL.Roll:Init() end
	if SL.History then SL.History:Init() end
	if SL.Options then SL.Options:Init() end
	SL:TakeOverElvUI()
end)

local firstWorld = true
SL:On("PLAYER_ENTERING_WORLD", function()
	if firstWorld then
		firstWorld = false
		SL:TakeOverElvUI()
		SL:ApplyTheme()
	end
end)

SL:On("UI_SCALE_CHANGED", function() SL:ApplyTheme() end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Help()
	SL:Print("v" .. SL.version .. " - made by feralpaw")
	DEFAULT_CHAT_FRAME:AddMessage("  /smartloot config  - open the options (also Esc > Interface > AddOns)")
	DEFAULT_CHAT_FRAME:AddMessage("  /smartloot test    - toggle test mode (move the frames here)")
	DEFAULT_CHAT_FRAME:AddMessage("  /smartloot lock    - lock / unlock the frames")
	DEFAULT_CHAT_FRAME:AddMessage("  /smartloot reset   - reset frame positions")
	DEFAULT_CHAT_FRAME:AddMessage("  /loot              - open the loot history")
end

SLASH_SMARTLOOT1 = "/smartloot"
SLASH_SMARTLOOT2 = "/sloot"
SlashCmdList.SMARTLOOT = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "test" then
		SL:ToggleTestMode()
	elseif msg == "lock" or msg == "unlock" then
		SL.db.general.locked = not SL.db.general.locked
		SL:Print(SL.db.general.locked and "Frames locked." or "Frames unlocked.")
	elseif msg == "reset" then
		SL:ResetPositions()
	elseif msg == "log" or msg == "history" then
		if SL.HistoryUI then SL.HistoryUI:Toggle() end
	elseif msg == "config" or msg == "options" or msg == "" then
		if SL.Options then SL.Options:Open() end
		if msg == "" then Help() end
	else
		Help()
	end
end
