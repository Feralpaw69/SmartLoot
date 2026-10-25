-- SmartLoot by feralpaw
-- Test mode: shows a sample loot window and sample roll bars so the
-- look can be checked and the frames can be moved.

local _, ns = ...
local SL = ns.SL

local GetTime = GetTime

-- id, fallback name, quality, ilvl, count, bind on pickup, can disenchant, fallback icon
local TEST_ITEMS = {
	{ 50363, "Deathbringer's Will", 4, 264, 1, true, true, "Interface\\Icons\\INV_Misc_Gem_01" },
	{ 49623, "Shadowmourne", 5, 284, 1, true, false, "Interface\\Icons\\INV_Axe_09" },
	{ 52027, "Conqueror's Mark of Sanctification", 4, 80, 1, true, false, "Interface\\Icons\\INV_Misc_Bag_08" },
	{ 49908, "Primordial Saronite", 4, 80, 1, false, false, "Interface\\Icons\\INV_Misc_Gem_01" },
	{ 34057, "Abyss Crystal", 4, 80, 2, false, false, "Interface\\Icons\\INV_Misc_Gem_01" },
	{ 33470, "Frostweave Cloth", 1, 80, 7, false, false, "Interface\\Icons\\INV_Misc_Bag_08" },
}

local function ItemData(def)
	local name, link, quality, ilvl, _, _, _, _, _, tex = GetItemInfo(def[1])
	if not tex and GetItemIcon then tex = GetItemIcon(def[1]) end
	return {
		name = name or def[2],
		link = link,
		quality = quality or def[3],
		ilvl = ilvl or def[4],
		count = def[5],
		bop = def[6],
		canDE = def[7],
		texture = tex or def[8],
	}
end

local ticker = CreateFrame("Frame")
ticker:Hide()
local FAKE_PLAYERS = { "Arthas", "Jaina", "Thrall", "Uther", "Sylvanas", "Garrosh", "Valeera", "Malfurion", "Tyrande", "Velen" }
local FAKE_CLASSES = { "DEATHKNIGHT", "MAGE", "SHAMAN", "PALADIN", "HUNTER", "WARRIOR", "ROGUE", "DRUID", "PRIEST", "PRIEST" }

-- every second a fake raid member picks need/greed/de/pass on a random bar
ticker:SetScript("OnUpdate", function(self, elapsed)
	self.t = (self.t or 0) + elapsed
	if self.t < 1.1 then return end
	self.t = 0
	local bars = {}
	for _, bar in ipairs(SL.Roll.bars) do
		if bar.test then bars[#bars + 1] = bar end
	end
	if #bars == 0 then return end
	local bar = bars[math.random(#bars)]
	local i = math.random(#FAKE_PLAYERS)
	local name = FAKE_PLAYERS[i]
	if bar.results[name] then
		-- everybody chose: start over on this bar
		local n = 0
		for _ in pairs(bar.results) do n = n + 1 end
		if n >= #FAKE_PLAYERS then
			wipe(bar.results)
			for _, b in pairs(bar.buttons) do b.count:SetText("") end
		end
		return
	end
	local choices = { 1, 2, 2, 0, 0 }
	if bar.buttons[3]:IsEnabled() == 1 then choices[#choices + 1] = 3 end
	if bar.buttons[1]:IsEnabled() ~= 1 then choices[1] = 2 end
	SL.Roll:AddResult(bar, name, choices[math.random(#choices)], FAKE_CLASSES[i])
end)

function SL:ToggleTestMode(force)
	local on
	if force == nil then on = not self.testMode else on = force end
	if on == (self.testMode and true or false) then return end
	self.testMode = on

	if on then
		-- loot window
		local items = {}
		items[1] = { texture = "Interface\\Icons\\INV_Misc_Coin_01", name = "12 Gold\n47 Silver\n3 Copper", quality = 0, count = 0 }
		for i = 1, #TEST_ITEMS do
			local d = ItemData(TEST_ITEMS[i])
			items[#items + 1] = d
		end
		if self.Loot and self.Loot.frame then self.Loot:ShowTest(items) end

		-- roll bars
		if self.Roll and self.Roll.anchor then
			self.Roll:ShowAnchor(true)
			for i = 1, 4 do
				local d = ItemData(TEST_ITEMS[i])
				d.canNeed = (i ~= 4)
				d.reasonNeed = (i == 4) and 1 or nil
				d.canGreed = true
				d.reasonDE = (not d.canDE) and 4 or nil
				d.deSkill = nil
				local bar = self.Roll:GetBar()
				bar.test = true
				bar.testEnd = GetTime() + 20 + i * 8
				self.Roll:Setup(bar, -i, (20 + i * 8) * 1000, d)
				bar.test = true
			end
			ticker:Show()
		end
		self:Print("Test mode |cff33ff33on|r - drag the loot window and the roll bars to move them. Type /smartloot test again to stop.")
	else
		ticker:Hide()
		if self.Loot then self.Loot:HideTest() end
		if self.Roll and self.Roll.anchor then
			self.Roll:ShowAnchor(false)
			for _, bar in ipairs(self.Roll.bars) do
				if bar.test then self.Roll:Release(bar) end
			end
			self.Roll:Reposition()
		end
		self:Print("Test mode |cffff3333off|r.")
	end
	if self.Options and self.Options.RefreshTestButton then self.Options:RefreshTestButton() end
end
