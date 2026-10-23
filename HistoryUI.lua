-- SmartLoot by feralpaw
-- Loot history window (/loot)

local _, ns = ...
local SL = ns.SL

local UI = {}
SL.HistoryUI = UI

local WIDTH, HEIGHT = 760, 470
local HEADER = 22
local LEFT_W = 210
local SROW_H, SROWS = 34, 10
local IROW_H, IROWS = 22, 14

local frame, sessionScroll, itemScroll
local sessionRows, itemRows = {}, {}

local function History() return SL.History end

-- newest first
local function SessionList()
	local list, out = SL.hdb.sessions, {}
	for i = #list, 1, -1 do out[#out + 1] = list[i] end
	return out
end

local function FormatDate(t, withDay)
	if not t then return "" end
	return date(withDay and "%d.%m.%Y %H:%M" or "%H:%M", t)
end

---------------------------------------------------------------------------
-- Flat button
---------------------------------------------------------------------------
local function ClassicButton(parent, text, width)
	-- Design 1: flat button that lights up in the theme colour
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width)
	b:SetHeight(20)
	SL:Border(b, 0, 0, 0, 0.5)
	b.text = SL:Text(b, "OVERLAY", -1)
	b.text:SetPoint("CENTER")
	b.text:SetText(text)
	b:SetScript("OnEnter", function(self)
		local c = SL:GetTheme().accent
		self:SetBackdropBorderColor(c[1], c[2], c[3], 1)
		self.text:SetTextColor(c[1], c[2], c[3])
		if self.tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(0, 0, 0, 1)
		self.text:SetTextColor(1, 1, 1)
		GameTooltip:Hide()
	end)
	return b
end

local function FlatButton(parent, text, width)
	if SL:IsClassic() then return ClassicButton(parent, text, width) end
	-- Design 2: standard red Blizzard button (as in the AH addon)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetWidth(width)
	b:SetHeight(22)
	b:SetText(text)
	b:HookScript("OnEnter", function(self)
		if self.tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:HookScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end
UI.FlatButton = FlatButton

---------------------------------------------------------------------------
-- Session list (left)
---------------------------------------------------------------------------
local function SessionRowOnClick(self)
	UI.selected = self.session
	UI:Refresh()
end

local function CreateSessionRow(parent, i)
	local r = CreateFrame("Button", nil, parent)
	r:SetHeight(SROW_H - 2)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * SROW_H)
	r:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	r.sel = r:CreateTexture(nil, "BACKGROUND")
	r.sel:SetAllPoints()
	r.sel:SetTexture(1, 1, 1, 1)
	SL:Accent(r.sel, "texture", 0.16)
	r.hl = r:CreateTexture(nil, "HIGHLIGHT")
	r.hl:SetAllPoints()
	r.hl:SetTexture(1, 1, 1, 0.06)
	r.title = SL:Text(r, "OVERLAY", 0, "LEFT")
	r.title:SetPoint("TOPLEFT", 6, -3)
	r.title:SetPoint("RIGHT", -4, 0)
	r.sub = SL:Text(r, "OVERLAY", -2, "LEFT")
	r.sub:SetPoint("BOTTOMLEFT", 6, 4)
	r.sub:SetPoint("RIGHT", -4, 0)
	r.sub:SetTextColor(0.65, 0.65, 0.65)
	r:SetScript("OnClick", SessionRowOnClick)
	return r
end

