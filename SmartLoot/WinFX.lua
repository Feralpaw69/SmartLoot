-- SmartLoot by feralpaw
-- Win visual: a gold laurel emblem in the middle of the screen when you
-- win an item that you rolled Need on (also in the test mode).

local _, ns = ...
local SL = ns.SL

local WinFX = {}
SL.WinFX = WinFX

local sin, pi, max, min = math.sin, math.pi, math.max, math.min
local GetTime = GetTime

local SIZE = 300          -- emblem size at scale 1
local ICON_Y = 0.4395     -- centre of the ring, from the top (texture coords)
local ICON_D = 0.242      -- diameter of the ring opening
local RIBBON_Y = 0.80     -- centre of the ribbon
local IN, HOLD, OUT = 0.35, 3.6, 0.7

local holder, frame
local needs = {}          -- item key -> { roll = n } for items you rolled Need on

local function db() return SL.db.win end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local function Create()
	holder = CreateFrame("Frame", "SmartLootWinHolder", UIParent)
	holder:SetWidth(SIZE)
	holder:SetHeight(SIZE)
	holder:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	holder:SetFrameStrata("FULLSCREEN_DIALOG")

	frame = CreateFrame("Button", "SmartLootWinFrame", holder)
	frame:SetWidth(SIZE)
	frame:SetHeight(SIZE)
	frame:SetPoint("CENTER")
	frame:Hide()
	frame:SetScript("OnClick", function(self) self.t = IN + HOLD end) -- click: fade out now

	local tex = SL.media .. "NeedWin"

	frame.emblem = frame:CreateTexture(nil, "ARTWORK")
	frame.emblem:SetAllPoints()
	frame.emblem:SetTexture(tex)

	-- the same emblem added on top again: a soft pulsing shine
	frame.shine = frame:CreateTexture(nil, "OVERLAY")
	frame.shine:SetAllPoints()
	frame.shine:SetTexture(tex)
	frame.shine:SetBlendMode("ADD")
	frame.shine:SetAlpha(0)

	-- round item icon inside the ring
	frame.iconHolder = CreateFrame("Frame", nil, frame)
	frame.iconHolder:SetFrameLevel(frame:GetFrameLevel() + 2)
	frame.icon = frame.iconHolder:CreateTexture(nil, "ARTWORK")

	-- item name above the emblem, "You won!" on the ribbon, roll below
	frame.name = frame.iconHolder:CreateFontString(nil, "OVERLAY")
	frame.banner = frame.iconHolder:CreateFontString(nil, "OVERLAY")
	frame.roll = frame.iconHolder:CreateFontString(nil, "OVERLAY")
	for _, fs in ipairs({ frame.name, frame.banner, frame.roll }) do
		-- a font must be set before any SetText (3.3.5); Layout sets the real one
		fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
		fs:SetJustifyH("CENTER")
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	end
	frame.banner:SetText("You won!")
	frame.banner:SetTextColor(1, 0.93, 0.62)
	frame.roll:SetTextColor(1, 0.95, 0.8)

	frame:SetScript("OnUpdate", function(self, elapsed)
		self.t = (self.t or 0) + elapsed
		local t = self.t
		local scale, alpha
		if t < IN then
			-- pop in: from big and transparent to normal size, with a small overshoot
			local p = t / IN
			scale = 1.6 - 0.65 * p + 0.05 * sin(p * pi)
			alpha = p
		elseif t < IN + HOLD then
			scale, alpha = 1, 1
		elseif t < IN + HOLD + OUT then
			local p = (t - IN - HOLD) / OUT
			scale = 1 + 0.08 * p
			alpha = 1 - p
		else
			self:Hide()
			return
		end
		self:SetScale(max(0.01, scale))
		self:SetAlpha(alpha)
		-- shine: a flash at the start, then a gentle pulse
		local flash = (t < IN + 0.4) and (1 - t / (IN + 0.4)) * 0.8 or 0
		self.shine:SetAlpha(min(1, flash + 0.18 * (0.5 + 0.5 * sin(t * 4))) * alpha)
	end)
end

