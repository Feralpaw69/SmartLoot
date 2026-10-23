-- SmartLoot by feralpaw
-- Loot window (replaces the Blizzard LootFrame)

local _, ns = ...
local SL = ns.SL

local Loot = {}
SL.Loot = Loot

local max = math.max
local HEADER = 20

local frame
local slots = {}

---------------------------------------------------------------------------
-- Slot scripts
---------------------------------------------------------------------------
local function SlotOnEnter(self)
	if not SL:IsClassic() then self.edge:Show() end
	self.hl:Show()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.test then
		if self.test.link then
			GameTooltip:SetHyperlink(self.test.link)
		else
			GameTooltip:SetText(self.test.name, SL:QualityColor(self.test.quality))
		end
		GameTooltip:Show()
		return
	end
	local id = self:GetID()
	if LootSlotIsItem(id) then
		GameTooltip:SetLootItem(id)
		CursorUpdate(self)
	else
		GameTooltip:Hide()
	end
end

local function SlotOnLeave(self)
	self.edge:Hide()
	self.hl:Hide()
	GameTooltip:Hide()
	ResetCursor()
end

local function SlotOnUpdate(self)
	if GameTooltip:IsOwned(self) and not self.test then
		CursorOnUpdate(self)
	end
end

local function SlotOnClick(self)
	if self.test then
		if IsModifiedClick() and self.test.link then
			HandleModifiedItemClick(self.test.link)
		else
			SL:Print("Test mode - you looted " .. (self.test.link or self.test.name))
			self:Hide()
			Loot:Layout()
		end
		return
	end
	local id = self:GetID()
	if IsModifiedClick() then
		HandleModifiedItemClick(GetLootSlotLink(id))
		return
	end
	StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
	-- Blizzard's master loot dropdown reads these fields
	LootFrame.selectedLootButton = self:GetName()
	LootFrame.selectedSlot = id
	LootFrame.selectedQuality = self.quality
	LootFrame.selectedItemName = self.itemName
	Loot.selectedButton = self
	LootSlot(id)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function CreateSlot(id)
	local s = CreateFrame("Button", "SmartLootSlot" .. id, frame)
	s:SetID(id)
	s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	s:SetScript("OnEnter", SlotOnEnter)
	s:SetScript("OnLeave", SlotOnLeave)
	s:SetScript("OnClick", SlotOnClick)
	s:SetScript("OnUpdate", SlotOnUpdate)
	-- dragging a slot moves the whole window
	SL:MakeDraggable(s, frame, SL.db.loot.point)

	-- quality glow: fades from the left side
	s.glow = s:CreateTexture(nil, "BACKGROUND")
	s.glow:SetTexture(1, 1, 1, 1)
	s.glow:SetAllPoints()

	s.hl = s:CreateTexture(nil, "HIGHLIGHT")
	s.hl:SetTexture(1, 1, 1, 0.08)
	s.hl:SetAllPoints()
	s.hl:Hide()

	-- gold line on the left while hovering
	s.edge = s:CreateTexture(nil, "OVERLAY")
	s.edge:SetTexture(1, 0.82, 0, 0.9)
	s.edge:SetWidth(2)
	s.edge:SetPoint("TOPLEFT", s, "TOPLEFT", -3, 0)
	s.edge:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", -3, 0)
	s.edge:Hide()

	s.iconFrame = CreateFrame("Frame", nil, s)
	SL:Border(s.iconFrame)
	s.icon = s.iconFrame:CreateTexture(nil, "ARTWORK")
	s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	s.count = SL:Text(s.iconFrame, "OVERLAY", -1, "RIGHT")
	s.count:SetPoint("BOTTOMRIGHT", s.iconFrame, "BOTTOMRIGHT", -1, 2)

	s.name = SL:Text(s, "OVERLAY", 0, "LEFT")
	s.name:SetNonSpaceWrap(true)

	slots[id] = s
	Loot:LayoutSlot(s)
	return s
