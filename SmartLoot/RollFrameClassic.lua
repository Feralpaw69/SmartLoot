-- SmartLoot by feralpaw
-- Design 1: the original roll bars (separate bars, icon outside, timer bar
-- below the name). Used instead of RollFrame.lua when "Design 1" is chosen.

local _, ns = ...
local SL = ns.SL

local Roll = {}
SL.RollClassic = Roll
Roll.bars = {}

local floor = math.floor
local GetTime = GetTime

local ROLL_TYPES = {
	[1] = { name = NEED or "Need", tip = NEED_NEWBIE, tex = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", down = "Interface\\Buttons\\UI-GroupLoot-Dice-Down", hl = "Interface\\Buttons\\UI-GroupLoot-Dice-Highlight" },
	[2] = { name = GREED or "Greed", tip = GREED_NEWBIE, tex = "Interface\\Buttons\\UI-GroupLoot-Coin-Up", down = "Interface\\Buttons\\UI-GroupLoot-Coin-Down", hl = "Interface\\Buttons\\UI-GroupLoot-Coin-Highlight" },
	[3] = { name = ROLL_DISENCHANT or "Disenchant", tip = ROLL_DISENCHANT_NEWBIE, tex = "Interface\\Buttons\\UI-GroupLoot-DE-Up", down = "Interface\\Buttons\\UI-GroupLoot-DE-Down", hl = "Interface\\Buttons\\UI-GroupLoot-DE-Highlight" },
	[0] = { name = PASS or "Pass", tip = nil, tex = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", down = "Interface\\Buttons\\UI-GroupLoot-Pass-Down", hl = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
}
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
-- Timer
---------------------------------------------------------------------------
local function TimerOnUpdate(self, elapsed)
	local bar = self.bar
	if not bar.rollTime then return end
	local left
	if bar.test then
		left = (bar.testEnd - GetTime()) * 1000
		if left <= 0 then
			bar.testEnd = GetTime() + bar.rollTime / 1000
			left = bar.rollTime
		end
	else
		left = GetLootRollTimeLeft(bar.rollID)
	end
	if left < 0 or left > bar.rollTime then left = 0 end
	self:SetValue(left)
	local w = self:GetWidth()
	self.spark:SetPoint("CENTER", self, "LEFT", w * left / bar.rollTime, 0)
	self.throttle = (self.throttle or 0) + elapsed
	if self.throttle > 0.2 then
		self.throttle = 0
		if SL.db.roll.showTimer then
			bar.timer:SetText(floor(left / 1000 + 0.5) .. "s")
		else
			bar.timer:SetText("")
		end
	end
end

---------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------
local function CreateBar()
	local index = #Roll.bars + 1
	local bar = CreateFrame("Frame", "SmartLootClassicRollBar" .. index, anchor)
	bar:SetFrameStrata("DIALOG")
	bar:Hide()
	SL:Skin(bar)
	SL:MakeDraggable(bar, anchor, SL.db.roll.point)

	-- icon with quality border
	local icon = CreateFrame("Button", nil, bar)
	SL:Border(icon)
	icon.tex = icon:CreateTexture(nil, "ARTWORK")
	icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.bar = bar
	icon:SetScript("OnEnter", ItemOnEnter)
	icon:SetScript("OnLeave", ItemOnLeave)
	icon:SetScript("OnClick", ItemOnClick)
	icon.level = SL:Text(icon, "OVERLAY", -1, "LEFT")
	icon.level:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 2, 2)
	icon.count = SL:Text(icon, "OVERLAY", -1, "RIGHT")
	icon.count:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -2)
	bar.icon = icon

	-- thin quality stripe on the left edge
	bar.stripe = bar:CreateTexture(nil, "ARTWORK")
	bar.stripe:SetTexture(1, 1, 1, 1)

	-- timer bar
	local status = CreateFrame("StatusBar", nil, bar)
	SL:Bar(status)
	status.bg = status:CreateTexture(nil, "BACKGROUND")
	status.bg:SetAllPoints()
	status.bg:SetTexture(SL:GetTexturePath())
	status.bar = bar
	status:SetScript("OnUpdate", TimerOnUpdate)
	status.spark = status:CreateTexture(nil, "OVERLAY")
	status.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	status.spark:SetBlendMode("ADD")
	bar.status = status
	bar.statusBorder = CreateFrame("Frame", nil, bar)
	SL:Border(bar.statusBorder, 0, 0, 0, 0)
	bar.statusBorder:SetFrameLevel(status:GetFrameLevel() + 1)

	bar.timer = SL:Text(bar.statusBorder, "OVERLAY", -2, "RIGHT")
	bar.timer:SetPoint("RIGHT", bar.statusBorder, "RIGHT", -3, 0)

	-- buttons
	bar.buttons = {}
	for _, t in ipairs(BUTTON_ORDER) do
		bar.buttons[t] = CreateButton(bar, t)
	end

	bar.bind = SL:Text(bar, "OVERLAY", -1, "RIGHT")
	bar.name = SL:Text(bar, "OVERLAY", 0, "LEFT")
	bar.name:SetNonSpaceWrap(true)

	bar.results = {}
	Roll.bars[index] = bar
	Roll:LayoutBar(bar)
	return bar
