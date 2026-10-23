-- SmartLoot by feralpaw
-- Loot roll bars (replace the Blizzard GroupLootFrames)

local _, ns = ...
local SL = ns.SL

local Roll = {}
SL.Roll = Roll
Roll.bars = {}

local max, floor = math.max, math.floor
local GetTime = GetTime

local ROLL_TYPES = {
	[1] = { key = "need", name = NEED or "Need", tip = NEED_NEWBIE, tex = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", down = "Interface\\Buttons\\UI-GroupLoot-Dice-Down", hl = "Interface\\Buttons\\UI-GroupLoot-Dice-Highlight" },
	[2] = { key = "greed", name = GREED or "Greed", tip = GREED_NEWBIE, tex = "Interface\\Buttons\\UI-GroupLoot-Coin-Up", down = "Interface\\Buttons\\UI-GroupLoot-Coin-Down", hl = "Interface\\Buttons\\UI-GroupLoot-Coin-Highlight" },
	[3] = { key = "de", name = ROLL_DISENCHANT or "Disenchant", tip = ROLL_DISENCHANT_NEWBIE, tex = "Interface\\Buttons\\UI-GroupLoot-DE-Up", down = "Interface\\Buttons\\UI-GroupLoot-DE-Down", hl = "Interface\\Buttons\\UI-GroupLoot-DE-Highlight" },
	[0] = { key = "pass", name = PASS or "Pass", tip = nil, tex = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", down = "Interface\\Buttons\\UI-GroupLoot-Pass-Down", hl = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
}
Roll.ROLL_TYPES = ROLL_TYPES
local BUTTON_ORDER = { 1, 2, 3, 0 }

local REASONS = {
	LOOT_ROLL_INELIGIBLE_REASON1, LOOT_ROLL_INELIGIBLE_REASON2, LOOT_ROLL_INELIGIBLE_REASON3,
	LOOT_ROLL_INELIGIBLE_REASON4, LOOT_ROLL_INELIGIBLE_REASON5,
}

local anchor

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function ButtonOnEnter(self)
	local bar = self.bar
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(ROLL_TYPES[self.rollType].name)
	if self.tip and SHOW_NEWBIE_TIPS == "1" then
		GameTooltip:AddLine(self.tip, 1, 0.82, 0, true)
	end
	if self.reason then
		GameTooltip:AddLine(self.reason, 1, 0.2, 0.2, true)
	end
	local any = false
	for name, data in pairs(bar.results) do
		if data.t == self.rollType then
			if not any then GameTooltip:AddLine(" ") any = true end
			local r, g, b = SL:ClassColor(data.class)
			GameTooltip:AddDoubleLine(name, data.n and tostring(data.n) or "", r, g, b, 1, 1, 1)
		end
	end
	GameTooltip:Show()
end

local function ButtonOnLeave()
	GameTooltip:Hide()
end

local function ButtonOnClick(self)
	local bar = self.bar
	if bar.test then
		SL:Print("Test mode - you chose " .. ROLL_TYPES[self.rollType].name .. " for " .. (bar.link or bar.itemName or "?"))
		if self.rollType == 1 and SL.WinFX then
			-- test mode: Need always wins
			SL.WinFX:Show({ link = bar.link, name = bar.itemName, quality = bar.quality,
				texture = bar.icon.tex:GetTexture(), roll = math.random(60, 100) })
		end
		Roll:Release(bar)
		Roll:Reposition()
		return
	end
	if bar.rollID then
		RollOnLoot(bar.rollID, self.rollType)
	end
end

local function SetButtonState(button, enabled, reason, value)
	if enabled then
		button:Enable()
		button:SetAlpha(1)
		button.reason = nil
		button:GetNormalTexture():SetDesaturated(false)
	else
		button:Disable()
		button:SetAlpha(0.3)
		local text = reason and REASONS[reason]
		if text and value then
			text = string.format(text, value)
		end
		button.reason = text
		button:GetNormalTexture():SetDesaturated(true)
	end
end

local function CreateButton(bar, rollType)
	local data = ROLL_TYPES[rollType]
	local b = CreateFrame("Button", nil, bar)
	b:SetNormalTexture(data.tex)
	b:SetPushedTexture(data.down)
	b:SetHighlightTexture(data.hl, "ADD")
	b:SetMotionScriptsWhileDisabled(true)
	b:SetScript("OnEnter", ButtonOnEnter)
	b:SetScript("OnLeave", ButtonOnLeave)
	b:SetScript("OnClick", ButtonOnClick)
	b.bar = bar
	b.rollType = rollType
	b.tip = data.tip
	b.count = SL:Text(b, "OVERLAY", -1, "RIGHT")
	b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -2)
	return b
end

---------------------------------------------------------------------------
-- Item icon
---------------------------------------------------------------------------
local function ItemOnEnter(self)
	local bar = self.bar
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	if bar.test then
		if bar.link then
			GameTooltip:SetHyperlink(bar.link)
		else
			GameTooltip:SetText(bar.itemName or "?", SL:QualityColor(bar.quality))
		end
		GameTooltip:Show()
	elseif bar.rollID then
		GameTooltip:SetLootRollItem(bar.rollID)
		CursorUpdate(self)
	end
end

local function ItemOnLeave()
	GameTooltip:Hide()
	ResetCursor()
end

local function ItemOnClick(self)
	local link = self.bar.link
	if not link then return end
	if IsModifiedClick("CHATLINK") then
		ChatEdit_InsertLink(link)
	elseif IsModifiedClick("DRESSUP") then
		DressUpItemLink(link)
	end
end

---------------------------------------------------------------------------
-- Timer: a soft fill across the whole card plus a thin line at the bottom
---------------------------------------------------------------------------
local function TimerOnUpdate(self, elapsed)
	local bar = self.bar
	if not bar.rollTime then return end
	local left
	if bar.test then
		left = (bar.testEnd - GetTime()) * 1000
		if left <= 0 then
			-- loop the test bars
			bar.testEnd = GetTime() + bar.rollTime / 1000
			left = bar.rollTime
		end
	else
		left = GetLootRollTimeLeft(bar.rollID)
	end
	if left < 0 or left > bar.rollTime then left = 0 end
	self:SetValue(left)
	bar.line:SetValue(left)
	local w = bar.line:GetWidth()
	bar.line.spark:SetPoint("CENTER", bar.line, "LEFT", w * left / bar.rollTime, 0)
	self.throttle = (self.throttle or 0) + elapsed
	if self.throttle > 0.2 then
		self.throttle = 0
		if SL.db.roll.showTimer then
			local sec = floor(left / 1000 + 0.5)
			bar.timer:SetText(sec .. "s")
			if sec <= 10 then
				bar.timer:SetTextColor(1, 0.3, 0.2)
			else
				bar.timer:SetTextColor(0.8, 0.8, 0.8)
			end
		else
			bar.timer:SetText("")
		end
	end
end

---------------------------------------------------------------------------
-- Bars (Blizzard style cards)
---------------------------------------------------------------------------
local COUNT_COLORS = { [1] = { 0.3, 1, 0.35 }, [2] = { 1, 0.82, 0 }, [3] = { 0.75, 0.55, 1 }, [0] = { 0.75, 0.75, 0.75 } }

local HEADER = 20
local PAD = 6

-- Row height: never smaller than two lines of text
local function RowHeight()
	local db = SL.db.roll
	local fs = SL.db.general.fontSize or 11
	return math.max(db.height, fs * 2 + 12 + db.barHeight)
end

local function CreateBar()
	local index = #Roll.bars + 1
	local container = Roll.container
	local bar = CreateFrame("Frame", "SmartLootRollBar" .. index, container)
	bar:Hide()
	SL:MakeDraggable(bar, anchor, SL.db.roll.point)

	-- soft quality glow from the left
	bar.glow = bar:CreateTexture(nil, "BACKGROUND")
	bar.glow:SetTexture(1, 1, 1, 1)
	bar.glow:SetAllPoints()

	-- fine separator to the row above
	bar.sep = bar:CreateTexture(nil, "BORDER")
	bar.sep:SetTexture(1, 1, 1, 0.09)
	bar.sep:SetHeight(1)
	bar.sep:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	bar.sep:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)

	-- time left as a soft fill behind the content
	local fill = CreateFrame("StatusBar", nil, bar)
	SL:Bar(fill)
	fill:SetAllPoints()
	fill:SetFrameLevel(bar:GetFrameLevel() + 1)
	fill.bar = bar
	fill:SetScript("OnUpdate", TimerOnUpdate)
	bar.fill = fill

	-- content above the fill
	local content = CreateFrame("Frame", nil, bar)
	content:SetAllPoints()
	content:SetFrameLevel(bar:GetFrameLevel() + 3)
	bar.content = content

	-- thin timer line at the bottom of the row
	local line = CreateFrame("StatusBar", nil, content)
	SL:Bar(line)
	line.bg = line:CreateTexture(nil, "BACKGROUND")
	line.bg:SetAllPoints()
	line.bg:SetTexture(0, 0, 0, 0.45)
	line.spark = line:CreateTexture(nil, "OVERLAY")
	line.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	line.spark:SetBlendMode("ADD")
	bar.line = line

	-- item icon with quality border
	local icon = CreateFrame("Button", nil, content)
	SL:Border(icon)
	icon.tex = icon:CreateTexture(nil, "ARTWORK")
	icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.bar = bar
	icon:SetScript("OnEnter", ItemOnEnter)
	icon:SetScript("OnLeave", ItemOnLeave)
	icon:SetScript("OnClick", ItemOnClick)
	icon.count = SL:Text(icon, "OVERLAY", -1, "RIGHT")
	icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -3, 3)
	bar.icon = icon

	-- buttons
	bar.buttons = {}
	for _, t in ipairs(BUTTON_ORDER) do
		local b = CreateButton(content, t)
		b.bar = bar
		local c = COUNT_COLORS[t]
		b.count:SetTextColor(c[1], c[2], c[3])
		bar.buttons[t] = b
	end

	bar.timer = SL:Text(content, "OVERLAY", -2, "RIGHT")
	bar.name = SL:Text(content, "OVERLAY", 0, "LEFT")
	bar.name:SetNonSpaceWrap(true)
	bar.sub = SL:Text(content, "OVERLAY", -3, "LEFT")

	bar.results = {}
	Roll.bars[index] = bar
	Roll:LayoutBar(bar)
	return bar