end

function Loot:LayoutSlot(s)
	local h = SL.db.loot.slotHeight
	s:SetHeight(h)
	local classic = SL:IsClassic()
	s.iconFrame:SetWidth(classic and h - 2 or h)
	s.iconFrame:SetHeight(classic and h - 2 or h)
	s.iconFrame:ClearAllPoints()
	s.iconFrame:SetPoint("LEFT", s, "LEFT", classic and 1 or 0, 0)
	SL:Inside(s.icon, s.iconFrame, 1)
	s.name:ClearAllPoints()
	s.name:SetPoint("LEFT", s.iconFrame, "RIGHT", 7, 0)
	s.name:SetPoint("RIGHT", s, "RIGHT", -4, 0)
end

local function CreateMainFrame()
	frame = CreateFrame("Frame", "SmartLootFrame", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetWidth(200)
	frame:SetHeight(60)
	frame:Hide()
	SL:Skin(frame)
	SL:MakeDraggable(frame, frame, SL.db.loot.point)

	-- header
	local header = CreateFrame("Frame", nil, frame)
	SL:MakeDraggable(header, frame, SL.db.loot.point)
	frame.header = header
	header:SetHeight(HEADER)

	if SL:IsClassic() then
		-- Design 1: coloured header band, title on the left, small x
		header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
		header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
		local hbg = header:CreateTexture(nil, "BORDER")
		hbg:SetAllPoints()
		hbg:SetTexture(1, 1, 1, 1)
		hbg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.22, 1, 1, 1, 0)
		SL:Accent(hbg, "texture", 1)
		local line = header:CreateTexture(nil, "ARTWORK")
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT")
		line:SetPoint("BOTTOMRIGHT")
		line:SetTexture(1, 1, 1, 1)
		SL:Accent(line, "texture", 0.6)

		frame.title = SL:Text(header, "OVERLAY", 0, "LEFT")
		frame.title:SetPoint("LEFT", header, "LEFT", 6, 0)
		frame.title:SetPoint("RIGHT", header, "RIGHT", -40, 0)
		SL:Accent(frame.title, "text")

		local close = CreateFrame("Button", nil, header)
		close:SetWidth(16)
		close:SetHeight(16)
		close:SetPoint("RIGHT", header, "RIGHT", -3, 0)
		close.text = SL:Text(close, "OVERLAY", 1)
		close.text:SetPoint("CENTER", 1, 0)
		close.text:SetText("x")
		close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.3, 0.3) end)
		close:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 1, 1) end)
		close:SetScript("OnClick", function() frame:Hide() end)

		frame.countText = SL:Text(header, "OVERLAY", -2, "RIGHT")
		frame.countText:SetPoint("RIGHT", close, "LEFT", -4, 0)
		frame.countText:SetTextColor(0.7, 0.7, 0.7)
	else
		-- Design 2: gold title in the middle, line that fades out to the sides
		header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
		header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
		frame.title = SL:Text(header, "OVERLAY", 1, "CENTER")
		frame.title:SetPoint("LEFT", header, "LEFT", 30, -1)
		frame.title:SetPoint("RIGHT", header, "RIGHT", -30, -1)
		SL:Accent(frame.title, "text")

		local lineL, lineR = SL:FadeLine(header, 1)
		lineL:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 6, 0)
		lineL:SetPoint("BOTTOMRIGHT", header, "BOTTOM", 0, 0)
		lineR:SetPoint("BOTTOMLEFT", header, "BOTTOM", 0, 0)
		lineR:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -6, 0)

		-- standard Blizzard close button
		local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
		close:SetWidth(24)
		close:SetHeight(24)
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
		close:SetScript("OnClick", function() frame:Hide() end)

		frame.countText = SL:Text(header, "OVERLAY", -2, "LEFT")
		frame.countText:SetPoint("LEFT", header, "LEFT", 6, -1)
		frame.countText:SetTextColor(0.7, 0.7, 0.7)
	end

	frame:SetScript("OnHide", function(self)
		StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
		if self.testing then
			self.testing = nil
		else
			CloseLoot()
		end
	end)

	tinsert(UISpecialFrames, "SmartLootFrame")
	Loot.frame = frame
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
function Loot:Layout()
	if not frame then return end
	local h = SL.db.loot.slotHeight
	local classic = SL:IsClassic()
	local y = classic and -(HEADER + 4) or -(HEADER + 8)
	local side = classic and 4 or 6
	local shown, maxQuality, w = 0, 0, frame.title:GetStringWidth() + 60
	for i = 1, #slots do
		local s = slots[i]
		if s:IsShown() then
			shown = shown + 1
			s:ClearAllPoints()
			s:SetPoint("TOPLEFT", frame, "TOPLEFT", side, y)
			s:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -side, y)
			y = y - h - 2
			if (s.quality or 0) > maxQuality then maxQuality = s.quality end
			w = max(w, s.name:GetStringWidth() + h + 24)
		end
	end
	frame:SetWidth(max(SL.db.loot.width, w))
	frame:SetHeight(HEADER + (classic and 8 or 14) + max(shown, 1) * (h + 2))
	if classic then
		frame.countText:SetText(shown > 0 and (shown .. (shown == 1 and " item" or " items")) or "")
	else
		frame.countText:SetText(shown > 0 and shown or "")
	end
	-- border in the colour of the best item (epic and better), otherwise theme
	if maxQuality >= 4 then
		frame.slKeepBorder = true
		frame:SetBackdropBorderColor(SL:QualityColor(maxQuality))
	else
		frame.slKeepBorder = nil
		SL:ApplyThemeTo(frame)
	end
	if shown == 0 and frame:IsShown() and not frame.testing then
		-- every slot looted; Blizzard closes the window on LOOT_CLOSED anyway
	end