end

function Roll:LayoutBar(bar)
	local db = SL.db.roll
	local h, bh = db.height, db.barHeight
	local total = h + bh
	bar:SetWidth(db.width)
	bar:SetHeight(total)

	bar.icon:SetWidth(total)
	bar.icon:SetHeight(total)
	bar.icon:ClearAllPoints()
	bar.icon:SetPoint("RIGHT", bar, "LEFT", -3, 0)
	SL:Inside(bar.icon.tex, bar.icon, 1)

	bar.stripe:ClearAllPoints()
	bar.stripe:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
	bar.stripe:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
	bar.stripe:SetWidth(2)

	bar.statusBorder:ClearAllPoints()
	bar.statusBorder:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 4, 3)
	bar.statusBorder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -3, 3)
	bar.statusBorder:SetHeight(bh)
	SL:Inside(bar.status, bar.statusBorder, 1)
	bar.status.spark:SetWidth(10)
	bar.status.spark:SetHeight(bh * 2.2)

	local size = h - 6
	local prev
	for i = #BUTTON_ORDER, 1, -1 do
		local b = bar.buttons[BUTTON_ORDER[i]]
		b:SetWidth(size)
		b:SetHeight(size)
		b:ClearAllPoints()
		if prev then
			b:SetPoint("RIGHT", prev, "LEFT", -5, 0)
		else
			b:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -7, -3)
		end
		prev = b
	end
	bar.bind:ClearAllPoints()
	bar.bind:SetPoint("RIGHT", prev, "LEFT", -6, 0)
	bar.name:ClearAllPoints()
	bar.name:SetPoint("LEFT", bar, "TOPLEFT", 8, -(h / 2) - 1)
	bar.name:SetPoint("RIGHT", bar.bind, "LEFT", -4, 0)
	bar.name:SetHeight(h)
end

function Roll:ColorBar(bar)
	local r, g, b = SL:QualityColor(bar.quality)
	bar.icon:SetBackdropBorderColor(r, g, b, 1)
	bar.stripe:SetVertexColor(r, g, b, 0.9)
	if SL.db.roll.qualityName then
		bar.name:SetTextColor(r, g, b)
	else
		bar.name:SetTextColor(1, 1, 1)
	end
	local br, bg, bb = r, g, b
	if SL.db.roll.barColor == "theme" then
		local c = SL:GetTheme().accent
		br, bg, bb = c[1], c[2], c[3]
	end
	bar.status:SetStatusBarColor(br, bg, bb, 0.85)
	bar.status.bg:SetVertexColor(br * 0.25, bg * 0.25, bb * 0.25, 0.8)
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

function Roll:Reposition()
	local db = SL.db.roll
	local prev
	local gap = db.spacing
	for _, bar in ipairs(self.bars) do
		if bar.rollID then
			bar:ClearAllPoints()
			if db.growUp then
				if prev then
					bar:SetPoint("BOTTOMRIGHT", prev, "TOPRIGHT", 0, gap)
				else
					bar:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
				end
			else
				if prev then
					bar:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -gap)
				else
					bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
				end
			end
			prev = bar
		end
	end
end

-- data: texture, name, count, quality, bop, canNeed, canGreed, canDE, reasonNeed, reasonGreed, reasonDE, deSkill, link, ilvl
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
	if SL.db.roll.showItemLevel and ilvl and ilvl > 1 then
		bar.icon.level:SetText(ilvl)
	else
		bar.icon.level:SetText("")
	end

	bar.name:SetText(d.name or "")
	if d.bop then
		bar.bind:SetText("BoP")
		bar.bind:SetTextColor(1, 0.35, 0.2)
	else
		bar.bind:SetText("BoE")
		bar.bind:SetTextColor(0.35, 1, 0.35)
	end

	bar.status:SetMinMaxValues(0, rollTime)
	bar.status:SetValue(rollTime)
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
-- Anchor
---------------------------------------------------------------------------
local function CreateAnchor()
	anchor = CreateFrame("Frame", "SmartLootRollAnchor", UIParent)
	anchor:SetFrameStrata("DIALOG")
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	Roll.anchor = anchor

	local box = CreateFrame("Frame", nil, anchor)
	box:SetAllPoints()
	SL:Border(box, 1, 1, 1, 0.25)
	box:SetBackdropBorderColor(1, 1, 1, 0.6)
	box.text = SL:Text(box, "OVERLAY", 0)
	box.text:SetPoint("CENTER")
	box.text:SetText("SmartLoot - Roll Bars (drag me)")
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
	anchor:SetWidth(db.width + db.height + db.barHeight + 3)
	anchor:SetHeight(db.height + db.barHeight)
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