end

function Roll:LayoutBar(bar)
	local db = SL.db.roll
	local h, lh = RowHeight(), db.barHeight
	bar:SetWidth(db.width)
	bar:SetHeight(h)

	bar.line:ClearAllPoints()
	bar.line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	bar.line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	bar.line:SetHeight(lh)
	bar.line.spark:SetWidth(12)
	bar.line.spark:SetHeight(lh * 4 + 6)

	local iconSize = h - lh - 8
	bar.icon:SetWidth(iconSize)
	bar.icon:SetHeight(iconSize)
	bar.icon:ClearAllPoints()
	bar.icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 3, -4)
	SL:Inside(bar.icon.tex, bar.icon, 1)

	local size = math.min(h - lh - 12, 24)
	local prev
	for i = #BUTTON_ORDER, 1, -1 do
		local b = bar.buttons[BUTTON_ORDER[i]]
		b:SetWidth(size)
		b:SetHeight(size)
		b:ClearAllPoints()
		if prev then
			b:SetPoint("RIGHT", prev, "LEFT", -4, 0)
		else
			b:SetPoint("RIGHT", bar, "RIGHT", -6, lh / 2)
		end
		prev = b
	end
	bar.timer:ClearAllPoints()
	bar.timer:SetPoint("RIGHT", prev, "LEFT", -6, 0)
	bar.timer:SetWidth(30)

	-- name on top, second line at the bottom of the icon
	bar.name:ClearAllPoints()
	bar.name:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 8, -2)
	bar.name:SetPoint("RIGHT", bar.timer, "LEFT", -6, 0)
	bar.sub:ClearAllPoints()
	bar.sub:SetPoint("BOTTOMLEFT", bar.icon, "BOTTOMRIGHT", 8, 2)
	bar.sub:SetPoint("RIGHT", bar.timer, "LEFT", -6, 0)