function WinFX:Layout()
	if not frame then return end
	local s = db().scale or 1
	holder:SetScale(s)
	local fontPath = SL:GetFontPath()
	local fs = SL.db.general.fontSize or 11
	local function Font(f, size)
		f:SetFont(fontPath, size, "OUTLINE")
		if not f:GetFont() then f:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	end
	Font(frame.name, fs + 6)
	Font(frame.banner, fs + 7)
	Font(frame.roll, fs + 1)

	local d = SIZE * ICON_D
	frame.icon:SetWidth(d)
	frame.icon:SetHeight(d)
	frame.icon:ClearAllPoints()
	frame.icon:SetPoint("CENTER", frame, "TOP", 0, -SIZE * ICON_Y)

	frame.name:ClearAllPoints()
	frame.name:SetPoint("BOTTOM", frame, "TOP", 0, -4)
	frame.name:SetWidth(SIZE * 1.3)
	frame.banner:ClearAllPoints()
	frame.banner:SetPoint("CENTER", frame, "TOP", 0, -SIZE * RIBBON_Y - 1)
	frame.roll:ClearAllPoints()
	frame.roll:SetPoint("TOP", frame, "TOP", 0, -SIZE * 0.93)
end

---------------------------------------------------------------------------
-- Sounds: one of the switched on sounds, picked at random
---------------------------------------------------------------------------
local SOUND_PATH = "Interface\\AddOns\\SmartLoot\\Media\\Sounds\\"
WinFX.SOUNDS = {
	{ key = "soundFanfare", file = "Fanfare.ogg", name = "Fanfare" },
	{ key = "soundNice", file = "Nice.wav", name = "Nice" },
}

function WinFX:PlayFile(snd)
	local path = SOUND_PATH .. snd.file
	-- "Master" so it is heard even with the game sound effects turned off
	if not pcall(PlaySoundFile, path, "Master") then
		pcall(PlaySoundFile, path)
	end
	if SL.testMode or self.previewing then
		SL:Print("Win sound: " .. snd.name)
	end
end

local lastSound
function WinFX:PlaySound()
	local d = db()
	if not d.sound then return end
	local list = {}
	for _, snd in ipairs(self.SOUNDS) do
		-- random, but never the same sound twice in a row
		if d[snd.key] and (snd ~= lastSound) then list[#list + 1] = snd end
	end
	if #list == 0 then
		for _, snd in ipairs(self.SOUNDS) do
			if d[snd.key] then list[#list + 1] = snd end
		end
	end
	if #list == 0 then return end
	local snd = list[math.random(#list)]
	lastSound = snd
	self:PlayFile(snd)
end

-- Play button in the options
function WinFX:TestSound(key)
	for _, snd in ipairs(self.SOUNDS) do
		if snd.key == key then
			self.previewing = true
			self:PlayFile(snd)
			self.previewing = nil
		end
	end
end

-- data: { link, name, quality, texture, roll }
function WinFX:Show(data)
	if not db().enabled then return end
	if not frame then Create() end
	self:Layout()

	local name, quality, texture = data.name, data.quality, data.texture
	if data.link then
		local n, _, q, _, _, _, _, _, _, t = GetItemInfo(data.link)
		name = name or n
		quality = quality or q
		texture = texture or t
	end
	texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"

	-- round icon (falls back to the square icon if the client can't make it round)
	if not pcall(SetPortraitToTexture, frame.icon, texture) then
		frame.icon:SetTexture(texture)
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	frame.name:SetText(name or "")
	frame.name:SetTextColor(SL:QualityColor(quality or 4))
	if data.roll then
		frame.roll:SetText("Need roll: " .. data.roll)
	else
		frame.roll:SetText("")
	end

	frame.t = 0
	frame:SetScale(1.6)
	frame:SetAlpha(0)
	frame:Show()
	self:PlaySound()
end

---------------------------------------------------------------------------
-- Watching the loot messages (called by the chat parser)
---------------------------------------------------------------------------
function WinFX:OnLootMessage(info)
	if info.player ~= SL.playerName then return end
	if SL:IsIgnored(info.link) then return end
	local key = SL:ItemKey(info.link)
	if not key then return end
	if info.kind == "choice" then
		if info.rollType == 1 then
			needs[key] = needs[key] or {}
		else
			needs[key] = nil
		end
	elseif info.kind == "rolled" and info.rollType == 1 then
		needs[key] = needs[key] or {}
		needs[key].roll = info.roll
	elseif info.kind == "won" then
		local n = needs[key]
		needs[key] = nil
		if n then
			self:Show({ link = info.link, roll = n.roll })
		end
	end
end

-- Preview from the options
function WinFX:Preview()
	self.previewing = true
	local name, link, quality, _, _, _, _, _, _, tex = GetItemInfo(50363)
	self:Show({
		link = link, name = name or "Deathbringer's Will", quality = quality or 4,
		texture = tex or (GetItemIcon and GetItemIcon(50363)), roll = math.random(70, 100),
	})
	self.previewing = nil
end