function UI:UpdateSessions()
	local list = SessionList()
	FauxScrollFrame_Update(sessionScroll, #list, SROWS, SROW_H)
	local offset = FauxScrollFrame_GetOffset(sessionScroll)
	for i = 1, SROWS do
		local row = sessionRows[i]
		local s = list[offset + i]
		if s then
			row.session = s
			row.title:SetText(s.instance or "?")
			local sub = (s.difficulty or "") .. "  -  " .. FormatDate(s.start, true) .. "  -  " .. #(s.items or {}) .. " items"
			if s.char and s.char ~= SL.playerName then
				sub = sub .. "  (" .. s.char .. ")"
			end
			row.sub:SetText(sub)
			if s == self.selected then
				row.sel:Show()
				local c = SL:GetTheme().accent
				row.title:SetTextColor(c[1], c[2], c[3])
			else
				row.sel:Hide()
				row.title:SetTextColor(1, 1, 1)
			end
			row:Show()
		else
			row:Hide()
		end
	end
end

---------------------------------------------------------------------------
-- Item list (right)
---------------------------------------------------------------------------
local function ItemRowOnEnter(self)
	local e = self.entry
	if not e then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(e.link)
	local names = {}
	for name in pairs(e.rolls or {}) do names[#names + 1] = name end
	if #names > 0 then
		table.sort(names, function(a, b)
			local ra, rb = e.rolls[a], e.rolls[b]
			local ta, tb = (ra.t == 0) and 9 or (ra.t or 9), (rb.t == 0) and 9 or (rb.t or 9)
			if ta ~= tb then return ta < tb end
			return (ra.n or 0) > (rb.n or 0)
		end)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Rolls:", 1, 0.82, 0)
		local H = History()
		for _, name in ipairs(names) do
			local r = e.rolls[name]
			local cr, cg, cb = SL:ClassColor(r.c)
			local right = (H.TYPE_COLORS[r.t] or "") .. (H.TYPE_NAMES[r.t] or "?") .. (r.n and (" " .. r.n) or "") .. "|r"
			if name == e.winner then
				right = right .. "  |cffffd100(winner)|r"
			end
			GameTooltip:AddDoubleLine(name, right, cr, cg, cb)
		end
	end
	GameTooltip:Show()
end

local function ItemRowOnLeave()
	GameTooltip:Hide()
end

local function ItemRowOnClick(self)
	local e = self.entry
	if e and IsModifiedClick() then
		HandleModifiedItemClick(e.link)
	end
end

local function CreateItemRow(parent, i)
	local r = CreateFrame("Button", nil, parent)
	r:SetHeight(IROW_H - 1)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * IROW_H)
	r:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	r.stripe = r:CreateTexture(nil, "BACKGROUND")
	r.stripe:SetAllPoints()
	r.stripe:SetTexture(1, 1, 1, 1)
	r.hl = r:CreateTexture(nil, "HIGHLIGHT")
	r.hl:SetAllPoints()
	r.hl:SetTexture(1, 1, 1, 0.07)

	r.iconFrame = CreateFrame("Frame", nil, r)
	r.iconFrame:SetWidth(IROW_H - 3)
	r.iconFrame:SetHeight(IROW_H - 3)
	r.iconFrame:SetPoint("LEFT", 2, 0)
	SL:Border(r.iconFrame)
	r.icon = r.iconFrame:CreateTexture(nil, "ARTWORK")
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	SL:Inside(r.icon, r.iconFrame, 1)

	r.item = SL:Text(r, "OVERLAY", -1, "LEFT")
	r.item:SetPoint("LEFT", r.iconFrame, "RIGHT", 6, 0)
	r.item:SetWidth(190)
	r.item:SetHeight(IROW_H)
	r.winner = SL:Text(r, "OVERLAY", -1, "LEFT")
	r.winner:SetPoint("LEFT", r.item, "RIGHT", 6, 0)
	r.winner:SetWidth(100)
	r.result = SL:Text(r, "OVERLAY", -1, "LEFT")
	r.result:SetPoint("LEFT", r.winner, "RIGHT", 4, 0)
	r.result:SetWidth(92)
	r.rolls = SL:Text(r, "OVERLAY", -2, "CENTER")
	r.rolls:SetPoint("LEFT", r.result, "RIGHT", 2, 0)
	r.rolls:SetWidth(40)
	r.rolls:SetTextColor(0.7, 0.7, 0.7)
	r.time = SL:Text(r, "OVERLAY", -2, "RIGHT")
	r.time:SetPoint("RIGHT", r, "RIGHT", -4, 0)
	r.time:SetTextColor(0.7, 0.7, 0.7)

	r:SetScript("OnEnter", ItemRowOnEnter)
	r:SetScript("OnLeave", ItemRowOnLeave)
	r:SetScript("OnClick", ItemRowOnClick)
	return r
end

function UI:UpdateItems()
	local s = self.selected
	local items = s and s.items or {}
	local n = #items
	FauxScrollFrame_Update(itemScroll, n, IROWS, IROW_H)
	local offset = FauxScrollFrame_GetOffset(itemScroll)
	local H = History()
	for i = 1, IROWS do
		local row = itemRows[i]
		-- newest item on top
		local e = items[n - (offset + i) + 1]
		if e then
			row.entry = e
			local name, _, _, _, _, _, _, _, _, tex = GetItemInfo(e.link)
			row.icon:SetTexture(tex or (GetItemIcon and GetItemIcon(e.link)) or "Interface\\Icons\\INV_Misc_QuestionMark")
			local count = (e.count or 1) > 1 and (" x" .. e.count) or ""
			row.item:SetText(e.link .. count)
			local r, g, b = SL:QualityColor(e.quality)
			row.iconFrame:SetBackdropBorderColor(r, g, b, 1)
			row.stripe:SetGradientAlpha("HORIZONTAL", r, g, b, 0.14, r, g, b, 0)
			if e.winner then
				row.winner:SetText(SL:ClassColoredName(e.winner, e.winnerClass))
			else
				row.winner:SetText("|cff777777-|r")
			end
			row.result:SetText(H:ResultText(e))
			local c = 0
			for _ in pairs(e.rolls or {}) do c = c + 1 end
			row.rolls:SetText(c > 0 and (c .. " rolls") or "")
			row.time:SetText(FormatDate(e.time))
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end
	frame.empty:SetShown(n == 0)
end

function UI:UpdateInfo()
	local s = self.selected
	if not s then
		frame.infoTitle:SetText("No loot recorded yet")
		frame.infoSub:SetText("Rolls and loot in raids" .. (SL.db.history.trackDungeons and " and dungeons" or "") .. " are recorded automatically.")
		return
	end
	frame.infoTitle:SetText(s.instance .. "  |cffaaaaaa" .. (s.difficulty or "") .. "|r")
	local players = 0
	for _ in pairs(s.players or {}) do players = players + 1 end
	local won = 0
	for _, e in ipairs(s.items or {}) do if e.winner then won = won + 1 end end
	frame.infoSub:SetText(string.format("%s - %s   |   %d items, %d with a winner   |   %d players   |   %s",
		FormatDate(s.start, true), FormatDate(s.last), #(s.items or {}), won, players, s.char or "?"))
end

function UI:Refresh()
	if not frame or not frame:IsShown() then return end
	local list = SL.hdb.sessions
	-- keep the selection valid
	local valid = false
	for _, s in ipairs(list) do if s == self.selected then valid = true break end end
	if not valid then self.selected = list[#list] end
	self:UpdateSessions()
	self:UpdateItems()
	self:UpdateInfo()
end

function UI:OnNewSession(s)
	if not frame or not frame:IsShown() then
		self.selected = s
	end
end

---------------------------------------------------------------------------
-- Report to chat
---------------------------------------------------------------------------
function UI:Report()
	local s = self.selected
	if not s then return end
	local channel
	if GetNumRaidMembers() > 0 then channel = "RAID" elseif GetNumPartyMembers() > 0 then channel = "PARTY" end
	local lines = {}
	lines[1] = "SmartLoot - " .. s.instance .. " " .. (s.difficulty or "") .. ":"
	local H = History()
	for _, e in ipairs(s.items or {}) do
		if e.winner then
			local res = ""
			if e.winType then
				res = " (" .. (H.TYPE_NAMES[e.winType] or "") .. (e.winRoll and (" " .. e.winRoll) or "") .. ")"
			elseif e.source == "master" then
				res = " (Master Loot)"
			end
			lines[#lines + 1] = e.link .. " - " .. e.winner .. res
		end
		if #lines >= 26 then break end
	end
	if #lines == 1 then
		SL:Print("Nothing to report in this session.")
		return
	end
	for _, line in ipairs(lines) do
		if channel then
			SendChatMessage(line, channel)
		else
			DEFAULT_CHAT_FRAME:AddMessage(line)
		end
	end
end

StaticPopupDialogs["SMARTLOOT_CLEAR_HISTORY"] = {
	text = "Delete the complete SmartLoot loot history?",
	button1 = YES or "Yes",
	button2 = NO or "No",
	OnAccept = function() SL.History:ClearAll() end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}
StaticPopupDialogs["SMARTLOOT_DELETE_SESSION"] = {
	text = "Delete the loot of %s?",
	button1 = YES or "Yes",
	button2 = NO or "No",
	OnAccept = function() if UI.selected then SL.History:Delete(UI.selected) end end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function CreateWindow()
	frame = CreateFrame("Frame", "SmartLootHistoryFrame", UIParent)
	frame:SetWidth(WIDTH)
	frame:SetHeight(HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:Hide()
	SL:Skin(frame)
	UI.frame = frame
	tinsert(UISpecialFrames, "SmartLootHistoryFrame")

	-- header
	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", 4, -4)
	header:SetPoint("TOPRIGHT", -4, -4)
	header:SetHeight(HEADER)
	SL:MakeDraggable(header, frame, SL.db.history.point)
	if SL:IsClassic() then
		-- Design 1: coloured header band, title on the left, small x
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", 1, -1)
		header:SetPoint("TOPRIGHT", -1, -1)
		local hbg = header:CreateTexture(nil, "BORDER")
		hbg:SetAllPoints()
		hbg:SetTexture(1, 1, 1, 1)
		hbg:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.25, 1, 1, 1, 0.02)
		SL:Accent(hbg, "texture", 1)
		local line = header:CreateTexture(nil, "ARTWORK")
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT")
		line:SetPoint("BOTTOMRIGHT")
		line:SetTexture(1, 1, 1, 1)
		SL:Accent(line, "texture", 0.6)
		local title = SL:Text(header, "OVERLAY", 1, "LEFT")
		title:SetPoint("LEFT", 8, 0)
		title:SetText("SmartLoot  -  Loot History")
		SL:Accent(title, "text")
		local by = SL:Text(header, "OVERLAY", -2, "LEFT")
		by:SetPoint("LEFT", title, "RIGHT", 8, -1)
		by:SetText("by feralpaw")
		by:SetTextColor(0.6, 0.6, 0.6)
		local close = CreateFrame("Button", nil, header)
		close:SetWidth(18)
		close:SetHeight(18)
		close:SetPoint("RIGHT", -3, 0)
		close.text = SL:Text(close, "OVERLAY", 2)
		close.text:SetPoint("CENTER", 1, 0)
		close.text:SetText("x")
		close:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.3, 0.3) end)
		close:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 1, 1) end)
		close:SetScript("OnClick", function() frame:Hide() end)
	else
		local title = SL:Text(header, "OVERLAY", 2, "CENTER")
		title:SetPoint("CENTER", header, "CENTER", 0, -1)
		title:SetText("SmartLoot - Loot History")
		SL:Accent(title, "text")
		local by = SL:Text(header, "OVERLAY", -2, "LEFT")
		by:SetPoint("LEFT", header, "LEFT", 8, -1)
		by:SetText("by feralpaw")
		by:SetTextColor(0.6, 0.6, 0.6)
		local lineL, lineR = SL:FadeLine(header, 1)
		lineL:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 6, 0)
		lineL:SetPoint("BOTTOMRIGHT", header, "BOTTOM", 0, 0)
		lineR:SetPoint("BOTTOMLEFT", header, "BOTTOM", 0, 0)
		lineR:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -6, 0)
		local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
		close:SetScript("OnClick", function() frame:Hide() end)
	end

	-- left pane: sessions
	local left = CreateFrame("Frame", nil, frame)
	left:SetPoint("TOPLEFT", 10, -(HEADER + 10))
	left:SetWidth(LEFT_W)
	left:SetHeight(SROWS * SROW_H + 8)
	if SL:IsClassic() then SL:Border(left, 0, 0, 0, 0.35) else SL:Skin(left, true) end
	local leftInner = CreateFrame("Frame", nil, left)
	leftInner:SetPoint("TOPLEFT", 2, -2)
	leftInner:SetPoint("BOTTOMRIGHT", -2, 2)
	for i = 1, SROWS do sessionRows[i] = CreateSessionRow(leftInner, i) end
	sessionScroll = CreateFrame("ScrollFrame", "SmartLootHistorySessionScroll", left, "FauxScrollFrameTemplate")
	sessionScroll:SetPoint("TOPLEFT", 0, -20)
	sessionScroll:SetPoint("BOTTOMRIGHT", -26, 20)
	sessionScroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, SROW_H, function() UI:UpdateSessions() end)
	end)
	-- rows above the scroll frame so they can be clicked
	leftInner:SetFrameLevel(sessionScroll:GetFrameLevel() + 2)
	leftInner:EnableMouseWheel(true)
	leftInner:SetScript("OnMouseWheel", function(_, delta)
		local bar = _G["SmartLootHistorySessionScrollScrollBar"]
		if bar then bar:SetValue(bar:GetValue() - delta * SROW_H) end
	end)
	leftInner:ClearAllPoints()
	leftInner:SetPoint("TOPLEFT", 4, -4)
	leftInner:SetPoint("BOTTOMRIGHT", -24, 4)

	-- right pane: info + items
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 38)
	if SL:IsClassic() then SL:Border(right, 0, 0, 0, 0.35) else SL:Skin(right, true) end

	local info = CreateFrame("Frame", nil, right)
	info:SetPoint("TOPLEFT", 8, -6)
	info:SetPoint("TOPRIGHT", -8, -6)
	info:SetHeight(36)
	info:EnableMouse(true)
	info:SetScript("OnEnter", function(self)
		local s = UI.selected
		if not s or not s.players then return end
		local names = {}
		for name in pairs(s.players) do names[#names + 1] = name end
		table.sort(names)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Players (" .. #names .. ")", 1, 0.82, 0)
		for i = 1, #names, 2 do
			local a, b = names[i], names[i + 1]
			local ar, ag, ab = SL:ClassColor(s.players[a])
			if b then
				local br, bg, bb = SL:ClassColor(s.players[b])
				GameTooltip:AddDoubleLine(a, b, ar, ag, ab, br, bg, bb)
			else
				GameTooltip:AddLine(a, ar, ag, ab)
			end
		end
		GameTooltip:Show()
	end)
	info:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame.infoTitle = SL:Text(info, "OVERLAY", 2, "LEFT")
	frame.infoTitle:SetPoint("TOPLEFT", 2, -2)
	SL:Accent(frame.infoTitle, "text")
	frame.infoSub = SL:Text(info, "OVERLAY", -2, "LEFT")
	frame.infoSub:SetPoint("BOTTOMLEFT", 2, 2)
	frame.infoSub:SetTextColor(0.75, 0.75, 0.75)

	-- column titles
	local cols = CreateFrame("Frame", nil, right)
	cols:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -2)
	cols:SetPoint("TOPRIGHT", info, "BOTTOMRIGHT", -20, -2)
	cols:SetHeight(16)
	local function Col(text, x, w, justify)
		local fs = SL:Text(cols, "OVERLAY", -2, justify or "LEFT")
		fs:SetPoint("LEFT", x, 0)
		if w then fs:SetWidth(w) end
		fs:SetText(text)
		SL:Accent(fs, "text")
		return fs
	end
	Col("Item", 27, 190)
	Col("Winner", 223, 100)
	Col("Result", 327, 92)
	Col("Rolls", 421, 40, "CENTER")
	local tcol = SL:Text(cols, "OVERLAY", -2, "RIGHT")
	tcol:SetPoint("RIGHT", -4, 0)
	tcol:SetText("Time")
	SL:Accent(tcol, "text")
	local sep = cols:CreateTexture(nil, "ARTWORK")
	sep:SetHeight(1)
	sep:SetPoint("BOTTOMLEFT")
	sep:SetPoint("BOTTOMRIGHT", 20, 0)
	sep:SetTexture(1, 1, 1, 0.15)

	local list = CreateFrame("Frame", nil, right)
	list:SetPoint("TOPLEFT", cols, "BOTTOMLEFT", 0, -3)
	list:SetPoint("RIGHT", cols, "RIGHT", 0, 0)
	list:SetHeight(IROWS * IROW_H)
	for i = 1, IROWS do itemRows[i] = CreateItemRow(list, i) end
	itemScroll = CreateFrame("ScrollFrame", "SmartLootHistoryItemScroll", right, "FauxScrollFrameTemplate")
	itemScroll:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
	itemScroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
	itemScroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, IROW_H, function() UI:UpdateItems() end)
	end)
	list:SetFrameLevel(itemScroll:GetFrameLevel() + 2)
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		local bar = _G["SmartLootHistoryItemScrollScrollBar"]
		if bar then bar:SetValue(bar:GetValue() - delta * IROW_H) end
	end)

	frame.empty = SL:Text(right, "OVERLAY", 0)
	frame.empty:SetPoint("CENTER", list, "CENTER")
	frame.empty:SetText("No items in this session.")
	frame.empty:SetTextColor(0.6, 0.6, 0.6)
	if not frame.empty.SetShown then
		frame.empty.SetShown = function(self, show) if show then self:Show() else self:Hide() end end
	end

	-- bottom buttons
	local newB = FlatButton(frame, "New Session", 96)
	newB:SetPoint("BOTTOMLEFT", 10, 10)
	newB.tip = "Start a new session for the current instance (e.g. a second run on another ID)."
	newB:SetScript("OnClick", function() SL.History:StartNewSession() end)

	local report = FlatButton(frame, "Report Winners", 106)
	report:SetPoint("LEFT", newB, "RIGHT", 6, 0)
	report.tip = "Post the winners of the selected session to raid / party chat (or only to you when you are alone)."
	report:SetScript("OnClick", function() UI:Report() end)

	local del = FlatButton(frame, "Delete Session", 100)
	del:SetPoint("LEFT", report, "RIGHT", 6, 0)
	del:SetScript("OnClick", function()
		if UI.selected then StaticPopup_Show("SMARTLOOT_DELETE_SESSION", UI.selected.instance) end
	end)

	local clear = FlatButton(frame, "Clear All", 80)
	clear:SetPoint("LEFT", del, "RIGHT", 6, 0)
	clear:SetScript("OnClick", function() StaticPopup_Show("SMARTLOOT_CLEAR_HISTORY") end)

	local opt = FlatButton(frame, "Options", 80)
	opt:SetPoint("BOTTOMRIGHT", -10, 10)
	opt:SetScript("OnClick", function() if SL.Options then SL.Options:Open() end end)

	local hint = SL:Text(frame, "OVERLAY", -2, "RIGHT")
	hint:SetPoint("RIGHT", opt, "LEFT", -8, 0)
	hint:SetText("Shift-click an item to link it")
	hint:SetTextColor(0.55, 0.55, 0.55)

	frame:SetScript("OnShow", function() UI:Refresh() end)
end

function UI:UpdateLayout()
	if not frame then return end
	frame:SetScale(SL.db.history.scale or 1)
	self:Refresh()
end

function UI:Toggle()
	if not frame then
		-- the window and its lists are only created on the first /loot
		SL.History:CloseStale()
		CreateWindow()
		SL:LoadPosition(frame, SL.db.history.point)
		frame:SetScale(SL.db.history.scale or 1)
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

function UI:Open()
	if not frame or not frame:IsShown() then self:Toggle() end
end

SLASH_SMARTLOOTHISTORY1 = "/loot"
SLASH_SMARTLOOTHISTORY2 = "/lootlog"
SlashCmdList.SMARTLOOTHISTORY = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "new" then
		SL.History:StartNewSession()
	elseif msg == "debug" then
		SL.debug = not SL.debug
		SL:Print("Loot debug " .. (SL.debug and "|cff33ff33on|r - every loot chat line is shown with how SmartLoot read it." or "|cffff3333off|r."))
	else
		UI:Toggle()
	end
end