end

function Roll:ColorBar(bar)
	local r, g, b = SL:QualityColor(bar.quality)
	bar.icon:SetBackdropBorderColor(r, g, b, 1)
	if SL.db.roll.qualityName then
		bar.name:SetTextColor(r, g, b)
	else
		bar.name:SetTextColor(1, 0.82, 0)
	end
	bar.glow:SetGradientAlpha("HORIZONTAL", r, g, b, 0.22, r, g, b, 0)
	local br, bg, bb = r, g, b
	if SL.db.roll.barColor == "theme" then
		local c = SL:GetTheme().accent
		br, bg, bb = c[1], c[2], c[3]
	end
	bar.fill:SetStatusBarColor(br, bg, bb, 0.09)
	bar.line:SetStatusBarColor(br, bg, bb, 0.95)
end

function Roll:RefreshColors()
	for _, bar in ipairs(self.bars) do
		if bar:IsShown() then self:ColorBar(bar) end
	end
end

function Roll:GetBar()
	for _, bar in ipairs(self.bars) do
		if not bar.rollID then return bar end
	end
	return CreateBar()
end

function Roll:Release(bar)
	bar:Hide()
	bar.rollID = nil
	bar.rollTime = nil
	bar.test = nil
	bar.link = nil
	for _, b in pairs(bar.buttons) do b.count:SetText("") end
	wipe(bar.results)
