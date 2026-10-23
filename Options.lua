-- SmartLoot by feralpaw
-- Options in Esc > Interface > AddOns > SmartLoot

local _, ns = ...
local SL = ns.SL

local Options = {}
SL.Options = Options

local widgets = {}
local count = 0
local function NewName()
	count = count + 1
	return "SmartLootOption" .. count
end

local function Changed()
	SL:ApplySettings()
end

StaticPopupDialogs["SMARTLOOT_RELOAD"] = {
	text = "SmartLoot: this change needs a UI reload. Reload now?",
	button1 = ACCEPT or "Accept",
	button2 = CANCEL or "Cancel",
	OnAccept = function() ReloadUI() end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function Header(panel, text, y)
	local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetText(text)
	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
	line:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	line:SetTexture(1, 0.82, 0, 0.25)
	return fs
end

local function Check(panel, x, y, label, tip, get, set, reload)
	local cb = CreateFrame("CheckButton", NewName(), panel, "OptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", x, y)
	_G[cb:GetName() .. "Text"]:SetText(label)
	cb.tooltipText = label
	cb.tooltipRequirement = tip
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		if reload then
			StaticPopup_Show("SMARTLOOT_RELOAD")
		else
			Changed()
		end
	end)
	cb.refresh = function() cb:SetChecked(get() and true or false) end
	widgets[#widgets + 1] = cb
	return cb
end

local function Slider(panel, x, y, label, minV, maxV, step, get, set, fmt)
	local name = NewName()
	local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", x + 4, y)
	s:SetWidth(240)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	_G[name .. "Low"]:SetText(fmt and string.format(fmt, minV) or minV)
	_G[name .. "High"]:SetText(fmt and string.format(fmt, maxV) or maxV)
	local text = _G[name .. "Text"]
	local function Show(v)
		text:SetText(label .. ":  |cffffffff" .. (fmt and string.format(fmt, v) or v) .. "|r")
	end
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		if step < 1 then v = tonumber(string.format("%.2f", v)) end
		Show(v)
		if not self.updating and get() ~= v then
			set(v)
			Changed()
		end
	end)
	s.refresh = function()
		s.updating = true
		s:SetValue(get())
		s.updating = false
		Show(get())
	end
	widgets[#widgets + 1] = s
	return s
end

-- values: function returning { { value, text }, ... }
local function Dropdown(panel, x, y, label, values, get, set, reload)
	local dd = CreateFrame("Frame", NewName(), panel, "UIDropDownMenuTemplate")
	dd:SetPoint("TOPLEFT", x - 12, y - 14)
	UIDropDownMenu_SetWidth(dd, 190)
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	title:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 18, 2)
	title:SetText(label)
	local function TextFor(v)
		for _, opt in ipairs(values()) do
			if opt[1] == v then return opt[2] end
		end
		return tostring(v)
	end
	UIDropDownMenu_Initialize(dd, function(self, level)
		for _, opt in ipairs(values()) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = opt[2]
			info.value = opt[1]
			info.checked = (opt[1] == get())
			info.func = function()
				set(opt[1])
				UIDropDownMenu_SetText(dd, opt[2])
				if reload then StaticPopup_Show("SMARTLOOT_RELOAD") else Changed() end
				if dd.onChange then dd.onChange() end
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)
	dd.refresh = function() UIDropDownMenu_SetText(dd, TextFor(get())) end
	widgets[#widgets + 1] = dd
	return dd
end

local function Button(panel, x, y, text, width, onClick)
	local b = CreateFrame("Button", NewName(), panel, "UIPanelButtonTemplate")
	b:SetPoint("TOPLEFT", x, y)
	b:SetWidth(width or 150)
	b:SetHeight(22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function NewPanel(name, parent)
	local p = CreateFrame("Frame", "SmartLootOptionsPanel" .. name:gsub("%s", ""), UIParent)
	p.name = name
	p.parent = parent
	p:Hide()
	p:SetScript("OnShow", function()
		-- the widgets are only built the first time the page is opened
		if p.build then
			local build = p.build
			p.build = nil
			build()
		end
		for _, w in ipairs(widgets) do
			if w.refresh and w:GetParent() == p then w.refresh() end
		end
		if Options.RefreshTestButton then Options:RefreshTestButton() end
	end)
	InterfaceOptions_AddCategory(p)
	return p
end

local function Title(p, text, sub)
	local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText(text)
	local s = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
	s:SetPoint("RIGHT", p, "RIGHT", -16, 0)
	s:SetJustifyH("LEFT")
	s:SetText(sub)
	return t
end

---------------------------------------------------------------------------
-- Value lists
---------------------------------------------------------------------------
local function ThemeValues()
	local out = {}
	for _, t in ipairs(SL.themes) do
		out[#out + 1] = { t.key, SL:ThemeHex(t) .. t.name .. "|r" }
	end
	return out
end

local function MediaValues(kind)
	return function()
		local out = {}
		for _, n in ipairs(SL:MediaNames(kind)) do out[#out + 1] = { n, n } end
		return out
	end
end

local QUALITY_VALUES = function()
	local out = {}
	for q = 0, 5 do
		local c = ITEM_QUALITY_COLORS[q]
		local name = _G["ITEM_QUALITY" .. q .. "_DESC"] or ("Quality " .. q)
		out[#out + 1] = { q, (c and c.hex or "") .. name .. "|r" .. (q == 0 and "  (everything)" or " and better") }
	end
	return out
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------
function Options:Init()
	local g, l, r, h = SL.db.general, SL.db.loot, SL.db.roll, SL.db.history
	local C1, C2 = 16, 330

	-- General -----------------------------------------------------------
	local main = NewPanel("SmartLoot")
	self.main = main
	main.build = function()
	Title(main, "|cff7fb2ffSmart|rLoot  |cff888888v" .. SL.version .. "|r",
		"Made by |cffff9933feralpaw|r.  A loot window, loot roll bars and a loot history (/loot). Works without ElvUI.")

	Header(main, "Look", -64)
	Dropdown(main, C1, -86, "Design", function()
		return { { 1, "Design 1  (thin bars, original)" }, { 2, "Design 2  (Blizzard frame)" } }
	end, function() return g.design end, function(v) SL:SetDesign(v) end, true)
	Dropdown(main, C2, -86, "Colour theme", ThemeValues,
		function() return g.theme end, function(v) g.theme = v end)
	Dropdown(main, C1, -136, "Frame style", function()
		return { { "blizzard", "Blizzard (silver rounded border)" }, { "pixel", "Pixel (thin flat border)" } }
	end, function() return g.style end, function(v) g.style = v end, true)
	Dropdown(main, C2, -136, "Font", MediaValues("font"),
		function() return g.font end, function(v) g.font = v end)
	Dropdown(main, C1, -186, "Font outline", function()
		return { { "NONE", "None (shadow)" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } }
	end, function() return g.fontOutline end, function(v) g.fontOutline = v end)
	Dropdown(main, C2, -186, "Bar texture", MediaValues("statusbar"),
		function() return g.texture end, function(v) g.texture = v end)
	Slider(main, C1, -252, "Font size", 8, 20, 1,
		function() return g.fontSize end, function(v) g.fontSize = v end)
	Slider(main, C2, -252, "Background opacity", 0.2, 1, 0.05,
		function() return g.bgAlpha end, function(v) g.bgAlpha = v end, "%.2f")
	Check(main, C1, -284, "Border in the theme colour", "Blizzard frame style only: colours the silver border in the theme colour.",
		function() return g.themeBorder end, function(v) g.themeBorder = v end)

	Header(main, "Behaviour", -322)
	Check(main, C1, -340, "Lock frames", "When locked the windows and roll bars can not be dragged.",
		function() return g.locked end, function(v) g.locked = v end)
	Check(main, C2, -340, "Switch off ElvUI's loot frames", "When ElvUI is loaded its own loot window and roll bars are switched off so nothing shows twice.",
		function() return g.takeOverElvUI end, function(v) g.takeOverElvUI = v end, true)

	Header(main, "Tools", -378)
	Options.testButton = Button(main, C1, -398, "Test Mode", 150, function() SL:ToggleTestMode() end)
	Button(main, C1 + 160, -398, "Reset Positions", 150, function() SL:ResetPositions() end)
	Button(main, C1 + 320, -398, "Loot History", 150, function() SL.HistoryUI:Open() end)
	local hint = main:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", C1, -430)
	hint:SetPoint("RIGHT", main, "RIGHT", -16, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Design 1 is the original look, Design 2 the Blizzard look with one frame around all rolls. Switching the design sets its font and sizes and reloads the UI.\n\nTest mode shows a sample loot window and roll bars - drag them to move them.   /smartloot  (test, lock, reset, config)   -   /loot  loot history")
	end

	-- Loot window -------------------------------------------------------
	local lp = NewPanel("Loot Window", "SmartLoot")
	lp.build = function()
	Title(lp, "Loot Window", "The window that opens when you loot a corpse or a chest. Drag it to move it.")
	Check(lp, C1, -60, "Use the SmartLoot loot window", "Replaces the Blizzard loot window.",
		function() return l.enabled end, function(v) l.enabled = v end, true)
	Check(lp, C2, -60, "Open at the mouse cursor", "Otherwise the window opens at its saved position.",
		function() return l.underMouse end, function(v) l.underMouse = v end)
	Check(lp, C1, -90, "Show stack size", nil,
		function() return l.showCount end, function(v) l.showCount = v end)
	Check(lp, C2, -90, "Quality glow behind items", "A soft glow in the item quality colour behind uncommon and better items.",
		function() return l.qualityGlow end, function(v) l.qualityGlow = v end)
	Slider(lp, C1, -140, "Scale", 0.5, 2, 0.05,
		function() return l.scale end, function(v) l.scale = v end, "%.2f")
	Slider(lp, C2, -140, "Minimum width", 150, 400, 5,
		function() return l.width end, function(v) l.width = v end)
	Slider(lp, C1, -190, "Row height", 18, 44, 1,
		function() return l.slotHeight end, function(v) l.slotHeight = v end)
	end

	-- Roll bars ---------------------------------------------------------
	local rp = NewPanel("Roll Bars", "SmartLoot")
	rp.build = function()
	Title(rp, "Roll Bars", "The Need / Greed / Disenchant / Pass bars. Use the test mode to see and move them.")
	Check(rp, C1, -60, "Use the SmartLoot roll bars", "Replaces the Blizzard roll frames.",
		function() return r.enabled end, function(v) r.enabled = v end, true)
	Check(rp, C2, -60, "Grow upwards", "New bars are added above the first one.",
		function() return r.growUp end, function(v) r.growUp = v end)
	Check(rp, C1, -86, "Item name in quality colour", nil,
		function() return r.qualityName end, function(v) r.qualityName = v end)
	Check(rp, C2, -86, "Show item level on the icon", nil,
		function() return r.showItemLevel end, function(v) r.showItemLevel = v end)
	Check(rp, C1, -112, "Show time left", nil,
		function() return r.showTimer end, function(v) r.showTimer = v end)
	Check(rp, C2, -112, "Show how many rolled Need / Greed / ...", "Hover a button to see who chose it.",
		function() return r.showCounts end, function(v) r.showCounts = v end)
	Check(rp, C1, -138, "Auto Greed / Disenchant green BoE items", "Only at max level. Uses Disenchant when possible.",
		function() return r.autoGreed end, function(v) r.autoGreed = v end)
	Dropdown(rp, C2, -142, "Timer colour", function()
		return { { "quality", "Item quality" }, { "theme", "Theme colour" } }
	end, function() return r.barColor end, function(v) r.barColor = v end)
	Slider(rp, C1, -196, "Width", 200, 520, 5,
		function() return r.width end, function(v) r.width = v end)
	Slider(rp, C2, -196, "Height", 16, 52, 1,
		function() return r.height end, function(v) r.height = v end)
	Slider(rp, C1, -246, "Timer bar height", 1, 16, 1,
		function() return r.barHeight end, function(v) r.barHeight = v end)
	Slider(rp, C2, -246, "Spacing (Design 1)", 0, 20, 1,
		function() return r.spacing end, function(v) r.spacing = v end)
	Slider(rp, C1, -296, "Scale", 0.5, 2, 0.05,
		function() return r.scale end, function(v) r.scale = v end, "%.2f")
	Options.testButton2 = Button(rp, C2 + 4, -296, "Test Mode", 150, function() SL:ToggleTestMode() end)
	Check(rp, C1, -340, "Auto pass on |cffa335ee[Reins of the Naxxramas Deathcharger]|r",
		"When this mount drops you pass on it automatically and no roll bar is shown. The pass is written to chat.",
		function() return r.autoPassDeathcharger end, function(v) r.autoPassDeathcharger = v end)
	end

	-- Win animation ------------------------------------------------------
	local wp = NewPanel("Win Animation", "SmartLoot")
	wp.build = function()
	local w = SL.db.win
	Title(wp, "Win Animation", "A gold emblem in the middle of the screen when you win an item you rolled Need on. In the test mode it shows when you press Need.")
	Check(wp, C1, -60, "Show the win animation", "Switch it off to never show the emblem.",
		function() return w.enabled end, function(v) w.enabled = v end)
	Slider(wp, C2, -66, "Size", 0.5, 2, 0.05,
		function() return w.scale end, function(v) w.scale = v end, "%.2f")
	Check(wp, C1, -100, "Play a sound", "One of the sounds below, picked at random each time.",
		function() return w.sound end, function(v) w.sound = v end)
	Check(wp, C1 + 20, -126, "Fanfare", nil,
		function() return w.soundFanfare end, function(v) w.soundFanfare = v end)
	Check(wp, C1 + 20, -152, "\"Nice\"", "The file Interface\\AddOns\\SmartLoot\\Media\\Sounds\\Nice.wav - you can replace it with another .wav (restart the game afterwards).",
		function() return w.soundNice end, function(v) w.soundNice = v end)
	Button(wp, C1 + 230, -128, "Play", 70, function() SL.WinFX:TestSound("soundFanfare") end)
	Button(wp, C1 + 230, -154, "Play", 70, function() SL.WinFX:TestSound("soundNice") end)
	Button(wp, C1, -214, "Preview", 150, function() SL.WinFX:Preview() end)
	end

	-- Loot history ------------------------------------------------------
	local hp = NewPanel("Loot History", "SmartLoot")
	hp.build = function()
	Title(hp, "Loot History", "Records every roll and who won the item, one session per raid or dungeon run. Open it with /loot.")
	Check(hp, C1, -60, "Record loot", nil,
		function() return h.enabled end, function(v) h.enabled = v end)
	Check(hp, C2, -60, "Also record dungeons", "Raids are always recorded.",
		function() return h.trackDungeons end, function(v) h.trackDungeons = v end)
	Check(hp, C1, -86, "Also record outside of instances", "One session per day for loot in the open world.",
		function() return h.trackWorld end, function(v) h.trackWorld = v end)
	Dropdown(hp, C1, -120, "Record items of quality", QUALITY_VALUES,
		function() return h.minQuality end, function(v) h.minQuality = v end)
	Slider(hp, C2, -132, "Keep the last sessions", 10, 200, 5,
		function() return h.maxSessions end, function(v) h.maxSessions = v end)
	Slider(hp, C1, -186, "Window scale", 0.5, 2, 0.05,
		function() return h.scale end, function(v) h.scale = v end, "%.2f")
	Button(hp, C1, -230, "Open Loot History", 150, function() SL.HistoryUI:Open() end)
	Button(hp, C1 + 160, -230, "New Session", 150, function() SL.History:StartNewSession() end)
	Button(hp, C1 + 320, -230, "Add Sample Raid", 150, function()
		SL.History:AddTestSession()
		SL.HistoryUI:Open()
		SL:Print("A sample raid was added to the loot history (you can delete it there).")
	end)
	end
end

function Options:RefreshTestButton()
	local text = SL.testMode and "Stop Test Mode" or "Test Mode"
	if self.testButton then self.testButton:SetText(text) end
	if self.testButton2 then self.testButton2:SetText(text) end
end

function Options:Open()
	if not self.main then return end
	InterfaceOptionsFrame_OpenToCategory(self.main)
	InterfaceOptionsFrame_OpenToCategory(self.main)
end