end

-- data: { texture, name, count, quality, locked, link }
function Loot:FillSlot(i, data)
	local s = slots[i] or CreateSlot(i)
	s.quality = data.quality or 1
	s.itemName = data.name
	s.test = data.test
	local name = data.name or ""
	name = name:gsub("\n", ", ")
	s.name:SetText(name)
	local r, g, b = SL:QualityColor(s.quality)
	if data.locked then
		s.name:SetTextColor(1, 0.25, 0.25)
	else
		s.name:SetTextColor(r, g, b)
	end
	s.icon:SetTexture(data.texture)
	s.icon:SetDesaturated(data.locked and true or false)
	if SL.db.loot.showCount and (data.count or 0) > 1 then
		s.count:SetText(data.count)
		s.count:Show()
	else
		s.count:Hide()
	end
	if s.quality >= 2 then
		s.iconFrame:SetBackdropBorderColor(r, g, b, 1)
	else
		s.iconFrame:SetBackdropBorderColor(SL:PlainBorderColor())
	end
	if SL.db.loot.qualityGlow and s.quality >= 2 then
		s.glow:SetGradientAlpha("HORIZONTAL", r, g, b, 0.28, r, g, b, 0)
		s.glow:Show()
	else
		s.glow:Hide()
	end
	s:Enable()
	s:Show()
	return s
end

function Loot:HideSlots()
	for _, s in pairs(slots) do s:Hide() end
end

function Loot:Position(atCursor)
	if atCursor then
		local x, y = GetCursorPosition()
		local scale = frame:GetEffectiveScale()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 30, y / scale + 20)
	else
		SL:LoadPosition(frame, SL.db.loot.point)
	end
end