end

-- All active rolls sit as rows in one frame
function Roll:Reposition()
	local container = self.container
	if not container then return end
	local h = RowHeight()
	local n = 0
	for _, bar in ipairs(self.bars) do
		if bar.rollID then
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", container, "TOPLEFT", PAD, -(PAD + HEADER + n * h))
			if n == 0 then bar.sep:Hide() else bar.sep:Show() end
			n = n + 1
		end
	end
	if n == 0 then
		container:Hide()
		return
	end
	container:SetWidth(SL.db.roll.width + 2 * PAD)
	container:SetHeight(PAD + HEADER + n * h + PAD - 1)
	container:ClearAllPoints()
	if SL.db.roll.growUp then
		container:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
	else
		container:SetPoint("TOP", anchor, "TOP", 0, 0)
	end
	container:Show()
end

-- data: texture, name, count, quality, bop, canNeed, canGreed, canDE, reasonNeed, reasonGreed, reasonDE, deSkill, link
function Roll:Setup(bar, rollID, rollTime, d)
	bar.rollID = rollID
	bar.rollTime = rollTime
	bar.quality = d.quality or 1
	bar.link = d.link
	bar.itemName = d.name
	wipe(bar.results)

	bar.icon.tex:SetTexture(d.texture)
	if (d.count or 1) > 1 then
		bar.icon.count:SetText(d.count)
	else
		bar.icon.count:SetText("")
	end
	local ilvl = d.ilvl
	if not ilvl and d.link then
		ilvl = select(4, GetItemInfo(d.link))
	end
	-- second line: bind type and item level
	local sub = d.bop and "|cffff5a33Bind on Pickup|r" or "|cff55ff55Bind on Equip|r"
	if SL.db.roll.showItemLevel and ilvl and ilvl > 1 then
		sub = sub .. "   |cffaaaaaaItem Level " .. ilvl .. "|r"
	end
	bar.sub:SetText(sub)

	bar.name:SetText(d.name or "")

	bar.fill:SetMinMaxValues(0, rollTime)
	bar.fill:SetValue(rollTime)
	bar.line:SetMinMaxValues(0, rollTime)
	bar.line:SetValue(rollTime)
	bar.timer:SetText("")

	SetButtonState(bar.buttons[1], d.canNeed, d.reasonNeed)
	SetButtonState(bar.buttons[2], d.canGreed, d.reasonGreed)
	SetButtonState(bar.buttons[3], d.canDE, d.reasonDE, d.deSkill)
	SetButtonState(bar.buttons[0], true)

	self:ColorBar(bar)
	bar:Show()
	self:Reposition()
end

function Roll:AddResult(bar, player, rollType, class)
	if bar.results[player] then return end
	bar.results[player] = { t = rollType, class = class }
	if SL.db.roll.showCounts then
		local b = bar.buttons[rollType]
		if b then
			b.count:SetText((tonumber(b.count:GetText()) or 0) + 1)
		end
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function Roll:START_LOOT_ROLL(rollID, rollTime)
	if SL.testMode then SL:ToggleTestMode(false) end
	local texture, name, count, quality, bop, canNeed, canGreed, canDE, reasonNeed, reasonGreed, reasonDE, deSkill = GetLootRollItemInfo(rollID)
	if not name then return end
	if SL:AutoPass(rollID, name) then return end
	local link = GetLootRollItemLink(rollID)
	local bar = self:GetBar()
	self:Setup(bar, rollID, rollTime, {
		texture = texture, name = name, count = count, quality = quality, bop = bop,
		canNeed = canNeed, canGreed = canGreed, canDE = canDE,
		reasonNeed = reasonNeed, reasonGreed = reasonGreed, reasonDE = reasonDE, deSkill = deSkill,
		link = link,
	})

	if SL.db.roll.autoGreed and quality == 2 and not bop and UnitLevel("player") == MAX_PLAYER_LEVEL then
		RollOnLoot(rollID, canDE and 3 or 2)
	end
