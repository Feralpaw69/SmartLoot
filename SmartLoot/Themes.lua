-- SmartLoot by feralpaw
-- Colour themes: the backgrounds of AuctionatorModern plus five more.
-- top/bottom: background gradient, border: frame line, accent: titles and highlights

local _, ns = ...
local SL = ns.SL

SL.themes = {
	-- from AuctionatorModern (same order and names)
	{ key = "black",    name = "Black (default)", top = { 0.10, 0.10, 0.11 }, bottom = { 0.02, 0.02, 0.02 }, border = { 0.30, 0.30, 0.32 }, accent = { 0.92, 0.96, 1.00 } },
	{ key = "midnight", name = "Midnight Blue", top = { 0.05, 0.12, 0.30 }, bottom = { 0.01, 0.02, 0.07 }, border = { 0.35, 0.55, 1.00 }, accent = { 0.35, 0.60, 1.00 } },
	{ key = "crimson",  name = "Crimson Gold",  top = { 0.30, 0.05, 0.03 }, bottom = { 0.07, 0.01, 0.01 }, border = { 1.00, 0.78, 0.20 }, accent = { 1.00, 0.30, 0.25 } },
	{ key = "emerald",  name = "Emerald",       top = { 0.03, 0.22, 0.14 }, bottom = { 0.01, 0.05, 0.03 }, border = { 0.30, 0.90, 0.60 }, accent = { 0.30, 1.00, 0.50 } },
}

-- five more, added after the class colours
local EXTRA = {
	{ key = "purple",   name = "Royal Purple",  top = { 0.20, 0.06, 0.32 }, bottom = { 0.04, 0.01, 0.07 }, border = { 0.73, 0.45, 1.00 }, accent = { 0.80, 0.52, 1.00 } },
	{ key = "frost",    name = "Frost",         top = { 0.06, 0.22, 0.30 }, bottom = { 0.01, 0.05, 0.07 }, border = { 0.55, 0.90, 1.00 }, accent = { 0.62, 0.95, 1.00 } },
	{ key = "amber",    name = "Amber",         top = { 0.30, 0.17, 0.02 }, bottom = { 0.07, 0.04, 0.00 }, border = { 1.00, 0.65, 0.15 }, accent = { 1.00, 0.72, 0.22 } },
	{ key = "rose",     name = "Rose",          top = { 0.30, 0.05, 0.18 }, bottom = { 0.07, 0.01, 0.04 }, border = { 1.00, 0.45, 0.70 }, accent = { 1.00, 0.52, 0.76 } },
	{ key = "steel",    name = "Steel",         top = { 0.18, 0.20, 0.23 }, bottom = { 0.05, 0.05, 0.06 }, border = { 0.70, 0.75, 0.82 }, accent = { 0.82, 0.87, 0.94 } },
}

-- One theme per class, in the class colour (as in AuctionatorModern)
do
	local CLASSES = {
		{ "DEATHKNIGHT", "Death Knight", 0.77, 0.12, 0.23 },
		{ "DRUID", "Druid", 1.00, 0.49, 0.04 },
		{ "HUNTER", "Hunter", 0.67, 0.83, 0.45 },
		{ "MAGE", "Mage", 0.41, 0.80, 0.94 },
		{ "PALADIN", "Paladin", 0.96, 0.55, 0.73 },
		{ "PRIEST", "Priest", 1.00, 1.00, 1.00 },
		{ "ROGUE", "Rogue", 1.00, 0.96, 0.41 },
		{ "SHAMAN", "Shaman", 0.00, 0.44, 0.87 },
		{ "WARLOCK", "Warlock", 0.58, 0.51, 0.79 },
		{ "WARRIOR", "Warrior", 0.78, 0.61, 0.43 },
	}
	for _, class in ipairs(CLASSES) do
		local token, name, r, g, b = class[1], class[2], class[3], class[4], class[5]
		local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
		if c then r, g, b = c.r, c.g, c.b end
		table.insert(SL.themes, {
			key = "class_" .. token,
			name = name,
			top = { r * 0.32, g * 0.32, b * 0.32 },
			bottom = { r * 0.07, g * 0.07, b * 0.07 },
			border = { r, g, b },
			accent = { r, g, b },
		})
	end
end

for _, t in ipairs(EXTRA) do
	table.insert(SL.themes, t)
end

function SL:GetTheme()
	local key = self.db and self.db.general.theme
	for _, t in ipairs(self.themes) do
		if t.key == key then return t end
	end
	return self.themes[1]
end

function SL:ThemeHex(t)
	local c = t.accent
	return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end