function Loot:UpdateLayout()
	if not frame then return end
	frame:SetScale(SL.db.loot.scale)
	for _, s in pairs(slots) do
		self:LayoutSlot(s)
	end
	self:Layout()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function Loot:LOOT_OPENED(autoLoot)
	if SL.testMode then SL:ToggleTestMode(false) end
	frame.testing = nil
	self:HideSlots()

	if IsFishingLoot() then
		frame.title:SetText("Fishing")
	elseif UnitExists("target") and UnitIsDead("target") then
		frame.title:SetText(UnitName("target"))
	else
		frame.title:SetText(LOOT or "Loot")
	end

	local num = GetNumLootItems()
	if num > 0 then
		for i = 1, num do
			local texture, item, quantity, quality, locked = GetLootSlotInfo(i)
			if texture then
				self:FillSlot(i, { texture = texture, name = item, count = quantity, quality = quality, locked = locked })
			end
		end
	else
		local s = self:FillSlot(1, { texture = "Interface\\Icons\\INV_Misc_Bag_08", name = "Nothing to loot", quality = 0 })
		s:Disable()
	end

	self:Position(SL.db.loot.underMouse or GetCVar("lootUnderMouse") == "1")
	frame:Show()
	self:Layout()
	if not frame:IsShown() then
		CloseLoot(autoLoot == 0)
	end
end

function Loot:LOOT_SLOT_CLEARED(slot)
	if not frame:IsShown() or frame.testing then return end
	if slots[slot] then slots[slot]:Hide() end
	self:Layout()
end

function Loot:LOOT_CLOSED()
	StaticPopup_Hide("LOOT_BIND")
	if frame.testing then return end
	frame:Hide()
	self:HideSlots()
end

function Loot:OPEN_MASTER_LOOT_LIST()
	ToggleDropDownMenu(1, nil, GroupLootDropDown, self.selectedButton or frame, 0, 0)
end

function Loot:UPDATE_MASTER_LOOT_LIST()
	UIDropDownMenu_Refresh(GroupLootDropDown)
end

-- ElvUI replaces the master loot functions with versions that only work
-- with its own window; put Blizzard's behaviour back.
function Loot:FixMasterLoot()
	if not SL.db.loot.enabled then return end
	_G.GroupLootDropDown_GiveLoot = function(self)
		local q = LootFrame.selectedQuality or 0
		if q >= MASTER_LOOT_THREHOLD then
			local color = ITEM_QUALITY_COLORS[q]
			local dialog = StaticPopup_Show("CONFIRM_LOOT_DISTRIBUTION", (color and color.hex or "") .. (LootFrame.selectedItemName or "") .. FONT_COLOR_CODE_CLOSE, self:GetText())
			if dialog then dialog.data = self.value end
		else
			GiveMasterLoot(LootFrame.selectedSlot, self.value)
		end
		CloseDropDownMenus()
	end
	if StaticPopupDialogs and StaticPopupDialogs.CONFIRM_LOOT_DISTRIBUTION then
		StaticPopupDialogs.CONFIRM_LOOT_DISTRIBUTION.OnAccept = function(_, data)
			GiveMasterLoot(LootFrame.selectedSlot, data)
		end
	end
end

-- Test mode
function Loot:ShowTest(items)
	self:HideSlots()
	frame.title:SetText("SmartLoot Test")
	for i, data in ipairs(items) do
		local s = self:FillSlot(i, data)
		s.test = data
	end
	frame.testing = true
	self:Position(false)
	frame:Show()
	self:Layout()
end

function Loot:HideTest()
	if frame and frame.testing then
		frame:Hide()
		frame.testing = nil
		self:HideSlots()
	end
end

function Loot:Init()
	CreateMainFrame()
	frame:SetScale(SL.db.loot.scale)
	if not SL.db.loot.enabled then return end

	LootFrame:UnregisterAllEvents()
	local events = { "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "OPEN_MASTER_LOOT_LIST", "UPDATE_MASTER_LOOT_LIST" }
	for _, ev in ipairs(events) do
		SL:On(ev, function(event, ...) Loot[event](Loot, ...) end)
	end
	self:FixMasterLoot()
end