end

function Roll:CANCEL_LOOT_ROLL(rollID)
	for _, bar in ipairs(self.bars) do
		if bar.rollID == rollID and not bar.test then
			self:Release(bar)
			StaticPopup_Hide("CONFIRM_LOOT_ROLL", rollID)
			break
		end
	end
	self:Reposition()
end

-- Called by the chat parser
function Roll:OnLootMessage(info)
	if info.kind ~= "choice" or not info.player then return end
	local key = SL:ItemKey(info.link)
	for _, bar in ipairs(self.bars) do
		if bar.rollID and not bar.test and SL:ItemKey(bar.link) == key and not bar.results[info.player] then
			self:AddResult(bar, info.player, info.rollType, info.class)
			return
		end
	end
end

---------------------------------------------------------------------------
-- Anchor (shown in test mode so the bars can be moved)
---------------------------------------------------------------------------
local function CreateAnchor()
	anchor = CreateFrame("Frame", "SmartLootRollAnchor", UIParent)
	anchor:SetFrameStrata("DIALOG")
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	Roll.anchor = anchor

	-- one frame around all rolls
	local container = CreateFrame("Frame", "SmartLootRollFrame", anchor)
	container:SetFrameStrata("DIALOG")
	container:Hide()
	SL:Skin(container)
	SL:MakeDraggable(container, anchor, SL.db.roll.point)
	Roll.container = container
	local header = CreateFrame("Frame", nil, container)
	header:SetPoint("TOPLEFT", PAD - 2, -4)
	header:SetPoint("TOPRIGHT", -(PAD - 2), -4)
	header:SetHeight(HEADER - 2)
	local title = SL:Text(header, "OVERLAY", 0, "CENTER")
	title:SetPoint("CENTER", 0, 0)
	title:SetText("Loot Rolls")
	SL:Accent(title, "text")
	local lineL, lineR = SL:FadeLine(header, 1)
	lineL:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	lineL:SetPoint("BOTTOMRIGHT", header, "BOTTOM", 0, 0)
	lineR:SetPoint("BOTTOMLEFT", header, "BOTTOM", 0, 0)
	lineR:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

	-- small label tab next to the frame, only shown in test mode
	local box = CreateFrame("Frame", nil, anchor)
	box:SetHeight(22)
	box:SetFrameLevel(anchor:GetFrameLevel() + 10)
	SL:Border(box, nil, nil, nil, 0.85)
	box.text = SL:Text(box, "OVERLAY", -1)
	box.text:SetPoint("CENTER")
	box.text:SetText("SmartLoot - Roll Bars  (drag to move)")
	box.text:SetTextColor(1, 0.82, 0)
	SL:MakeDraggable(box, anchor, SL.db.roll.point)
	box:Hide()
	anchor.box = box
end

function Roll:ShowAnchor(show)
	if show then anchor.box:Show() else anchor.box:Hide() end
end

function Roll:UpdateLayout()
	if not anchor then return end
	local db = SL.db.roll
	anchor:SetScale(db.scale)
	anchor:SetWidth(db.width + 2 * PAD)
	anchor:SetHeight(HEADER + PAD)
	local box = anchor.box
	box:ClearAllPoints()
	if db.growUp then
		box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
		box:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	else
		box:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
		box:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 2)
	end
	for _, bar in ipairs(self.bars) do
		self:LayoutBar(bar)
		if bar.rollID then self:ColorBar(bar) end
	end
	self:Reposition()
end

function Roll:Init()
	CreateAnchor()
	SL:LoadPosition(anchor, SL.db.roll.point)
	self:UpdateLayout()
	if not SL.db.roll.enabled then return end

	UIParent:UnregisterEvent("START_LOOT_ROLL")
	UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")
	for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
		local f = _G["GroupLootFrame" .. i]
		if f then
			f:UnregisterEvent("CANCEL_LOOT_ROLL")
			f:Hide()
		end
	end
	SL:On("START_LOOT_ROLL", function(_, ...) Roll:START_LOOT_ROLL(...) end)
	SL:On("CANCEL_LOOT_ROLL", function(_, ...) Roll:CANCEL_LOOT_ROLL(...) end)
end
