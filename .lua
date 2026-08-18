local getcustomasset = getcustomasset or getsynasset
local executor = (identifyexecutor or getexecutorname or function() return "Unknown" end)()
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local scriptSessionStart = os.clock()
local UIS = game:GetService("UserInputService")
local cl = {
	bg = Color3.fromRGB(14, 14, 14),
	topbar = Color3.fromRGB(22, 22, 22),
	card = Color3.fromRGB(22, 22, 22),
	field = Color3.fromRGB(32, 32, 32),
	text = Color3.fromRGB(230, 230, 235),
	dim = Color3.fromRGB(140, 140, 150),
	dark = Color3.fromRGB(80, 80, 90),
	sep = Color3.fromRGB(40, 40, 45),
	tog_off = Color3.fromRGB(48, 48, 48),
	check = Color3.fromRGB(40, 40, 40),
	tab_sel = Color3.fromRGB(30, 30, 35)
}
local ac = Color3.fromRGB(255, 255, 255)
local ac2 = Color3.fromRGB(160, 160, 160)
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local gameNetworking = nil
local lastMoveWhitelist = 0
local moveWhitelistGap = 0.3
local hub
local hubStore
local syde

local function getGameNetworking()
	if gameNetworking then
		return gameNetworking
	end
	pcall(function()
		gameNetworking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	end)
	return gameNetworking
end

local function firePrompt(prompt)
	if not prompt then
		return false
	end
	if fireproximityprompt then
		local ok = pcall(fireproximityprompt, prompt)
		return ok
	end
	local ok = pcall(function()
		prompt:InputBegan(Enum.UserInputType.Keyboard)
		task.wait(prompt.HoldDuration + 0.02)
		prompt:InputEnded(Enum.UserInputType.Keyboard)
	end)
	return ok
end

local function whitelistMove(pos)
	if typeof(pos) == "CFrame" then
		pos = pos.Position
	end
	local net = getGameNetworking()
	if not net or not net.Place or not net.Place.UseTeleporter then
		return
	end
	pcall(function()
		net.Place.UseTeleporter:Fire(pos)
	end)
end

local function whitelistMoveThrottled(pos)
	local now = os.clock()
	if now - lastMoveWhitelist < moveWhitelistGap then
		return
	end
	lastMoveWhitelist = now
	whitelistMove(pos)
end

local function safeTeleport(cf)
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	if typeof(cf) == "Vector3" then
		cf = CFrame.new(cf)
	end
	hrp.CFrame = cf
	whitelistMove(cf.Position)
	return true
end

function destroyEspBeamEntry(entry)
	if not entry then
		return
	end
	if typeof(entry) == "Instance" then
		pcall(function()
			entry:Destroy()
		end)
		return
	end
	pcall(function()
		if entry.beam then
			entry.beam:Destroy()
		end
	end)
	pcall(function()
		if entry.att0 then
			entry.att0:Destroy()
		end
	end)
	pcall(function()
		if entry.att1 then
			entry.att1:Destroy()
		end
	end)
end

function clearEspBeamTable(beamTable)
	if not beamTable then
		return
	end
	for key, entry in pairs(beamTable) do
		destroyEspBeamEntry(entry)
		beamTable[key] = nil
	end
end

function styleEspBeam(beam, color)
	if not beam then
		return
	end
	beam.Texture = "rbxassetid://446111271"
	beam.TextureSpeed = 1.5
	beam.TextureLength = 8
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.LightEmission = 0.75
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	beam.CurveSize0 = 2.5
	beam.CurveSize1 = -2.5
	beam.Segments = 24
	beam.Width0 = 0.4
	beam.Width1 = 0.4
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(color or Color3.fromRGB(120, 100, 255))
end

function createEspBeam(rootPart, targetPart, beamKey, color)
	if not rootPart or not targetPart then
		return nil
	end
	local att0 = Instance.new("Attachment")
	att0.Name = beamKey .. "_A0"
	att0.Parent = rootPart
	local att1 = Instance.new("Attachment")
	att1.Name = beamKey .. "_A1"
	att1.Parent = targetPart
	local beam = Instance.new("Beam")
	beam.Name = beamKey .. "_Beam"
	styleEspBeam(beam, color)
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Parent = targetPart
	return {beam = beam, att0 = att0, att1 = att1}
end

function syncEspBeamTable(beamTable, currentKeys)
	for key, entry in pairs(beamTable) do
		if not currentKeys[key] then
			destroyEspBeamEntry(entry)
			beamTable[key] = nil
		end
	end
end

function ensureEspBeam(beamTable, beamKey, showBeam, rootPart, targetPart, color, currentKeys)
	if not showBeam or not rootPart or not targetPart then
		return
	end
	local entry = beamTable[beamKey]
	if not entry or not entry.beam or not entry.beam.Parent then
		destroyEspBeamEntry(entry)
		beamTable[beamKey] = createEspBeam(rootPart, targetPart, beamKey, color)
	end
	if currentKeys then
		currentKeys[beamKey] = true
	end
end

function setHubParagraph(widget, content, title)
	if syde and syde.setHubParagraph then
		syde.setHubParagraph(widget, content, title)
	end
end

function enableParagraphRichText(widget)
	if syde and syde.enableParagraphRichText then
		syde.enableParagraphRichText(widget)
	end
end

local function tw(obj, props, t)
	local info = TweenInfo.new(t or 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tween = TS:Create(obj, info, props)
	tween:Play()
	return tween
end
local function rnd(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end
local function stk(p, col, th)
	local s = Instance.new("UIStroke")
	s.Color = col or Color3.fromRGB(30, 30, 35)
	s.Thickness = th or 1
	s.Transparency = 0.35
	s.Parent = p
end
local function pad(p, t, b, l, r)
	local pd = Instance.new("UIPadding")
	pd.PaddingTop = UDim.new(0, t or 0)
	pd.PaddingBottom = UDim.new(0, b or 0)
	pd.PaddingLeft = UDim.new(0, l or 0)
	pd.PaddingRight = UDim.new(0, r or 0)
	pd.Parent = p
end
local function getZenithGUI()
	local coreGui = game:GetService("CoreGui")
	return coreGui:FindFirstChild("sydeUILoader")
end
local seedData = nil
local valCalc = nil
local weightFormat = nil
local plantSizeMultipliers = nil
local petData = nil

local safeRequire = function(module)
	if not module then return nil end
	local success, result = pcall(require, module)
	if success then
		return result
	end
	local success3, clone = pcall(function() return module:Clone() end)
	if success3 and clone then
		clone.Parent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("Workspace")
		local success4, result4 = pcall(require, clone)
		clone:Destroy()
		if success4 then
			return result4
		end
	end
	return nil
end

local findModule = function(name)
	local rep = game:GetService("ReplicatedStorage")
	local sharedModules = rep:FindFirstChild("SharedModules")
	if sharedModules then
		local found = sharedModules:FindFirstChild(name)
		if found then return found end
		for _, v in sharedModules:GetDescendants() do
			if v:IsA("ModuleScript") and v.Name == name then
				return v
			end
		end
	end
	local sharedData = rep:FindFirstChild("SharedData")
	if sharedData then
		local found = sharedData:FindFirstChild(name)
		if found then return found end
	end
	return nil
end

local function getSeedData()
	if not seedData then
		local mod = findModule("SeedData")
		seedData = mod and safeRequire(mod)
	end
	return seedData
end

local function getPlantSizeMultipliers()
	if not plantSizeMultipliers then
		local mod = findModule("PlantSizeMultipliers")
		plantSizeMultipliers = mod and safeRequire(mod)
	end
	return plantSizeMultipliers
end

local function getPetData()
	if not petData then
		local mod = findModule("PetData")
		petData = mod and safeRequire(mod)
	end
	if not petData or typeof(petData) ~= "table" or not next(petData) then
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
		folder = folder and folder:FindFirstChild("PetModules")
		if folder then
			petData = {}
			for _, child in folder:GetChildren() do
				if child:IsA("ModuleScript") then
					local info = safeRequire(child)
					local displayName = info and info.AssetName
					if not displayName or displayName == "" then
						displayName = child.Name:gsub("(%u)", " %1"):gsub("^%s+", "")
					end
					petData[displayName] = info or {}
					petData[child.Name] = info or {}
				end
			end
		end
	end
	return petData
end

local function getWeightFormat()
	if not weightFormat then
		local mod = findModule("WeightFormat")
		weightFormat = mod and safeRequire(mod)
	end
	return weightFormat
end

local function getValCalc()
	if not valCalc then
		local mod = findModule("FruitValueCalc")
		valCalc = mod and safeRequire(mod)
	end
	return valCalc
end

local function resolveGameFruitIcon(name)
	if not name then return "rbxassetid://13001190533" end
	local rep = game:GetService("ReplicatedStorage")
	local sdFolder = rep:FindFirstChild("SharedModules") and rep.SharedModules:FindFirstChild("SeedData")
	if sdFolder then
		local fFolder = sdFolder:FindFirstChild("FruitImages")
		local f = fFolder and fFolder:FindFirstChild(name)
		if f and f:IsA("StringValue") and f.Value ~= "" then return f.Value end
		local sFolder = sdFolder:FindFirstChild("SeedImages")
		local s = sFolder and sFolder:FindFirstChild(name)
		if s and s:IsA("StringValue") and s.Value ~= "" then return s.Value end
	end
	return "rbxassetid://13001190533"
end

local function resolveGamePetIcon(name)
	if not name then return "rbxassetid://13001190533" end
	local clean = name:gsub("%s+", ""):lower()
	local pd = getPetData()
	if pd and typeof(pd) == "table" then
		for k, v in pairs(pd) do
			if typeof(v) == "table" and v.Image then
				if k:lower() == clean or (v.DisplayName and v.DisplayName:gsub("%s+", ""):lower() == clean) then
					return v.Image
				end
			end
		end
	end
	local rep = game:GetService("ReplicatedStorage")
	local gearImages = rep:FindFirstChild("SharedModules") and rep.SharedModules:FindFirstChild("GearImages")
	if gearImages then
		local found = gearImages:FindFirstChild(name)
		if found and found:IsA("StringValue") and found.Value ~= "" then
			return found.Value
		end
	end
	return "rbxassetid://13001190533"
end

local fruitIcons = setmetatable({}, {
	__index = function(_, key)
		return resolveGameFruitIcon(key)
	end
})

local petColors = {
	["Common"] = Color3.fromRGB(150, 150, 150),
	["Uncommon"] = Color3.fromRGB(80, 200, 120),
	["Rare"] = Color3.fromRGB(80, 150, 240),
	["Legendary"] = Color3.fromRGB(255, 195, 55),
	["Mythic"] = Color3.fromRGB(240, 75, 75),
	["Super"] = Color3.fromRGB(180, 120, 255),
}

local getFruitAsset = function(name, _, imgLabel)
	if not imgLabel then return end
	if name == "SheckleCoin" or name == "Coin" then
		imgLabel.Image = "rbxassetid://106697118185275"
		return
	end
	imgLabel.Image = resolveGameFruitIcon(name)
end

local getOnlineAsset = function(name, _, imgLabel)
	if not imgLabel then return end
	imgLabel.Image = resolveGamePetIcon(name)
end
do
	local UI_BRAND = {
		Name = "Casual Hub",
		Subtitle = "Grow a Garden 2",
		Logo = "107758724327938",
		Discord = "https://discord.gg/zTXP6w6DWJ",
		ConfigFolder = "CasualHub",
		ConfigFile = "growagarden2",
		Accent = Color3.fromRGB(255, 255, 255),
	}
	local function disconnectSydeRuntime()
		if typeof(shared) ~= "table" or typeof(shared.SydeRuntimeConnections) ~= "table" then
			return
		end
		for i = #shared.SydeRuntimeConnections, 1, -1 do
			local conn = shared.SydeRuntimeConnections[i]
			if conn and conn.Connected then
				pcall(function() conn:Disconnect() end)
			end
			shared.SydeRuntimeConnections[i] = nil
		end
	end
	local function loadSydeLibrary()
		disconnectSydeRuntime()
		local source
		if typeof(readfile) == "function" and typeof(isfile) == "function" then
			for _, path in ipairs({
				"liba.lua",
				"Syde.lua",
				"lib.lua",
				"луашечки/liba.lua",
			}) do
				if isfile(path) then
					local ok, contents = pcall(readfile, path)
					if ok and typeof(contents) == "string" and #contents > 1000 then
						source = contents
						break
					end
				end
			end
		end
		if not source then
			warn("[" .. UI_BRAND.Name .. "] liba.lua not found locally, downloading remote UI library")
			source = game:HttpGet("https://raw.githubusercontent.com/KaspikScriptsRb/redacted/refs/heads/main/.lua")
		end
		if typeof(source) ~= "string" or #source < 1000 then
			error("[" .. UI_BRAND.Name .. "] Failed to download Syde UI")
		end
		local compile = loadstring or load
		local factory, compileErr = compile(source)
		if not factory then
			error("[" .. UI_BRAND.Name .. "] Syde compile failed: " .. tostring(compileErr))
		end
		local ok, result = pcall(factory)
		if not ok then
			error("[" .. UI_BRAND.Name .. "] Syde init failed: " .. tostring(result))
		end
		return result
	end
	syde = loadSydeLibrary()
	local savedToggleKey = hubStore and hubStore.ToggleKey
	hubStore = {}
	if savedToggleKey then
		hubStore.ToggleKey = savedToggleKey
	end
	webhookHooks = {}
	hub, hubStore = syde:CreateHub({
		brand = UI_BRAND,
		hubStore = hubStore,
		getGuiRoot = getZenithGUI,
	})
end
do
sellValueData = nil
displayCropMap = {}
local worldsModule = nil
local WORLD_PLACE_IDS = {
	Main = 97598239454123,
	FallHarvest = 126987765280963,
}
local optionWidgetRegistry = {}

local function getWorldsModule()
	if worldsModule then
		return worldsModule
	end
	local mod = findModule and findModule("Worlds")
	worldsModule = mod and safeRequire and safeRequire(mod)
	return worldsModule
end

function getCurrentWorldId()
	local Worlds = getWorldsModule()
	if Worlds and Worlds.CurrentId then
		return Worlds.CurrentId
	end
	local placeId = game.PlaceId
	for worldId, mappedPlaceId in pairs(WORLD_PLACE_IDS) do
		if mappedPlaceId == placeId then
			return worldId
		end
	end
	return "Main"
end

function getWorldPlaceId(worldId)
	local Worlds = getWorldsModule()
	if Worlds and Worlds.GetPlaceId then
		local ok, placeId = pcall(Worlds.GetPlaceId, Worlds, worldId)
		if ok and placeId then
			return placeId
		end
	end
	return WORLD_PLACE_IDS[worldId]
end

function getWorldDisplayName(worldId)
	worldId = worldId or getCurrentWorldId()
	local Worlds = getWorldsModule()
	if Worlds and Worlds.Worlds and Worlds.Worlds[worldId] then
		return Worlds.Worlds[worldId].DisplayName or worldId
	end
	if worldId == "Main" then
		return "Garden Valley"
	end
	if worldId == "FallHarvest" then
		return "Fall Harvest"
	end
	return worldId
end

local shopItemWorldsCache = {}
function getShopItemWorlds(shopName, itemName)
	if typeof(itemName) ~= "string" or itemName == "" then
		return {}
	end
	local cacheKey = tostring(shopName) .. "\0" .. itemName
	if shopItemWorldsCache[cacheKey] ~= nil then
		return shopItemWorldsCache[cacheKey]
	end
	local sharedModules = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
	local moduleName = shopName == "SeedShop" and "SeedData" or (shopName == "GearShop" and "GearShopData" or "CrateData")
	local nameKey = shopName == "SeedShop" and "SeedName" or (shopName == "GearShop" and "GearName" or "CrateName")
	local mod = sharedModules and sharedModules:FindFirstChild(moduleName)
	if not mod then
		shopItemWorldsCache[cacheKey] = {}
		return {}
	end
	local ok, dataModule = pcall(require, mod)
	if not ok or typeof(dataModule) ~= "table" then
		shopItemWorldsCache[cacheKey] = {}
		return {}
	end
	for _, entry in dataModule do
		if type(entry) == "table" and entry[nameKey] == itemName then
			local worlds = entry.Worlds
			if typeof(worlds) == "table" then
				shopItemWorldsCache[cacheKey] = worlds
				return worlds
			end
			break
		end
	end
	shopItemWorldsCache[cacheKey] = {}
	return {}
end

function isShopItemInCurrentWorld(shopName, itemName)
	local worlds = getShopItemWorlds(shopName, itemName)
	if not worlds or #worlds == 0 then
		return true
	end
	local currentWorld = getCurrentWorldId()
	for _, worldId in worlds do
		if worldId == currentWorld then
			return true
		end
	end
	return false
end

function filterPredictStockByWorld(stockMap, shopName)
	if typeof(stockMap) ~= "table" then
		return stockMap
	end
	local filtered = {}
	for itemName, quantity in stockMap do
		if isShopItemInCurrentWorld(shopName, itemName) then
			filtered[itemName] = quantity
		end
	end
	return filtered
end

function getWalletStatName(worldId)
	worldId = worldId or getCurrentWorldId()
	local Worlds = getWorldsModule()
	if Worlds and Worlds.WalletStatName then
		local ok, statName = pcall(Worlds.WalletStatName, Worlds, worldId)
		if ok and typeof(statName) == "string" and statName ~= "" then
			return statName
		end
	end
	local WorldsTable = Worlds and Worlds.Worlds
	local cfg = WorldsTable and WorldsTable[worldId]
	if cfg and typeof(cfg.CurrencyName) == "string" and cfg.CurrencyName ~= "" then
		return cfg.CurrencyName
	end
	return "Sheckles"
end

function getCurrencyName()
	local Worlds = getWorldsModule()
	local worldId = getCurrentWorldId()
	local cfg = Worlds and Worlds.Worlds and Worlds.Worlds[worldId]
	if cfg and typeof(cfg.CurrencyName) == "string" and cfg.CurrencyName ~= "" then
		return cfg.CurrencyName
	end
	return "Sheckles"
end

function getCurrencySuffix()
	local Worlds = getWorldsModule()
	local worldId = getCurrentWorldId()
	local cfg = Worlds and Worlds.Worlds and Worlds.Worlds[worldId]
	if cfg and typeof(cfg.CurrencySuffix) == "string" and cfg.CurrencySuffix ~= "" then
		return cfg.CurrencySuffix
	end
	return "¢"
end

function getPlayerCurrency()
	local statName = getWalletStatName()
	local leaderstats = localPlayer:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(statName)
	if stat then
		return stat.Value
	end
	local _, gcPlayerdata = getGCPricesAndBalance and getGCPricesAndBalance()
	if gcPlayerdata and gcPlayerdata.Data then
		local data = gcPlayerdata.Data
		return data[statName] or data.Sheckles or data.Leaves or 0
	end
	return 0
end

function formatCurrencyAmount(amount, compact)
	amount = tonumber(amount) or 0
	local suffix = getCurrencySuffix()
	if compact then
		local n = amount
		if n >= 1000000000 then
			return suffix .. string.format("%.2fB", n / 1000000000)
		elseif n >= 1000000 then
			return suffix .. string.format("%.2fM", n / 1000000)
		elseif n >= 1000 then
			return suffix .. string.format("%.2fK", n / 1000)
		end
		return suffix .. tostring(math.floor(n))
	end
	return suffix .. tostring(math.floor(amount))
end

function teleportToWorld(worldId)
	if not worldId or worldId == "" then
		return
	end
	if getCurrentWorldId() == worldId then
		if hub then
			hub:Notify("You're already in " .. getWorldDisplayName(worldId) .. "!")
		end
		return
	end
	local net = getGameNetworking()
	if net and net.Worlds and net.Worlds.RequestTravel then
		pcall(function()
			net.Worlds.RequestTravel:Fire(worldId)
		end)
		if hub then
			hub:Notify("Teleporting to " .. getWorldDisplayName(worldId) .. "...")
		end
		return
	end
	local placeId = getWorldPlaceId(worldId)
	if placeId then
		pcall(function()
			game:GetService("TeleportService"):Teleport(placeId, localPlayer)
		end)
	end
end

function registerGameListWidget(widget, listKey)
	if widget and listKey then
		table.insert(optionWidgetRegistry, {widget = widget, key = listKey})
	end
end

function refreshAllGameListWidgets()
	for _, entry in optionWidgetRegistry do
		local list = gameLists[entry.key]
		if list and entry.widget and entry.widget.SetOptions then
			pcall(function()
				entry.widget:SetOptions(list)
			end)
		end
	end
end

gameLists = {
	crops = {},
	seeds = {},
	plants = {},
	gears = {},
	crates = {},
	mutations = {"None"},
	pets = {},
	petSizes = {"Normal", "Big", "Huge"},
	petTypes = {"Normal", "Rainbow"},
	petMutations = {"None", "Normal", "Big", "Huge", "Rainbow"},
	rarities = {"Common", "Uncommon", "Rare", "Legendary", "Mythic", "Super"},
	eventSeeds = {},
	eggs = {},
}
local fruitStock = {}
local function ensureSellValueData()
	if sellValueData then return sellValueData end
	if findModule then
		local mod = findModule("SellValueData")
		if mod and safeRequire then
			sellValueData = safeRequire(mod)
		end
	end
	return sellValueData
end
function refreshGameLists()
	local function clearAndFill(target, names)
		table.clear(target)
		for _, name in names do
			table.insert(target, name)
		end
	end
	local function addUnique(targetSet, name)
		if typeof(name) == "string" and name ~= "" then
			targetSet[name] = true
		end
	end
	local sellData = ensureSellValueData()
	local cropSet, plantSet = {}, {}
	if sellData then
		for name, _ in pairs(sellData) do
			if typeof(name) == "string" then
				addUnique(cropSet, name)
				addUnique(plantSet, name)
			end
		end
	end
	local sv = game:GetService("ReplicatedStorage"):FindFirstChild("StockValues")
	local function loadShop(shopName)
		local names = {}
		if sv then
			local shop = sv:FindFirstChild(shopName)
			local items = shop and shop:FindFirstChild("Items")
			if items then
				for _, item in items:GetChildren() do
					table.insert(names, item.Name)
				end
				table.sort(names)
			end
		end
		return names
	end
	local seeds = loadShop("SeedShop")
	local gears = loadShop("GearShop")
	local crates = loadShop("CrateShop")
	for _, seedName in seeds do
		addUnique(cropSet, seedName)
		addUnique(plantSet, seedName)
	end
	local crops, plants = {}, {}
	for name in cropSet do
		table.insert(crops, name)
	end
	for name in plantSet do
		table.insert(plants, name)
	end
	table.sort(crops)
	table.sort(plants)
	clearAndFill(gameLists.crops, crops)
	clearAndFill(gameLists.plants, plants)
	table.clear(displayCropMap)
	local locTable = game:FindFirstChild("LocalizationTable")
	if locTable then
		pcall(function()
			for _, e in locTable:GetEntries() do
				local ru = e.Values and (e.Values["ru"] or e.Values["ru-ru"] or e.Values["ru-RU"])
				if ru and ru ~= "" and e.Source and e.Source ~= "" then
					local cleanSrc = e.Source:gsub("%[.-%]", ""):gsub("⚖️.*", ""):match("^%s*(.-)%s*$")
					local cleanRu = ru:gsub("%[.-%]", ""):gsub("⚖️.*", ""):match("^%s*(.-)%s*$")
					if cleanRu and cleanRu ~= "" and cleanSrc and cleanSrc ~= "" then
						displayCropMap[cleanRu] = cleanSrc
						displayCropMap[cleanRu:lower()] = cleanSrc
					end
				end
			end
		end)
	end
	local locMod = findModule and findModule("SeedLocalize")
	local locData = locMod and safeRequire and safeRequire(locMod)
	for _, cropName in crops do
		displayCropMap[cropName] = cropName
		displayCropMap[cropName:lower()] = cropName
		if locData and locData.LocalizeSeedName then
			local ok, displayName = pcall(locData.LocalizeSeedName, cropName)
			if ok and typeof(displayName) == "string" and displayName ~= "" then
				displayCropMap[displayName] = cropName
				displayCropMap[displayName:lower()] = cropName
			end
		end
	end
	clearAndFill(gameLists.seeds, seeds)
	clearAndFill(gameLists.gears, gears)
	clearAndFill(gameLists.crates, crates)
	local mutations = {"None"}
	if findModule then
		local md = findModule("MutationData")
		if md then
			for _, child in md:GetChildren() do
				if child:IsA("ModuleScript") then
					table.insert(mutations, child.Name)
				end
			end
			table.sort(mutations, function(a, b)
				if a == "None" then return true end
				if b == "None" then return false end
				return a < b
			end)
		end
	end
	clearAndFill(gameLists.mutations, mutations)

	local pData = getPetData()
	local petNames = {}
	local petModulesFolder = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
	petModulesFolder = petModulesFolder and petModulesFolder:FindFirstChild("PetModules")
	if petModulesFolder then
		for _, child in petModulesFolder:GetChildren() do
			if child:IsA("ModuleScript") then
				local info = safeRequire(child)
				local displayName = info and info.AssetName
				if not displayName or displayName == "" then
					displayName = child.Name:gsub("(%u)", " %1"):gsub("^%s+", "")
				end
				table.insert(petNames, displayName)
			end
		end
	elseif pData and typeof(pData) == "table" then
		for name, val in pairs(pData) do
			if typeof(name) == "string" and not name:find("^Get") and typeof(val) == "table" then
				table.insert(petNames, name)
			end
		end
	end
	table.sort(petNames)
	if #petNames > 0 then
		clearAndFill(gameLists.pets, petNames)
	end

	local petSizesMod = findModule and findModule("PetSizes")
	local petSizesData = petSizesMod and safeRequire and safeRequire(petSizesMod)
	local petSizesList = {"Normal", "Big", "Huge"}
	if petSizesData and typeof(petSizesData.Scales) == "table" then
		for sz, _ in pairs(petSizesData.Scales) do
			if not table.find(petSizesList, sz) then
				table.insert(petSizesList, sz)
			end
		end
	end
	clearAndFill(gameLists.petSizes, petSizesList)

	local petTypesMod = findModule and findModule("PetTypes")
	local petTypesData = petTypesMod and safeRequire and safeRequire(petTypesMod)
	local petTypesList = {"Normal", "Rainbow"}
	if petTypesData and typeof(petTypesData.Registry) == "table" then
		for typ, _ in pairs(petTypesData.Registry) do
			if not table.find(petTypesList, typ) then
				table.insert(petTypesList, typ)
			end
		end
	end
	clearAndFill(gameLists.petTypes, petTypesList)

	local petMutList = {"None", "Normal"}
	for _, sz in petSizesList do
		if not table.find(petMutList, sz) then
			table.insert(petMutList, sz)
		end
	end
	for _, typ in petTypesList do
		if not table.find(petMutList, typ) then
			table.insert(petMutList, typ)
		end
	end
	clearAndFill(gameLists.petMutations, petMutList)

	local raritySet = {}
	for _, rarity in {"Common", "Uncommon", "Rare", "Legendary", "Mythic", "Super"} do
		raritySet[rarity] = true
	end
	for _, petName in petNames do
		local info = getPetInfo(petName)
		if info and typeof(info.Rarity) == "string" and info.Rarity ~= "" then
			raritySet[info.Rarity] = true
		end
	end
	local rarities = {}
	for rarity in raritySet do
		table.insert(rarities, rarity)
	end
	table.sort(rarities)
	clearAndFill(gameLists.rarities, rarities)

	local eventSeedSet = {}
	for _, seedName in seeds do
		local normalized = seedName
		if seedName == "Gold" or seedName == "Rainbow" or seedName == "Mega" then
			normalized = seedName .. " Seed"
		end
		if seedName:find("Gold") or seedName:find("Rainbow") or seedName:find("Mega") then
			eventSeedSet[normalized] = true
			eventSeedSet[seedName] = true
		end
	end
	if sv then
		local seedItems = sv:FindFirstChild("SeedShop") and sv.SeedShop:FindFirstChild("Items")
		if seedItems then
			for _, item in seedItems:GetChildren() do
				if item:GetAttribute("GoldSeed") or item:GetAttribute("RainbowSeed") or item:GetAttribute("MegaSeed") or item:GetAttribute("EventSeed") then
					local label = item.Name
					if item.Name == "Gold" then label = "Gold Seed"
					elseif item.Name == "Rainbow" then label = "Rainbow Seed"
					elseif item.Name == "Mega" then label = "Mega Seed"
					end
					eventSeedSet[label] = true
					eventSeedSet[item.Name] = true
				end
			end
		end
	end
	if not next(eventSeedSet) then
		eventSeedSet["Gold Seed"] = true
		eventSeedSet["Rainbow Seed"] = true
		eventSeedSet["Mega Seed"] = true
	end
	local eventSeeds = {}
	for name in eventSeedSet do
		table.insert(eventSeeds, name)
	end
	table.sort(eventSeeds)
	clearAndFill(gameLists.eventSeeds, eventSeeds)

	local eggSet = {}
	if sv then
		for _, shop in sv:GetChildren() do
			local items = shop:FindFirstChild("Items")
			if items then
				for _, item in items:GetChildren() do
					if item.Name:lower():find("egg") then
						eggSet[item.Name] = true
					end
				end
			end
		end
	end
	if not next(eggSet) then
		for _, eggName in {"Common Egg", "Test Egg", "Big Egg", "Mega Egg", "Rainbow Egg"} do
			eggSet[eggName] = true
		end
	end
	local eggs = {}
	for name in eggSet do
		table.insert(eggs, name)
	end
	table.sort(eggs)
	clearAndFill(gameLists.eggs, eggs)

	refreshAllGameListWidgets()
end
local function getStockMultiplierFromUI(cropName)
	if fruitStock[cropName] then
		local mult = fruitStock[cropName].multiplier
		if mult then return mult end
	end
	local success, val = pcall(function()
		local fruitStockPrice = localPlayer.PlayerGui:FindFirstChild("FruitStockPrice")
		local scrollingFrame = fruitStockPrice and fruitStockPrice:FindFirstChild("Frame") and fruitStockPrice.Frame:FindFirstChild("ScrollingFrame")
		if scrollingFrame then
			for _, card in scrollingFrame:GetChildren() do
				if card.Name == "FruitCard" and card:GetAttribute("SeedToolTip") == cropName then
					local frame = card:FindFirstChild("Frame")
					local multiplierLabel = frame and frame:FindFirstChild("Multiplier")
					if multiplierLabel then
						local txt = multiplierLabel.Text
						local num = tonumber(txt:match("X([%d%.]+)"))
						if num then return num end
					end
				end
			end
		end
	end)
	if success and val then return val end
	return 1
end
local function getFriendCount()
	local count = 0
	pcall(function()
		for _, p in game:GetService("Players"):GetPlayers() do
			if p ~= localPlayer then
				local isFriend = false
				pcall(function()
					isFriend = localPlayer:IsFriendsWith(p.UserId)
				end)
				if isFriend then
					count = count + 1
				end
			end
		end
	end)
	return count
end
getPetInfo = function(name)
	if not name then return nil end
	local pd = getPetData()
	if not pd or typeof(pd) ~= "table" then return nil end
	local info = pd[name]
	if info then return info end
	local clean = name:gsub("%s+", ""):lower()
	for k, v in pairs(pd) do
		if typeof(v) == "table" then
			if k:gsub("%s+", ""):lower() == clean or (v.DisplayName and v.DisplayName:gsub("%s+", ""):lower() == clean) then
				return v
			end
		end
	end
	return nil
end
function getPlayerFarm()
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then return nil end
	for _, plot in gardens:GetChildren() do
		if isPlotOwnedByLocalPlayer(plot) then
			return plot
		end
	end
	return nil
end

function getPlotOwnerUserId(plot)
	if not plot then
		return nil
	end
	local ownerId = plot:GetAttribute("OwnerUserId")
	if typeof(ownerId) == "number" and ownerId > 0 then
		return ownerId
	end
	local ownerName = plot:GetAttribute("Owner")
	if typeof(ownerName) ~= "string" or ownerName == "" then
		return nil
	end
	local lowerOwner = string.lower(ownerName)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == lowerOwner or string.lower(player.DisplayName) == lowerOwner then
			return player.UserId
		end
	end
	return nil
end

function isPlotOwnedByLocalPlayer(plot)
	if not plot then
		return false
	end
	local ownerId = getPlotOwnerUserId(plot)
	if ownerId then
		return ownerId == localPlayer.UserId
	end
	local ownerName = plot:GetAttribute("Owner")
	if typeof(ownerName) ~= "string" or ownerName == "" then
		return false
	end
	local lowerOwner = string.lower(ownerName)
	return lowerOwner == string.lower(localPlayer.Name) or lowerOwner == string.lower(localPlayer.DisplayName)
end

function getPlotOwnerPlayer(plot)
	local ownerId = getPlotOwnerUserId(plot)
	if not ownerId then
		return nil
	end
	return Players:GetPlayerByUserId(ownerId)
end

function isPlayerInsidePlot(player, plot)
	if not player or not plot then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local ref = plot:FindFirstChild("PlotSizeReference")
	if ref and ref:IsA("BasePart") then
		local pos = ref.CFrame:PointToObjectSpace(hrp.Position)
		local half = ref.Size / 2
		if math.abs(pos.X) <= half.X and math.abs(pos.Z) <= half.Z and math.abs(pos.Y) <= half.Y + 16 then
			return true
		end
	end
	local sp = plot:FindFirstChild("SpawnPoint")
	if sp and sp:IsA("BasePart") and (hrp.Position - sp.Position).Magnitude < 120 then
		return true
	end
	return false
end

function isPlotOwnerInGarden(plot, plantOwnerUserId)
	local ownerPlayer = getPlotOwnerPlayer(plot)
	if ownerPlayer and ownerPlayer ~= localPlayer and isPlayerInsidePlot(ownerPlayer, plot) then
		return true
	end
	if typeof(plantOwnerUserId) == "number" and plantOwnerUserId > 0 and plantOwnerUserId ~= localPlayer.UserId then
		local plantOwner = Players:GetPlayerByUserId(plantOwnerUserId)
		if plantOwner and plantOwner ~= ownerPlayer and isPlayerInsidePlot(plantOwner, plot) then
			return true
		end
	end
	return false
end

local sprinklerRangesCache = nil
local sprinklerNameListCache = nil
local gardenSyncControllerCache = nil

local function loadSprinklerData()
	if sprinklerRangesCache then
		return sprinklerRangesCache, sprinklerNameListCache
	end
	local ranges = {}
	local names = {}
	local mod = findModule("SprinklerData")
	local data = mod and safeRequire(mod)
	if data then
		for _, entry in ipairs(data) do
			local sprinklerName = entry.SprinklerName
			if sprinklerName and entry.Radius then
				ranges[sprinklerName] = entry.Radius
				table.insert(names, sprinklerName)
			end
		end
		table.sort(names)
	end
	if not next(ranges) then
		ranges = {
			["Common Sprinkler"] = 20,
			["Uncommon Sprinkler"] = 25,
			["Rare Sprinkler"] = 30,
			["Legendary Sprinkler"] = 40,
			["Super Sprinkler"] = 55,
			["Syrup Sprinkler"] = 20,
			["Super Syrup Sprinkler"] = 55,
		}
		names = {
			"Common Sprinkler", "Uncommon Sprinkler", "Rare Sprinkler",
			"Legendary Sprinkler", "Super Sprinkler", "Syrup Sprinkler", "Super Syrup Sprinkler",
		}
	end
	sprinklerRangesCache = ranges
	sprinklerNameListCache = names
	return ranges, names
end

function getSprinklerRadius(sprinklerName)
	local ranges = loadSprinklerData()
	return ranges[sprinklerName] or 20
end

function getSprinklerNameList()
	local _, names = loadSprinklerData()
	return names
end

local function horizontalDistance(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getSprinklerPart(model)
	return model:FindFirstChild("RootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

function forEachPlacedSprinkler(farm, callback)
	if not farm or not callback then
		return
	end
	local ranges = loadSprinklerData()
	local seen = {}
	local sprinklersFolder = farm:FindFirstChild("Sprinklers")
	if sprinklersFolder then
		for _, sprinkler in sprinklersFolder:GetChildren() do
			if sprinkler:IsA("Model") then
				seen[sprinkler] = true
				local part = getSprinklerPart(sprinkler)
				if part then
					callback(sprinkler.Name, part.Position, getSprinklerRadius(sprinkler.Name))
				end
			end
		end
	end
	for _, child in farm:GetDescendants() do
		if child:IsA("Model") and not seen[child] and ranges[child.Name] then
			local part = getSprinklerPart(child)
			if part then
				callback(child.Name, part.Position, ranges[child.Name])
			end
		end
	end
end

function isPositionCoveredBySprinkler(farm, position, extraRadius)
	if not farm or not position then
		return false
	end
	extraRadius = extraRadius or 0
	local covered = false
	forEachPlacedSprinkler(farm, function(_, sprinklerPos, radius)
		if horizontalDistance(sprinklerPos, position) <= radius + extraRadius then
			covered = true
		end
	end)
	return covered
end

function isTooCloseToSprinklerStack(farm, position)
	if not farm or not position then
		return false
	end
	local tooClose = false
	forEachPlacedSprinkler(farm, function(_, sprinklerPos)
		if horizontalDistance(sprinklerPos, position) < 1 then
			tooClose = true
		end
	end)
	return tooClose
end

function raycastPlantAreaPosition(worldPos, farm)
	if not worldPos or not farm then
		return worldPos
	end
	local collectionService = game:GetService("CollectionService")
	local include = {}
	for _, part in farm:GetDescendants() do
		if part:IsA("BasePart") and collectionService:HasTag(part, "PlantArea") then
			table.insert(include, part)
		end
	end
	if #include == 0 then
		return worldPos
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local result = workspace:Raycast(worldPos + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
	return result and result.Position or worldPos
end

function getPlantAreaColumns()
	local farm = getPlayerFarm()
	if not farm then
		return {}
	end
	local cols = {}
	local visual = farm:FindFirstChild("Visual")
	if visual then
		for _, child in visual:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "PlantAreaColumn1" or child.Name == "PlantAreaColumn2" or child.Name:find("PlantAreaColumn")) then
				table.insert(cols, child)
			end
		end
	end
	if #cols == 0 then
		for _, child in farm:GetDescendants() do
			if child:IsA("BasePart") and child.Name:find("PlantAreaColumn") then
				table.insert(cols, child)
			end
		end
	end
	return cols
end

function isPointInPart(worldPos, part)
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local halfSize = part.Size / 2
	return math.abs(localPos.X) <= (halfSize.X + 3)
		and math.abs(localPos.Z) <= (halfSize.Z + 3)
end

function isPositionInPlantArea(pos, columns)
	columns = columns or getPlantAreaColumns()
	if #columns == 0 then
		return true
	end
	for _, col in columns do
		if isPointInPart(pos, col) then
			return true
		end
	end
	return false
end

function isPlantNear(pos, range)
	local farm = getPlayerFarm()
	local plants = farm and farm:FindFirstChild("Plants")
	if plants then
		for _, plant in plants:GetChildren() do
			local pPart = plant:FindFirstChild("PrimaryPart") or plant:FindFirstChildWhichIsA("BasePart")
			if pPart and (pPart.Position - pos).Magnitude < (range or 1.2) then
				return true
			end
		end
	end
	return false
end

function getGroundUnderPlayer()
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}
	local result = workspace:Raycast(rootPart.Position, Vector3.new(0, -15, 0), raycastParams)
	if result then
		return result.Position
	end
	return rootPart.Position - Vector3.new(0, 3.2, 0)
end

function projectToSoil(worldPos)
	local farm = getPlayerFarm()
	if not farm then
		return worldPos, false, nil
	end
	local parts = {}
	local visual = farm:FindFirstChild("Visual")
	if visual then
		for _, child in visual:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "Can_Plant" or child.Name:find("PlantAreaColumn")) then
				table.insert(parts, child)
			end
		end
	end
	if #parts == 0 then
		local imp = farm:FindFirstChild("Important", true)
		local locs = imp and imp:FindFirstChild("Plant_Locations")
		if locs then
			for _, part in locs:GetChildren() do
				if part:IsA("BasePart") and part.Name == "Can_Plant" then
					table.insert(parts, part)
				end
			end
		end
	end
	if #parts == 0 then
		return worldPos, false, nil
	end
	local closestPart = nil
	local closestDist = math.huge
	for _, part in parts do
		local dist = (Vector3.new(part.Position.X, 0, part.Position.Z) - Vector3.new(worldPos.X, 0, worldPos.Z)).Magnitude
		if dist < closestDist then
			closestDist = dist
			closestPart = part
		end
	end
	if closestPart then
		local localPos = closestPart.CFrame:PointToObjectSpace(worldPos)
		local halfSize = closestPart.Size / 2
		if math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Z) <= halfSize.Z then
			local topY = (closestPart.CFrame * CFrame.new(0, halfSize.Y, 0)).Position.Y
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Include
			raycastParams.FilterDescendantsInstances = {closestPart}
			local startRay = Vector3.new(worldPos.X, topY + 5, worldPos.Z)
			local result = workspace:Raycast(startRay, Vector3.new(0, -10, 0), raycastParams)
			if result then
				return result.Position, true, closestPart
			end
			return Vector3.new(worldPos.X, topY, worldPos.Z), true, closestPart
		end
	end
	return worldPos, false, nil
end

function getRandomPointInColumn(col)
	local cf = col.CFrame
	local size = col.Size
	local rx = (math.random() - 0.5) * size.X
	local rz = (math.random() - 0.5) * size.Z
	return cf:PointToWorldSpace(Vector3.new(rx, 0.13, rz))
end

function getRandomPointInZone(zoneMin, zoneMax)
	if not zoneMin or not zoneMax then
		return nil
	end
	for _ = 1, 12 do
		local x = zoneMin.X + math.random() * (zoneMax.X - zoneMin.X)
		local z = zoneMin.Z + math.random() * (zoneMax.Z - zoneMin.Z)
		local y = (zoneMin.Y + zoneMax.Y) * 0.5
		local projected, isValid = projectToSoil(Vector3.new(x, y, z))
		if isValid then
			return projected
		end
	end
	return nil
end

function GetRandomPlantingPosition(playerFarmFolder)
	if not playerFarmFolder then
		return nil
	end
	local plantLocationsFolder = playerFarmFolder:FindFirstChild("Important", true)
	if plantLocationsFolder then
		plantLocationsFolder = plantLocationsFolder:FindFirstChild("Plant_Locations")
	end
	if not plantLocationsFolder then
		return nil
	end
	local canPlantParts = {}
	for _, part in plantLocationsFolder:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Can_Plant" then
			table.insert(canPlantParts, part)
		end
	end
	if #canPlantParts == 0 then
		return nil
	end
	for _ = 1, 40 do
		local randomPart = canPlantParts[math.random(1, #canPlantParts)]
		local randomXOffset = (math.random() - 0.5) * (randomPart.Size.X - 1.0)
		local randomZOffset = (math.random() - 0.5) * (randomPart.Size.Z - 1.0)
		local positionInPartSpace = Vector3.new(randomXOffset, randomPart.Size.Y / 2, randomZOffset)
		local worldSpacePlantPosition = randomPart.CFrame * positionInPartSpace
		local projectedPos, isValid = projectToSoil(worldSpacePlantPosition)
		if isValid and not isPlantNear(projectedPos, 1.3) then
			return projectedPos
		end
	end
	return nil
end

local function getGardenSyncController()
	if gardenSyncControllerCache == nil then
		local ok, controller = pcall(function()
			return require(localPlayer.PlayerScripts.Controllers.GardenSyncController)
		end)
		gardenSyncControllerCache = ok and controller or false
	end
	return gardenSyncControllerCache or nil
end

local function hasActiveGrowthBoost(userId, plantId, fruitId)
	local ok, growthData = pcall(function()
		local fruitVisualizer = require(localPlayer.PlayerScripts.Controllers.FruitVisualizerController)
		return fruitVisualizer:GetFruitGrowthData(userId, plantId, fruitId)
	end)
	if ok and growthData and (growthData.BoostExpiresClock or 0) > os.clock() then
		return true
	end
	return false
end

local function plantHasFruitsWithoutBoost(userId, plantId, syncData)
	if not syncData or not syncData.Fruits then
		return true
	end
	for fruitId, fruitData in pairs(syncData.Fruits) do
		local age = fruitData.Age or 0
		local maxAge = fruitData.MaxAge or 0
		if age < maxAge and not hasActiveGrowthBoost(userId, plantId, fruitId) then
			return true
		end
	end
	return false
end

local function plantAllFruitsFullyGrown(syncData)
	if not syncData or not syncData.Fruits then
		return false
	end
	local hasFruit = false
	for _, fruitData in pairs(syncData.Fruits) do
		hasFruit = true
		local age = fruitData.Age or 0
		local maxAge = fruitData.MaxAge or 0
		if age < maxAge then
			return false
		end
	end
	return hasFruit
end

function shouldAutoWaterPlant(plant)
	if not plant then
		return false
	end
	if not autowaterskipmature and not autowaterskipboost and not autowaterskipallfruitsgrown then
		return true
	end
	local plantId = plant:GetAttribute("PlantId")
	local gardenSync = getGardenSyncController()
	local syncData = plantId and gardenSync and gardenSync:GetPlant(localPlayer.UserId, plantId)
	if syncData and syncData.Fruits then
		if autowaterskipallfruitsgrown and plantAllFruitsFullyGrown(syncData) then
			return false
		end
		if autowaterskipboost and not plantHasFruitsWithoutBoost(localPlayer.UserId, plantId, syncData) then
			return false
		end
		return true
	end
	if autowaterskipmature then
		local age = syncData and (syncData.Age or syncData.CurrentAge) or plant:GetAttribute("Age")
		local maxAge = syncData and syncData.MaxAge or plant:GetAttribute("MaxAge")
		if age and maxAge and age >= maxAge then
			return false
		end
	end
	return true
end

local function multiselectCsvToSet(csv)
	local set = {}
	if not csv or csv == "" or csv == "None" then
		return set, true
	end
	for entry in (csv .. ","):gmatch("([^,]+),") do
		local trimmed = entry:match("^%s*(.-)%s*$")
		if trimmed ~= "" and trimmed ~= "None" then
			set[trimmed] = true
		end
	end
	if not next(set) then
		return set, true
	end
	return set, false
end

local function csvMatchesFilter(csv, value, filterType)
	local set, all = multiselectCsvToSet(csv)
	if all or not next(set) then
		return true
	end
	local matched = set[value] == true
	if filterType == "Blacklist" then
		return not matched
	end
	return matched
end

local EVENT_SEED_PRIORITY = {
	["Gold Seed"] = 1, ["Gold"] = 1,
	["Rainbow Seed"] = 2, ["Rainbow"] = 2,
	["Mega Seed"] = 3, ["Mega"] = 3,
}

function getClaimableSeedTypeList()
	local list = {}
	for _, name in gameLists.eventSeeds do
		table.insert(list, name)
	end
	return list
end

local function getEventSeedLabel(part)
	if not part then
		return nil
	end
	if part:GetAttribute("RainbowSeed") == true then
		return "Rainbow Seed"
	end
	if part:GetAttribute("GoldSeed") == true then
		return "Gold Seed"
	end
	if part:GetAttribute("MegaSeed") == true then
		return "Mega Seed"
	end
	local packName = part:GetAttribute("SeedPack")
	if packName == "Rainbow" then
		return "Rainbow Seed"
	end
	if packName == "Gold" then
		return "Gold Seed"
	end
	if packName == "Mega" then
		return "Mega Seed"
	end
	if part.Name == "Gold" or part:GetAttribute("SeedTool") == "Gold" then
		return "Gold Seed"
	end
	if part.Name == "Rainbow" or part:GetAttribute("SeedTool") == "Rainbow" then
		return "Rainbow Seed"
	end
	if part.Name == "Mega" or part:GetAttribute("SeedTool") == "Mega" then
		return "Mega Seed"
	end
	return nil
end

local function resolveEventSeedLabel(inst)
	if not inst then
		return nil
	end
	local label = getEventSeedLabel(inst)
	if label then
		return label
	end
	local current = inst.Parent
	while current and current ~= workspace do
		label = getEventSeedLabel(current)
		if label then
			return label
		end
		current = current.Parent
	end
	for _, desc in inst:GetDescendants() do
		label = getEventSeedLabel(desc)
		if label then
			return label
		end
	end
	return nil
end

local function labelFromPrompt(prompt)
	if not prompt then
		return nil
	end
	local text = string.lower(tostring(prompt.ObjectText or "") .. " " .. tostring(prompt.ActionText or ""))
	if text:find("rainbow", 1, true) then
		return "Rainbow Seed"
	end
	if text:find("mega", 1, true) then
		return "Mega Seed"
	end
	if text:find("gold", 1, true) then
		return "Gold Seed"
	end
	return nil
end

function classifyWorldDrop(obj)
	if not obj then
		return "Other", "Unknown"
	end
	local model = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model")
	if model and model.Parent and model.Parent.Name == "DroppedItems" then
		local categoryMap = {
			HarvestedFruits = "Fruits",
			SeedTool = "Seeds",
			Seeds = "Seeds",
			Sprinkler = "Gears",
			WateringCan = "Gears",
			Mushroom = "Gears",
			Gnome = "Cosmetics",
			Raccoon = "Cosmetics",
			Crate = "Crates",
			Teleporter = "Gears",
			PlayerMagnet = "Gears",
			FruitMagnet = "Gears",
			PetTeleporter = "Gears",
			SeedPack = "Seed Packs",
			Wheelbarrow = "Gears",
			Trowel = "Gears",
			Crowbar = "Gears",
			Ladder = "Gears",
			FreezeRay = "Gears",
			PowerHose = "Gears",
			Rake = "Gears",
			Sign = "Gears",
			EmptyPot = "Gears",
			Flashbang = "Gears",
			Bird = "Gears",
			Pets = "Pets",
			Raccoons = "Pets",
		}
		local category = model:GetAttribute("ItemCategory")
		local displayName = model:GetAttribute("DisplayName")
		local dropType = categoryMap[category] or category or "Other"
		local dropName = displayName or model:GetAttribute("ItemName") or model.Name
		if typeof(dropName) == "string" then
			local cleaned = dropName:match("^(.-)%s*%[")
			if cleaned then
				dropName = cleaned:match("^%s*(.-)%s*$") or cleaned
			end
		end
		return dropType, dropName
	end
	local function fromInst(inst)
		if not inst then return end
		if inst:GetAttribute("HarvestedFruit") or inst:GetAttribute("FruitName") then
			return "Fruits", inst:GetAttribute("FruitName") or inst:GetAttribute("Fruit") or inst.Name
		end
		if inst:GetAttribute("SeedTool") or inst:GetAttribute("MainCategory") == "Seed" then
			return "Seeds", inst:GetAttribute("SeedTool") or inst.Name
		end
		if inst:GetAttribute("MainCategory") == "Gear" or inst:GetAttribute("WateringCan") or inst:GetAttribute("Shovel") or inst:GetAttribute("Build") then
			return "Gears", inst.Name
		end
		if inst:GetAttribute("MainCategory") == "Cosmetic" or inst:GetAttribute("Cosmetic") or inst:GetAttribute("CosmeticName") then
			return "Cosmetics", inst.Name
		end
		if inst:GetAttribute("MainCategory") == "Crate" or inst:GetAttribute("Crate") then
			return "Crates", inst.Name
		end
		if inst:GetAttribute("PackName") or inst.Name:find("Pack", 1, true) then
			return "Seed Packs", inst:GetAttribute("PackName") or inst.Name
		end
	end
	local dropType, dropName = fromInst(obj)
	if dropType then
		return dropType, dropName
	end
	if obj.Parent and obj.Parent ~= workspace and obj.Parent.Name ~= "DroppedItems" then
		dropType, dropName = fromInst(obj.Parent)
		if dropType then
			return dropType, dropName
		end
	end
	local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	return "Other", (prompt and prompt.ObjectText ~= "" and prompt.ObjectText) or obj.Name
end

function getDropPickupTarget(model)
	if not model or not model:IsA("Model") then
		return nil, nil
	end
	local anchor = model:FindFirstChild("PromptAnchor", true)
	if anchor and anchor:IsA("BasePart") then
		local prompt = anchor:FindFirstChild("PickupPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			return prompt, anchor
		end
	end
	local prompt = model:FindFirstChild("PickupPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt, model.PrimaryPart or anchor or model:FindFirstChildWhichIsA("BasePart")
	end
	return nil, nil
end

function getModelPosition(model)
	if not model then return nil end
	if model:IsA("BasePart") then return model.Position end
	if model.PrimaryPart then return model.PrimaryPart.Position end
	local part = model:FindFirstChild("HarvestPart")
	if not part then
		for _, desc in model:GetDescendants() do
			if desc:IsA("BasePart") then
				part = desc
				break
			end
		end
	end
	return part and part.Position
end

function isSingleHarvestSeed(seedName)
	if not seedName then
		return false
	end
	local cropName = getcropname(seedName) or seedName
	local data = getSeedData()
	if not data then
		return false
	end
	for _, entry in data do
		if type(entry) == "table" and entry.SeedName == cropName and entry.IsSingleHarvest == true then
			return true
		end
	end
	return false
end

local fruitVisualizerController

local function getFruitVisualizerController()
	if not fruitVisualizerController then
		pcall(function()
			fruitVisualizerController = require(game.Players.LocalPlayer.PlayerScripts.Controllers.FruitVisualizerController)
		end)
	end
	return fruitVisualizerController
end

function getSingleHarvestWeightKg(obj)
	local fvc = getFruitVisualizerController()
	if not fvc or not fvc.CalculatePlantWeight then
		return 0
	end
	local ok, weight = pcall(fvc.CalculatePlantWeight, fvc, obj)
	return ok and weight or 0
end

local plantHeightExcludedFolders = {
	Fruits = true,
	FruitSpawnLocations = true,
}

function getPlantHeightFt(plant)
	if not plant then
		return nil
	end
	local heightAttr = plant:GetAttribute("Height")
	if heightAttr then
		return heightAttr
	end
	local minY = math.huge
	local maxY = -math.huge
	for _, part in plant:QueryDescendants("BasePart") do
		local parent = part.Parent
		local skip = false
		while parent and parent ~= plant do
			if plantHeightExcludedFolders[parent.Name] then
				skip = true
				break
			end
			parent = parent.Parent
		end
		if not skip then
			local topY = (part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)).Position.Y
			local bottomY = (part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)).Position.Y
			if topY > maxY then
				maxY = topY
			end
			if bottomY < minY then
				minY = bottomY
			end
		end
	end
	if maxY == -math.huge then
		return nil
	end
	return math.round(maxY - minY)
end

function formatPlantHeightText(heightFt)
	if not heightFt or heightFt <= 0 then
		return nil
	end
	return "Height: " .. string.format("%.1f", heightFt):gsub("%.0$", "") .. "ft"
end

function isSingleHarvestGardenObject(obj, plant)
	if not obj then
		return false
	end
	plant = plant or ((obj.Parent and obj.Parent.Name == "Fruits") and obj.Parent.Parent) or obj
	if plant:FindFirstChild("Fruits") then
		return false
	end
	local seedName = plant:GetAttribute("SeedName") or getseedname(plant)
	return isSingleHarvestSeed(seedName)
end

function estimateFruitPrice(seedName, sizeMulti, mutation, decay)
	local price = calcGamePrice(seedName, sizeMulti, mutation, decay)
	if price > 0 then return price end
	local base = getbaseprice(seedName)
	if base <= 0 then return 0 end
	local decayFactor = 1 - math.clamp(tonumber(decay) or 0, 0, 1)
	return math.floor(base * (sizeMulti or 1) * getMutationMultiplier(mutation) * decayFactor)
end

function getGardenObjectCalcInputs(obj, plant)
	if not obj then
		return nil
	end
	plant = plant or ((obj.Parent and obj.Parent.Name == "Fruits") and obj.Parent.Parent) or obj
	local seedName = getseedname(obj)
	if (not seedName or seedName == "") and plant then
		seedName = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName") or plant:GetAttribute("Fruit")
	end
	if not seedName or seedName == "" then
		return nil
	end
	local cropName = getcropname(seedName) or seedName
	local mutation = obj:GetAttribute("Mutation") or "None"
	local decay = tonumber(obj:GetAttribute("DecayAlpha")) or 0
	local sizeMulti = obj:GetAttribute("SizeMultiplier") or obj:GetAttribute("SizeMulti")
	if isSingleHarvestGardenObject(obj, plant) then
		if not sizeMulti then
			local weight = getSingleHarvestWeightKg(obj)
			if weight > 0 then
				local mod = game:GetService("ReplicatedStorage").PlantGenerationModules.Plants:FindFirstChild(cropName)
				if mod then
					local ok, data = pcall(require, mod)
					local base = ok and data and data.GrowData and data.GrowData.BaseWeight
					if base and base > 0 then
						sizeMulti = weight / base
					end
				end
			end
		end
	end
	if not sizeMulti then
		local attrWeight = obj:GetAttribute("Weight")
		local baseWeight = getbaseweight(cropName) or getbaseweight(seedName) or 1
		if attrWeight then
			sizeMulti = attrWeight > 100 and (attrWeight / 1000 / baseWeight) or (attrWeight / baseWeight)
		end
	end
	if not sizeMulti then
		local isFruit = (obj.Parent and obj.Parent.Name == "Fruits")
		local lastGen
		if isFruit then
			lastGen = obj:GetAttribute("LastGenerated") or obj:GetAttribute("PlantedAt")
		else
			lastGen = obj:GetAttribute("PlantedAt") or obj:GetAttribute("LastGenerated")
		end
		local psm = getPlantSizeMultipliers()
		if lastGen and psm and typeof(psm) == "table" then
			local ok, res
			if isFruit and typeof(psm.GetRandomFruitSize) == "function" then
				ok, res = pcall(function() return psm.GetRandomFruitSize(1, lastGen) end)
			elseif typeof(psm.GetRandomPlantSize) == "function" then
				local stage = obj:GetAttribute("Age") or obj:GetAttribute("MaxAge") or 1
				ok, res = pcall(function() return psm.GetRandomPlantSize(stage, lastGen, cropName) end)
			end
			if ok and res then
				sizeMulti = res
			end
		end
	end
	if not sizeMulti or sizeMulti <= 0 then
		sizeMulti = 1
	end
	return cropName, seedName, sizeMulti, mutation, decay
end

function estimateGardenObjectPrice(obj, plant)
	local cropName, seedName, sizeMulti, mutation, decay = getGardenObjectCalcInputs(obj, plant)
	if not cropName then
		return 0
	end
	local price = calcGamePrice(cropName, sizeMulti, mutation, decay)
	if price > 0 then
		return price
	end
	return estimateFruitPrice(seedName or cropName, sizeMulti, mutation, decay)
end

function scanGardenFruitStats(plot, onlyRipe)
	local bestPrice, bestWeight = nil, nil
	local bestPriceVal, bestWeightVal = 0, 0
	if not plot then
		return bestPrice, bestWeight
	end
	local plants = plot:FindFirstChild("Plants")
	if not plants then
		return bestPrice, bestWeight
	end
	for _, plant in plants:GetChildren() do
		local seedName = plant:GetAttribute("SeedName") or getseedname(plant) or ""
		local function consider(obj)
			if onlyRipe then
				local age = obj:GetAttribute("Age")
				local maxAge = obj:GetAttribute("MaxAge")
				if typeof(age) == "number" and typeof(maxAge) == "number" and age < maxAge then
					return
				end
			end
			local _, displayName, sizeMulti, mutation, decay = getGardenObjectCalcInputs(obj, plant)
			if not displayName then
				return
			end
			local price = estimateGardenObjectPrice(obj, plant)
			local weight = getweightkg(obj, displayName)
			if price > bestPriceVal then
				bestPriceVal = price
				bestPrice = {seedName = displayName, mutation = mutation, price = price, weight = weight}
			end
			if weight > bestWeightVal then
				bestWeightVal = weight
				bestWeight = {seedName = displayName, mutation = mutation, price = price, weight = weight}
			end
		end
		local fruitsFolder = plant:FindFirstChild("Fruits")
		if fruitsFolder then
			for _, fruit in fruitsFolder:GetChildren() do
				consider(fruit)
			end
		else
			consider(plant)
		end
	end
	return bestPrice, bestWeight
end

function enumerateMyGardenFruits(onlyRipe)
	local results = {}
	local farm = getPlayerFarm()
	if not farm then
		return results
	end
	local plants = farm:FindFirstChild("Plants")
	if not plants then
		return results
	end
	for _, plant in plants:GetChildren() do
		local seedName = plant:GetAttribute("SeedName") or getseedname(plant) or ""
		local plantId = plant:GetAttribute("PlantId") or plant.Name
		local function addFruit(obj, fruitId)
			if onlyRipe then
				local age = obj:GetAttribute("Age")
				local maxAge = obj:GetAttribute("MaxAge")
				if typeof(age) == "number" and typeof(maxAge) == "number" and age < maxAge then
					return
				end
			end
			local cropName, rawSeedName, _, mutation = getGardenObjectCalcInputs(obj, plant)
			if not cropName then
				return
			end
			local price = estimateGardenObjectPrice(obj, plant)
			local weight = getweightkg(obj, cropName)
			local key = tostring(plantId) .. ":" .. tostring(fruitId or obj.Name)
			table.insert(results, {
				key = key,
				seedName = cropName,
				rawSeedName = rawSeedName,
				mutation = mutation or "None",
				weight = weight,
				price = price,
			})
		end
		local fruitsFolder = plant:FindFirstChild("Fruits")
		if fruitsFolder then
			for _, fruit in fruitsFolder:GetChildren() do
				local fruitId = fruit:GetAttribute("FruitId") or fruit.Name
				addFruit(fruit, fruitId)
			end
		else
			addFruit(plant, plantId)
		end
	end
	return results
end

function scanServerFruitStats(onlyRipe)
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then
		return nil, nil
	end
	local bestPrice, bestWeight = nil, nil
	for _, plot in gardens:GetChildren() do
		local plotBestPrice, plotBestWeight = scanGardenFruitStats(plot, onlyRipe)
		if plotBestPrice and (not bestPrice or plotBestPrice.price > bestPrice.price) then
			bestPrice = plotBestPrice
		end
		if plotBestWeight and (not bestWeight or plotBestWeight.weight > bestWeight.weight) then
			bestWeight = plotBestWeight
		end
	end
	return bestPrice, bestWeight
end

function formatSessionTime(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm %02ds", h, m, s)
	end
	return string.format("%dm %02ds", m, s)
end

function getTimeOfDayInfo()
	local nightVal = game:GetService("ReplicatedStorage"):FindFirstChild("Night")
	local isNight = nightVal and nightVal.Value == true
	local clock = game:GetService("Lighting").ClockTime
	if isNight or clock >= 21 or clock < 6 then
		return "Night", "rgb(150,130,255)"
	elseif clock >= 6 and clock < 12 then
		return "Morning", "rgb(255,220,100)"
	elseif clock >= 17 and clock < 21 then
		return "Evening", "rgb(255,150,90)"
	end
	return "Day", "rgb(120,200,255)"
end

local running = false
local harvestDelay = 0
local minweight = 0
local maxweight = 0
local cropBaseWeights = {}
function getbaseweight(seedName)
	if not seedName then return nil end
	local cleanName = seedName:gsub("%s+", ""):gsub("Seed$", "")
	local weight = cropBaseWeights[cleanName]
		or cropBaseWeights[cleanName .. "Seed"]
		or cropBaseWeights[seedName]
	if not weight and seedData then
		local crop = getcropname(seedName)
		for _, entry in seedData do
			if type(entry) == "table" and (entry.SeedName == crop or entry.SeedName == seedName) then
				weight = entry.BaseWeight
				if not weight and entry.GrowData then
					weight = entry.GrowData.BaseWeight or entry.GrowData.Weight or entry.GrowData.weight
				end
				if weight then break end
			end
		end
	end
	return weight or 1
end
function getcropname(seedName)
	if not seedName then return nil end
	local clean = seedName:gsub("Produce$", ""):gsub("Seed$", ""):gsub("Crop$", "")
	local sellData = ensureSellValueData()
	if sellData then
		if sellData[clean] ~= nil then return clean end
		local cleanLower = clean:lower():gsub("%s+", "")
		for name, _ in pairs(sellData) do
			if typeof(name) == "string" and name:lower():gsub("%s+", "") == cleanLower then
				return name
			end
		end
	end
	return clean
end
function getbaseprice(seedName)
	local cropName = getcropname(seedName)
	local sellData = ensureSellValueData()
	if sellData and cropName then
		return sellData[cropName] or 0
	end
	return 0
end
function getfriendmultiplier()
	local friendsCount = 0
	local success, players = pcall(function() return game:GetService("Players"):GetPlayers() end)
	if success then
		for _, p in players do
			if p ~= localPlayer then
				local ok, isFriends = pcall(function() return localPlayer:IsFriendsWith(p.UserId) end)
				if ok and isFriends then
					friendsCount = friendsCount + 1
				end
			end
		end
	end
	return 1 + (0.10 * friendsCount)
end
function getMutationMultiplier(mutation)
	if not mutation or mutation == "None" or mutation == "" then return 1 end
	local sm = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
	local md = sm and sm:FindFirstChild("MutationData")
	if md then
		local ok, MutationData = pcall(require, md)
		if ok and MutationData and MutationData.ReturnPriceMultiplier then
			local mult = MutationData.ReturnPriceMultiplier(mutation)
			if typeof(mult) == "number" then
				return mult
			end
		end
	end
	return 1
end
function calcGamePrice(cropName, sizeMulti, mutation, decay)
	cropName = getcropname(cropName) or cropName
	if not cropName then return 0 end
	local vc = getValCalc()
	if vc and typeof(vc) == "function" then
		local ok, res = pcall(vc, cropName, sizeMulti or 1, mutation ~= "None" and mutation or nil, localPlayer, decay or 0)
		if ok and res and res > 0 then
			local stockMult = getStockMultiplierFromUI(cropName)
			return math.floor(res * stockMult)
		end
	end
	return 0
end
function _localCalculatePrice(seedName, sizeMulti, mutation)
	return calcGamePrice(seedName, sizeMulti, mutation, 0)
end
function getseedname(obj)
	if not obj then return nil end
	local name = obj:GetAttribute("CorePartName")
		or obj:GetAttribute("SeedName")
		or obj:GetAttribute("Fruit")
	if not name and obj.Parent and obj.Parent.Name == "Fruits" and obj.Parent.Parent then
		name = obj.Parent.Parent:GetAttribute("CorePartName")
			or obj.Parent.Parent:GetAttribute("SeedName")
			or obj.Parent.Parent:GetAttribute("Fruit")
	end
	if not name then
		name = obj.Name
	end
	if name then
		name = name:gsub("%s*%b[]%s*$", "")
		if name:match("^%d+_%w+") or name:match("^%d+_%-") then
			name = nil
		end
	end
	return name
end
local ftype = "Blacklist"
local flist = "None"
local lastPredictions = {}
local function allowed(seedName)
	local set = {}
	for name in (flist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if ftype == "Whitelist" then
		return set[seedName] == true
	end
	return set[seedName] == nil
end
local muttype = "Whitelist"
local mutlist = "None"
local function mutallowed(mutation)
	if not mutation or mutation == "" then
		mutation = "None"
	end
	local set = {}
	for name in (mutlist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if mutlist == "" or mutlist == "None" then
		return true
	end
	if muttype == "Whitelist" then
		return set[mutation] == true
	end
	return set[mutation] == nil
end
local purchasedCurrentCycle = {}
local gcPricesCache = {}
local gcPlayerDataCache = nil

local function getGCPricesAndBalance()
	local prices = {}
	local playerdata = nil
	pcall(function()
		for _, v in pairs(getgc()) do
			if type(v) == "function" then
				local s = debug.info(v, "s")
				if s and s:match("RestockStoreController") then
					local numUpvals = debug.info(v, "u")
					local tempPrices, tempPlayerData
					for idx = 1, numUpvals do
						local name, val = debug.getupvalue(v, idx)
						if val and type(val) == "table" then
							if val.Data and (val.Data.Sheckles ~= nil or val.Data.Leaves ~= nil) then
								tempPlayerData = val
							elseif val.CommonWateringCan or val.Carrot or val.FenceCrate or val["Common Watering Can"] or val["Fence Crate"] then
								tempPrices = val
							end
						end
					end
					if tempPrices then table.insert(prices, tempPrices) end
					if tempPlayerData then playerdata = tempPlayerData end
				end
			end
		end
	end)
	if #prices > 0 then gcPricesCache = prices end
	if playerdata then gcPlayerDataCache = playerdata end
	return gcPricesCache, gcPlayerDataCache
end

function getItemPrice(itemName, categoryId)
	if not itemName then return 0 end
	if typeof(categoryId) == "string" then
		if categoryId:find("Seed") then
			categoryId = 1
		elseif categoryId:find("Gear") then
			categoryId = 2
		elseif categoryId:find("Crate") then
			categoryId = 3
		end
	end
	local gcPrices, _ = getGCPricesAndBalance()
	if gcPrices then
		for _, shopPrices in gcPrices do
			local itemData = shopPrices[itemName] or shopPrices[itemName:gsub("%s+", "")]
			if itemData and itemData.price then
				return itemData.price
			end
		end
	end

	local priceOverride = nil
	pcall(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		if categoryId == 1 then
			local flags = require(ReplicatedStorage.SharedModules.Flags.SeedShopFlags)
			priceOverride = flags.PriceOverrides:Get()[itemName]
		elseif categoryId == 2 then
			local flags = require(ReplicatedStorage.SharedModules.Flags.GearShopFlags)
			priceOverride = flags.PriceOverrides:Get()[itemName]
		elseif categoryId == 3 then
			local flags = require(ReplicatedStorage.SharedModules.Flags.CrateShopFlags)
			priceOverride = flags.PriceOverrides:Get()[itemName]
		end
	end)
	if priceOverride then return priceOverride end

	local shopNames = { [1] = "SeedShop", [2] = "GearShop", [3] = "CrateShop" }
	local sv = game:GetService("ReplicatedStorage"):FindFirstChild("StockValues")
	local shop = sv and sv:FindFirstChild(shopNames[categoryId] or "")
	local itemsFolder = shop and shop:FindFirstChild("Items")
	local itemVal = itemsFolder and itemsFolder:FindFirstChild(itemName)
	if itemVal then
		local walletStat = getWalletStatName()
		local p = itemVal:GetAttribute("Price") or itemVal:GetAttribute("Cost") or itemVal:GetAttribute(walletStat) or itemVal:GetAttribute("Sheckles") or itemVal:GetAttribute("Leaves")
		if p then return p end
	end
	if categoryId == 1 then
		return getbaseprice(itemName)
	end
	return 0
end

function isinstock(itemName, categoryId, virtualMoney)
	local currentMoney = virtualMoney
	if not currentMoney then
		currentMoney = getPlayerCurrency()
	end
	
	local price = getItemPrice(itemName, categoryId)
	if currentMoney < price then
		return false
	end
	local isEnabled = true
	pcall(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		if categoryId == 1 then
			local shopEnabled = require(ReplicatedStorage.SharedModules.SeedShopEnabled)
			if shopEnabled and not shopEnabled.IsSeedEnabled(itemName) then
				isEnabled = false
			end
		elseif categoryId == 2 then
			local shopEnabled = require(ReplicatedStorage.SharedModules.GearShopABTest)
			if shopEnabled and not shopEnabled.IsGearEnabled(localPlayer, itemName) then
				isEnabled = false
			end
		elseif categoryId == 3 then
			local shopEnabled = require(ReplicatedStorage.SharedModules.CrateShopEnabled)
			if shopEnabled and not shopEnabled.IsCrateEnabled(itemName) then
				isEnabled = false
			end
		end
	end)
	if not isEnabled then
		return false
	end
	local shopNames = {
		[1] = "SeedShop",
		[2] = "GearShop",
		[3] = "CrateShop"
	}
	local shopName = shopNames[categoryId]
	if not shopName then return true end
	local stockValues = game:GetService("ReplicatedStorage"):FindFirstChild("StockValues")
	if not stockValues then return false end
	local shopFolder = stockValues:FindFirstChild(shopName)
	if not shopFolder then return false end
	local itemsFolder = shopFolder:FindFirstChild("Items")
	if not itemsFolder then return false end
	local itemVal = itemsFolder:FindFirstChild(itemName)
	if not itemVal then return false end
	local val = nil
	pcall(function() val = itemVal.Value end)
	local limit = typeof(val) == "number" and val or (tonumber(val) or 0)
	if limit <= 0 then
		return false
	end
	if not itemVal:GetAttribute("Tracked") then
		itemVal:SetAttribute("Tracked", true)
		itemVal.Changed:Connect(function()
			purchasedCurrentCycle[itemName] = 0
		end)
	end
	local bought = purchasedCurrentCycle[itemName] or 0
	return bought < limit
end
function getweightkg(obj, seedName)
	if not obj then return 0 end
	seedName = seedName or getseedname(obj)
	if not seedName then return 0 end
	local plant = (obj.Parent and obj.Parent.Name == "Fruits" and obj.Parent.Parent) or obj
	if isSingleHarvestGardenObject(obj, plant) then
		return getSingleHarvestWeightKg(obj)
	end
	local attrWeight = obj:GetAttribute("Weight")
	if attrWeight then
		return attrWeight > 100 and (attrWeight / 1000) or attrWeight
	end
	local sizeMulti = obj:GetAttribute("SizeMulti") or obj:GetAttribute("SizeMultiplier")
	if not sizeMulti then
		local isFruit = (obj.Parent and obj.Parent.Name == "Fruits")
		local lastGen
		if isFruit then
			lastGen = obj:GetAttribute("LastGenerated") or obj:GetAttribute("PlantedAt")
		else
			lastGen = obj:GetAttribute("PlantedAt") or obj:GetAttribute("LastGenerated")
		end
		local psm = getPlantSizeMultipliers()
		if lastGen and psm and typeof(psm) == "table" then
			local ok, res
			if isFruit and typeof(psm.GetRandomFruitSize) == "function" then
				ok, res = pcall(function() return psm.GetRandomFruitSize(1, lastGen) end)
			elseif typeof(psm.GetRandomPlantSize) == "function" then
				local stage = obj:GetAttribute("Age") or obj:GetAttribute("MaxAge") or 1
				ok, res = pcall(function() return psm.GetRandomPlantSize(stage, lastGen, seedName) end)
			end
			if ok and res then sizeMulti = res end
		end
	end
	if not sizeMulti then sizeMulti = 1 end
	local baseWeight = getbaseweight(seedName) or 1
	local realWeight = baseWeight * sizeMulti
	local finalWeight = realWeight > 50 and (realWeight / 1000) or realWeight
	return finalWeight
end
local function findDescendantOfClass(root, className)
	if not root then
		return nil
	end
	if root:IsA(className) then
		return root
	end
	if typeof(root.FindFirstChildWhichIsA) == "function" then
		local found = root:FindFirstChildWhichIsA(className, true)
		if found then
			return found
		end
	end
	for _, desc in root:GetDescendants() do
		if desc:IsA(className) then
			return desc
		end
	end
	return nil
end

local function weightallowed(obj, seedName)
	if minweight == 0 and maxweight == 0 then return true end
	local w = getweightkg(obj, seedName)
	if minweight ~= 0 and w < minweight then return false end
	if maxweight ~= 0 and w > maxweight then return false end
	return true
end
local harvestCooldown = {}
local harvestCooldownSec = 0.4

local function isRipeCrop(obj)
	local age = obj:GetAttribute("Age")
	local maxAge = obj:GetAttribute("MaxAge")
	if typeof(age) ~= "number" or typeof(maxAge) ~= "number" then
		return true
	end
	return age >= maxAge
end

local function fireCollect(collectEvent, plantId, fruitId)
	local key = plantId .. ":" .. (fruitId or "")
	local now = os.clock()
	if harvestCooldown[key] and now - harvestCooldown[key] < harvestCooldownSec then
		return
	end
	harvestCooldown[key] = now
	pcall(function()
		collectEvent:Fire(plantId, fruitId or "")
	end)
end

local function doharvest()
	local farm = getPlayerFarm()
	if not farm then
		return
	end
	local plants = farm:FindFirstChild("Plants")
	if not plants then
		return
	end
	local netMod = findModule and findModule("Networking")
	local Networking = netMod and safeRequire and safeRequire(netMod)
	local collectEvent = Networking and Networking.Garden and Networking.Garden.CollectFruit
	if not collectEvent then
		return
	end
	local plantBehaviorRules = nil
	pcall(function()
		plantBehaviorRules = require(game:GetService("ReplicatedStorage").SharedModules.PlantBehaviorRules)
	end)
	for _, plant in plants:GetChildren() do
		if not running then
			break
		end
		local seedName = getseedname(plant)
		if not seedName or seedName == "" then
			continue
		end
		local plantId = plant:GetAttribute("PlantId") or plant.Name:match("^%d+_(.+)$")
		if not plantId then
			continue
		end
		local coreName = plant:GetAttribute("CorePartName") or plant:GetAttribute("SeedName") or seedName
		if plantBehaviorRules and plantBehaviorRules.GrowsForever(coreName) then
			continue
		end
		local fruitsFolder = plant:FindFirstChild("Fruits")
		if fruitsFolder then
			for _, fruit in fruitsFolder:GetChildren() do
				if not running then
					break
				end
				if not isRipeCrop(fruit) then
					continue
				end
				local mutation = fruit:GetAttribute("Mutation") or "None"
				if not allowed(seedName) or not mutallowed(mutation) or not weightallowed(fruit, seedName) then
					continue
				end
				local fruitId = fruit:GetAttribute("FruitId") or fruit.Name:match("^%d+_%d+_(.+)$") or ""
				fireCollect(collectEvent, plantId, fruitId)
			end
		elseif isRipeCrop(plant) then
			local mutation = plant:GetAttribute("Mutation") or "None"
			if allowed(seedName) and mutallowed(mutation) and weightallowed(plant, seedName) then
				fireCollect(collectEvent, plantId, "")
			end
		end
	end
end
hub:CreateTab("Main", "rbxassetid://13060262529")
hub:CreateModule("Main", {
	name = "Auto Harvest",
	on = false,
	bind = "None",
	desc = "Auto harvest crops.",
	callback = function(enabled)
		running = enabled
		if enabled then
			task.spawn(function()
				while running do
					doharvest()
					task.wait(math.max(harvestDelay, 0))
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Harvest Delay", value = 0, min = 0, max = 100, increment = 1, suffix = " ds", callback = function(value)
			harvestDelay = value / 10
		end},
		{type = "dropdown", label = "Filter Type", value = "Blacklist", list = {"Whitelist","Blacklist"}, callback = function(value)
			ftype = value
		end},
		{type = "multiselect", label = "Filter Fruits", value = "None", list = gameLists.crops, callback = function(value)
			flist = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "crops")
		end},
		{type = "dropdown", label = "Filter Mutation Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			muttype = value
		end},
		{type = "multiselect", label = "Filter Mutations", value = "None", list = gameLists.mutations, callback = function(value)
			mutlist = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "mutations")
		end},
		{type = "slider", label = "Min Weight (kg)", value = 0, min = 0, max = 100, increment = 1, suffix = " kg", callback = function(value)
			minweight = value
		end},
		{type = "slider", label = "Max Weight (kg)", value = 0, min = 0, max = 100, increment = 1, suffix = " kg", callback = function(value)
			maxweight = value
		end},
	}
})
local sellev = nil
pcall(function()
	local sm = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules") or game:GetService("ReplicatedStorage"):WaitForChild("SharedModules", 5)
	local pkt = sm and (sm:FindFirstChild("Packet") or sm:WaitForChild("Packet", 3))
	sellev = pkt and (pkt:FindFirstChild("RemoteEvent") or pkt:WaitForChild("RemoteEvent", 3))
end)
valCalc = nil
seedData = nil
weightFormat = nil
plantSizeMultipliers = nil
safeRequire = nil
findModule = nil
findShovelTool = nil
pcall(function()
	safeRequire = function(module)
		local success, result = pcall(require, module)
		if success then
			return result
		end
		local success3, clone = pcall(function() return module:Clone() end)
		if success3 and clone then
			clone.Parent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("Workspace")
			local success4, result4 = pcall(require, clone)
			clone:Destroy()
			if success4 then
				return result4
			end
		end
		local hasSource, source = pcall(function() return module.Source end)
		if hasSource and typeof(source) == "string" and source ~= "" then
			local fn, err = loadstring(source)
			if fn then
				local success5, result5 = pcall(fn)
				if success5 then
					return result5
				end
			end
		end
		return nil
	end
	findModule = function(name)
		local sharedModules = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
		if sharedModules then
			local found = sharedModules:FindFirstChild(name)
			if found then return found end
			for _, v in sharedModules:GetDescendants() do
				if v:IsA("ModuleScript") and v.Name == name then
					return v
				end
			end
		end
		return nil
	end
	local fd = findModule("SeedData")
	if fd then
		seedData = safeRequire(fd)
	end
	local fvc = findModule("FruitValueCalc")
	if fvc then
		valCalc = safeRequire(fvc)
	end
	local wf = findModule("WeightFormat")
	if wf then
		weightFormat = safeRequire(wf)
	end
	local psm = findModule("PlantSizeMultipliers")
	if psm then
		plantSizeMultipliers = safeRequire(psm)
	end
	pcall(refreshGameLists)
	task.spawn(function()
		local sv = game:GetService("ReplicatedStorage"):WaitForChild("StockValues", 30)
		if sv then
			sv.DescendantAdded:Connect(function()
				task.defer(refreshGameLists)
			end)
		end
	end)
	task.spawn(function()
		local count = 0
		local sharedModules = game:GetService("ReplicatedStorage"):WaitForChild("SharedModules", 10)
		if sharedModules then
			task.wait(3)
			local function registerModule(v)
				if v:IsA("ModuleScript") then
					local nameL = v.Name:lower()
					if nameL:find("seed") or nameL:find("crop") or nameL:find("fruit") or nameL:find("plant") or nameL:find("weight") then
						local success, res = pcall(safeRequire, v)
						if success and res and typeof(res) == "table" then
							local bw = nil
							pcall(function()
								bw = res.BaseWeight or res.baseweight or res.Weight or res.weight
								if not bw and res.GrowData then
									local gd = res.GrowData
									bw = gd.BaseWeight or gd.baseweight or gd.Weight or gd.weight
								end
							end)
							if bw then
								local nameNoSpaces = v.Name:gsub("%s+", "")
								local cleanName = nameNoSpaces:gsub("Seed$", "")
								cropBaseWeights[v.Name] = bw
								cropBaseWeights[nameNoSpaces] = bw
								cropBaseWeights[cleanName] = bw
								count = count + 1
							end
						end
					end
				end
			end
			for _, v in sharedModules:GetDescendants() do
				task.spawn(registerModule, v)
			end
			sharedModules.DescendantAdded:Connect(function(v)
				task.spawn(registerModule, v)
			end)
		end
		local assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets", 5)
		local plants = assets and assets:WaitForChild("Plants", 5)
		if plants then
			for _, model in plants:GetChildren() do
				local bw = model:GetAttribute("BaseWeight") or model:GetAttribute("baseweight") or model:GetAttribute("Weight") or model:GetAttribute("weight")
				if bw then
					local nameNoSpaces = model.Name:gsub("%s+", "")
					cropBaseWeights[model.Name] = bw
					cropBaseWeights[nameNoSpaces] = bw
					count = count + 1
				end
			end
		end
		pcall(function()
			local netMod = findModule("Networking")
			local Networking = netMod and safeRequire(netMod)
			if Networking and Networking.FruitStock then
				local function updateStock(snapshot)
					if typeof(snapshot) == "table" and typeof(snapshot.entries) == "table" then
						for crop, data in pairs(snapshot.entries) do
							if typeof(crop) == "string" and typeof(data) == "table" then
								fruitStock[crop] = {
									multiplier = typeof(data.multiplier) == "number" and data.multiplier or 1,
									tier = typeof(data.tier) == "string" and data.tier or "normal"
								}
							end
						end
					end
				end
				Networking.FruitStock.Snapshot.OnClientEvent:Connect(updateStock)
				local ok, result = pcall(function()
					if Networking.FruitStock.Request.InvokeServer then
						return Networking.FruitStock.Request:InvokeServer()
					else
						return Networking.FruitStock.Request:Fire()
					end
				end)
				if ok and typeof(result) == "table" then
					updateStock(result)
				end
			end
		end)
	end)
end)
favoriterunning = false
favoritedelay = 1
favoritetype = "Whitelist"
favoritelist = ""
favoritemuttype = "Whitelist"
favoritemutlist = ""
favoriteminweight = 0
favoritemaxweight = 0
favoritedIds = {}
function getInventoryItems()
	local items = {}
	local bp = localPlayer:FindFirstChildOfClass("Backpack")
	if bp then
		for _, child in bp:GetChildren() do
			if child:GetAttribute("HarvestedFruit") or child:GetAttribute("Id") then
				table.insert(items, child)
			end
		end
	end
	local char = localPlayer.Character
	if char then
		for _, child in char:GetChildren() do
			if child:IsA("Tool") then
				if child:GetAttribute("HarvestedFruit") or child:GetAttribute("Id") then
					table.insert(items, child)
				end
			end
		end
	end
	return items
end
local function favoriteallowed(fruitName)
	if favoritelist == "" or favoritelist == "None" then return favoritetype == "Blacklist" end
	local set = {}
	for s in (favoritelist .. ","):gmatch("([^,]+),") do
		set[s:match("^%s*(.-)%s*$")] = true
	end
	if favoritetype == "Whitelist" then
		return set[fruitName] == true
	else
		return set[fruitName] ~= true
	end
end
local function favoritemutallowed(mut)
	if not mut or mut == "" then mut = "None" end
	if favoritemutlist == "" or favoritemutlist == "None" then return favoritemuttype == "Blacklist" end
	local set = {}
	for s in (favoritemutlist .. ","):gmatch("([^,]+),") do
		set[s:match("^%s*(.-)%s*$")] = true
	end
	if favoritemuttype == "Whitelist" then
		return set[mut] == true
	else
		return set[mut] ~= true
	end
end
local function dofavorite()
	local items = getInventoryItems()
	local netMod = findModule("Networking")
	local Networking = netMod and safeRequire(netMod)
	if not Networking or not Networking.Backpack or not Networking.Backpack.SetFruitFavorite then return end
	local setFavorite = Networking.Backpack.SetFruitFavorite
	for _, item in items do
		if not favoriterunning then break end
		local itemId = item:GetAttribute("Id")
		if itemId and not favoritedIds[itemId] then
			local isFav = item:GetAttribute("Favorite") or item:GetAttribute("IsFavorite") or item:GetAttribute("Favored")
			if isFav then
				favoritedIds[itemId] = true
			else
				local fruit = item:GetAttribute("Fruit") or item:GetAttribute("FruitName") or item.Name:gsub("%s*%b[]%s*$", "")
				local mutation = item:GetAttribute("Mutation") or "None"
				local weight = tonumber(item:GetAttribute("Weight")) or tonumber(item:GetAttribute("SizeMultiplier")) or 0
				local allowed = favoriteallowed(fruit)
				local mutAllowed = favoritemutallowed(mutation)
				local matchesMin = (favoriteminweight == 0 or weight >= favoriteminweight)
				local matchesMax = (favoritemaxweight == 0 or weight <= favoritemaxweight)
				if allowed and mutAllowed and matchesMin and matchesMax then
					pcall(function()
						setFavorite:Fire(itemId, true)
					end)
					favoritedIds[itemId] = true
					if not favoriterunning then break end
					task.wait(0.1)
				end
			end
		end
	end
end
hub:CreateModule("Main", {
	name = "Auto Favorite",
	on = false,
	bind = "None",
	desc = "Favorite fruits by filter.",
	callback = function(enabled)
		favoriterunning = enabled
		if enabled then
			task.spawn(function()
				while favoriterunning do
					pcall(dofavorite)
					task.wait(favoritedelay)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Delay", value = 1, min = 1, max = 30, suffix = "s", callback = function(value)
			favoritedelay = value
		end},
		{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			favoritetype = value
		end},
		{type = "multiselect", label = "Filter Fruits", value = "None", list = gameLists.crops, callback = function(value)
			favoritelist = value
		end},
		{type = "dropdown", label = "Filter Mutation Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			favoritemuttype = value
		end},
		{type = "multiselect", label = "Filter Mutations", value = "None", list = gameLists.mutations, callback = function(value)
			favoritemutlist = value
		end},
		{type = "textbox", label = "Min Weight Filter (kg)", value = "0", placeholder = "Enter min weight in kg...", callback = function(value)
			local num = tonumber(value)
			favoriteminweight = num or 0
		end},
		{type = "textbox", label = "Max Weight Filter (kg)", value = "0", placeholder = "Enter max weight in kg...", callback = function(value)
			local num = tonumber(value)
			favoritemaxweight = num or 0
		end},
	}
})
end
do
	sprinklerrunning = false
	sprinklerdelay = 2
	sprinklerlist = ""
	sprinklerfiltertype = "Blacklist"
	sprinklerfilterlist = ""
	sprinklermode = "On Plants"
	sprinklernoduplicates = true
	local savedSprinklerPositions = {}
	local sprinklerPosParagraph = nil
	local sprinklerPosListIndex = 1
	local sprinklerZoneMin = nil
	local sprinklerZoneMax = nil
	local sprinklerZoneStartPos = nil
	local sprinklerSelecting = false
	local sprinklerSelectionPart = nil
	local sprinklerSelectionRunConn = nil
	local sprinklerSelectionClickConn = nil
	local sprinklerSelectionKeyConn = nil
	local sprinklerLastOffset = Vector3.zero
	local sprinklerTypeList = getSprinklerNameList()
	local function cleanupSprinklerSelection()
		if sprinklerSelectionClickConn then sprinklerSelectionClickConn:Disconnect() sprinklerSelectionClickConn = nil end
		if sprinklerSelectionRunConn then sprinklerSelectionRunConn:Disconnect() sprinklerSelectionRunConn = nil end
		if sprinklerSelectionKeyConn then sprinklerSelectionKeyConn:Disconnect() sprinklerSelectionKeyConn = nil end
		if sprinklerSelectionPart then
			sprinklerSelectionPart:Destroy()
			sprinklerSelectionPart = nil
		end
		sprinklerZoneStartPos = nil
		local mouse = localPlayer:GetMouse()
		if mouse.TargetFilter == sprinklerSelectionPart then
			mouse.TargetFilter = nil
		end
		sprinklerSelecting = false
	end
	local function formatSprinklerPosList()
		if sprinklermode == "Part" then
			if #savedSprinklerPositions == 0 then
				return "No saved points.\nUse Add Point to place one."
			end
			local lines = {}
			for i, pos in savedSprinklerPositions do
				lines[#lines + 1] = string.format("#%d: %.1f, %.1f, %.1f", i, pos.X, pos.Y, pos.Z)
			end
			return table.concat(lines, "\n")
		end
		if sprinklermode == "Zone" and sprinklerZoneMin and sprinklerZoneMax then
			return string.format(
				"Zone saved:\nX %.1f -> %.1f\nZ %.1f -> %.1f",
				sprinklerZoneMin.X, sprinklerZoneMax.X, sprinklerZoneMin.Z, sprinklerZoneMax.Z
			)
		end
		if sprinklermode == "HumanoidRootPart" then
			return "Places at player position."
		end
		if sprinklermode == "On Plants" then
			return "Places on filtered plants."
		end
		return "Uses random valid soil spots."
	end
	local function updateSprinklerPosDisplay()
		if sprinklerPosParagraph then
			setHubParagraph(sprinklerPosParagraph, formatSprinklerPosList(), "Saved Positions")
		end
	end
	local function getNextSprinklerPosition(farm)
		if sprinklermode == "HumanoidRootPart" then
			local basePos = getGroundUnderPlayer()
			if not basePos then
				return nil
			end
			for _ = 1, 10 do
				local testPos = basePos + sprinklerLastOffset
				local projected, isValid = projectToSoil(testPos)
				if isValid and isPositionInPlantArea(projected) then
					return projected
				end
				local angle = math.random() * math.pi * 2
				local dist = 0.4 + math.random() * 0.8
				sprinklerLastOffset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
			end
			local projected, isValid = projectToSoil(basePos)
			return isValid and projected or basePos
		end
		if sprinklermode == "Random" then
			local pos = farm and GetRandomPlantingPosition(farm)
			if not pos then
				local cols = getPlantAreaColumns()
				if #cols > 0 then
					pos = getRandomPointInColumn(cols[math.random(1, #cols)])
				end
			end
			if pos then
				local projected, isValid = projectToSoil(pos)
				if isValid then
					return projected
				end
			end
			return pos
		end
		if sprinklermode == "Part" then
			if #savedSprinklerPositions == 0 then
				return nil
			end
			for _ = 1, #savedSprinklerPositions do
				local entry = savedSprinklerPositions[sprinklerPosListIndex]
				sprinklerPosListIndex = sprinklerPosListIndex + 1
				if sprinklerPosListIndex > #savedSprinklerPositions then
					sprinklerPosListIndex = 1
				end
				local projected, isValid = projectToSoil(entry)
				if isValid then
					return projected
				end
			end
			return nil
		end
		if sprinklermode == "Zone" then
			for _ = 1, 12 do
				local pos = getRandomPointInZone(sprinklerZoneMin, sprinklerZoneMax)
				if pos then
					return pos
				end
			end
		end
		return nil
	end
	local function startSprinklerPositionSelection()
		if sprinklerSelecting then
			cleanupSprinklerSelection()
			hub:Notify("Selection cancelled.")
			return
		end
		if sprinklermode ~= "Part" and sprinklermode ~= "Zone" then
			hub:Notify("Switch Mode to Part or Zone first.")
			return
		end
		sprinklerSelecting = true
		sprinklerZoneStartPos = nil
		local mouse = localPlayer:GetMouse()
		local part = Instance.new("Part")
		part.Size = Vector3.new(2, 0.4, 2)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.Neon
		part.Transparency = 0.35
		part.Parent = workspace
		sprinklerSelectionPart = part
		mouse.TargetFilter = part
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 0.45
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.OutlineTransparency = 0
		hl.Adornee = part
		hl.Parent = part
		sprinklerSelectionRunConn = RS.RenderStepped:Connect(function()
			if not part.Parent then
				cleanupSprinklerSelection()
				return
			end
			local projected, isValid = projectToSoil(mouse.Hit.Position)
			if sprinklermode == "Zone" and sprinklerZoneStartPos then
				local snapGrid = 2
				local startX = math.round(sprinklerZoneStartPos.X / snapGrid) * snapGrid
				local startZ = math.round(sprinklerZoneStartPos.Z / snapGrid) * snapGrid
				local currX = math.round(projected.X / snapGrid) * snapGrid
				local currZ = math.round(projected.Z / snapGrid) * snapGrid
				local minX = math.min(startX, currX) - 1
				local maxX = math.max(startX, currX) + 1
				local minZ = math.min(startZ, currZ) - 1
				local maxZ = math.max(startZ, currZ) + 1
				part.Size = Vector3.new(maxX - minX, 3, maxZ - minZ)
				part.Position = Vector3.new((minX + maxX) / 2, projected.Y + 1.5, (minZ + maxZ) / 2)
			else
				if sprinklermode == "Zone" then
					part.Size = Vector3.new(0.8, 0.8, 0.8)
				else
					part.Size = Vector3.new(2, 0.4, 2)
				end
				part.Position = projected
			end
			if isValid then
				part.Color = Color3.fromRGB(100, 200, 255)
				hl.FillColor = Color3.fromRGB(100, 200, 255)
			else
				part.Color = Color3.fromRGB(240, 80, 80)
				hl.FillColor = Color3.fromRGB(240, 80, 80)
			end
		end)
		sprinklerSelectionClickConn = mouse.Button1Down:Connect(function()
			local projected, isValid = projectToSoil(mouse.Hit.Position)
			if sprinklermode == "Zone" then
				if not sprinklerZoneStartPos then
					local snapGrid = 2
					sprinklerZoneStartPos = Vector3.new(
						math.round(projected.X / snapGrid) * snapGrid,
						projected.Y,
						math.round(projected.Z / snapGrid) * snapGrid
					)
					hub:Notify("First corner set. Click again to expand zone.")
				else
					local snapGrid = 2
					local startX = math.round(sprinklerZoneStartPos.X / snapGrid) * snapGrid
					local startZ = math.round(sprinklerZoneStartPos.Z / snapGrid) * snapGrid
					local currX = math.round(projected.X / snapGrid) * snapGrid
					local currZ = math.round(projected.Z / snapGrid) * snapGrid
					local minX = math.min(startX, currX) - 1
					local maxX = math.max(startX, currX) + 1
					local minZ = math.min(startZ, currZ) - 1
					local maxZ = math.max(startZ, currZ) + 1
					sprinklerZoneMin = Vector3.new(minX, projected.Y, minZ)
					sprinklerZoneMax = Vector3.new(maxX, projected.Y + 3, maxZ)
					cleanupSprinklerSelection()
					updateSprinklerPosDisplay()
					hub:Notify("Sprinkler zone saved.")
				end
			elseif isValid then
				savedSprinklerPositions[#savedSprinklerPositions + 1] = projected
				cleanupSprinklerSelection()
				updateSprinklerPosDisplay()
				hub:Notify("Sprinkler point saved.")
			else
				hub:Notify("Cannot place here.")
			end
		end)
		sprinklerSelectionKeyConn = UIS.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then
				cleanupSprinklerSelection()
				hub:Notify("Selection cancelled.")
			end
		end)
	end
	local function sprinklerallowed(plantName)
		if sprinklerfilterlist == "" then return sprinklerfiltertype == "Blacklist" end
		local set = {}
		for s in (sprinklerfilterlist .. ","):gmatch("([^,]+),") do
			set[s:match("^%s*(.-)%s*$")] = true
		end
		if sprinklerfiltertype == "Whitelist" then
			return set[plantName] == true
		else
			return set[plantName] ~= true
		end
	end
	local function getPlantAtPosition(pos, farm)
		local plants = farm and farm:FindFirstChild("Plants")
		if plants then
			for _, plant in plants:GetChildren() do
				local pPart = plant.PrimaryPart or plant:FindFirstChild("HarvestPart") or plant:FindFirstChildWhichIsA("BasePart", true)
				if pPart then
					local dx = pPart.Position.X - pos.X
					local dz = pPart.Position.Z - pos.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					if dist < 6 then
						return plant
					end
				else
				end
			end
		else
		end
		return nil
	end
	local function tryPlaceSprinkler(Networking, targetPos, sprinklerName, tool, plotId, farm)
		targetPos = raycastPlantAreaPosition(targetPos, farm)
		if isTooCloseToSprinklerStack(farm, targetPos) then
			return false
		end
		if sprinklernoduplicates and isPositionCoveredBySprinkler(farm, targetPos) then
			return false
		end
		local ok = pcall(function()
			Networking.Place.PlaceSprinkler:Fire(targetPos, sprinklerName, tool, tonumber(plotId))
		end)
		if ok then
			task.wait(0.1)
		end
		return ok
	end
	local function dosprinkler()
		if sprinklerlist == "" then return end
		local netMod = findModule("Networking")
		local Networking = netMod and safeRequire(netMod)
		if not Networking or not Networking.Place or not Networking.Place.PlaceSprinkler then return end
		local bp = localPlayer:FindFirstChildOfClass("Backpack")
		local char = localPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not hum then return end
		local plotId = localPlayer:GetAttribute("PlotId")
		if not plotId then return end
		local farm = getPlayerFarm()
		if not farm then return end
		for s in (sprinklerlist .. ","):gmatch("([^,]+),") do
			local name = s:match("^%s*(.-)%s*$")
			local tool = char:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
			if tool then
				local sprinklerName = tool:GetAttribute("Sprinkler") or name
				local needsUnequip = false
				if tool.Parent == bp then
					hum:EquipTool(tool)
					needsUnequip = true
					task.wait(0.25)
				end
				if sprinklermode == "On Plants" then
					local plantsFolder = farm:FindFirstChild("Plants")
					if plantsFolder then
						for _, plant in plantsFolder:GetChildren() do
							local seedName = plant:GetAttribute("SeedName") or ""
							if sprinklerallowed(seedName) then
								local pPart = plant.PrimaryPart or plant:FindFirstChild("HarvestPart") or plant:FindFirstChildWhichIsA("BasePart", true)
								if pPart then
									tryPlaceSprinkler(Networking, pPart.Position, sprinklerName, tool, plotId, farm)
								end
							end
						end
					end
					if sprinklerfilterlist == "" and sprinklerfiltertype == "Blacklist" then
						local dirtPlots = {}
						local imp = farm:FindFirstChild("Important", true)
						local locs = imp and imp:FindFirstChild("Plant_Locations")
						if locs then
							for _, part in locs:GetChildren() do
								if part:IsA("BasePart") and part.Name == "Can_Plant" then
									table.insert(dirtPlots, part)
								end
							end
						end
						if #dirtPlots == 0 then
							for _, child in farm:GetDescendants() do
								if child:IsA("BasePart") and (child.Name == "PlantArea" or child.Name:find("PlantArea") or game:GetService("CollectionService"):HasTag(child, "PlantArea")) then
									table.insert(dirtPlots, child)
								end
							end
						end
						for _, plot in dirtPlots do
							tryPlaceSprinkler(Networking, plot.Position, sprinklerName, tool, plotId, farm)
						end
					end
				else
					local targetPos = getNextSprinklerPosition(farm)
					if targetPos and (sprinklermode == "Random" or isPositionInPlantArea(targetPos)) then
						tryPlaceSprinkler(Networking, targetPos, sprinklerName, tool, plotId, farm)
					end
				end
				if needsUnequip and tool.Parent == char then
					tool.Parent = bp
				end
			end
		end
	end
	function updateSprinklerPosVisibility()
		updateSprinklerPosDisplay()
	end
	hub:CreateModule("Main", {
		name = "Auto Sprinkler",
		on = false,
		bind = "None",
		desc = "Place sprinklers by filter.",
		callback = function(enabled)
			sprinklerrunning = enabled
			if enabled then
				task.spawn(function()
					while sprinklerrunning do
						pcall(dosprinkler)
						task.wait(sprinklerdelay)
					end
				end)
			else
				cleanupSprinklerSelection()
			end
		end,
		opts = {
			{type = "slider", label = "Use Interval", value = 5, min = 1, max = 60, suffix = "s", callback = function(value)
				sprinklerdelay = value
			end},
			{type = "dropdown", label = "Mode", value = "On Plants", list = {"On Plants", "Random", "HumanoidRootPart", "Part", "Zone"}, callback = function(value)
				sprinklermode = value
				if sprinklermode ~= "Part" and sprinklermode ~= "Zone" then
					cleanupSprinklerSelection()
				end
				updateSprinklerPosDisplay()
			end},
			{type = "paragraph", title = "Saved Positions", content = "Loading...", onCreate = function(widget)
				sprinklerPosParagraph = widget
				updateSprinklerPosDisplay()
			end},
			{type = "button", label = "Add Point / Select Zone", callback = startSprinklerPositionSelection},
			{type = "button", label = "Clear Saved", callback = function()
				table.clear(savedSprinklerPositions)
				sprinklerZoneMin = nil
				sprinklerZoneMax = nil
				sprinklerPosListIndex = 1
				updateSprinklerPosDisplay()
				hub:Notify("Saved sprinkler data cleared.")
			end},
			{type = "checkbox", label = "No Duplicates (Check Range)", value = true, callback = function(value)
				sprinklernoduplicates = value
			end},
			{type = "multiselect", label = "Select Sprinklers", value = "", list = sprinklerTypeList, callback = function(value)
				sprinklerlist = value
			end},
			{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
				sprinklerfiltertype = value
			end},
			{type = "multiselect", label = "Filter Plants", value = "None", list = gameLists.plants, callback = function(value)
				sprinklerfilterlist = value
			end},
		}
	})
end
do
sellrunning = false
selldelay = 1
sellmode = "Default"
local function getsellpacket()
	local netMod = findModule("Networking")
	local Networking = netMod and safeRequire(netMod)
	if Networking then
		local sellMethod = nil
		for _, category in pairs(Networking) do
			if typeof(category) == "table" then
				for name, method in pairs(category) do
					if typeof(name) == "string" and name:lower():find("sell") and typeof(method) == "table" and method.Serialize then
						sellMethod = method
						break
					end
				end
			end
			if sellMethod then break end
		end
		if sellMethod then
			local ok, paramsBuf = pcall(function() return sellMethod:Serialize() end)
			if ok and paramsBuf then
				local finalBuf = buffer.create(2 + buffer.len(paramsBuf))
				buffer.writeu16(finalBuf, 0, sellMethod.Id)
				buffer.copy(finalBuf, 2, paramsBuf, 0, buffer.len(paramsBuf))
				return finalBuf
			end
		end
	end
	local sellId = sellev:GetAttribute("Sell")
		or sellev:GetAttribute("SellFruits")
		or sellev:GetAttribute("SellAll")
		or sellev:GetAttribute("SellCrops")
	if not sellId then
		for attrName, val in pairs(sellev:GetAttributes()) do
			if attrName:lower():find("sell") then
				sellId = val
				break
			end
		end
	end
	sellId = sellId or 175
	local buf = buffer.create(3)
	buffer.writeu16(buf, 0, sellId)
	buffer.writeu8(buf, 2, 21)
	return buf
end
sellonpeak = false
sellminprice = 0
function getBackpackFruits()
	local items = {}
	local bp = localPlayer:FindFirstChild("Backpack")
	if bp then
		for _, child in bp:GetChildren() do
			local fruitName = child:GetAttribute("FruitName") or child:GetAttribute("Fruit")
			if fruitName or child:GetAttribute("HarvestedFruit") or child:GetAttribute("FruitProxy") then
				table.insert(items, {
					tool = child,
					fruitName = fruitName or child.Name:gsub("%[.-%]", ""):match("^%s*(.-)%s*$"),
					fruitId = child:GetAttribute("Id"),
				})
			end
		end
	end
	local char = localPlayer.Character
	if char then
		for _, child in char:GetChildren() do
			local fruitName = child:GetAttribute("FruitName") or child:GetAttribute("Fruit")
			if fruitName or child:GetAttribute("HarvestedFruit") or child:GetAttribute("FruitProxy") then
				table.insert(items, {
					tool = child,
					fruitName = fruitName or child.Name:gsub("%[.-%]", ""):match("^%s*(.-)%s*$"),
					fruitId = child:GetAttribute("Id"),
				})
			end
		end
	end
	return items
end
usedailydeal = false
function dosell()
	local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	if usedailydeal then
		local deal = Networking.NPCS.CheckDailyDeal:Fire()
		if deal and deal.Available then
			pcall(function() Networking.NPCS.UseDailyDealAll:Fire() end)
		end
	end
	if sellonpeak then
		local items = getBackpackFruits()
		for _, item in items do
			local tool = item.tool
			if item.fruitId and tool then
				local fruitName = item.fruitName
				local mutation = tool:GetAttribute("Mutation") or "None"
				local sizeMulti = tonumber(tool:GetAttribute("Weight")) or tonumber(tool:GetAttribute("SizeMultiplier")) or 1
				local price = calcGamePrice(fruitName, sizeMulti, mutation, tonumber(tool:GetAttribute("DecayAlpha")) or 0)
				if price >= sellminprice then
					pcall(function() Networking.NPCS.SellFruit:Fire(item.fruitId) end)
				end
			end
		end
	else
		local pk = getsellpacket()
		if pk then
			pcall(function() sellev:FireServer(pk) end)
		end
	end
end
function isinvfull()
	local current = #getInventoryItems()
	local capacity = localPlayer:GetAttribute("MaxFruitCapacity") or 100
	return current >= tonumber(capacity)
end
hub:CreateModule("Main", {
	name = "Auto Sell",
	on = false,
	bind = "None",
	desc = "Auto sell crops.",
	callback = function(enabled)
		sellrunning = enabled
		if enabled then
			task.spawn(function()
				while sellrunning do
					if sellmode ~= "Max Inventory" or isinvfull() then
						pcall(dosell)
					end
					task.wait(selldelay)
				end
			end)
		end
	end,
	opts = {
		{type = "dropdown", label = "Mode", value = "Default", list = {"Default", "Max Inventory"}, callback = function(value)
			sellmode = value
		end},
		{type = "checkbox", label = "Use Daily Deal", value = false, callback = function(value)
			usedailydeal = value
		end},
		{type = "checkbox", label = "Sell on Min Price", value = false, callback = function(value)
			sellonpeak = value
		end},
		{type = "textbox", label = "Min Price (coins)", value = "0", placeholder = "e.g. 50000", callback = function(value)
			sellminprice = tonumber(value) or 0
		end},
		{type = "slider", label = "Sell Delay", value = 1, min = 1, max = 60, suffix = "s", callback = function(value)
			selldelay = value
		end},
		{type = "button", label = "Sell Now", callback = function()
			dosell()
		end},
	}
})
doubleornothingrunning = false
doubleornothingtarget = 2
doubleornothingdelay = 1
doubleornothingmaxinv = false
doubleornothingactive = false

function dodoubleornothing()
	if doubleornothingactive then return end
	doubleornothingactive = true
	local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	if doubleornothingmaxinv and not isinvfull() then
		doubleornothingactive = false
		return
	end
	local items = getInventoryItems()
	if #items == 0 then
		doubleornothingactive = false
		return
	end
	local roll = nil
	pcall(function() roll = Networking.NPCS.DoubleOrNothing:Fire() end)
	if roll and roll.Won then
		local currentWins = roll.Wins or 1
		hub:Notify("Double or Nothing Won! Wins: " .. currentWins)
		while currentWins < doubleornothingtarget and doubleornothingrunning do
			task.wait(doubleornothingdelay)
			if not doubleornothingrunning then break end
			local nextRoll = nil
			pcall(function() nextRoll = Networking.NPCS.DoubleOrNothing:Fire() end)
			if nextRoll and nextRoll.Won then
				currentWins = nextRoll.Wins or (currentWins + 1)
				hub:Notify("Double or Nothing Won! Wins: " .. currentWins)
			else
				hub:Notify("Double or Nothing Busted! Lost all crops.")
				currentWins = 0
				break
			end
		end
		if currentWins > 0 then
			pcall(function() Networking.NPCS.CashOutDoubleOrNothing:Fire() end)
			hub:Notify("Successfully cashed out Double or Nothing!")
		end
	end
	doubleornothingactive = false
end

hub:CreateModule("Main", {
	name = "Auto Double or Nothing",
	on = false,
	bind = "None",
	desc = "Auto Double or Nothing.",
	callback = function(enabled)
		doubleornothingrunning = enabled
		if enabled then
			task.spawn(function()
				while doubleornothingrunning do
					pcall(dodoubleornothing)
					task.wait(1)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Target Streak Wins", value = 2, min = 1, max = 5, suffix = " wins", callback = function(value)
			doubleornothingtarget = value
		end},
		{type = "checkbox", label = "Max Inventory Only", value = false, callback = function(value)
			doubleornothingmaxinv = value
		end},
		{type = "slider", label = "Roll Delay", value = 1, min = 1, max = 15, suffix = "s", callback = function(value)
			doubleornothingdelay = value
		end},
	}
})

shovelaurarunning = false
shovelaurarange = 15
shovelauradelay = 0.5
shovelauraonlyplot = true
shovelauraswing = true
shovelauraactive = false

function findShovel()
	local bp = localPlayer:FindFirstChild("Backpack")
	local char = localPlayer.Character
	if char then
		for _, child in char:GetChildren() do
			if child:IsA("Tool") and child.Name:lower():find("shovel") then
				return child
			end
		end
	end
	if bp then
		for _, child in bp:GetChildren() do
			if child:IsA("Tool") and child.Name:lower():find("shovel") then
				return child
			end
		end
	end
	return nil
end

function doshovelaura()
	if shovelauraactive then return end
	shovelauraactive = true
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		shovelauraactive = false
		return
	end
	local shovel = findShovel()
	if not shovel then
		shovelauraactive = false
		return
	end
	local farm = getPlayerFarm()
	local farmCenter = farm and (farm:FindFirstChild("PlotSizeReference") or farm:FindFirstChild("SpawnPoint") or farm:FindFirstChildWhichIsA("BasePart", true))
	local targets = {}
	for _, player in game.Players:GetPlayers() do
		if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local targetHrp = player.Character.HumanoidRootPart
			local dist = (targetHrp.Position - hrp.Position).Magnitude
			if dist <= shovelaurarange then
				local allowed = true
				if shovelauraonlyplot then
					if farmCenter then
						local distToPlot = (targetHrp.Position - farmCenter.Position).Magnitude
						if distToPlot > 120 then
							allowed = false
						end
					else
						allowed = false
					end
				end
				if allowed then
					table.insert(targets, player)
				end
			end
		end
	end
	if #targets > 0 then
		local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
		if shovel.Parent ~= char then
			hum:EquipTool(shovel)
			task.wait(0.15)
		end
		for _, target in targets do
			if not shovelaurarunning then break end
			if shovelauraswing then
				pcall(function() Networking.Shovel.SwingShovel:Fire(shovel) end)
			end
			pcall(function() Networking.Shovel.HitPlayer:Fire(target.UserId) end)
		end
	end
	shovelauraactive = false
end

hub:CreateModule("Main", {
	name = "Shovel Aura",
	on = false,
	bind = "None",
	desc = "Shovel aura on nearby players.",
	callback = function(enabled)
		shovelaurarunning = enabled
		if enabled then
			task.spawn(function()
				while shovelaurarunning do
					pcall(doshovelaura)
					task.wait(shovelauradelay)
				end
				local char = localPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local bp = localPlayer:FindFirstChild("Backpack")
				if hum and bp then
					local shovel = char and char:FindFirstChild(function(c) return c:IsA("Tool") and c.Name:lower():find("shovel") end)
					if shovel then
						shovel.Parent = bp
					end
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Aura Range", value = 15, min = 5, max = 30, suffix = " studs", callback = function(value)
			shovelaurarange = value
		end},
		{type = "slider", label = "Attack Speed Delay", value = 5, min = 1, max = 20, suffix = "ds", callback = function(value)
			shovelauradelay = value / 10
		end},
		{type = "checkbox", label = "Only on My Plot", value = true, callback = function(value)
			shovelauraonlyplot = value
		end},
		{type = "checkbox", label = "Visual Swing Effect", value = true, callback = function(value)
			shovelauraswing = value
		end},
	}
})

baseprotectorrunning = false
baseprotectoractive = false
baseprotectorconn = nil

function protectBase(thief)
	if not baseprotectorrunning or baseprotectoractive then return end
	if not thief or not thief:IsA("Player") or thief == localPlayer then return end
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	local thiefChar = thief.Character
	local thiefHrp = thiefChar and thiefChar:FindFirstChild("HumanoidRootPart")
	if not thiefHrp then return end
	local farm = getPlayerFarm()
	if not farm then return end
	local farmCenter = farm:FindFirstChild("PlotSizeReference") or farm:FindFirstChild("SpawnPoint") or farm:FindFirstChildWhichIsA("BasePart", true)
	if not farmCenter then return end
	local distToFarm = (thiefHrp.Position - farmCenter.Position).Magnitude
	if distToFarm > 100 then return end
	local shovel = findShovel()
	if not shovel then return end
	baseprotectoractive = true
	hub:Notify("Base Protector: Detecting thief " .. thief.DisplayName .. "! Neutralizing...")
	task.spawn(function()
		local startCF = hrp.CFrame
		local targetCF = thiefHrp.CFrame + Vector3.new(0, 1.5, 0)
		local needsUnequip = false
		if shovel.Parent ~= char then
			hum:EquipTool(shovel)
			needsUnequip = true
			task.wait(0.1)
		end
		hrp.CFrame = targetCF
		hrp.Velocity = Vector3.zero
		task.wait(0.08)
		local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
		pcall(function() Networking.Shovel.SwingShovel:Fire(shovel) end)
		pcall(function() Networking.Shovel.HitPlayer:Fire(thief.UserId) end)
		task.wait(0.05)
		hrp.CFrame = startCF
		hrp.Velocity = Vector3.zero
		if needsUnequip and shovel.Parent == char then
			shovel.Parent = localPlayer:FindFirstChild("Backpack")
		end
		task.wait(1.0)
		baseprotectoractive = false
	end)
end

function toggleBaseProtector(val)
	baseprotectorrunning = val
	if baseprotectorconn then
		baseprotectorconn:Disconnect()
		baseprotectorconn = nil
	end
	if val then
		local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
		baseprotectorconn = Networking.Steal.StealStarted.OnClientEvent:Connect(protectBase)
	end
end

hub:CreateModule("Main", {
	name = "Base Protector",
	on = false,
	bind = "None",
	desc = "Auto hit thieves.",
	callback = function(enabled)
		toggleBaseProtector(enabled)
	end,
	opts = {}
})

autowaterrunning = false
autowaterdelay = 5
autowateractive = false
autowaterfiltertype = "Whitelist"
autowaterfilterlist = "None"
autowaternoduplicates = true
autowaterskipmature = false
autowaterskipallfruitsgrown = false
autowaterskipboost = false
autowatercanselect = "Auto (Any)"

local wateringCanNameListCache = nil
local wateringCanPriority = {
	["Super Syrup Watering Can"] = 1,
	["Super Watering Can"] = 2,
	["Syrup Watering Can"] = 3,
	["Common Watering Can"] = 4,
}

local function getWateringCanNameList()
	if wateringCanNameListCache then
		return wateringCanNameListCache
	end
	local names = {}
	local mod = findModule("WateringcanData")
	local data = mod and safeRequire(mod)
	if data then
		for _, entry in ipairs(data) do
			if entry.Name then
				table.insert(names, entry.Name)
			end
		end
	end
	if #names == 0 then
		names = {
			"Common Watering Can",
			"Super Watering Can",
			"Syrup Watering Can",
			"Super Syrup Watering Can",
		}
	end
	wateringCanNameListCache = names
	return names
end

local function getWateringCanSelectList()
	local list = { "Auto (Any)", "Best Available" }
	for _, name in ipairs(getWateringCanNameList()) do
		table.insert(list, name)
	end
	return list
end

function findWateringCan(preferred)
	preferred = preferred or autowatercanselect
	local candidates = {}
	local function collect(container)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("WateringCan") then
				table.insert(candidates, child)
			end
		end
	end
	collect(localPlayer.Character)
	collect(localPlayer:FindFirstChild("Backpack"))
	if #candidates == 0 then
		return nil
	end
	if preferred == "Best Available" then
		table.sort(candidates, function(a, b)
			local nameA = a:GetAttribute("WateringCan") or a.Name
			local nameB = b:GetAttribute("WateringCan") or b.Name
			return (wateringCanPriority[nameA] or 99) < (wateringCanPriority[nameB] or 99)
		end)
		return candidates[1]
	end
	if preferred and preferred ~= "" and preferred ~= "Auto (Any)" then
		for _, tool in candidates do
			local canName = tool:GetAttribute("WateringCan") or tool.Name
			if canName == preferred or tool.Name == preferred then
				return tool
			end
		end
		return nil
	end
	return candidates[1]
end

function autowaterallowed(seedName)
	local set = {}
	for name in (autowaterfilterlist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if autowaterfilterlist == "" or autowaterfilterlist == "None" then
		return autowaterfiltertype ~= "Whitelist"
	end
	if autowaterfiltertype == "Whitelist" then
		return set[seedName] == true
	end
	return set[seedName] == nil
end

function iscoveredbysprinkler(plantPos)
	local farm = getPlayerFarm()
	return isPositionCoveredBySprinkler(farm, plantPos)
end

function doautowater()
	if autowateractive then return end
	autowateractive = true
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then 
		autowateractive = false
		return 
	end
	local wateringCan = findWateringCan()
	if not wateringCan then 
		autowateractive = false
		return 
	end
	local canName = wateringCan:GetAttribute("WateringCan")
	local farm = getPlayerFarm()
	local plants = farm and farm:FindFirstChild("Plants")
	if not plants then 
		autowateractive = false
		return 
	end
	local children = plants:GetChildren()
	if #children == 0 then 
		autowateractive = false
		return 
	end
	local needsUnequip = false
	local equipped = false
	local netMod = findModule("Networking")
	local Networking = netMod and safeRequire(netMod)
	if not Networking or not Networking.WateringCan or not Networking.WateringCan.UseWateringCan then
		autowateractive = false
		return
	end
	for _, plant in children do
		if not autowaterrunning then break end
		local seedName = getseedname(plant)
		if seedName and autowaterallowed(seedName) and shouldAutoWaterPlant(plant) then
			local rp = plant:FindFirstChild("RootPart") or plant.PrimaryPart or plant:FindFirstChildWhichIsA("BasePart")
			if rp then
				local waterPos = raycastPlantAreaPosition(rp.Position, farm)
				if not autowaternoduplicates or not iscoveredbysprinkler(waterPos) then
					if not equipped then
						if wateringCan.Parent ~= char then
							hum:EquipTool(wateringCan)
							needsUnequip = true
							task.wait(0.1)
						end
						equipped = true
					end
					pcall(function()
						Networking.WateringCan.UseWateringCan:Fire(waterPos - Vector3.new(0, 0.3, 0), canName, wateringCan)
					end)
					task.wait(0.55)
				end
			end
		end
	end
	if needsUnequip and wateringCan.Parent == char then
		wateringCan.Parent = localPlayer:FindFirstChild("Backpack")
	end
	autowateractive = false
end

hub:CreateModule("Main", {
	name = "Auto Watering Can",
	on = false,
	bind = "None",
	desc = "Auto water plants. Waters mature plants by default to boost fruit growth.",
	callback = function(enabled)
		autowaterrunning = enabled
		if enabled then
			task.spawn(function()
				while autowaterrunning do
					pcall(doautowater)
					task.wait(autowaterdelay)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Watering Delay", value = 5, min = 1, max = 30, suffix = "s", callback = function(value)
			autowaterdelay = value
		end},
		{type = "dropdown", label = "Watering Can", value = "Auto (Any)", list = getWateringCanSelectList(), callback = function(value)
			autowatercanselect = value
		end},
		{type = "checkbox", label = "Skip If All Fruits Grown", value = false, callback = function(value)
			autowaterskipallfruitsgrown = value
		end},
		{type = "checkbox", label = "Skip Mature Plants", value = false, callback = function(value)
			autowaterskipmature = value
		end},
		{type = "checkbox", label = "Skip Active Boost", value = false, callback = function(value)
			autowaterskipboost = value
		end},
		{type = "checkbox", label = "No Duplicates (Check Sprinklers)", value = true, callback = function(value)
			autowaternoduplicates = value
		end},
		{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			autowaterfiltertype = value
		end},
		{type = "multiselect", label = "Filter Plants", value = "None", list = gameLists.plants, callback = function(value)
			autowaterfilterlist = value
		end},
	}
})

end
do
local claimrunning = false
local claimspeed = 80
local claimMoveMode = "Teleport"
local claimAutoReturn = true
local claimLoopDelay = 0.35
local claimSeedFilter = ""
local claimSeedFilterType = "Whitelist"

local function getSeedSpawnPrompt(inst)
	if not inst then
		return nil
	end
	if inst:IsA("ProximityPrompt") then
		return inst
	end
	local claimPrompt = inst:FindFirstChild("ClaimPrompt", true)
	if claimPrompt and claimPrompt:IsA("ProximityPrompt") then
		return claimPrompt
	end
	return findDescendantOfClass(inst, "ProximityPrompt")
end

local function getSeedSpawnPart(inst)
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or findDescendantOfClass(inst, "BasePart")
	end
	return nil
end

local function getSeedSpawnFolders()
	local folders = {}
	local map = workspace:FindFirstChild("Map")
	if not map then
		return folders
	end
	for _, name in {"SeedPackSpawnServerLocations", "SeedPackSpawnClient"} do
		local folder = map:FindFirstChild(name)
		if folder then
			table.insert(folders, folder)
		end
	end
	return folders
end

local function collectClaimableSeedSpawns()
	local targets = {}
	local seen = {}
	local function addTarget(rootInst, part, prompt)
		if not part or not prompt or not prompt.Parent or prompt.Enabled == false then
			return
		end
		local key = tostring(part:GetFullName()) .. "|" .. tostring(prompt:GetFullName())
		if seen[key] then
			return
		end
		local label = resolveEventSeedLabel(rootInst)
			or resolveEventSeedLabel(part)
			or resolveEventSeedLabel(prompt.Parent)
			or labelFromPrompt(prompt)
		if not label or not csvMatchesFilter(claimSeedFilter, label, claimSeedFilterType) then
			return
		end
		seen[key] = true
		table.insert(targets, {
			part = part,
			prompt = prompt,
			label = label,
			tier = EVENT_SEED_PRIORITY[label] or EVENT_SEED_PRIORITY[label:gsub(" Seed$", "")] or 9,
		})
	end
	for _, spawnLocs in getSeedSpawnFolders() do
		for _, child in spawnLocs:GetChildren() do
			local part = getSeedSpawnPart(child)
			local prompt = getSeedSpawnPrompt(child)
			addTarget(child, part, prompt)
			for _, desc in child:GetDescendants() do
				if desc:IsA("ProximityPrompt") and desc.Enabled ~= false then
					local promptPart = getSeedSpawnPart(desc.Parent) or (desc.Parent:IsA("BasePart") and desc.Parent)
					addTarget(child, promptPart, desc)
				end
			end
		end
	end
	table.sort(targets, function(a, b)
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.label < b.label
	end)
	return targets
end

local function claimSeedPrompt(prompt)
	if not prompt or not prompt.Parent then
		return false
	end
	local oldHold = prompt.HoldDuration
	prompt.HoldDuration = 0
	local ok = firePrompt(prompt)
	prompt.HoldDuration = oldHold
	return ok
end

local function moveClaimToPosition(hrp, hum, targetPos)
	if not hrp or not targetPos then
		return false
	end
	if claimMoveMode == "Teleport" then
		return safeTeleport(CFrame.new(targetPos))
	end
	local dist = (targetPos - hrp.Position).Magnitude
	if dist < 3 then
		return true
	end
	local duration = math.max(0.12, dist / math.max(claimspeed, 10))
	if hum then hum.PlatformStand = true end
	local bv = hrp:FindFirstChild("ClaimSeedBV") or Instance.new("BodyVelocity")
	bv.Name = "ClaimSeedBV"
	bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bv.Parent = hrp
	local bg = hrp:FindFirstChild("ClaimSeedBG") or Instance.new("BodyGyro")
	bg.Name = "ClaimSeedBG"
	bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	bg.Parent = hrp
	local tween = TS:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
	local done = false
	local conn = tween.Completed:Connect(function()
		done = true
	end)
	tween:Play()
	while not done and claimrunning do
		task.wait(0.05)
	end
	conn:Disconnect()
	if bv then bv:Destroy() end
	if bg then bg:Destroy() end
	if hum then hum.PlatformStand = false end
	return claimrunning
end

local function cleanupClaimMovement(hrp, hum)
	if hum then hum.PlatformStand = false end
	if hrp then
		local bv = hrp:FindFirstChild("ClaimSeedBV")
		if bv then bv:Destroy() end
		local bg = hrp:FindFirstChild("ClaimSeedBG")
		if bg then bg:Destroy() end
	end
end

hub:CreateModule("Main", {
	name = "Auto Claim Seed",
	on = false,
	bind = "None",
	desc = "Claim event seeds (Gold, Rainbow, Mega).",
	callback = function(enabled)
		claimrunning = enabled
		if enabled then
			task.spawn(function()
				local returnCF = nil
				while claimrunning do
					local char = localPlayer.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local targets = collectClaimableSeedSpawns()
					if hrp and hum and #targets > 0 then
						if not returnCF then
							returnCF = hrp.CFrame
						end
						for _, target in ipairs(targets) do
							if not claimrunning then
								break
							end
							local part = target.part
							local prompt = target.prompt
							if part and part.Parent and prompt and prompt.Parent then
								local targetPos = part.Position
								moveClaimToPosition(hrp, hum, targetPos)
								task.wait(0.12)
								char = localPlayer.Character
								hrp = char and char:FindFirstChild("HumanoidRootPart")
								hum = char and char:FindFirstChildOfClass("Humanoid")
								if claimrunning and hrp then
									claimSeedPrompt(prompt)
									task.wait(0.25)
								end
							end
						end
					elseif claimAutoReturn and returnCF and hrp and hum then
						moveClaimToPosition(hrp, hum, returnCF.Position)
						returnCF = nil
					end
					cleanupClaimMovement(hrp, hum)
					task.wait(claimLoopDelay)
				end
				local endChar = localPlayer.Character
				cleanupClaimMovement(
					endChar and endChar:FindFirstChild("HumanoidRootPart"),
					endChar and endChar:FindFirstChildOfClass("Humanoid")
				)
			end)
		end
	end,
	opts = {
		{type = "dropdown", label = "Move Mode", value = "Teleport", list = {"Teleport", "Fly"}, callback = function(value)
			claimMoveMode = value
		end},
		{type = "slider", label = "Fly Speed", value = 80, min = 10, max = 250, suffix = " studs/s", callback = function(value)
			claimspeed = value
		end},
		{type = "slider", label = "Loop Delay", value = 4, min = 0, max = 30, suffix = " ds", callback = function(value)
			claimLoopDelay = value / 10
		end},
		{type = "checkbox", label = "Return When Idle", value = true, callback = function(value)
			claimAutoReturn = value
		end},
		{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
			claimSeedFilterType = value
		end},
		{type = "multiselect", label = "Event Seeds", value = "Gold Seed,Rainbow Seed,Mega Seed", list = gameLists.eventSeeds, callback = function(value)
			claimSeedFilter = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "eventSeeds")
		end},
	}
})

local dropClaimRunning = false
local dropClaimMoveMode = "Teleport"
local dropClaimAutoReturn = true
local dropClaimLoopDelay = 0.25
local dropClaimFilter = ""
local dropClaimFilterType = "Whitelist"
local dropClaimMaxDistance = 200
local dropTypeList = {"Fruits", "Seeds", "Gears", "Cosmetics", "Crates", "Seed Packs", "Pets", "Other"}

local function canPickupDropModel(model)
	if not model or not model:IsA("Model") or not model.Parent then
		return false
	end
	if model:GetAttribute("OwnerRestricted") == true and model:GetAttribute("DroppedBy") ~= localPlayer.UserId then
		return false
	end
	return true
end

local function collectPickupDrops(hrp)
	if not hrp then
		return {}
	end
	local folder = workspace:FindFirstChild("DroppedItems")
	if not folder then
		return {}
	end
	local drops = {}
	for _, model in folder:GetChildren() do
		if canPickupDropModel(model) then
			local prompt, anchor = getDropPickupTarget(model)
			if prompt and prompt.Enabled ~= false then
				local pos = nil
				if anchor and anchor:IsA("BasePart") then
					pos = anchor.Position
				else
					pos = getModelPosition(model)
				end
				if pos then
					local dist = (hrp.Position - pos).Magnitude
					if dist <= dropClaimMaxDistance then
						local dropType, dropName = classifyWorldDrop(model)
						if csvMatchesFilter(dropClaimFilter, dropType, dropClaimFilterType) then
							table.insert(drops, {
								model = model,
								prompt = prompt,
								anchor = anchor,
								pos = pos,
								type = dropType,
								name = dropName,
								label = dropType .. " · " .. tostring(dropName),
								dist = dist,
							})
						end
					end
				end
			end
		end
	end
	table.sort(drops, function(a, b)
		return a.dist < b.dist
	end)
	return drops
end

local function cleanupDropClaimMovement(hrp, hum)
	if hum then
		hum.PlatformStand = false
	end
	if hrp then
		local bv = hrp:FindFirstChild("DropClaimBV")
		if bv then
			bv:Destroy()
		end
		local bg = hrp:FindFirstChild("DropClaimBG")
		if bg then
			bg:Destroy()
		end
	end
end

local function moveDropClaimToPosition(hrp, hum, targetPos, runningFlag)
	if not hrp or not targetPos then
		return false
	end
	if dropClaimMoveMode == "Teleport" then
		return safeTeleport(CFrame.new(targetPos))
	end
	local dist = (targetPos - hrp.Position).Magnitude
	if dist < 3 then
		return true
	end
	local duration = math.max(0.12, dist / math.max(claimspeed, 10))
	if hum then
		hum.PlatformStand = true
	end
	local bv = hrp:FindFirstChild("DropClaimBV") or Instance.new("BodyVelocity")
	bv.Name = "DropClaimBV"
	bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bv.Parent = hrp
	local bg = hrp:FindFirstChild("DropClaimBG") or Instance.new("BodyGyro")
	bg.Name = "DropClaimBG"
	bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	bg.Parent = hrp
	local tween = TS:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
	local done = false
	local conn = tween.Completed:Connect(function()
		done = true
	end)
	tween:Play()
	while not done and runningFlag() do
		task.wait(0.05)
	end
	conn:Disconnect()
	cleanupDropClaimMovement(hrp, hum)
	return runningFlag()
end

local function tryPickupDrop(drop)
	if not drop or not drop.prompt or not drop.prompt.Parent then
		return false
	end
	local prompt = drop.prompt
	local oldHold = prompt.HoldDuration
	prompt.HoldDuration = 0
	firePrompt(prompt)
	prompt.HoldDuration = oldHold
	task.wait(0.12)
	return not (drop.model and drop.model.Parent)
end

hub:CreateModule("Main", {
	name = "Auto Claim Drops",
	on = false,
	bind = "None",
	desc = "Pick up world drops.",
	callback = function(enabled)
		dropClaimRunning = enabled
		if enabled then
			task.spawn(function()
				local returnCF = nil
				while dropClaimRunning do
					local char = localPlayer.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local drops = collectPickupDrops(hrp)
					if hrp and #drops > 0 then
						if not returnCF then
							returnCF = hrp.CFrame
						end
						for _, drop in drops do
							if not dropClaimRunning then
								break
							end
							if not drop.model.Parent then
								continue
							end
							moveDropClaimToPosition(hrp, hum, drop.pos + Vector3.new(0, 1.5, 0), function()
								return dropClaimRunning
							end)
							if tryPickupDrop(drop) then
								break
							end
							task.wait(0.05)
						end
					elseif dropClaimAutoReturn and returnCF and hrp then
						moveDropClaimToPosition(hrp, hum, returnCF.Position, function()
							return dropClaimRunning
						end)
						returnCF = nil
					end
					cleanupDropClaimMovement(hrp, hum)
					task.wait(dropClaimLoopDelay)
				end
				local endChar = localPlayer.Character
				cleanupDropClaimMovement(
					endChar and endChar:FindFirstChild("HumanoidRootPart"),
					endChar and endChar:FindFirstChildOfClass("Humanoid")
				)
			end)
		end
	end,
	opts = {
		{type = "dropdown", label = "Move Mode", value = "Teleport", list = {"Teleport", "Fly"}, callback = function(value)
			dropClaimMoveMode = value
		end},
		{type = "slider", label = "Fly Speed", value = 80, min = 10, max = 250, suffix = " studs/s", callback = function(value)
			claimspeed = value
		end},
		{type = "slider", label = "Loop Delay", value = 3, min = 0, max = 30, suffix = " ds", callback = function(value)
			dropClaimLoopDelay = value / 10
		end},
		{type = "checkbox", label = "Return When Idle", value = true, callback = function(value)
			dropClaimAutoReturn = value
		end},
		{type = "dropdown", label = "Drop Filter Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
			dropClaimFilterType = value
		end},
		{type = "multiselect", label = "Target Drop Types", value = "", list = dropTypeList, callback = function(value)
			dropClaimFilter = value
		end},
	}
})
end
do
local plantrunning = false
local plantdelay = 0.1
local plantpos = "Random"
local selectedseed = "Carrot"
local savedPlantPositions = {}
local plantPosParagraph = nil
local plantPosListIndex = 1
local custompos = nil
local zoneStartPos = nil
local zoneMin = nil
local zoneMax = nil
local selecting = false
local selectionPart = nil
local selectionRunConn = nil
local selectionClickConn = nil
local selectionKeyConn = nil
local failedAttempts = 0
local lastOffset = Vector3.zero

local function makePlantPacket(pos, seedName)
	local netMod = findModule("Networking")
	local Networking = netMod and safeRequire(netMod)
	if Networking then
		local plantMethod = nil
		for _, category in pairs(Networking) do
			if typeof(category) == "table" then
				for name, method in pairs(category) do
					if typeof(name) == "string" and name:lower():find("plant") and typeof(method) == "table" and method.Serialize then
						plantMethod = method
						break
					end
				end
			end
			if plantMethod then break end
		end
		if plantMethod then
			local ok, paramsBuf = pcall(function() return plantMethod:Serialize(pos, seedName) end)
			if ok and paramsBuf then
				local finalBuf = buffer.create(2 + buffer.len(paramsBuf))
				buffer.writeu16(finalBuf, 0, plantMethod.Id)
				buffer.copy(finalBuf, 2, paramsBuf, 0, buffer.len(paramsBuf))
				return finalBuf
			end
		end
	end
	local plantId = sellev:GetAttribute("Plant")
		or sellev:GetAttribute("PlantSeed")
		or sellev:GetAttribute("PlantCrop")
	if not plantId then
		for attrName, val in pairs(sellev:GetAttributes()) do
			if attrName:lower():find("plant") then
				plantId = val
				break
			end
		end
	end
	plantId = plantId or 10
	local bufLen = 2 + 12 + 1 + #seedName
	local buf = buffer.create(bufLen)
	buffer.writeu16(buf, 0, plantId)
	buffer.writef32(buf, 2, pos.X)
	buffer.writef32(buf, 6, pos.Y)
	buffer.writef32(buf, 10, pos.Z)
	buffer.writeu8(buf, 14, #seedName)
	for i = 1, #seedName do
		buffer.writeu8(buf, 14 + i, string.byte(seedName, i))
	end
	return buf
end

local function findSeedTool(seedName)
	local backpack = localPlayer:FindFirstChild("Backpack")
	local character = localPlayer.Character
	local searchName = seedName:lower()
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and not child:IsA("Configuration") then
				local childName = child.Name
				if not childName:find("%[.-kg%]") then
					local childNameLower = childName:lower()
					if childNameLower == searchName or childNameLower:find(searchName, 1, true) then
						return child
					end
				end
			end
		end
	end
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and not child:IsA("Configuration") then
				local childName = child.Name
				if not childName:find("%[.-kg%]") then
					local childNameLower = childName:lower()
					if childNameLower == searchName or childNameLower:find(searchName, 1, true) then
						return child
					end
				end
			end
		end
	end
	return nil
end

local function formatPlantPosList()
	if plantpos == "Part" then
		if #savedPlantPositions == 0 then
			return "No saved points.\nUse Add Point to place one."
		end
		local lines = {}
		for i, pos in savedPlantPositions do
			lines[#lines + 1] = string.format("#%d: %.1f, %.1f, %.1f", i, pos.X, pos.Y, pos.Z)
		end
		return table.concat(lines, "\n")
	end
	if plantpos == "Zone" and zoneMin and zoneMax then
		return string.format(
			"Zone saved:\nX %.1f -> %.1f\nZ %.1f -> %.1f",
			zoneMin.X, zoneMax.X, zoneMin.Z, zoneMax.Z
		)
	end
	if plantpos == "HumanoidRootPart" then
		return "Plants at player position."
	end
	return "Uses random valid soil spots."
end

local function updatePlantPosDisplay()
	if plantPosParagraph then
		setHubParagraph(plantPosParagraph, formatPlantPosList(), "Saved Positions")
	end
end

local function getNextPlantPosition(farm)
	if plantpos == "HumanoidRootPart" then
		local basePos = getGroundUnderPlayer()
		if not basePos then
			return nil
		end
		for _ = 1, 10 do
			local testPos = basePos + lastOffset
			local projected, isValid = projectToSoil(testPos)
			if isValid and isPositionInPlantArea(projected) and not isPlantNear(projected, 1.2) then
				return projected
			end
			local angle = math.random() * math.pi * 2
			local dist = 0.4 + math.random() * 0.8
			lastOffset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		end
		local projected, isValid = projectToSoil(basePos)
		return isValid and projected or basePos
	end
	if plantpos == "Random" then
		local pos = farm and GetRandomPlantingPosition(farm)
		if not pos then
			local cols = getPlantAreaColumns()
			if #cols > 0 then
				pos = getRandomPointInColumn(cols[math.random(1, #cols)])
			end
		end
		if pos then
			local projected, isValid = projectToSoil(pos)
			if isValid then
				return projected
			end
		end
		return pos
	end
	if plantpos == "Part" then
		if #savedPlantPositions == 0 then
			return nil
		end
		for _ = 1, #savedPlantPositions do
			local entry = savedPlantPositions[plantPosListIndex]
			plantPosListIndex = plantPosListIndex + 1
			if plantPosListIndex > #savedPlantPositions then
				plantPosListIndex = 1
			end
			local projected, isValid = projectToSoil(entry)
			if isValid and not isPlantNear(projected, 1.2) then
				return projected
			end
		end
		return nil
	end
	if plantpos == "Zone" then
		for _ = 1, 12 do
			local pos = getRandomPointInZone(zoneMin, zoneMax)
			if pos and not isPlantNear(pos, 1.2) then
				return pos
			end
		end
	end
	return nil
end

local function cleanupSelection()
	if selectionClickConn then selectionClickConn:Disconnect() selectionClickConn = nil end
	if selectionRunConn then selectionRunConn:Disconnect() selectionRunConn = nil end
	if selectionKeyConn then selectionKeyConn:Disconnect() selectionKeyConn = nil end
	if selectionPart then
		selectionPart:Destroy()
		selectionPart = nil
	end
	zoneStartPos = nil
	local mouse = localPlayer:GetMouse()
	if mouse.TargetFilter == selectionPart then
		mouse.TargetFilter = nil
	end
	selecting = false
end

local function startPlantPositionSelection()
	if selecting then
		cleanupSelection()
		hub:Notify("Selection cancelled.")
		return
	end
	if plantpos ~= "Part" and plantpos ~= "Zone" then
		hub:Notify("Switch Plant Mode to Part or Zone first.")
		return
	end
	selecting = true
	zoneStartPos = nil
	local mouse = localPlayer:GetMouse()
	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 0.4, 2)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35
	part.Parent = workspace
	selectionPart = part
	mouse.TargetFilter = part
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.45
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.OutlineTransparency = 0
	hl.Adornee = part
	hl.Parent = part
	selectionRunConn = RS.RenderStepped:Connect(function()
		if not part.Parent then
			cleanupSelection()
			return
		end
		local projected, isValid = projectToSoil(mouse.Hit.Position)
		if plantpos == "Zone" and zoneStartPos then
			local snapGrid = 2
			local startX = math.round(zoneStartPos.X / snapGrid) * snapGrid
			local startZ = math.round(zoneStartPos.Z / snapGrid) * snapGrid
			local currX = math.round(projected.X / snapGrid) * snapGrid
			local currZ = math.round(projected.Z / snapGrid) * snapGrid
			local minX = math.min(startX, currX) - 1
			local maxX = math.max(startX, currX) + 1
			local minZ = math.min(startZ, currZ) - 1
			local maxZ = math.max(startZ, currZ) + 1
			part.Size = Vector3.new(maxX - minX, 3, maxZ - minZ)
			part.Position = Vector3.new((minX + maxX) / 2, projected.Y + 1.5, (minZ + maxZ) / 2)
		else
			if plantpos == "Zone" then
				part.Size = Vector3.new(0.8, 0.8, 0.8)
			else
				part.Size = Vector3.new(2, 0.4, 2)
			end
			part.Position = projected
		end
		if isValid then
			part.Color = Color3.fromRGB(80, 220, 100)
			hl.FillColor = Color3.fromRGB(80, 220, 100)
		else
			part.Color = Color3.fromRGB(240, 80, 80)
			hl.FillColor = Color3.fromRGB(240, 80, 80)
		end
	end)
	selectionClickConn = mouse.Button1Down:Connect(function()
		local projected, isValid = projectToSoil(mouse.Hit.Position)
		if plantpos == "Zone" then
			if not zoneStartPos then
				local snapGrid = 2
				zoneStartPos = Vector3.new(
					math.round(projected.X / snapGrid) * snapGrid,
					projected.Y,
					math.round(projected.Z / snapGrid) * snapGrid
				)
				hub:Notify("First corner set. Click again to expand zone.")
			else
				local snapGrid = 2
				local startX = math.round(zoneStartPos.X / snapGrid) * snapGrid
				local startZ = math.round(zoneStartPos.Z / snapGrid) * snapGrid
				local currX = math.round(projected.X / snapGrid) * snapGrid
				local currZ = math.round(projected.Z / snapGrid) * snapGrid
				local minX = math.min(startX, currX) - 1
				local maxX = math.max(startX, currX) + 1
				local minZ = math.min(startZ, currZ) - 1
				local maxZ = math.max(startZ, currZ) + 1
				zoneMin = Vector3.new(minX, projected.Y, minZ)
				zoneMax = Vector3.new(maxX, projected.Y + 3, maxZ)
				cleanupSelection()
				updatePlantPosDisplay()
				hub:Notify("Plant zone saved.")
			end
		elseif isValid then
			savedPlantPositions[#savedPlantPositions + 1] = projected
			custompos = projected
			cleanupSelection()
			updatePlantPosDisplay()
			hub:Notify("Plant point saved.")
		else
			hub:Notify("Cannot plant here.")
		end
	end)
	selectionKeyConn = UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.X then
			cleanupSelection()
			hub:Notify("Selection cancelled.")
		end
	end)
end

local function doplant()
	if selectedseed == "" or selectedseed == "None" then
		return
	end
	local farm = getPlayerFarm()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local seeds = {}
	for s in string.gmatch(selectedseed, "[^,%s]+") do
		table.insert(seeds, s)
	end
	if #seeds == 0 then return end
	local tool = nil
	local chosenSeed = nil
	local count = 0
	for _, seedName in seeds do
		local t = findSeedTool(seedName)
		if t then
			local seedCount = 0
			local bp = localPlayer:FindFirstChildOfClass("Backpack")
			if bp then
				local backpackTool = bp:FindFirstChild(t.Name)
				if backpackTool then
					local numVal = backpackTool:FindFirstChild("Numbers")
					seedCount = numVal and numVal.Value or 1
				end
			end
			if seedCount == 0 and t.Parent == character then
				local numVal = t:FindFirstChild("Numbers")
				seedCount = numVal and numVal.Value or 1
			end
			if seedCount > 0 then
				tool = t
				chosenSeed = seedName
				count = seedCount
				break
			end
		end
	end
	if not tool or count <= 0 then
		return
	end
	humanoid:EquipTool(tool)
	task.wait(0.15)
	for _ = 1, count do
		if not plantrunning then break end
		local pos = getNextPlantPosition(farm)
		if not pos then
			break
		end
		if plantpos ~= "Random" and not isPositionInPlantArea(pos) then
			continue
		end
		local pkt = makePlantPacket(pos, chosenSeed)
		pcall(function() sellev:FireServer(pkt, {tool}) end)
		if plantdelay > 0 then
			task.wait(plantdelay)
		end
	end
	humanoid:UnequipTools()
end

hub:CreateModule("Main", {
	name = "Auto Plant",
	on = false,
	bind = "None",
	desc = "Auto plant seeds.",
	callback = function(enabled)
		plantrunning = enabled
		if enabled then
			task.spawn(function()
				while plantrunning do
					pcall(doplant)
					task.wait(0.5)
				end
			end)
		else
			cleanupSelection()
		end
	end,
	opts = {
		{type = "multiselect", label = "Select Seeds", value = "", list = gameLists.seeds, callback = function(value)
			selectedseed = value
		end},
		{type = "dropdown", label = "Plant Mode", value = "Random", list = {"Random", "HumanoidRootPart", "Part", "Zone"}, callback = function(value)
			plantpos = value
			if plantpos ~= "Part" and plantpos ~= "Zone" then
				cleanupSelection()
			end
			updatePlantPosDisplay()
		end},
		{type = "paragraph", title = "Saved Positions", content = "Loading...", onCreate = function(widget)
			plantPosParagraph = widget
			updatePlantPosDisplay()
		end},
		{type = "button", label = "Add Point / Select Zone", callback = startPlantPositionSelection},
		{type = "button", label = "Clear Saved", callback = function()
			table.clear(savedPlantPositions)
			custompos = nil
			zoneMin = nil
			zoneMax = nil
			plantPosListIndex = 1
			updatePlantPosDisplay()
			hub:Notify("Saved plant data cleared.")
		end},
		{type = "slider", label = "Plant Delay", value = 1, min = 0, max = 50, suffix = " ds", callback = function(value)
			plantdelay = value / 10
		end},
		{type = "button", label = "Plant All Now", callback = function()
			task.spawn(function()
				local oldRunning = plantrunning
				plantrunning = true
				pcall(doplant)
				plantrunning = oldRunning
			end)
		end},
	}
})
end
local shovelrunning = false
local shoveldelay = 0
local shovelftype = "Whitelist"
local shovelplantftype = "Whitelist"
local shovelflist = "None"
local shovelplantslist = "None"
local shovelmuttype = "Whitelist"
local shovelmutlist = "None"
local shovelminweight = 0
local shovelmaxweight = 0
local function shovelplantallowed(seedName)
	local set = {}
	for name in (shovelplantslist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if shovelplantslist == "" or shovelplantslist == "None" then
		if shovelplantftype == "Whitelist" then
			return false
		else
			return true
		end
	end
	if shovelplantftype == "Whitelist" then
		return set[seedName] == true
	end
	return set[seedName] == nil
end
local function shovelallowed(seedName)
	local set = {}
	for name in (shovelflist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if shovelftype == "Whitelist" then
		return set[seedName] == true
	end
	return set[seedName] == nil
end
local function shovelmutallowed(mutation)
	if not mutation or mutation == "" then
		mutation = "None"
	end
	local set = {}
	for name in (shovelmutlist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if shovelmutlist == "" or shovelmutlist == "None" then
		return true
	end
	if shovelmuttype == "Whitelist" then
		return set[mutation] == true
	end
	return set[mutation] == nil
end
findShovelTool = function()
	local function pick(container)
		if not container then
			return nil
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("Shovel") then
				return child
			end
		end
		return nil
	end
	local character = localPlayer.Character
	return pick(character) or pick(localPlayer:FindFirstChild("Backpack"))
end
local function fireShovelAction(plant, targetObj, shovel)
	if not shovel or not shovel.Parent then
		return false
	end
	local netMod = findModule("Networking")
	local Networking = netMod and safeRequire(netMod)
	if not Networking or not Networking.Shovel or not Networking.Shovel.UseShovel then
		return false
	end
	local plantId = plant.Name
	local fruitId = ""
	if targetObj and targetObj ~= plant and targetObj.Parent and targetObj.Parent.Name == "Fruits" then
		fruitId = targetObj.Name
	end
	local shovelAttr = shovel:GetAttribute("Shovel") or shovel.Name
	local ok = pcall(function()
		if Networking.Shovel.SwingShovel then
			Networking.Shovel.SwingShovel:Fire(shovel)
		end
		Networking.Shovel.UseShovel:Fire(plantId, fruitId, shovelAttr, shovel)
	end)
	return ok
end
local function doshovel()
	local farm = getPlayerFarm()
	if not farm then
		return
	end
	local plants = farm:FindFirstChild("Plants")
	if not plants then
		return
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local shovel = findShovelTool()
	if not shovel then
		return
	end
	if shovel.Parent ~= character then
		humanoid:EquipTool(shovel)
	end
	shovel = findShovelTool()
	if not shovel or shovel.Parent ~= character then
		return
	end
	local children = plants:GetChildren()
	if #children == 0 then
		return
	end
	for _, plant in children do
		if not shovelrunning then
			break
		end
		local plantSeedName = getseedname(plant)
		local plantCropName = plantSeedName and (getcropname(plantSeedName) or plantSeedName) or nil
		local shovelAsPlant = plantCropName and shovelplantallowed(plantCropName)
		local fruitsFolder = plant:FindFirstChild("Fruits")
		local targetsToCheck = {}
		if shovelAsPlant then
			table.insert(targetsToCheck, plant)
		elseif fruitsFolder and #fruitsFolder:GetChildren() > 0 then
			for _, fruit in fruitsFolder:GetChildren() do
				table.insert(targetsToCheck, fruit)
			end
		else
			table.insert(targetsToCheck, plant)
		end
		for _, obj in targetsToCheck do
			if not shovelrunning then
				break
			end
			local seedName = getseedname(obj)
			local cropName = seedName and (getcropname(seedName) or seedName) or nil
			local mutation = obj:GetAttribute("Mutation") or "None"
			local calcWeightKg = getweightkg(obj, seedName)
			if cropName and cropName ~= "" then
				local isFruit = (obj.Parent and obj.Parent.Name == "Fruits")
				local allowed = isFruit and shovelallowed(cropName) or shovelplantallowed(cropName)
				local mutAllowed = shovelmutallowed(mutation)
				local matchesMin = (shovelminweight == 0 or calcWeightKg >= shovelminweight)
				local matchesMax = (shovelmaxweight == 0 or calcWeightKg <= shovelmaxweight)
				if allowed and mutAllowed and matchesMin and matchesMax then
					fireShovelAction(plant, obj, shovel)
					if shoveldelay > 0 then
						task.wait(shoveldelay)
					end
				end
			end
		end
	end
end
local shovelthread = nil
hub:CreateModule("Main", {
	name = "Auto Shovel",
	on = false,
	bind = "None",
	desc = "Auto dig plants.",
	callback = function(enabled)
		shovelrunning = enabled
		if shovelthread then
			pcall(task.cancel, shovelthread)
			shovelthread = nil
		end
		if enabled then
			shovelthread = task.spawn(function()
				while shovelrunning do
					doshovel()
					if shoveldelay > 0 then
						task.wait(shoveldelay)
					else
						task.wait()
					end
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Shovel Delay (0 = Max Speed)", value = 0, min = 0, max = 30, suffix = "s", callback = function(value)
			shoveldelay = value
		end},
		{type = "dropdown", label = "Filter Type (Fruits)", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			shovelftype = value
		end},
		{type = "multiselect", label = "Filter Fruits", value = "None", list = gameLists.crops, callback = function(value)
			shovelflist = value
		end},
		{type = "dropdown", label = "Filter Type (Plants)", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			shovelplantftype = value
		end},
		{type = "multiselect", label = "Filter Plants", value = "None", list = gameLists.plants, callback = function(value)
			shovelplantslist = value
		end},
		{type = "dropdown", label = "Filter Mutation Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			shovelmuttype = value
		end},
		{type = "multiselect", label = "Filter Mutations", value = "None", list = gameLists.mutations, callback = function(value)
			shovelmutlist = value
		end},
		{type = "textbox", label = "Min Weight Filter (kg)", value = "0", placeholder = "Enter min weight in kg...", callback = function(value)
			local num = tonumber(value)
			shovelminweight = num or 0
		end},
		{type = "textbox", label = "Max Weight Filter (kg)", value = "0", placeholder = "Enter max weight in kg...", callback = function(value)
			local num = tonumber(value)
			shovelmaxweight = num or 0
		end},
	}
})
;(function()
	local stealRunning = false
	local stealThread = nil
	local stealDelay = 0.35
	local stealMaxEnabled = false
	local stealMax = 50
	local stealSpeed = 180
	local stealMode = "Bypass Method [NEW BEST!]"
	local stealPriority = "Highest Price"
	local stealCheckNight = true
	local stealCheckOwner = true
	local stealTargetPlots = ""
	local stealBestParagraph = nil
	local stealRecent = {}
	local stealRecentSec = 1.5

	local function formatStealMoney(n)
		if n >= 1000000000 then
			return string.format("%.2fB", n / 1000000000)
		elseif n >= 1000000 then
			return string.format("%.2fM", n / 1000000)
		elseif n >= 1000 then
			return string.format("%.2fK", n / 1000)
		end
		return tostring(math.floor(n))
	end

	local function getStealEstPrice(seedName, sizeMulti, mutation, decay)
		local price = calcGamePrice(seedName, sizeMulti, mutation, decay)
		if price > 0 then
			return price
		end
		local base = getbaseprice(seedName)
		if base <= 0 then
			return 0
		end
		local decayFactor = 1 - math.clamp(tonumber(decay) or 0, 0, 1)
		return math.floor(base * (sizeMulti or 1) * getMutationMultiplier(mutation) * decayFactor)
	end

	local function getStealNet()
		local net = nil
		pcall(function()
			net = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
		end)
		return net
	end

	local function isNight()
		local night = game.ReplicatedStorage:FindFirstChild("Night")
		return night and night.Value == true
	end

	local function getPlotLabel(plot)
		local owner = plot:GetAttribute("Owner")
		if typeof(owner) == "string" and owner ~= "" then
			return owner .. "'s Garden"
		end
		local ownerId = getPlotOwnerUserId(plot)
		if ownerId then
			local ownerPlayer = Players:GetPlayerByUserId(ownerId)
			if ownerPlayer then
				return ownerPlayer.DisplayName .. "'s Garden"
			end
		end
		return plot.Name
	end

	local function getPlotCenter(plot)
		if not plot then return nil end
		local ref = plot:FindFirstChild("PlotSizeReference")
		if ref then return ref.Position end
		local sp = plot:FindFirstChild("SpawnPoint")
		if sp then return sp.Position end
		local part = plot:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position
	end

	local function getModelPos(model)
		if not model then return nil end
		if model:IsA("BasePart") then return model.Position end
		if model.PrimaryPart then return model.PrimaryPart.Position end
		local part = model:FindFirstChild("HarvestPart") or model:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position
	end

	local function isStealableCrop(obj)
		local age = obj:GetAttribute("Age")
		local maxAge = obj:GetAttribute("MaxAge")
		if typeof(age) ~= "number" or typeof(maxAge) ~= "number" then
			return true
		end
		return age >= maxAge
	end

	local function isFruitVisible(model)
		if not model or not model.Parent then
			return false
		end
		-- HarvestPart in this game remains transparency=1 even for fully grown fruits.
		-- So we check if there are visible BaseParts in the model (e.g. fruit meshes/parts).
		local hasVisiblePart = false
		for _, desc in model:GetChildren() do
			if desc:IsA("BasePart") and desc.Name ~= "HarvestPart" and desc.Name ~= "Base" then
				if desc.Transparency < 0.95 then
					hasVisiblePart = true
					break
				end
			end
		end
		if not hasVisiblePart then
			local hp = model:FindFirstChild("HarvestPart") or model:FindFirstChild("Base")
			if hp and hp:IsA("BasePart") and hp.Transparency < 0.95 then
				hasVisiblePart = true
			end
		end
		return hasVisiblePart
	end

	local stealGardenDropdown = nil

	local function buildGardenList()
		local list = {}
		local gardens = workspace:FindFirstChild("Gardens")
		if gardens then
			for _, plot in gardens:GetChildren() do
				table.insert(list, getPlotLabel(plot))
			end
			table.sort(list)
		end
		return list
	end

	local function refreshStealGardenList()
		local list = buildGardenList()
		if stealGardenDropdown and stealGardenDropdown.SetOptions then
			pcall(function()
				stealGardenDropdown:SetOptions(list)
			end)
		end
		return list
	end

	local function updateStealDisplay(best, total, statusMsg, footnote)
		if not stealBestParagraph then
			return
		end
		if statusMsg then
			setHubParagraph(stealBestParagraph, statusMsg, "Best Target")
			return
		end
		if not best then
			setHubParagraph(stealBestParagraph, '<font color="rgb(180,180,190)">No ripe fruits found.</font>\n<font color="rgb(120,200,255)">Scanning gardens...</font>', "Best Target")
			return
		end
		local title = string.format("%s · %s", best.seedName, best.mutation)
		local content = string.format(
			'<font color="rgb(110,255,140)">Price: ¢%s</font>\n<font color="rgb(255,200,120)">Weight: %.2f kg</font>\n<font color="rgb(160,200,255)">Garden: %s</font>\n<font color="rgb(200,200,210)">Distance: %dm</font>\n<font color="rgb(140,140,150)">Scanned: %d fruits</font>',
			formatStealMoney(best.price),
			best.weight,
			best.plotLabel,
			math.floor(best.distance),
			total or 0
		)
		if footnote then
			content = content .. "\n\n" .. footnote
		end
		setHubParagraph(stealBestParagraph, content, title)
	end

	local function buildStealTargetSet()
		local set = {}
		if stealTargetPlots == "" then
			return set, true
		end
		for entry in (stealTargetPlots .. ","):gmatch("([^,]+),") do
			set[entry:match("^%s*(.-)%s*$")] = true
		end
		return set, false
	end

	local function scanStealTargets(myPos)
		local results = {}
		local gardens = workspace:FindFirstChild("Gardens")
		if not gardens then
			return results
		end
		local targetSet, targetAll = buildStealTargetSet()
		for _, plot in gardens:GetChildren() do
			if isPlotOwnedByLocalPlayer(plot) then
				continue
			end
			if not targetAll and not targetSet[getPlotLabel(plot)] then
				continue
			end
			local plants = plot:FindFirstChild("Plants")
			if not plants then
				continue
			end
			local plotLabel = getPlotLabel(plot)
			local plotOwnerId = getPlotOwnerUserId(plot)
			if stealCheckOwner and isPlotOwnerInGarden(plot, plotOwnerId) then
				continue
			end
			for _, plant in plants:GetChildren() do
				local userId = tonumber(plant:GetAttribute("UserId")) or tonumber(plant.Name:match("^(%d+)_"))
				local plantId = plant:GetAttribute("PlantId") or plant.Name:match("^%d+_(.+)$")
				if not userId or not plantId or userId == localPlayer.UserId then
					continue
				end
				if stealCheckOwner and userId ~= plotOwnerId and isPlotOwnerInGarden(plot, userId) then
					continue
				end
				local seedName = plant:GetAttribute("SeedName") or getseedname(plant) or ""
				local fruitsFolder = plant:FindFirstChild("Fruits")
				if fruitsFolder then
					for _, fruit in fruitsFolder:GetChildren() do
						if not isStealableCrop(fruit) or not isFruitVisible(fruit) then
							continue
						end
						local fruitId = fruit:GetAttribute("FruitId") or fruit.Name:match("^%d+_%d+_(.+)$") or ""
						local key = string.format("%d_%s_%s", userId, plantId, fruitId)
						if stealRecent[key] and os.clock() - stealRecent[key] < stealRecentSec then
							continue
						end
						local mutation = fruit:GetAttribute("Mutation") or "None"
						local sizeMulti = fruit:GetAttribute("SizeMultiplier") or fruit:GetAttribute("SizeMulti") or 1
						local decay = tonumber(fruit:GetAttribute("DecayAlpha")) or 0
						local price = getStealEstPrice(seedName, sizeMulti, mutation, decay)
						local weight = getweightkg(fruit, seedName)
						local pos = getModelPos(fruit)
						local distance = myPos and pos and (pos - myPos).Magnitude or 99999
						local basePrice = getStealEstPrice(seedName, sizeMulti, "None", decay)
						table.insert(results, {
							userId = userId,
							plantId = plantId,
							fruitId = fruitId,
							seedName = seedName,
							mutation = mutation,
							price = price,
							weight = weight,
							distance = distance,
							mutationScore = math.max(0, price - basePrice),
							pos = pos,
							plot = plot,
							plotLabel = plotLabel,
							model = fruit,
						})
					end
				elseif isStealableCrop(plant) and isFruitVisible(plant) then
					local key = string.format("%d_%s_", userId, plantId)
					if stealRecent[key] and os.clock() - stealRecent[key] < stealRecentSec then
						continue
					end
					local mutation = plant:GetAttribute("Mutation") or "None"
					local sizeMulti = plant:GetAttribute("SizeMultiplier") or plant:GetAttribute("SizeMulti") or 1
					local decay = tonumber(plant:GetAttribute("DecayAlpha")) or 0
					local price = getStealEstPrice(seedName, sizeMulti, mutation, decay)
					local weight = getweightkg(plant, seedName)
					local pos = getModelPos(plant)
					local distance = myPos and pos and (pos - myPos).Magnitude or 99999
					local basePrice = getStealEstPrice(seedName, sizeMulti, "None", decay)
					table.insert(results, {
						userId = userId,
						plantId = plantId,
						fruitId = "",
						seedName = seedName,
						mutation = mutation,
						price = price,
						weight = weight,
						distance = distance,
						mutationScore = math.max(0, price - basePrice),
						pos = pos,
						plot = plot,
						plotLabel = plotLabel,
						model = plant,
					})
				end
			end
		end
		return results
	end

	local function sortStealTargets(targets)
		table.sort(targets, function(a, b)
			if stealPriority == "Highest Price" then
				if a.price ~= b.price then return a.price > b.price end
			elseif stealPriority == "Highest Weight" then
				if a.weight ~= b.weight then return a.weight > b.weight end
			elseif stealPriority == "Price per kg" then
				local aRatio = a.weight > 0 and a.price / a.weight or 0
				local bRatio = b.weight > 0 and b.price / b.weight or 0
				if aRatio ~= bRatio then return aRatio > bRatio end
			elseif stealPriority == "Nearest" then
				if a.distance ~= b.distance then return a.distance < b.distance end
			elseif stealPriority == "Best Mutation" then
				if a.mutationScore ~= b.mutationScore then return a.mutationScore > b.mutationScore end
			end
			if a.price ~= b.price then return a.price > b.price end
			return a.distance < b.distance
		end)
	end

	local function cleanupStealMovement(hrp, hum)
		if hum then hum.PlatformStand = false end
		if hrp then
			local bv = hrp:FindFirstChild("SimpleStealBV")
			if bv then bv:Destroy() end
			local bg = hrp:FindFirstChild("SimpleStealBG")
			if bg then bg:Destroy() end
		end
	end

	local function moveToPosition(targetPos, hrp, hum)
		if not hrp or not targetPos then
			return false
		end
		if stealMode == "Teleport" then
			safeTeleport(CFrame.new(targetPos))
			task.wait(0.08)
			return true
		end
		local dist = (targetPos - hrp.Position).Magnitude
		local duration = math.max(0.15, dist / stealSpeed)
		if hum then hum.PlatformStand = true end
		local bv = hrp:FindFirstChild("SimpleStealBV") or Instance.new("BodyVelocity")
		bv.Name = "SimpleStealBV"
		bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bv.Velocity = Vector3.new(0, 0, 0)
		bv.Parent = hrp
		local bg = hrp:FindFirstChild("SimpleStealBG") or Instance.new("BodyGyro")
		bg.Name = "SimpleStealBG"
		bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
		bg.CFrame = hrp.CFrame
		bg.Parent = hrp
		local tween = TS:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
		local done = false
		local conn = tween.Completed:Connect(function()
			done = true
		end)
		tween:Play()
		while not done and stealRunning do
			task.wait(0.05)
		end
		conn:Disconnect()
		if not stealRunning then
			tween:Cancel()
			cleanupStealMovement(hrp, hum)
			return false
		end
		return true
	end

	local function shouldUseStealMax()
		return stealMaxEnabled and stealMode ~= "Bypass Method [NEW BEST!]"
	end

	local function hasReachedStealMax(stolen)
		return shouldUseStealMax() and stolen >= stealMax
	end

	local function returnStealHome(hrp, hum, origCf)
		if not hrp or not origCf then
			return
		end
		cleanupStealMovement(hrp, hum)
		if stealMode == "Fly" then
			moveToPosition(origCf.Position + Vector3.new(0, 2, 0), hrp, hum)
			hrp.CFrame = origCf
		elseif stealMode == "Teleport" then
			safeTeleport(origCf)
		end
	end

	local function attemptSteal(net, target, hrp, hum)
		if not hrp then
			return false
		end
		local savedCf = hrp.CFrame
		local myFarm = getPlayerFarm()
		local myCenter = getPlotCenter(myFarm)
		local targetPos = target.pos and (target.pos + Vector3.new(0, 2, 0)) or getPlotCenter(target.plot)
		local initCarry = localPlayer:GetAttribute("StolenCarryValue") or 0
		local initCarrying = localPlayer:GetAttribute("CarryingStolenFruit")

		if stealMode == "Bypass Method [NEW BEST!]" then
			pcall(function()
				net.Steal.BeginSteal:Fire(target.userId, target.plantId, target.fruitId)
			end)
			pcall(function()
				net.Steal.CompleteSteal:Fire()
			end)
		elseif stealMode == "Teleport" then
			if targetPos then
				safeTeleport(CFrame.new(targetPos))
			end
			pcall(function()
				net.Steal.BeginSteal:Fire(target.userId, target.plantId, target.fruitId)
			end)
			if myCenter then
				safeTeleport(CFrame.new(myCenter + Vector3.new(0, 3, 0)))
			end
			task.wait(0.05)
			pcall(function()
				net.Steal.CompleteSteal:Fire()
			end)
			safeTeleport(savedCf)
		else
			moveToPosition(targetPos, hrp, hum)
			pcall(function()
				net.Steal.BeginSteal:Fire(target.userId, target.plantId, target.fruitId)
			end)
			if myCenter then
				moveToPosition(myCenter + Vector3.new(0, 3, 0), hrp, hum)
			end
			pcall(function()
				net.Steal.CompleteSteal:Fire()
			end)
			if stealMode == "Fly" then
				hrp.CFrame = savedCf
			end
		end

		task.wait(0.2)
		local carry = localPlayer:GetAttribute("StolenCarryValue") or 0
		local carrying = localPlayer:GetAttribute("CarryingStolenFruit")
		local modelGone = not target.model or not target.model.Parent or not target.model:IsDescendantOf(workspace)
		if carry > initCarry or (carrying and not initCarrying) or modelGone then
			local key = string.format("%d_%s_%s", target.userId, target.plantId, target.fruitId)
			stealRecent[key] = os.clock()
			if webhookHooks.onSteal then
				pcall(webhookHooks.onSteal, target)
			end
			return true
		end
		return false
	end

	local function stealLoop()
		local net = getStealNet()
		if not net then
			stealRunning = false
			return
		end
		local stolen = 0
		local origCf = nil
		local char = localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then origCf = hrp.CFrame end

		while stealRunning do
			if hasReachedStealMax(stolen) then
				break
			end
			char = localPlayer.Character
			hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local myPos = hrp and hrp.Position
			local targets = scanStealTargets(myPos)
			if #targets == 0 then
				updateStealDisplay(nil, 0)
				task.wait(1.5)
				continue
			end
			sortStealTargets(targets)
			local best = targets[1]
			local waitingNight = stealCheckNight and not isNight()
			if waitingNight then
				updateStealDisplay(best, #targets, nil, "Daytime — showing best target.\nSteal attempts resume at night.")
				task.wait(1.5)
				continue
			end
			updateStealDisplay(best, #targets)
			local stoleThisPass = false
			for _, target in targets do
				if not stealRunning or hasReachedStealMax(stolen) then
					break
				end
				char = localPlayer.Character
				hrp = char and char:FindFirstChild("HumanoidRootPart")
				hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp then
					break
				end
				hub:Notify("Attempting steal: " .. target.seedName .. " (" .. formatCurrencyAmount(target.price, true) .. ")")
				if attemptSteal(net, target, hrp, hum) then
					stolen = stolen + 1
					stoleThisPass = true
					if shouldUseStealMax() then
						hub:Notify("Steal successful! (" .. stolen .. "/" .. stealMax .. ")")
					else
						hub:Notify("Steal successful!")
					end
					updateStealDisplay(target, #targets)
					if hasReachedStealMax(stolen) then
						break
					end
				else
					hub:Notify("Steal failed / protected.")
				end
				cleanupStealMovement(hrp, hum)
				if stealDelay > 0 then
					task.wait(stealDelay)
				end
			end
			if not stoleThisPass then
				task.wait(2)
			end
		end

		char = localPlayer.Character
		hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		cleanupStealMovement(hrp, hum)
		if hasReachedStealMax(stolen) then
			hub:Notify("Max fruits limit reached. Returning home.")
			returnStealHome(hrp, hum, origCf)
		elseif origCf and hrp and stealMode == "Fly" then
			hrp.CFrame = origCf
		end
		updateStealDisplay(nil, 0)
		stealRunning = false
	end

	local scanThread = nil
	local function startStealScanLoop()
		if scanThread then
			return
		end
		scanThread = task.spawn(function()
			while true do
				if not stealRunning then
					local char = localPlayer.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local myPos = hrp and hrp.Position
					local targets = scanStealTargets(myPos)
					if #targets == 0 then
						updateStealDisplay(nil, 0)
					else
						sortStealTargets(targets)
						updateStealDisplay(targets[1], #targets)
					end
				end
				task.wait(1.5)
			end
		end)
	end

	hub:CreateModule("Main", {
		name = "Auto Steal",
		badge = {text = "BETA", color = Color3.fromRGB(80, 180, 255)},
		on = false,
		bind = "None",
		desc = "Steal fruits.",
		callback = function(enabled)
			stealRunning = enabled
			if enabled then
				if stealThread then pcall(task.cancel, stealThread) end
				stealThread = task.spawn(stealLoop)
			else
				if stealThread then
					pcall(task.cancel, stealThread)
					stealThread = nil
				end
				local char = localPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				cleanupStealMovement(hrp, hum)
			end
		end,
		opts = {
			{type = "paragraph", title = "Best Target", content = "Waiting for scan...", onCreate = function(widget)
				stealBestParagraph = widget
				enableParagraphRichText(widget)
				startStealScanLoop()
			end},
			{type = "dropdown", label = "Priority", value = "Highest Price", list = {"Highest Price", "Highest Weight", "Price per kg", "Nearest", "Best Mutation"}, callback = function(value)
				stealPriority = value
			end},
			{type = "dropdown", label = "Move Mode", value = "Bypass Method [NEW BEST!]", list = {"Bypass Method [NEW BEST!]", "Fly", "Teleport"}, callback = function(value)
				stealMode = value
			end},
			{type = "slider", label = "Fly Speed", value = 180, min = 50, max = 500, suffix = "", callback = function(value)
				stealSpeed = value
			end},
			{type = "checkbox", label = "Limit Max Fruits", value = false, callback = function(value)
				stealMaxEnabled = value
			end},
			{type = "slider", label = "Max Fruits Limit", value = 50, min = 1, max = 200, suffix = "", callback = function(value)
				stealMax = value
			end},
			{type = "slider", label = "Steal Delay", value = 4, min = 0, max = 30, suffix = "ds", callback = function(value)
				stealDelay = value / 10
			end},
			{type = "checkbox", label = "Check Night", value = true, callback = function(value)
				stealCheckNight = value
			end},
			{type = "checkbox", label = "Skip If Owner Present", value = true, callback = function(value)
				stealCheckOwner = value
			end},
			(function()
				local gardenOpt = {
					type = "multiselect",
					label = "Target Gardens",
					value = "",
					list = buildGardenList(),
					callback = function(value)
						stealTargetPlots = value
					end,
					onCreate = function(widget)
						stealGardenDropdown = widget
						refreshStealGardenList()
					end,
				}
				task.defer(function()
					refreshStealGardenList()
					local gardens = workspace:FindFirstChild("Gardens")
					if gardens then
						gardens.ChildAdded:Connect(refreshStealGardenList)
						gardens.ChildRemoved:Connect(refreshStealGardenList)
						for _, plot in gardens:GetChildren() do
							plot:GetAttributeChangedSignal("Owner"):Connect(refreshStealGardenList)
							plot:GetAttributeChangedSignal("OwnerUserId"):Connect(refreshStealGardenList)
						end
					end
				end)
				return gardenOpt
			end)(),
			{type = "button", label = "Refresh Gardens", callback = function()
				refreshStealGardenList()
				hub:Notify("Garden list refreshed (" .. #buildGardenList() .. " plots)")
			end},
		}
	})
end)()
local buyrunning = false
local buydelay = 1
local buylist = ""
local function dobuy()
	table.clear(purchasedCurrentCycle)
	local virtualMoney = getPlayerCurrency()
	local list = buylist
	if list == "" then
		list = table.concat(gameLists.seeds, ",")
	end
	local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	for name in (list .. ","):gmatch("([^,]+),") do
		local seedName = name:match("^%s*(.-)%s*$")
		if isinstock(seedName, 1, virtualMoney) then
			pcall(function() Networking.SeedShop.PurchaseSeed:Fire(seedName) end)
			purchasedCurrentCycle[seedName] = (purchasedCurrentCycle[seedName] or 0) + 1
			local price = getItemPrice(seedName, 1)
			virtualMoney = virtualMoney - price
		end
		task.wait(0.15)
	end
end
do
	local speedval = 16
	local jumpval = 50
	local infJumpOn = false
	local flyOn = false
	local flyspeedval = 60
	local noclipOn = false
	local flyConn = nil
	local noclipConn = nil
	local infJumpConn = nil
	local antiVoidOn = false
	local antiVoidConn = nil
	local bodyVel = nil
	local bodyGyro = nil
	local playerActive = false
	local function getchar()
		return localPlayer and localPlayer.Character
	end
	local function gethrp()
		local c = getchar()
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function gethum()
		local c = getchar()
		return c and c:FindFirstChildOfClass("Humanoid")
	end
	local function stopfly()
		if flyConn then flyConn:Disconnect() flyConn = nil end
		if bodyVel then bodyVel:Destroy() bodyVel = nil end
		if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
		local hum = gethum()
		if hum then hum.PlatformStand = false end
	end
	local function stopnoclip()
		if noclipConn then noclipConn:Disconnect() noclipConn = nil end
	end
	local function stopinfjump()
		if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
	end
	local function stopAntiVoid()
		if antiVoidConn then antiVoidConn:Disconnect() antiVoidConn = nil end
	end
	local function startAntiVoid()
		stopAntiVoid()
		antiVoidConn = RS.Heartbeat:Connect(function()
			if not antiVoidOn or not playerActive then
				return
			end
			local hrp = gethrp()
			if not hrp then
				return
			end
			local voidY = (workspace.FallenPartsDestroyHeight or -500) + 20
			if hrp.Position.Y < voidY then
				local safePos = getGroundUnderPlayer()
				if not safePos then
					local farm = getPlayerFarm()
					if farm then
						safePos = farm:GetPivot().Position + Vector3.new(0, 5, 0)
					end
				end
				if safePos then
					safeTeleport(CFrame.new(safePos + Vector3.new(0, 4, 0)))
				end
			end
		end)
	end
	local function startinfjump()
		stopinfjump()
		local UIS = game:GetService("UserInputService")
		infJumpConn = UIS.JumpRequest:Connect(function()
			if infJumpOn and playerActive then
				local hum = gethum()
				if hum then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	end
	local function startfly()
		stopfly()
		local hrp = gethrp()
		local hum = gethum()
		if not hrp or not hum then return end
		hum.PlatformStand = true
		bodyVel = Instance.new("BodyVelocity")
		bodyVel.Velocity = Vector3.new(0, 0, 0)
		bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		bodyVel.Parent = hrp
		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		bodyGyro.P = 1e5
		bodyGyro.Parent = hrp
		local cam = workspace.CurrentCamera
		local UIS = game:GetService("UserInputService")
		local RS = game:GetService("RunService")
		flyConn = RS.RenderStepped:Connect(function()
			if not flyOn or not playerActive or not hrp or not hrp.Parent then
				stopfly()
				return
			end
			local dir = Vector3.new(0, 0, 0)
			if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
			bodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * flyspeedval or Vector3.new(0, 0, 0)
			bodyGyro.CFrame = cam.CFrame
		end)
	end
	local function startnoclip()
		stopnoclip()
		local RS = game:GetService("RunService")
		noclipConn = RS.Stepped:Connect(function()
			local char = getchar()
			if not char or not noclipOn or not playerActive then
				stopnoclip()
				return
			end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end)
	end
	hub:CreateModule("Main", {
		name = "Player",
		on = false,
		bind = "None",
		desc = "Speed, jump, fly, noclip.",
		callback = function(enabled)
			playerActive = enabled
			if not enabled then
				stopfly()
				stopnoclip()
				stopinfjump()
				stopAntiVoid()
				local hum = gethum()
				if hum then
					hum.WalkSpeed = 16
					hum.JumpPower = 50
				end
			else
				local hum = gethum()
				if hum then
					hum.WalkSpeed = speedval
					hum.UseJumpPower = true
					hum.JumpPower = jumpval
				end
				if infJumpOn then
					startinfjump()
				end
				if flyOn then
					startfly()
				end
				if noclipOn then
					startnoclip()
				end
				if antiVoidOn then
					startAntiVoid()
				end
			end
		end,
		opts = {
			{type = "slider", label = "Walk Speed", value = 16, min = 1, max = 200, suffix = "", callback = function(value)
				speedval = value
				if not playerActive then return end
				local hum = gethum()
				if hum then hum.WalkSpeed = speedval end
			end},
			{type = "slider", label = "Jump Power", value = 50, min = 1, max = 500, suffix = "", callback = function(value)
				jumpval = value
				if not playerActive then return end
				local hum = gethum()
				if hum then
					hum.UseJumpPower = true
					hum.JumpPower = jumpval
				end
			end},
			{type = "toggle", label = "InfJump", value = false, callback = function(enabled)
				infJumpOn = enabled
				stopinfjump()
				if not playerActive then return end
				if enabled then
					startinfjump()
				end
			end},
			{type = "toggle", label = "Fly", value = false, callback = function(enabled)
				flyOn = enabled
				stopfly()
				if not playerActive then return end
				if enabled then
					startfly()
				end
			end},
			{type = "slider", label = "Fly Speed", value = 60, min = 5, max = 300, suffix = "", callback = function(value)
				flyspeedval = value
			end},
			{type = "toggle", label = "Noclip", value = false, callback = function(enabled)
				noclipOn = enabled
				stopnoclip()
				if not playerActive then return end
				if enabled then
					startnoclip()
				end
			end},
			{type = "toggle", label = "Anti Void", value = false, callback = function(enabled)
				antiVoidOn = enabled
				stopAntiVoid()
				if not playerActive then return end
				if enabled then
					startAntiVoid()
				end
			end},
		}
	})
end
hub:CreateTab("Auto Buy", "rbxassetid://13429538917")
hub:CreateModule("Auto Buy", {
	name = "Seeds",
	on = false,
	bind = "None",
	desc = "Auto buy seeds.",
	callback = function(enabled)
		buyrunning = enabled
		if enabled then
			purchasedCurrentCycle = {}
			task.spawn(function()
				while buyrunning do
					dobuy()
					task.wait(buydelay)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Buy Delay", value = 1, min = 0, max = 30, suffix = "s", callback = function(value)
			buydelay = value
		end},
		{type = "multiselect", label = "Select Seeds", value = "", list = gameLists.seeds, callback = function(value)
			buylist = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "seeds")
		end},
		{type = "button", label = "Buy Now", callback = function()
			dobuy()
		end},
	}
})
local function dogear()
	table.clear(purchasedCurrentCycle)
	local virtualMoney = getPlayerCurrency()
	local list = gearlist
	if list == "" then
		list = table.concat(gameLists.gears, ",")
	end
	local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	for name in (list .. ","):gmatch("([^,]+),") do
		local gearName = name:match("^%s*(.-)%s*$")
		if isinstock(gearName, 2, virtualMoney) then
			pcall(function() Networking.GearShop.PurchaseGear:Fire(gearName) end)
			purchasedCurrentCycle[gearName] = (purchasedCurrentCycle[gearName] or 0) + 1
			local price = getItemPrice(gearName, 2)
			virtualMoney = virtualMoney - price
		end
		task.wait(0.15)
	end
end
hub:CreateModule("Auto Buy", {
	name = "Gear",
	on = false,
	bind = "None",
	desc = "Auto buy gear.",
	callback = function(enabled)
		gearrunning = enabled
		if enabled then
			purchasedCurrentCycle = {}
			task.spawn(function()
				while gearrunning do
					dogear()
					task.wait(geardelay)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Buy Delay", value = 1, min = 0, max = 30, suffix = "s", callback = function(value)
			geardelay = value
		end},
		{type = "multiselect", label = "Select Gear", value = "", list = gameLists.gears, callback = function(value)
			gearlist = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "gears")
		end},
		{type = "button", label = "Buy Now", callback = function()
			dogear()
		end},
	}
})
local proprunning = false
local propdelay = 1
local proplist = ""
local function doprop()
	table.clear(purchasedCurrentCycle)
	local virtualMoney = getPlayerCurrency()
	local list = proplist
	if list == "" then
		list = table.concat(gameLists.crates, ",")
	end
	local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	for name in (list .. ","):gmatch("([^,]+),") do
		local propName = name:match("^%s*(.-)%s*$")
		local cleanProp = propName:gsub("%s*Crate%s*$", "")
		local targetName = nil
		if isinstock(propName, 3, virtualMoney) then
			targetName = propName
		elseif isinstock(cleanProp, 3, virtualMoney) then
			targetName = cleanProp
		end
		if targetName then
			pcall(function() Networking.CrateShop.PurchaseCrate:Fire(propName) end)
			purchasedCurrentCycle[targetName] = (purchasedCurrentCycle[targetName] or 0) + 1
			local price = getItemPrice(targetName, 3)
			virtualMoney = virtualMoney - price
		end
		task.wait(0.15)
	end
end
hub:CreateModule("Auto Buy", {
	name = "Crates",
	on = false,
	bind = "None",
	desc = "Auto buy props.",
	callback = function(enabled)
		proprunning = enabled
		if enabled then
			purchasedCurrentCycle = {}
			task.spawn(function()
				while proprunning do
					doprop()
					task.wait(propdelay)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Buy Delay", value = 1, min = 0, max = 30, suffix = "s", callback = function(value)
			propdelay = value
		end},
		{type = "multiselect", label = "Select Crates", value = "", list = gameLists.crates, callback = function(value)
			proplist = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "crates")
		end},
		{type = "button", label = "Buy Now", callback = function()
			doprop()
		end},
	}
})

gardenexpanderrunning = false
gardenexpanderdelay = 5
hub:CreateModule("Auto Buy", {
	name = "Garden Expander",
	on = false,
	bind = "None",
	desc = "Auto buy plot expansion.",
	callback = function(enabled)
		gardenexpanderrunning = enabled
		if enabled then
			task.spawn(function()
				while gardenexpanderrunning do
					local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
					pcall(function() Networking.Actions.ExpandGarden:Fire() end)
					task.wait(gardenexpanderdelay)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Check Delay", value = 5, min = 1, max = 30, suffix = "s", callback = function(value)
			gardenexpanderdelay = value
		end},
	}
})

autoeggselected = "Common Egg"
autoeggdelay = 1.0
autoeggrunning = false
autoeggactive = false
autoeggtrashrarity = ""
autoeggcon = nil

function setupAutoEggTrash(val)
	if autoeggcon then
		autoeggcon:Disconnect()
		autoeggcon = nil
	end
	if val then
		local bp = localPlayer:WaitForChild("Backpack")
		autoeggcon = bp.ChildAdded:Connect(function(child)
			task.wait(0.05) -- let attributes replicate
			if child:IsA("Tool") and child:GetAttribute("Pet") then
				local petName = child:GetAttribute("Pet")
				local petId = child:GetAttribute("PetId")
				if petId then
					local info = getPetInfo and getPetInfo(petName)
					local rarity = info and info.Rarity or "Common"
					local set = {}
					for s in (autoeggtrashrarity .. ","):gmatch("([^,]+),") do
						set[s:match("^%s*(.-)%s*$")] = true
					end
					if set[rarity] then
						local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
						pcall(function() Networking.NPCS.SellPet:Fire(petId) end)
					end
				end
			end
		end)
	end
end

function doautoegg()
	if autoeggactive then return end
	autoeggactive = true
	local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	pcall(function()
		Networking.Egg.OpenEgg:Fire(autoeggselected)
	end)
	autoeggactive = false
end

hub:CreateModule("Main", {
	name = "Auto Open Eggs",
	on = false,
	bind = "None",
	desc = "Auto buy and open eggs.",
	callback = function(enabled)
		autoeggrunning = enabled
		setupAutoEggTrash(enabled)
		if enabled then
			task.spawn(function()
				while autoeggrunning do
					doautoegg()
					task.wait(autoeggdelay)
				end
			end)
		end
	end,
	opts = {
		{type = "dropdown", label = "Egg Type", value = gameLists.eggs[1] or "Common Egg", list = gameLists.eggs, callback = function(value)
			autoeggselected = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "eggs")
		end},
		{type = "slider", label = "Hatch Delay", value = 10, min = 2, max = 50, suffix = "ds", callback = function(value)
			autoeggdelay = value / 10
		end},
		{type = "multiselect", label = "Auto Sell Rarities", value = "", list = gameLists.rarities, callback = function(value)
			autoeggtrashrarity = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "rarities")
		end}
	}
})
nightvisionrunning = false
nightvisionconnection = nil
origambient = game.Lighting.Ambient
origbrightness = game.Lighting.Brightness
origfogend = game.Lighting.FogEnd
origclocktime = game.Lighting.ClockTime

function togglenightvision(val)
	nightvisionrunning = val
	if nightvisionconnection then
		nightvisionconnection:Disconnect()
		nightvisionconnection = nil
	end
	if val then
		origambient = game.Lighting.Ambient
		origbrightness = game.Lighting.Brightness
		origfogend = game.Lighting.FogEnd
		origclocktime = game.Lighting.ClockTime
		nightvisionconnection = game:GetService("RunService").RenderStepped:Connect(function()
			game.Lighting.Ambient = Color3.fromRGB(200, 200, 200)
			game.Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
			game.Lighting.Brightness = 2
			game.Lighting.FogEnd = 999999
			game.Lighting.FogStart = 999999
			game.Lighting.ClockTime = 14
			local atmosphere = game.Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere then
				atmosphere.Density = 0
			end
		end)
	else
		game.Lighting.Ambient = origambient
		game.Lighting.Brightness = origbrightness
		game.Lighting.FogEnd = origfogend
		game.Lighting.ClockTime = origclocktime
	end
end

cropsdamageimmunityrunning = false
poisonivyimmune = true
ghostpepperimmune = true
venomspitterimmune = true
thornroseimmune = true
plantimmuneconn = nil

function applyplantimmunity(inst)
	if not cropsdamageimmunityrunning then return end
	if not inst:IsA("BasePart") then return end
	local plantName = nil
	local model = inst:FindFirstAncestorWhichIsA("Model")
	if model then
		plantName = model:GetAttribute("SeedName") or model.Name
	end
	if not plantName then return end
	
	local isPoisonIvy = plantName:find("Poison Ivy")
	local isGhostPepper = plantName:find("Ghost Pepper")
	local isVenomSpitter = plantName:find("Venom Spitter")
	local isThornRose = plantName:find("Thorn Rose")
	
	if (isPoisonIvy and poisonivyimmune) or
	   (isGhostPepper and ghostpepperimmune) or
	   (isVenomSpitter and venomspitterimmune) or
	   (isThornRose and thornroseimmune) then
		inst.CanTouch = false
	end
end

function toggleplantimmunity(val)
	cropsdamageimmunityrunning = val
	if plantimmuneconn then
		plantimmuneconn:Disconnect()
		plantimmuneconn = nil
	end
	if val then
		plantimmuneconn = workspace.DescendantAdded:Connect(function(desc)
			pcall(applyplantimmunity, desc)
		end)
		for _, desc in workspace:GetDescendants() do
			pcall(applyplantimmunity, desc)
		end
	end
end

hub:CreateTab("Visuals", "rbxassetid://10885640682")
hub:CreateModule("Visuals", {
	name = "Night Vision",
	on = false,
	bind = "None",
	desc = "Remove darkness.",
	callback = function(enabled)
		togglenightvision(enabled)
	end,
	opts = {}
})

hub:CreateModule("Main", {
	name = "Crops Damage Immunity",
	on = false,
	bind = "None",
	desc = "No crop damage.",
	callback = function(enabled)
		toggleplantimmunity(enabled)
	end,
	opts = {
		{type = "checkbox", label = "Immune to Poison Ivy", value = true, callback = function(value)
			poisonivyimmune = value
			if cropsdamageimmunityrunning then toggleplantimmunity(true) end
		end},
		{type = "checkbox", label = "Immune to Ghost Pepper", value = true, callback = function(value)
			ghostpepperimmune = value
			if cropsdamageimmunityrunning then toggleplantimmunity(true) end
		end},
		{type = "checkbox", label = "Immune to Venom Spitter", value = true, callback = function(value)
			venomspitterimmune = value
			if cropsdamageimmunityrunning then toggleplantimmunity(true) end
		end},
		{type = "checkbox", label = "Immune to Thorn Rose", value = true, callback = function(value)
			thornroseimmune = value
			if cropsdamageimmunityrunning then toggleplantimmunity(true) end
		end}
	}
})


petsniperrunning = false
petsniperdelay = 1
petsniperlist = ""
petsniperrarities = ""
petsnipermutlist = ""
petsnipermaxdist = 999999
petsniperreserve = 0
petsniperactive = false
local function petsniperallowed(petName)
	if petsniperlist == "" then return true end
	local set = {}
	for s in (petsniperlist .. ","):gmatch("([^,]+),") do
		set[s:match("^%s*(.-)%s*$")] = true
	end
	return set[petName] == true
end
local function petsniperrarityallowed(rarity)
	if petsniperrarities == "" then return true end
	local set = {}
	for s in (petsniperrarities .. ","):gmatch("([^,]+),") do
		set[s:match("^%s*(.-)%s*$")] = true
	end
	return set[rarity] == true
end
local function petsnipermutallowed(mut)
	if not mut or mut == "" then mut = "None" end
	if petsnipermutlist == "" then return true end
	local set = {}
	for s in (petsnipermutlist .. ","):gmatch("([^,]+),") do
		set[s:match("^%s*(.-)%s*$")] = true
	end
	return set[mut] == true
end
local function dopetsniper()
	if petsniperactive then return end
	local map = workspace:FindFirstChild("Map")
	local wildSpawns = map and map:FindFirstChild("WildPetSpawns")
	if not wildSpawns then return end
	local currentSheckles = getPlayerCurrency()
	local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
	for _, model in wildSpawns:GetChildren() do
		if not petsniperrunning then break end
		if model:IsA("Model") then
			local petName = model:GetAttribute("PetName")
			if not petName then
				local mName = model.Name
				petName = mName:match("^WildPet_(.-)_WildPet") or mName:match("^WildPet_(.-)_") or mName
			end
			local cleanName = petName:gsub("^WildPet_[^_]+_", "")
			local mutation = model:GetAttribute("Mutation") or "None"
			local info = getPetInfo(cleanName)
			local rarity = info and info.Rarity or "Common"
			local costStr = info and info.Cost or "Sheckle 0"
			local cost = tonumber(costStr:gsub("%D", "")) or 0
			if petsniperallowed(cleanName) and petsniperrarityallowed(rarity) and petsnipermutallowed(mutation) then
				local ownerId = model:GetAttribute("OwnerUserId")
				if not ownerId or ownerId == 0 then
					local rp = model:FindFirstChild("RootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
					if rp then
						if cost == 0 or (currentSheckles - petsniperreserve) >= cost then
							petsniperactive = true
							task.spawn(function()
								for i = 1, 4 do
									if not petsniperrunning then break end
									pcall(function() Networking.Pets.WildPetTame:Fire(rp) end)
									task.wait(0.05)
								end
								task.wait(0.2)
								petsniperactive = false
							end)
							break
						end
					end
				end
			end
		end
	end
end
hub:CreateModule("Auto Buy", {
	name = "Pet Sniper",
	on = false,
	bind = "None",
	desc = "Auto tame wild pets.",
	callback = function(enabled)
		petsniperrunning = enabled
		if enabled then
			task.spawn(function()
				while petsniperrunning do
					pcall(dopetsniper)
					task.wait(petsniperdelay)
				end
			end)
		end
	end,
	opts = {
		{type = "slider", label = "Snipe Delay", value = 1, min = 0.5, max = 15, suffix = "s", callback = function(value)
			petsniperdelay = value
		end},
		{type = "multiselect", label = "Filter Pets", value = "", list = gameLists.pets, callback = function(value)
			petsniperlist = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "pets")
		end},
		{type = "multiselect", label = "Filter Rarities", value = "", list = gameLists.rarities, callback = function(value)
			petsniperrarities = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "rarities")
		end},
		{type = "multiselect", label = "Filter Mutations", value = "None", list = gameLists.mutations, callback = function(value)
			petsnipermutlist = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "mutations")
		end},
		{type = "textbox", label = "Min Currency Reserve", value = "0", placeholder = "Reserve currency...", callback = function(value)
			petsniperreserve = tonumber(value) or 0
		end},
	}
})
local PREDICT_RESTOCK_PERIOD = 300
local PREDICT_TIME_CYCLE = 600
local PREDICT_SCHEDULE_REPEAT = 2016
local PREDICT_COMMUNITY_URL = "https://raw.githubusercontent.com/jcgaming-official/GAG-2-Predictor/main/script.js"
local predictShopOffsets = {
	SeedShop = 0,
	GearShop = 0,
	CrateShop = 0,
}
local predictShopCalibrated = {
	SeedShop = false,
	GearShop = false,
	CrateShop = false,
}
local predictCommunitySchedules = nil
local predictCommunityAnchors = {
	SeedShop = 0,
	GearShop = 0,
	CrateShop = 0,
}
local predictCommunityNames = {
	SeedShop = {},
	GearShop = {},
	CrateShop = {},
}
local predictCommunityLoaded = false
local predictRollSeedAdd = {
	SeedShop = 3,
	GearShop = 1,
	CrateShop = 2,
}
local loadPredictCommunitySchedules
local predictStockFromCommunity
local predictStockFromRoll
local calibratePredictShopOffset
local predictShopStockAt
local predictMoonColors = {
	Moon = "rgb(150,170,255)",
	Goldmoon = "rgb(255,210,70)",
	["Rainbow Moon"] = "rgb(190,120,255)",
	Bloodmoon = "rgb(240,80,80)",
	["Mega Moon"] = "rgb(120,160,255)",
}
local predictWeatherMeta = {
	Rain = { occurance = 120, last = 300, color = "rgb(80,150,255)" },
	Lightning = { occurance = 90, last = 300, color = "rgb(255,215,0)" },
	Rainbow = { occurance = 60, last = 300, color = "rgb(255,100,255)" },
	Snowfall = { occurance = 30, last = 150, color = "rgb(150,220,255)" },
	Starfall = { occurance = 30, last = 150, color = "rgb(180,100,255)" },
	Aurora = { occurance = 30, last = 150, color = "rgb(100,255,170)" },
	Sunburst = { occurance = 30, last = 300, color = "rgb(255,120,0)" },
	Eclipse = { occurance = 30, last = 150, color = "rgb(200,200,220)" },
}
local predictTimePhases = nil
local predictNightPhaseIndex = 3
local predictMoonGating = nil
local predictTimeCycleData = nil

local function getPredictServerNow()
	return workspace:GetServerTimeNow()
end

local function formatPredictClock(unixTime)
	return os.date("%H:%M:%S", math.floor(tonumber(unixTime) or 0))
end

local function formatPredictCountdown(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	if seconds >= 3600 then
		return string.format("%dh %02dm %02ds", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
	end
	return formatSessionTime(seconds)
end

local function predictWhite(text)
	return string.format('<font color="rgb(255,255,255)">%s</font>', tostring(text))
end

local function predictLabel(label, value)
	return string.format('<font color="rgb(180,200,220)">%s:</font> %s', label, predictWhite(value))
end

local function ensurePredictModules()
	if predictTimeCycleData and predictMoonGating and predictTimePhases then
		return true
	end
	local sharedModules = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules") or game:GetService("ReplicatedStorage"):WaitForChild("SharedModules", 3)
	if not sharedModules then
		return false
	end
	local timeCycleVal = sharedModules:FindFirstChild("TimeCycleData") or sharedModules:WaitForChild("TimeCycleData", 2)
	local moonGatingVal = sharedModules:FindFirstChild("MoonGating") or sharedModules:WaitForChild("MoonGating", 2)
	if not timeCycleVal or not moonGatingVal then
		return false
	end
	local okTcd, tcd = pcall(require, timeCycleVal)
	local okMg, mg = pcall(require, moonGatingVal)
	if not okTcd or not okMg or not tcd or not tcd.Data then
		return false
	end
	predictTimeCycleData = tcd
	predictMoonGating = mg
	predictTimePhases = {}
	for phaseName, phaseData in tcd.Data do
		table.insert(predictTimePhases, {
			Name = phaseName,
			Order = phaseData.StartOrder or 999,
			Duration = phaseData.Lasts or 0,
			Weathers = phaseData.Weathers,
		})
	end
	table.sort(predictTimePhases, function(a, b)
		return a.Order < b.Order
	end)
	predictNightPhaseIndex = 3
	for index, phase in predictTimePhases do
		if phase.Name == "Night" then
			predictNightPhaseIndex = index
			break
		end
	end
	local weatherDataVal = sharedModules:FindFirstChild("WeatherData") or sharedModules:WaitForChild("WeatherData", 2)
	if weatherDataVal then
		local okWd, wd = pcall(require, weatherDataVal)
		if okWd and wd and wd.Data then
			for _, weatherEntry in wd.Data do
				if weatherEntry.Name and predictWeatherMeta[weatherEntry.Name] then
					predictWeatherMeta[weatherEntry.Name].occurance = weatherEntry.Occurance or predictWeatherMeta[weatherEntry.Name].occurance
					predictWeatherMeta[weatherEntry.Name].last = weatherEntry.Last or predictWeatherMeta[weatherEntry.Name].last
				end
			end
		end
	end
	return true
end

local function pickPredictWeather(phaseData, rng)
	if not phaseData or not phaseData.Weathers or not predictMoonGating then
		return "Moon"
	end
	local totalChance = 0
	for weatherName, weatherInfo in phaseData.Weathers do
		if not weatherInfo.AdminOnly and predictMoonGating.IsNaturallySpawnable(weatherName) then
			totalChance = totalChance + (weatherInfo.Chance or 0)
		end
	end
	if totalChance <= 0 then
		return "Moon"
	end
	local roll = rng:NextNumber() * totalChance
	local accumulator = 0
	for weatherName, weatherInfo in phaseData.Weathers do
		if not weatherInfo.AdminOnly and predictMoonGating.IsNaturallySpawnable(weatherName) then
			accumulator = accumulator + (weatherInfo.Chance or 0)
			if roll <= accumulator then
				return weatherName
			end
		end
	end
	for weatherName in phaseData.Weathers do
		if predictMoonGating.IsNaturallySpawnable(weatherName) then
			return weatherName
		end
	end
	return "Moon"
end

local function predictNightMoon(cycleId)
	if not ensurePredictModules() then
		return "Moon"
	end
	local nightPhase = predictTimeCycleData.Data.Night
	if not nightPhase then
		return "Moon"
	end
	local rng = Random.new(cycleId * 1000 + predictNightPhaseIndex)
	return pickPredictWeather(nightPhase, rng)
end

local function getPredictCycleInfo(now)
	now = now or getPredictServerNow()
	if not ensurePredictModules() then
		return 0, "Unknown", 0, 0
	end
	local totalDuration = 0
	for _, phase in predictTimePhases do
		totalDuration = totalDuration + phase.Duration
	end
	if totalDuration <= 0 then
		totalDuration = PREDICT_TIME_CYCLE
	end
	local cycleId = math.floor(now / totalDuration)
	local inCycle = now % totalDuration
	local elapsed = 0
	for _, phase in predictTimePhases do
		if inCycle < elapsed + phase.Duration then
			return cycleId, phase.Name, math.max(0, elapsed + phase.Duration - inCycle), inCycle - elapsed
		end
		elapsed = elapsed + phase.Duration
	end
	return cycleId, predictTimePhases[#predictTimePhases].Name or "Night", 0, 0
end

local function getPredictCycleDuration()
	if not ensurePredictModules() then
		return PREDICT_TIME_CYCLE
	end
	local totalDuration = 0
	for _, phase in predictTimePhases do
		totalDuration = totalDuration + phase.Duration
	end
	return totalDuration > 0 and totalDuration or PREDICT_TIME_CYCLE
end

local function getNightStartUnix(cycleId)
	if not ensurePredictModules() then
		return cycleId * PREDICT_TIME_CYCLE + 480
	end
	local offset = 0
	for _, phase in predictTimePhases do
		if phase.Name == "Night" then
			break
		end
		offset = offset + phase.Duration
	end
	return cycleId * getPredictCycleDuration() + offset
end

local function buildPredictCycleText()
	if not ensurePredictModules() then
		return "Time cycle data unavailable."
	end
	local now = getPredictServerNow()
	local cycleId, phaseName, phaseLeft = getPredictCycleInfo(now)
	local activeWeather = workspace:GetAttribute("ActiveWeather")
	local adminWeather = type(activeWeather) == "string" and activeWeather ~= "" and activeWeather or nil
	local lines = {
		predictLabel("Server time", formatPredictClock(now)),
		string.format('<font color="rgb(180,200,220)">Cycle #%d</font> · %s', cycleId, predictLabel("Phase", phaseName)),
		predictLabel("Phase ends in", formatPredictCountdown(phaseLeft)),
	}
	if phaseName == "Night" then
		local moonName = adminWeather or predictNightMoon(cycleId)
		local moonColor = predictMoonColors[moonName] or "rgb(200,200,210)"
		lines[#lines + 1] = string.format('Tonight: <font color="%s">%s</font>%s', moonColor, moonName, adminWeather and predictWhite(" (admin)") or "")
	else
		local nextNight = getNightStartUnix(cycleId)
		if nextNight <= now then
			nextNight = getNightStartUnix(cycleId + 1)
		end
		local nextMoon = predictNightMoon(math.floor(nextNight / getPredictCycleDuration()))
		local moonColor = predictMoonColors[nextMoon] or "rgb(200,200,210)"
		lines[#lines + 1] = string.format('Next night (%s): <font color="%s">%s</font>', predictWhite(formatPredictClock(nextNight)), moonColor, nextMoon)
	end
	return table.concat(lines, "\n")
end

local function buildPredictMoonText()
	if not ensurePredictModules() then
		return "Moon prediction unavailable."
	end
	local now = getPredictServerNow()
	local endTime = now + (24 * 3600)
	local events = {}
	local cycleDuration = getPredictCycleDuration()
	local cycleId = math.floor(now / cycleDuration)
	local lastCycle = math.ceil(endTime / cycleDuration)
	for cid = cycleId, lastCycle do
		local nightStart = getNightStartUnix(cid)
		if nightStart >= now and nightStart <= endTime then
			local moonName = predictNightMoon(cid)
			if moonName ~= "Moon" then
				table.insert(events, { time = nightStart, name = moonName })
			end
		end
	end
	table.sort(events, function(a, b)
		return a.time < b.time
	end)
	local lines = {}
	for _, event in events do
		local moonColor = predictMoonColors[event.name] or "rgb(200,200,210)"
		table.insert(lines, string.format('<font color="%s">%s</font> — %s', moonColor, predictWhite(formatPredictClock(event.time)), predictWhite(event.name)))
	end
	if #lines == 0 then
		return predictWhite("No rare moons in the next 24 hours.")
	end
	return table.concat(lines, "\n")
end

local function buildPredictWeatherText()
	local weatherValues = game:GetService("ReplicatedStorage"):FindFirstChild("WeatherValues")
	if not weatherValues then
		return "WeatherValues unavailable."
	end
	local now = DateTime.now().UnixTimestamp
	local weatherOrder = {"Rain", "Lightning", "Rainbow", "Snowfall", "Starfall", "Aurora", "Sunburst", "Eclipse"}
	local rows = {}
	for _, weatherName in weatherOrder do
		local meta = predictWeatherMeta[weatherName]
		if meta then
			local isPlaying = weatherValues:GetAttribute(weatherName .. "_Playing") == true
			local endTime = weatherValues:GetAttribute(weatherName .. "_EndTime") or 0
			local timeLeft = math.max(0, endTime - now)
			local nextEarliest = endTime + (meta.occurance or 60)
			local nextIn = math.max(0, nextEarliest - now)
			table.insert(rows, {
				name = weatherName,
				meta = meta,
				isPlaying = isPlaying,
				timeLeft = timeLeft,
				nextIn = nextIn,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.isPlaying ~= b.isPlaying then
			return a.isPlaying
		end
		if a.isPlaying then
			return a.timeLeft > b.timeLeft
		end
		return a.nextIn < b.nextIn
	end)
	local lines = {}
	for _, entry in rows do
		local color = entry.meta.color or "rgb(200,200,210)"
		if entry.isPlaying then
			table.insert(lines, string.format('<font color="%s">%s</font> ACTIVE · %s left', color, entry.name, formatPredictCountdown(entry.timeLeft)))
		else
			local nextLabel = entry.nextIn <= 0 and "Soon" or formatPredictCountdown(entry.nextIn)
			table.insert(lines, string.format('%s next ≥ %s', entry.name, nextLabel))
		end
	end
	if #lines == 0 then
		return "No weather data."
	end
	return table.concat(lines, "\n")
end

function readShopStockSnapshot(shopFolder)
	local snapshot = {}
	if not shopFolder then
		return snapshot
	end
	local itemsFolder = shopFolder:FindFirstChild("Items")
	if not itemsFolder then
		return snapshot
	end
	for _, itemValue in itemsFolder:GetChildren() do
		if itemValue.Value and itemValue.Value > 0 then
			snapshot[itemValue.Name] = itemValue.Value
		end
	end
	return snapshot
end

local function getPredictScheduleIndex(unix, shopName, offset)
	local anchor = predictCommunityAnchors[shopName]
	if not anchor or anchor <= 0 then
		return 0
	end
	local cycleIndex = math.floor((unix - anchor) / PREDICT_RESTOCK_PERIOD)
	return ((cycleIndex + (offset or 0)) % PREDICT_SCHEDULE_REPEAT) + 1
end

local function parseCommunityIconNames(body, sectionKey, nextSectionKey)
	local names = {}
	local section = body:match("ICON_URLS.-" .. sectionKey .. ":%s*({.-})%s*,%s*" .. nextSectionKey)
	if not section then
		return names
	end
	for itemName in section:gmatch('"([^"]+)"%s*:') do
		table.insert(names, itemName)
	end
	return names
end

local function parseCommunityQArrays(body, sectionKey, nextSectionKey)
	local startPos = body:find('"' .. sectionKey .. '"', 1, true)
	local endPos = body:find('"' .. nextSectionKey .. '"', startPos and (startPos + 1) or 1, true)
	if not startPos or not endPos then
		return {}
	end
	local section = body:sub(startPos, endPos)
	local arrays = {}
	for qChunk in section:gmatch('"q"%s*:%s*%[([^%]]+)%]') do
		local nums = {}
		for numberText in qChunk:gmatch("%d+") do
			table.insert(nums, tonumber(numberText))
		end
		if #nums >= PREDICT_SCHEDULE_REPEAT then
			table.insert(arrays, nums)
		end
	end
	return arrays
end

loadPredictCommunitySchedules = function()
	if predictCommunityLoaded then
		return predictCommunitySchedules ~= nil
	end
	predictCommunityLoaded = true
	local ok, body = pcall(function()
		return game:HttpGet(PREDICT_COMMUNITY_URL)
	end)
	if not ok or typeof(body) ~= "string" or body == "" then
		return false
	end
	predictCommunityAnchors.SeedShop = tonumber(body:match('"seedAnchor"%s*:%s*(%d+)')) or 0
	predictCommunityAnchors.GearShop = tonumber(body:match('"gearAnchor"%s*:%s*(%d+)')) or predictCommunityAnchors.SeedShop
	predictCommunityAnchors.CrateShop = tonumber(body:match('"crateAnchor"%s*:%s*(%d+)')) or predictCommunityAnchors.SeedShop
	predictCommunityNames.SeedShop = parseCommunityIconNames(body, "seeds", "gears")
	predictCommunityNames.GearShop = parseCommunityIconNames(body, "gears", "crates")
	predictCommunityNames.CrateShop = parseCommunityIconNames(body, "crates", "seedAnchor")
	predictCommunitySchedules = {
		SeedShop = parseCommunityQArrays(body, "seeds", "gears"),
		GearShop = parseCommunityQArrays(body, "gears", "crates"),
		CrateShop = parseCommunityQArrays(body, "crates", "seedAnchor"),
	}
	return true
end

predictStockFromCommunity = function(shopName, unix, offset)
	if not predictCommunitySchedules then
		return nil
	end
	local names = predictCommunityNames[shopName]
	local arrays = predictCommunitySchedules[shopName]
	if not names or not arrays or #names == 0 then
		return nil
	end
	local scheduleIndex = getPredictScheduleIndex(unix, shopName, offset)
	local stockMap = {}
	for arrayIndex, quantities in arrays do
		local itemName = names[arrayIndex]
		local quantity = quantities[scheduleIndex]
		if itemName and quantity and quantity > 0 then
			stockMap[itemName] = quantity
		end
	end
	if next(stockMap) == nil then
		return nil
	end
	return stockMap
end

local function getPredictShopCatalog(shopName)
	local sharedModules = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
	if not sharedModules then
		return {}
	end
	local moduleName = shopName == "SeedShop" and "SeedData" or (shopName == "GearShop" and "GearShopData" or "CrateData")
	local enabledModule = shopName == "SeedShop" and "SeedShopEnabled" or (shopName == "GearShop" and "GearShopEnabled" or "CrateShopEnabled")
	local okData, dataModule = pcall(require, sharedModules:WaitForChild(moduleName, 2))
	if not okData or not dataModule then
		return {}
	end
	local enabledChecker = nil
	local enabledVal = sharedModules:FindFirstChild(enabledModule)
	if enabledVal then
		local okEnabled, enabledMod = pcall(require, enabledVal)
		if okEnabled and enabledMod then
			enabledChecker = enabledMod
		end
	end
	local items = {}
	local function getItemName(entry)
		return entry.SeedName or entry.GearName or entry.CrateName or entry.Name
	end
	local function isEnabled(itemName, entry)
		if shopName == "SeedShop" and enabledChecker and enabledChecker.IsSeedEnabled then
			return enabledChecker.IsSeedEnabled(itemName) == true
		end
		if shopName == "GearShop" and enabledChecker and enabledChecker.IsGearEnabled then
			return enabledChecker.IsGearEnabled(itemName) == true
		end
		if shopName == "CrateShop" and enabledChecker and enabledChecker.IsCrateEnabled then
			return enabledChecker.IsCrateEnabled(itemName) == true
		end
		return entry.RestockShop == true
	end
	if shopName == "CrateShop" then
		for _, entry in dataModule do
			if type(entry) == "table" and entry.RestockShop and getItemName(entry) and isEnabled(getItemName(entry), entry) and isShopItemInCurrentWorld(shopName, getItemName(entry)) then
				table.insert(items, entry)
			end
		end
	else
		for _, entry in dataModule do
			if type(entry) == "table" and entry.RestockShop and getItemName(entry) and isEnabled(getItemName(entry), entry) and isShopItemInCurrentWorld(shopName, getItemName(entry)) then
				table.insert(items, entry)
			end
		end
	end
	table.sort(items, function(a, b)
		return (a.SeedShopDisplayOrder or a.GearShopDisplayOrder or 999) < (b.SeedShopDisplayOrder or b.GearShopDisplayOrder or 999)
	end)
	return items
end

predictStockFromRoll = function(shopName, unix)
	local items = getPredictShopCatalog(shopName)
	if #items == 0 then
		return nil
	end
	local cycleIndex = math.floor(unix / PREDICT_RESTOCK_PERIOD) + (predictRollSeedAdd[shopName] or 0)
	local rng = Random.new(cycleIndex)
	local stockMap = {}
	for _, entry in items do
		local itemName = entry.SeedName or entry.GearName or entry.CrateName or entry.Name
		if not isShopItemInCurrentWorld(shopName, itemName) then
			continue
		end
		local chance = entry.RestockChance or 0
		if chance > 0 and rng:NextInteger(1, 100) <= chance then
			local restockValues = entry.RestockValues
			if restockValues then
				stockMap[itemName] = rng:NextInteger(restockValues.Min, restockValues.Max)
			end
		end
	end
	if next(stockMap) == nil then
		return nil
	end
	return stockMap
end

local function countPredictStockMatches(expected, actual)
	if typeof(expected) ~= "table" or typeof(actual) ~= "table" then
		return 0
	end
	local matches = 0
	for itemName, quantity in expected do
		if actual[itemName] == quantity then
			matches = matches + 1
		end
	end
	return matches
end

local function mergePredictStockMaps(primary, secondary)
	local merged = {}
	if typeof(primary) == "table" then
		for itemName, quantity in primary do
			merged[itemName] = quantity
		end
	end
	if typeof(secondary) == "table" then
		for itemName, quantity in secondary do
			if merged[itemName] == nil then
				merged[itemName] = quantity
			end
		end
	end
	return merged
end

calibratePredictShopOffset = function(shopName)
	local ok, err = pcall(function()
	local stockValues = game:GetService("ReplicatedStorage"):FindFirstChild("StockValues")
	local shopFolder = stockValues and stockValues:FindFirstChild(shopName)
	local lastRestock = shopFolder and shopFolder:FindFirstChild("UnixLastRestock")
	if not lastRestock then
		return
	end
	local currentStock = filterPredictStockByWorld(readShopStockSnapshot(shopFolder), shopName)
	if next(currentStock) == nil then
		return
	end
	if loadPredictCommunitySchedules() then
		local bestOffset, bestMatches = predictShopOffsets[shopName] or 0, -1
		for offset = 0, PREDICT_SCHEDULE_REPEAT - 1 do
			local predicted = filterPredictStockByWorld(predictStockFromCommunity(shopName, lastRestock.Value, offset), shopName)
			local matches = countPredictStockMatches(currentStock, predicted)
			if matches > bestMatches then
				bestMatches = matches
				bestOffset = offset
			end
			if offset % 128 == 127 then
				task.wait()
			end
		end
		if bestMatches >= 2 then
			predictShopOffsets[shopName] = bestOffset
		end
	end
	local bestRollMatches = -1
	local bestRollSeedAdd = predictRollSeedAdd[shopName] or 0
	for seedAdd = -10, 10 do
		predictRollSeedAdd[shopName] = seedAdd
		local rolled = predictStockFromRoll(shopName, lastRestock.Value)
		local matches = countPredictStockMatches(currentStock, rolled)
		if matches > bestRollMatches then
			bestRollMatches = matches
			bestRollSeedAdd = seedAdd
		end
	end
	predictRollSeedAdd[shopName] = bestRollSeedAdd
	predictShopCalibrated[shopName] = true
	end)
	if not ok then
		warn("[Predict] calibrate failed for", shopName, err)
	end
end

predictShopStockAt = function(shopName, unix)
	loadPredictCommunitySchedules()
	local scheduled = predictStockFromCommunity(shopName, unix, predictShopOffsets[shopName])
	if scheduled then
		return filterPredictStockByWorld(scheduled, shopName), "schedule"
	end
	local rolled = predictStockFromRoll(shopName, unix)
	if rolled then
		return filterPredictStockByWorld(rolled, shopName), "roll"
	end
	return nil, "unknown"
end

local function formatPredictStockLines(stockMap, emptyText)
	local names = {}
	for itemName in stockMap do
		table.insert(names, itemName)
	end
	table.sort(names)
	if #names == 0 then
		return predictWhite(emptyText or "Nothing in stock.")
	end
	local lines = {}
	for _, itemName in names do
		table.insert(lines, string.format('%s x%s', predictWhite(itemName), predictWhite(stockMap[itemName])))
	end
	return table.concat(lines, "\n")
end

local function buildPredictNextStockText(shopName, title)
	local stockValues = game:GetService("ReplicatedStorage"):FindFirstChild("StockValues")
	local shopFolder = stockValues and stockValues:FindFirstChild(shopName)
	if not shopFolder then
		return predictWhite("Prediction unavailable.")
	end
	if not predictShopCalibrated[shopName] then
		task.defer(calibratePredictShopOffset, shopName)
	end
	local nextRestock = shopFolder:FindFirstChild("UnixNextRestock")
	if not nextRestock then
		return predictWhite("Prediction unavailable.")
	end
	local now = DateTime.now().UnixTimestamp
	local okPredict, predictedStock, source = pcall(predictShopStockAt, shopName, nextRestock.Value)
	if not okPredict then
		warn("[Predict] stock lookup failed for", shopName, predictedStock)
		return predictWhite("Prediction unavailable.")
	end
	local header = table.concat({
		predictLabel("Restock in", formatPredictCountdown(nextRestock.Value - now)),
		predictLabel("At", formatPredictClock(nextRestock.Value)),
	}, "\n")
	if predictedStock then
		return header .. "\n" .. formatPredictStockLines(predictedStock, "Empty restock.")
	end
	return header .. "\n" .. predictWhite("Could not load stock schedule.")
end

hubStore = hubStore or {}
hubStore.buildPredictMoonText = buildPredictMoonText
hubStore.buildPredictNextStockText = buildPredictNextStockText

task.spawn(function()
	local stockValues = game:GetService("ReplicatedStorage"):WaitForChild("StockValues", 30)
	if not stockValues then
		return
	end
	for _, shopName in {"SeedShop", "GearShop", "CrateShop"} do
		local shopFolder = stockValues:WaitForChild(shopName, 10)
		local lastRestock = shopFolder and shopFolder:WaitForChild("UnixLastRestock", 10)
		if lastRestock then
			task.defer(function()
				calibratePredictShopOffset(shopName)
			end)
			lastRestock.Changed:Connect(function()
				task.defer(function()
					calibratePredictShopOffset(shopName)
				end)
			end)
		end
	end
end)

hub:CreateTab("Predict", "rbxassetid://16000149927")
;(function()
	local predictWidgets = {}
	local predictThread = nil
	local predictUpdaters = {
		moons = function()
			local buildMoonText = hubStore.buildPredictMoonText or buildPredictMoonText
			return buildMoonText(), "Moon Events (24h)"
		end,
		seedNext = function()
			local buildNextStockText = hubStore.buildPredictNextStockText or buildPredictNextStockText
			return buildNextStockText("SeedShop", "Seeds"), "Next Seed Restock"
		end,
		gearNext = function()
			local buildNextStockText = hubStore.buildPredictNextStockText or buildPredictNextStockText
			return buildNextStockText("GearShop", "Gear"), "Next Gear Restock"
		end,
		crateNext = function()
			local buildNextStockText = hubStore.buildPredictNextStockText or buildPredictNextStockText
			return buildNextStockText("CrateShop", "Crates"), "Next Crate Restock"
		end,
	}

	local function refreshPredictWidget(key)
		local widget = predictWidgets[key]
		local updater = predictUpdaters[key]
		if not widget or not updater then
			return
		end
		local ok, resultContent, resultTitle = pcall(updater)
		if ok then
			setHubParagraph(widget, resultContent, resultTitle)
		else
			warn("[Predict] update failed for", key, resultContent)
			setHubParagraph(widget, "Update error.", resultTitle or key)
		end
	end

	local function startPredictLoop()
		if predictThread then
			return
		end
		predictThread = task.spawn(function()
			while next(predictWidgets) do
				for key in pairs(predictUpdaters) do
					refreshPredictWidget(key)
				end
				task.wait(1)
			end
			predictThread = nil
		end)
	end

	local function bindPredictParagraph(key, widget)
		if not widget then
			warn("[Predict] missing widget for", key)
			return
		end
		if predictWidgets[key] then
			return
		end
		predictWidgets[key] = widget
		enableParagraphRichText(widget)
		refreshPredictWidget(key)
	end

	hub:CreateModule("Predict", {
		name = "Live Predictions",
		notoggle = true,
		on = false,
		bind = "None",
		callback = function() end,
		opts = {
			{type = "paragraph", title = "Moon Events (24h)", content = "Loading...", onCreate = function(widget)
				bindPredictParagraph("moons", widget)
			end},
			{type = "paragraph", title = "Next Seed Restock", content = "Loading...", onCreate = function(widget)
				bindPredictParagraph("seedNext", widget)
			end},
			{type = "paragraph", title = "Next Gear Restock", content = "Loading...", onCreate = function(widget)
				bindPredictParagraph("gearNext", widget)
			end},
			{type = "paragraph", title = "Next Crate Restock", content = "Loading...", onCreate = function(widget)
				bindPredictParagraph("crateNext", widget)
			end},
		}
	})
	table.insert(hubStore.paragraphBootstraps, function()
		for key in pairs(predictUpdaters) do
			refreshPredictWidget(key)
		end
		startPredictLoop()
	end)
end)()
hub:CreateTab("Misc", "rbxassetid://10885640682")
local instantPromptsEnabled = false
hub:CreateModule("Misc", {
	name = "Instant Prompts",
	beta = false,
	on = false,
	bind = "None",
	desc = "Instant prompts.",
	callback = function(enabled)
		instantPromptsEnabled = enabled
		if enabled then
			for _, prompt in workspace:GetDescendants() do
				if prompt:IsA("ProximityPrompt") then
					prompt.HoldDuration = 0
				end
			end
		end
	end,
	opts = {}
})
espftype = "Blacklist"
espflist = ""
espmuttype = "Whitelist"
espmutlist = ""
espshowothers = false
espmaxdist = 300
;(function()
local function espallowed(seedName)
	local set = {}
	for name in (espflist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if espflist == "" or espflist == "None" then
		if espftype == "Whitelist" then
			return false
		else
			return true
		end
	end
	if espftype == "Whitelist" then
		return set[seedName] == true
	end
	return set[seedName] == nil
end
local function espmutallowed(mutation)
	if not mutation or mutation == "" then
		mutation = "None"
	end
	local set = {}
	for name in (espmutlist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if espmutlist == "" or espmutlist == "None" or set["None"] then
		return true
	end
	if espmuttype == "Whitelist" then
		return set[mutation] == true
	end
	return set[mutation] == nil
end
esprunning = false
espminweight = 0
espmaxweight = 0
espshowbeam = false
espBills = {}
espBeams = {}
espThread = nil
local function updateESP()
	local function formatNumber(n)
		if n >= 1000000000000 then
			return string.format("%.2fT", n / 1000000000000):gsub("%.?0+([T])$", "%1")
		elseif n >= 1000000000 then
			return string.format("%.2fB", n / 1000000000):gsub("%.?0+([B])$", "%1")
		elseif n >= 1000000 then
			return string.format("%.2fM", n / 1000000):gsub("%.?0+([M])$", "%1")
		elseif n >= 1000 then
			return string.format("%.2fK", n / 1000):gsub("%.?0+([K])$", "%1")
		end
		local rounded = math.floor(n * 10 + 0.5) / 10
		return (string.format("%.1f", rounded):gsub("%.0$", ""))
	end
	if not esprunning then
		for _, bill in pairs(espBills) do
			pcall(function() bill:Destroy() end)
		end
		table.clear(espBills)
		clearEspBeamTable(espBeams)
		return
	end
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then return end
	local currentBills = {}
	local currentBeams = {}
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local function processInstance(obj, plant)
		plant = plant or ((obj.Parent and obj.Parent.Name == "Fruits") and obj.Parent.Parent) or obj
		local seedName = getseedname(obj)
		if not seedName or seedName == "" then return end
		local cropName = getcropname(seedName) or seedName
		local mutation = obj:GetAttribute("Mutation") or "None"
		if not espallowed(cropName) or not espmutallowed(mutation) then return end
		local hp = obj:FindFirstChild("HarvestPart") or obj:FindFirstChildWhichIsA("BasePart") or (obj:IsA("BasePart") and obj) or (obj:IsA("Model") and obj.PrimaryPart)
		if not hp then return end
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (hp.Position - rootPart.Position).Magnitude
			if dist > espmaxdist then return end
		end
		if obj.Parent and obj.Parent.Name == "Fruits" and tonumber(obj.Name) then
			return
		end
		local baseWeight = getbaseweight(seedName)
		if not baseWeight then
				baseWeight = 1
		end
		local sizeMulti = obj:GetAttribute("SizeMulti") or obj:GetAttribute("SizeMultiplier")
		if not sizeMulti then
			local attrWeight = obj:GetAttribute("Weight")
			if attrWeight then
				if baseWeight > 50 then
					sizeMulti = attrWeight / baseWeight
				else
					sizeMulti = (attrWeight / 1000) / baseWeight
				end
			end
		end
		if not sizeMulti then
			local isFruit = (obj.Parent and obj.Parent.Name == "Fruits")
			local lastGen
			if isFruit then
				lastGen = obj:GetAttribute("LastGenerated") or obj:GetAttribute("PlantedAt")
			else
				lastGen = obj:GetAttribute("PlantedAt") or obj:GetAttribute("LastGenerated")
			end
			local psm = getPlantSizeMultipliers()
			if lastGen and psm and typeof(psm) == "table" then
				local ok, res
				if isFruit and typeof(psm.GetRandomFruitSize) == "function" then
					ok, res = pcall(function() return psm.GetRandomFruitSize(1, lastGen) end)
				elseif typeof(psm.GetRandomPlantSize) == "function" then
					local stage = obj:GetAttribute("Age") or obj:GetAttribute("MaxAge") or 1
					ok, res = pcall(function() return psm.GetRandomPlantSize(stage, lastGen, seedName) end)
				end
				if ok and res then
					sizeMulti = res
				end
			end
		end
		if not sizeMulti then sizeMulti = 1 end
		local decay = tonumber(obj:GetAttribute("DecayAlpha")) or 0
		local value = estimateGardenObjectPrice(obj, plant)
		local calcWeightKg = getweightkg(obj, seedName)
		local wf = getWeightFormat()
		local weightStr = ""
		if wf and typeof(wf) == "table" and typeof(wf.FormatGrams) == "function" then
			local ok, formatted = pcall(wf.FormatGrams, calcWeightKg)
			if ok and formatted then
				weightStr = formatted
			else
				weightStr = string.format("%.2fkg", calcWeightKg)
			end
		else
			weightStr = string.format("%.2fkg", calcWeightKg)
		end
		local matchesMin = (espminweight == 0 or calcWeightKg >= espminweight)
		local matchesMax = (espmaxweight == 0 or calcWeightKg <= espmaxweight)
		if not (matchesMin and matchesMax) then
			return
		end
		local bb = hp:FindFirstChild("FruitESP")
		if not bb then
			bb = Instance.new("BillboardGui")
			bb.Name = "FruitESP"
			bb.Size = UDim2.new(0, 320, 0, 30)
			bb.StudsOffset = Vector3.new(0, 2.5, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = hp
			bb.Parent = hp
			local container = Instance.new("Frame")
			container.Name = "Container"
			container.Size = UDim2.new(0, 0, 1, 0)
			container.AutomaticSize = Enum.AutomaticSize.X
			container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
			container.BorderSizePixel = 0
			container.AnchorPoint = Vector2.new(0.5, 0.5)
			container.Position = UDim2.new(0.5, 0, 0.5, 0)
			container.Parent = bb
			rnd(container, 15)
			stk(container, Color3.fromRGB(30, 30, 35), 1)
			pad(container, 6, 6, 12, 12)
			local lay = Instance.new("UIListLayout")
			lay.FillDirection = Enum.FillDirection.Horizontal
			lay.VerticalAlignment = Enum.VerticalAlignment.Center
			lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
			lay.Padding = UDim.new(0, 8)
			lay.Parent = container
		end
		currentBills[bb] = true
		espBills[bb] = bb
		local container = bb:FindFirstChild("Container")
		if container then
			local nameLbl = container:FindFirstChild("NameLbl")
			if nameLbl then
			else
				container:ClearAllChildren()
				rnd(container, 15)
				stk(container, Color3.fromRGB(30, 30, 35), 1)
				pad(container, 6, 6, 12, 12)
				local lay = Instance.new("UIListLayout")
				lay.FillDirection = Enum.FillDirection.Horizontal
				lay.VerticalAlignment = Enum.VerticalAlignment.Center
				lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
				lay.Padding = UDim.new(0, 8)
				lay.Parent = container
				local iconUrl = fruitIcons and fruitIcons[seedName]
				if iconUrl and getFruitAsset then
					local img = Instance.new("ImageLabel")
					img.Size = UDim2.new(0, 18, 0, 18)
					img.BackgroundTransparency = 1
					img.ScaleType = Enum.ScaleType.Fit
					img.Parent = container
					getFruitAsset(seedName, iconUrl, img)
				end
				local function createLabel(text, color)
					local lbl = Instance.new("TextLabel")
					lbl.BackgroundTransparency = 1
					lbl.Text = text
					lbl.TextColor3 = color
					lbl.TextSize = 10
					lbl.Font = Enum.Font.MontserratBold
					lbl.Size = UDim2.new(0, 0, 1, 0)
					lbl.AutomaticSize = Enum.AutomaticSize.X
					lbl.Parent = container
					return lbl
				end
				local nameLbl = createLabel(seedName, Color3.fromRGB(255, 255, 255))
				nameLbl.Name = "NameLbl"
				if mutation ~= "None" then
					local mutCol = Color3.fromRGB(255, 195, 55)
					local useGrad = false
					local gradColors = nil
					local animateGrad = false
					local animSpeed = 0.3
					if mutation == "Rainbow" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
							ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
							ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
							ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))
						}
						animateGrad = true
						animSpeed = 0.4
					elseif mutation == "Gold" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 245, 150)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))
						}
						animateGrad = true
						animSpeed = 0.3
					elseif mutation == "Blood" or mutation == "Bloodlit" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 0, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
						}
					elseif mutation == "Frozen" then
						mutCol = Color3.fromRGB(0, 240, 255)
					elseif mutation == "Dark" then
						mutCol = Color3.fromRGB(100, 100, 120)
					elseif mutation == "Light" then
						mutCol = Color3.fromRGB(240, 240, 255)
					elseif mutation == "Glitch" then
						mutCol = Color3.fromRGB(0, 255, 150)
					elseif mutation == "Giant" then
						mutCol = Color3.fromRGB(255, 100, 100)
					elseif mutation == "Electric" then
						mutCol = Color3.fromRGB(0, 0, 0)
					elseif mutation == "Starstruck" then
						mutCol = Color3.fromRGB(255, 255, 0)
					elseif mutation == "Aurora" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 170)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 150, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 80, 255))
						}
					elseif mutation == "Ignited" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 0))
						}
					end
					local mutLbl = createLabel("[" .. mutation .. "]", mutCol)
					if mutation == "Electric" then
						local stroke = Instance.new("UIStroke")
						stroke.Color = Color3.fromRGB(255, 255, 255)
						stroke.Thickness = 1
						stroke.Parent = mutLbl
					end
					if useGrad and gradColors then
						local grad = Instance.new("UIGradient")
						grad.Color = ColorSequence.new(gradColors)
						grad.Parent = mutLbl
						if animateGrad then
							task.spawn(function()
								while mutLbl and mutLbl.Parent do
									local t = (os.clock() * animSpeed) % 1
									grad.Offset = Vector2.new(-t * 2 + 1, 0)
									task.wait()
								end
							end)
						end
					end
				end
				createLabel(weightStr, Color3.fromRGB(130, 130, 140))
				local priceTag = container:FindFirstChild("PriceTag")
				if value > 0 then
					if not priceTag then
						priceTag = Instance.new("Frame")
						priceTag.Name = "PriceTag"
						priceTag.Size = UDim2.new(0, 0, 1, 0)
						priceTag.AutomaticSize = Enum.AutomaticSize.X
						priceTag.BackgroundTransparency = 1
						priceTag.Parent = container
						local priceLay = Instance.new("UIListLayout")
						priceLay.FillDirection = Enum.FillDirection.Horizontal
						priceLay.VerticalAlignment = Enum.VerticalAlignment.Center
						priceLay.Padding = UDim.new(0, 4)
						priceLay.Parent = priceTag
						local coinImg = Instance.new("ImageLabel")
						coinImg.Name = "CoinImg"
						coinImg.Size = UDim2.new(0, 11, 0, 11)
						coinImg.BackgroundTransparency = 1
						coinImg.ScaleType = Enum.ScaleType.Fit
						coinImg.Parent = priceTag
						getFruitAsset("SheckleCoin", nil, coinImg)
						local priceLbl = Instance.new("TextLabel")
						priceLbl.Name = "PriceLbl"
						priceLbl.BackgroundTransparency = 1
						priceLbl.Text = formatNumber(value)
						priceLbl.TextColor3 = Color3.fromRGB(80, 220, 100)
						priceLbl.TextSize = 10
						priceLbl.Font = Enum.Font.MontserratBold
						priceLbl.Size = UDim2.new(0, 0, 1, 0)
						priceLbl.AutomaticSize = Enum.AutomaticSize.X
						priceLbl.Parent = priceTag
					else
						local priceLbl = priceTag:FindFirstChild("PriceLbl")
						if priceLbl then
							priceLbl.Text = formatNumber(value)
						end
					end
				else
					if priceTag then
						priceTag:Destroy()
					end
				end
			end
		end
		if espshowbeam and rootPart and hp then
			ensureEspBeam(espBeams, "FruitESP_" .. hp:GetFullName(), true, rootPart, hp, Color3.fromRGB(80, 220, 120), currentBeams)
		end
	end
	for _, plot in gardens:GetChildren() do
		local owner = plot:GetAttribute("Owner")
		local ownerid = plot:GetAttribute("OwnerUserId")
		local isMyPlot = (owner == localPlayer.Name or owner == localPlayer.DisplayName) or (ownerid == localPlayer.UserId)
		if not isMyPlot and not espshowothers then
			continue
		end
		local plants = plot:FindFirstChild("Plants")
		if plants then
			for _, plant in plants:GetChildren() do
				local fruits = plant:FindFirstChild("Fruits")
				if fruits then
					for _, fruit in fruits:GetChildren() do
						processInstance(fruit, plant)
					end
				else
					processInstance(plant, plant)
				end
			end
		end
	end
	for bill, _ in pairs(espBills) do
		if not currentBills[bill] then
			pcall(function() bill:Destroy() end)
			espBills[bill] = nil
		end
	end
	syncEspBeamTable(espBeams, currentBeams)
end
function toggleESP(val)
	esprunning = val
	if val then
		espThread = task.spawn(function()
			while esprunning do
				updateESP()
				task.wait(2)
			end
		end)
	else
		if espThread then
			task.cancel(espThread)
			espThread = nil
		end
		updateESP()
	end
end
plantEsprunning = false
plantEspminweight = 0
plantEspmaxweight = 0
plantEspmaxdist = 300
plantEspshowothers = false
plantEspshowbeam = false
plantEspftype = "Blacklist"
plantEspflist = ""
plantEspmuttype = "Whitelist"
plantEspmutlist = ""
plantEspBills = {}
plantEspBeams = {}
plantEspThread = nil
local function plantEspallowed(seedName)
	local set = {}
	for name in (plantEspflist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if plantEspflist == "" or plantEspflist == "None" then
		if plantEspftype == "Whitelist" then
			return false
		else
			return true
		end
	end
	if plantEspftype == "Whitelist" then
		return set[seedName] == true
	end
	return set[seedName] == nil
end
local function plantEspmutallowed(mutation)
	if not mutation or mutation == "" then
		mutation = "None"
	end
	local set = {}
	for name in (plantEspmutlist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if plantEspmutlist == "" or plantEspmutlist == "None" then
		return true
	end
	if plantEspmuttype == "Whitelist" then
		return set[mutation] == true
	end
	return set[mutation] == nil
end
local function getPlantBboxTopWorld(plant)
	if not plant then
		return nil
	end
	local excludedFolders = { Fruits = true, FruitSpawnLocations = true }
	local minY, maxY = math.huge, -math.huge
	for _, part in plant:QueryDescendants("BasePart") do
		local parent = part.Parent
		local skip = false
		while parent and parent ~= plant do
			if excludedFolders[parent.Name] then
				skip = true
				break
			end
			parent = parent.Parent
		end
		if not skip then
			local cf = part.CFrame
			local topY = (cf * CFrame.new(0, part.Size.Y / 2, 0)).Position.Y
			local bottomY = (cf * CFrame.new(0, -part.Size.Y / 2, 0)).Position.Y
			if topY > maxY then
				maxY = topY
			end
			if bottomY < minY then
				minY = bottomY
			end
		end
	end
	if maxY == -math.huge then
		return nil
	end
	local anchor = plant.PrimaryPart or plant:FindFirstChild("Base") or plant:FindFirstChildWhichIsA("BasePart")
	local pivot = anchor and anchor.Position or plant:GetPivot().Position
	return Vector3.new(pivot.X, maxY + 2, pivot.Z)
end

local function getPlantEspAdornee(plant)
	if not plant then
		return nil
	end
	if isSingleHarvestGardenObject(plant, plant) then
		return plant.PrimaryPart or plant:FindFirstChild("Base") or plant:FindFirstChildWhichIsA("BasePart")
	end
	return plant:FindFirstChild("HarvestPart") or plant.PrimaryPart or plant:FindFirstChild("Base") or plant:FindFirstChildWhichIsA("BasePart")
end

local function applyPlantEspBillboardPlacement(bb, plant, anchor)
	if not bb or not anchor then
		return
	end
	if bb.Parent ~= anchor then
		bb.Parent = anchor
	end
	bb.Adornee = anchor
	if isSingleHarvestGardenObject(plant, plant) then
		local topWorld = getPlantBboxTopWorld(plant)
		if topWorld then
			bb.StudsOffset = Vector3.zero
			bb.ExtentsOffsetWorldSpace = topWorld - anchor.Position
			return
		end
	end
	bb.ExtentsOffsetWorldSpace = Vector3.zero
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
end

local function findPlantEspBillboard(plant, anchor)
	local bb = anchor and anchor:FindFirstChild("PlantESP")
	if bb then
		return bb
	end
	for _, desc in plant:GetDescendants() do
		if desc:IsA("BillboardGui") and desc.Name == "PlantESP" then
			return desc
		end
	end
	return nil
end

local function updatePlantESP()
	if not plantEsprunning then
		for _, bill in pairs(plantEspBills) do
			pcall(function() bill:Destroy() end)
		end
		table.clear(plantEspBills)
		clearEspBeamTable(plantEspBeams)
		return
	end
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then return end
	local currentBills = {}
	local currentBeams = {}
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local function processPlant(obj)
		local seedName = getseedname(obj)
		if not seedName or seedName == "" then return end
		local cropName = getcropname(seedName) or seedName
		local mutation = obj:GetAttribute("Mutation") or "None"
		if not plantEspallowed(cropName) or not plantEspmutallowed(mutation) then return end
		local hp = getPlantEspAdornee(obj)
		if not hp then return end
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local dist = (hp.Position - rootPart.Position).Magnitude
			if dist > plantEspmaxdist then return end
		end
		local sizeMulti = obj:GetAttribute("SizeMulti") or obj:GetAttribute("SizeMultiplier")
		if not sizeMulti then
			local lastGen = obj:GetAttribute("PlantedAt") or obj:GetAttribute("LastGenerated")
			local psm = getPlantSizeMultipliers()
			if lastGen and psm and typeof(psm) == "table" and typeof(psm.GetRandomPlantSize) == "function" then
				local stage = obj:GetAttribute("Age") or obj:GetAttribute("MaxAge") or 1
				local ok, res = pcall(function() return psm.GetRandomPlantSize(stage, lastGen, seedName) end)
				if ok and res then
					sizeMulti = res
				end
			end
		end
		if not sizeMulti then sizeMulti = 1 end
		local baseWeight = getbaseweight(seedName) or 1
		local calcWeightKg = getweightkg(obj, seedName)
		local wf = getWeightFormat()
		local weightStr = ""
		if wf and typeof(wf) == "table" and typeof(wf.FormatGrams) == "function" then
			local ok, formatted = pcall(wf.FormatGrams, calcWeightKg)
			if ok and formatted then
				weightStr = formatted
			else
				weightStr = string.format("%.2fkg", calcWeightKg)
			end
		else
			weightStr = string.format("%.2fkg", calcWeightKg)
		end
		local matchesMin = (plantEspminweight == 0 or calcWeightKg >= plantEspminweight)
		local matchesMax = (plantEspmaxweight == 0 or calcWeightKg <= plantEspmaxweight)
		if not (matchesMin and matchesMax) then
			return
		end
		local bb = findPlantEspBillboard(obj, hp)
		if not bb then
			bb = Instance.new("BillboardGui")
			bb.Name = "PlantESP"
			bb.Size = UDim2.new(0, 320, 0, 30)
			bb.AlwaysOnTop = true
			bb.Parent = hp
			local container = Instance.new("Frame")
			container.Name = "Container"
			container.Size = UDim2.new(0, 0, 1, 0)
			container.AutomaticSize = Enum.AutomaticSize.X
			container.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
			container.BorderSizePixel = 0
			container.AnchorPoint = Vector2.new(0.5, 0.5)
			container.Position = UDim2.new(0.5, 0, 0.5, 0)
			container.Parent = bb
			rnd(container, 15)
			stk(container, Color3.fromRGB(30, 35, 30), 1)
			pad(container, 6, 6, 12, 12)
			local lay = Instance.new("UIListLayout")
			lay.FillDirection = Enum.FillDirection.Horizontal
			lay.VerticalAlignment = Enum.VerticalAlignment.Center
			lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
			lay.Padding = UDim.new(0, 8)
			lay.Parent = container
		end
		applyPlantEspBillboardPlacement(bb, obj, hp)
		currentBills[bb] = true
		plantEspBills[bb] = bb
		local container = bb:FindFirstChild("Container")
		if container then
			local nameLbl = container:FindFirstChild("NameLbl")
			local heightFt = getPlantHeightFt(obj)
			local heightText = formatPlantHeightText(heightFt)
			if nameLbl then
				if heightText then
					local heightLbl = container:FindFirstChild("HeightLbl")
					if heightLbl then
						heightLbl.Text = heightText
					else
						heightLbl = Instance.new("TextLabel")
						heightLbl.Name = "HeightLbl"
						heightLbl.BackgroundTransparency = 1
						heightLbl.Text = heightText
						heightLbl.TextColor3 = Color3.fromRGB(100, 200, 255)
						heightLbl.TextSize = 10
						heightLbl.Font = Enum.Font.MontserratBold
						heightLbl.Size = UDim2.new(0, 0, 1, 0)
						heightLbl.AutomaticSize = Enum.AutomaticSize.X
						heightLbl.Parent = container
					end
				end
			else
				container:ClearAllChildren()
				rnd(container, 15)
				stk(container, Color3.fromRGB(30, 35, 30), 1)
				pad(container, 6, 6, 12, 12)
				local lay = Instance.new("UIListLayout")
				lay.FillDirection = Enum.FillDirection.Horizontal
				lay.VerticalAlignment = Enum.VerticalAlignment.Center
				lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
				lay.Padding = UDim.new(0, 8)
				lay.Parent = container
				local iconUrl = fruitIcons and fruitIcons[seedName]
				if iconUrl and getFruitAsset then
					local img = Instance.new("ImageLabel")
					img.Size = UDim2.new(0, 18, 0, 18)
					img.BackgroundTransparency = 1
					img.ScaleType = Enum.ScaleType.Fit
					img.Parent = container
					getFruitAsset(seedName, iconUrl, img)
				end
				local function createLabel(text, color)
					local lbl = Instance.new("TextLabel")
					lbl.BackgroundTransparency = 1
					lbl.Text = text
					lbl.TextColor3 = color
					lbl.TextSize = 10
					lbl.Font = Enum.Font.MontserratBold
					lbl.Size = UDim2.new(0, 0, 1, 0)
					lbl.AutomaticSize = Enum.AutomaticSize.X
					lbl.Parent = container
					return lbl
				end
				local nameLbl = createLabel(seedName:gsub("%s*%b[]%s*$", ""), Color3.fromRGB(255, 255, 255))
				nameLbl.Name = "NameLbl"
				if mutation ~= "None" then
					local mutCol = Color3.fromRGB(255, 195, 55)
					local useGrad = false
					local gradColors = nil
					local animateGrad = false
					local animSpeed = 0.3
					if mutation == "Rainbow" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
							ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
							ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
							ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
							ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))
						}
						animateGrad = true
						animSpeed = 0.4
					elseif mutation == "Gold" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 245, 150)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))
						}
						animateGrad = true
						animSpeed = 0.3
					elseif mutation == "Blood" or mutation == "Bloodlit" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 0, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
						}
					elseif mutation == "Frozen" then
						mutCol = Color3.fromRGB(0, 240, 255)
					elseif mutation == "Dark" then
						mutCol = Color3.fromRGB(100, 100, 120)
					elseif mutation == "Light" then
						mutCol = Color3.fromRGB(240, 240, 255)
					elseif mutation == "Glitch" then
						mutCol = Color3.fromRGB(0, 255, 150)
					elseif mutation == "Giant" then
						mutCol = Color3.fromRGB(255, 100, 100)
					elseif mutation == "Electric" then
						mutCol = Color3.fromRGB(0, 0, 0)
					elseif mutation == "Starstruck" then
						mutCol = Color3.fromRGB(255, 255, 0)
					elseif mutation == "Aurora" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 170)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 150, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 80, 255))
						}
					elseif mutation == "Ignited" then
						mutCol = Color3.fromRGB(255, 255, 255)
						useGrad = true
						gradColors = {
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 0))
						}
					end
					local mutLbl = createLabel("[" .. mutation .. "]", mutCol)
					if mutation == "Electric" then
						local stroke = Instance.new("UIStroke")
						stroke.Color = Color3.fromRGB(255, 255, 255)
						stroke.Thickness = 1
						stroke.Parent = mutLbl
					end
					if useGrad and gradColors then
						local grad = Instance.new("UIGradient")
						grad.Color = ColorSequence.new(gradColors)
						grad.Parent = mutLbl
						if animateGrad then
							task.spawn(function()
								while mutLbl and mutLbl.Parent do
									local t = (os.clock() * animSpeed) % 1
									grad.Offset = Vector2.new(-t * 2 + 1, 0)
									task.wait()
								end
							end)
						end
					end
				end
				local heightText = formatPlantHeightText(getPlantHeightFt(obj))
				if heightText then
					local heightLbl = createLabel(heightText, Color3.fromRGB(100, 200, 255))
					heightLbl.Name = "HeightLbl"
				end
			end
		end
		if plantEspshowbeam and rootPart and hp then
			ensureEspBeam(plantEspBeams, "PlantESP_" .. hp:GetFullName(), true, rootPart, hp, Color3.fromRGB(100, 200, 255), currentBeams)
		end
	end
	for _, plot in gardens:GetChildren() do
		local owner = plot:GetAttribute("Owner")
		local ownerid = plot:GetAttribute("OwnerUserId")
		local isMyPlot = (owner == localPlayer.Name or owner == localPlayer.DisplayName) or (ownerid == localPlayer.UserId)
		if not isMyPlot and not plantEspshowothers then
			continue
		end
		local plants = plot:FindFirstChild("Plants")
		if plants then
			for _, plant in plants:GetChildren() do
				processPlant(plant)
			end
		end
	end
	for bill, _ in pairs(plantEspBills) do
		if not currentBills[bill] then
			pcall(function() bill:Destroy() end)
			plantEspBills[bill] = nil
		end
	end
	syncEspBeamTable(plantEspBeams, currentBeams)
end
function togglePlantESP(val)
	plantEsprunning = val
	if val then
		plantEspThread = task.spawn(function()
			while plantEsprunning do
				updatePlantESP()
				task.wait(2)
			end
		end)
	else
		if plantEspThread then
			task.cancel(plantEspThread)
			plantEspThread = nil
		end
		updatePlantESP()
	end
end

gardenEsprunning = false
gardenEspshowpath = false
gardenEspmaxdist = 1000
gardenEspBills = {}
gardenEspBeams = {}
gardenEspThread = nil

local function updateGardenESP()
	if not gardenEsprunning then
		for _, bill in pairs(gardenEspBills) do
			pcall(function() bill:Destroy() end)
		end
		table.clear(gardenEspBills)
		clearEspBeamTable(gardenEspBeams)
		return
	end
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then return end
	local currentBills = {}
	local currentBeams = {}
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	for _, plot in gardens:GetChildren() do
		local owner = plot:GetAttribute("Owner") or "Empty"
		local ownerId = plot:GetAttribute("OwnerUserId")
		local plotId = plot.Name:match("%d+") or plot.Name
		
		-- Center part to attach ESP/Beam to
		local targetPart = plot:FindFirstChild("SpawnPoint") or plot:FindFirstChild("PlotSizeReference") or plot:FindFirstChildWhichIsA("BasePart", true)
		if targetPart and rootPart then
			local dist = (targetPart.Position - rootPart.Position).Magnitude
			if dist <= gardenEspmaxdist then
				-- 1. Billboard ESP
				local bb = targetPart:FindFirstChild("GardenESP")
				if not bb then
					bb = Instance.new("BillboardGui")
					bb.Name = "GardenESP"
					bb.Size = UDim2.new(0, 280, 0, 30)
					bb.StudsOffset = Vector3.new(0, 5, 0)
					bb.AlwaysOnTop = true
					bb.Adornee = targetPart
					bb.Parent = targetPart
					
					local container = Instance.new("Frame")
					container.Name = "Container"
					container.Size = UDim2.new(0, 0, 1, 0)
					container.AutomaticSize = Enum.AutomaticSize.X
					container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
					container.BorderSizePixel = 0
					container.AnchorPoint = Vector2.new(0.5, 0.5)
					container.Position = UDim2.new(0.5, 0, 0.5, 0)
					container.Parent = bb
					rnd(container, 15)
					stk(container, Color3.fromRGB(35, 35, 45), 1)
					pad(container, 6, 6, 12, 12)
					
					local lay = Instance.new("UIListLayout")
					lay.FillDirection = Enum.FillDirection.Horizontal
					lay.VerticalAlignment = Enum.VerticalAlignment.Center
					lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
					lay.Padding = UDim.new(0, 8)
					lay.Parent = container

					local titleLbl = Instance.new("TextLabel")
					titleLbl.Name = "TitleLbl"
					titleLbl.BackgroundTransparency = 1
					titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
					titleLbl.TextSize = 10
					titleLbl.Font = Enum.Font.MontserratBold
					titleLbl.Size = UDim2.new(0, 0, 1, 0)
					titleLbl.AutomaticSize = Enum.AutomaticSize.X
					titleLbl.Parent = container

					local distLbl = Instance.new("TextLabel")
					distLbl.Name = "DistLbl"
					distLbl.BackgroundTransparency = 1
					distLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
					distLbl.TextSize = 9
					distLbl.Font = Enum.Font.MontserratMedium
					distLbl.Size = UDim2.new(0, 0, 1, 0)
					distLbl.AutomaticSize = Enum.AutomaticSize.X
					distLbl.Parent = container
				end
				currentBills[bb] = true
				gardenEspBills[bb] = bb
				
				local container = bb:FindFirstChild("Container")
				if container then
					local titleLbl = container:FindFirstChild("TitleLbl")
					local distLbl = container:FindFirstChild("DistLbl")
					if titleLbl then
						titleLbl.Text = string.format("Plot %s [%s]", tostring(plotId), tostring(owner))
					end
					if distLbl then
						distLbl.Text = string.format("[%d studs]", math.floor(dist))
					end
				end

				-- 2. Draw Path (Beam)
				if gardenEspshowpath and rootPart then
					local beamKey = "GardenESP_" .. plot.Name
					ensureEspBeam(gardenEspBeams, beamKey, true, rootPart, targetPart, Color3.fromRGB(120, 100, 255), currentBeams)
				end
			end
		end
	end

	for bb, _ in pairs(gardenEspBills) do
		if not currentBills[bb] then
			pcall(function() bb:Destroy() end)
			gardenEspBills[bb] = nil
		end
	end
	syncEspBeamTable(gardenEspBeams, currentBeams)
end

local function toggleGardenESP(val)
	gardenEsprunning = val
	if val then
		gardenEspThread = task.spawn(function()
			while gardenEsprunning do
				pcall(updateGardenESP)
				task.wait(1.5)
			end
		end)
	else
		if gardenEspThread then
			task.cancel(gardenEspThread)
			gardenEspThread = nil
		end
		updateGardenESP()
	end
end

playerEsprunning = false
playerEspshowhealth = true
playerEspshowfriends = false
playerEsphighlight = true
playerEspshowbeam = false
playerEspmaxdist = 1500
playerEspBills = {}
playerEspBeams = {}
playerEspHighlights = {}
playerEspThread = nil

local function updatePlayerESP()
	if not playerEsprunning then
		for _, bill in pairs(playerEspBills) do
			pcall(function() bill:Destroy() end)
		end
		table.clear(playerEspBills)
		clearEspBeamTable(playerEspBeams)
		for _, hl in pairs(playerEspHighlights) do
			pcall(function() hl:Destroy() end)
		end
		table.clear(playerEspHighlights)
		return
	end
	local currentBills = {}
	local currentBeams = {}
	local currentHighlights = {}
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	
	for _, player in game.Players:GetPlayers() do
		if player ~= localPlayer and player.Character and player.Character:FindFirstChild("Head") then
			local charModel = player.Character
			local head = charModel.Head
			local pRoot = charModel:FindFirstChild("HumanoidRootPart")
			local hum = charModel:FindFirstChildOfClass("Humanoid")
			if pRoot and hum then
				local dist = rootPart and (pRoot.Position - rootPart.Position).Magnitude or 0
				if dist <= playerEspmaxdist then
					local isFriend = false
					pcall(function() isFriend = localPlayer:IsFriendsWith(player.UserId) end)
					if playerEspshowfriends and not isFriend then
						continue
					end
					
					-- 1. Billboard ESP (Small & Sleek like ESP Fruits)
					local bb = head:FindFirstChild("PlayerESP")
					if not bb then
						bb = Instance.new("BillboardGui")
						bb.Name = "PlayerESP"
						bb.Size = UDim2.new(0, 280, 0, 24)
						bb.StudsOffset = Vector3.new(0, 3.5, 0)
						bb.AlwaysOnTop = true
						bb.Adornee = head
						bb.Parent = head
						
						local container = Instance.new("Frame")
						container.Name = "Container"
						container.Size = UDim2.new(0, 0, 1, 0)
						container.AutomaticSize = Enum.AutomaticSize.X
						container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
						container.BorderSizePixel = 0
						container.AnchorPoint = Vector2.new(0.5, 0.5)
						container.Position = UDim2.new(0.5, 0, 0.5, 0)
						container.Parent = bb
						rnd(container, 8)
						stk(container, Color3.fromRGB(35, 35, 45), 1)
						pad(container, 4, 4, 8, 8)
						
						local lay = Instance.new("UIListLayout")
						lay.FillDirection = Enum.FillDirection.Horizontal
						lay.VerticalAlignment = Enum.VerticalAlignment.Center
						lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
						lay.Padding = UDim.new(0, 6)
						lay.SortOrder = Enum.SortOrder.LayoutOrder
						lay.Parent = container
						
						-- Avatar headshot thumbnail icon
						local icon = Instance.new("ImageLabel")
						icon.Name = "Icon"
						icon.Size = UDim2.new(0, 16, 0, 16)
						icon.BackgroundTransparency = 1
						icon.ScaleType = Enum.ScaleType.Fit
						icon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
						icon.LayoutOrder = 1
						icon.Parent = container
						rnd(icon, 8)
						
						local nameLbl = Instance.new("TextLabel")
						nameLbl.Name = "NameLbl"
						nameLbl.BackgroundTransparency = 1
						nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
						nameLbl.TextSize = 10
						nameLbl.Font = Enum.Font.MontserratBold
						nameLbl.Size = UDim2.new(0, 0, 1, 0)
						nameLbl.AutomaticSize = Enum.AutomaticSize.X
						nameLbl.LayoutOrder = 2
						nameLbl.Parent = container

						local healthLbl = Instance.new("TextLabel")
						healthLbl.Name = "HealthLbl"
						healthLbl.BackgroundTransparency = 1
						healthLbl.TextColor3 = Color3.fromRGB(80, 220, 100)
						healthLbl.TextSize = 9
						healthLbl.Font = Enum.Font.MontserratBold
						healthLbl.Size = UDim2.new(0, 0, 1, 0)
						healthLbl.AutomaticSize = Enum.AutomaticSize.X
						healthLbl.LayoutOrder = 3
						healthLbl.Parent = container

						local distLbl = Instance.new("TextLabel")
						distLbl.Name = "DistLbl"
						distLbl.BackgroundTransparency = 1
						distLbl.TextColor3 = Color3.fromRGB(150, 150, 160)
						distLbl.TextSize = 9
						distLbl.Font = Enum.Font.MontserratMedium
						distLbl.Size = UDim2.new(0, 0, 1, 0)
						distLbl.AutomaticSize = Enum.AutomaticSize.X
						distLbl.LayoutOrder = 4
						distLbl.Parent = container
					end
					currentBills[bb] = true
					playerEspBills[bb] = bb
					
					local container = bb:FindFirstChild("Container")
					if container then
						local nameLbl = container:FindFirstChild("NameLbl")
						local healthLbl = container:FindFirstChild("HealthLbl")
						local distLbl = container:FindFirstChild("DistLbl")
						
						if nameLbl then
							local friendPrefix = isFriend and "[FRIEND] " or ""
							nameLbl.Text = friendPrefix .. player.DisplayName
							nameLbl.TextColor3 = isFriend and Color3.fromRGB(150, 120, 255) or Color3.fromRGB(235, 235, 240)
						end
						if healthLbl then
							if playerEspshowhealth then
								healthLbl.Visible = true
								healthLbl.Text = string.format("[%d HP]", math.floor(hum.Health))
								healthLbl.TextColor3 = hum.Health > 50 and Color3.fromRGB(80, 220, 100) or Color3.fromRGB(240, 100, 100)
							else
								healthLbl.Visible = false
							end
						end
						if distLbl then
							distLbl.Text = string.format("[%d studs]", math.floor(dist))
						end
					end

					-- 2. Highlight (Zenith Styled Purple Glow Chams)
					if playerEsphighlight then
						local hl = charModel:FindFirstChild("PlayerHighlight")
						if not hl then
							hl = Instance.new("Highlight")
							hl.Name = "PlayerHighlight"
							hl.FillColor = isFriend and Color3.fromRGB(120, 100, 255) or Color3.fromRGB(180, 70, 255)
							hl.FillTransparency = 0.8
							hl.OutlineColor = Color3.fromRGB(200, 180, 255)
							hl.OutlineTransparency = 0.2
							hl.Adornee = charModel
							hl.Parent = charModel
						end
						if isFriend then
							hl.FillColor = Color3.fromRGB(120, 100, 255)
							hl.OutlineColor = Color3.fromRGB(230, 220, 255)
						else
							hl.FillColor = Color3.fromRGB(180, 70, 255)
							hl.OutlineColor = Color3.fromRGB(200, 180, 255)
						end
						currentHighlights[hl] = true
						playerEspHighlights[hl] = hl
					end

					if playerEspshowbeam and rootPart and pRoot then
						local beamColor = isFriend and Color3.fromRGB(150, 120, 255) or Color3.fromRGB(200, 100, 255)
						ensureEspBeam(playerEspBeams, "PlayerESP_" .. player.UserId, true, rootPart, pRoot, beamColor, currentBeams)
					end
				end
			end
		end
	end
	
	for bb, _ in pairs(playerEspBills) do
		if not currentBills[bb] then
			pcall(function() bb:Destroy() end)
			playerEspBills[bb] = nil
		end
	end
	for hl, _ in pairs(playerEspHighlights) do
		if not currentHighlights[hl] then
			pcall(function() hl:Destroy() end)
			playerEspHighlights[hl] = nil
		end
	end
	syncEspBeamTable(playerEspBeams, currentBeams)
end

local function togglePlayerESP(val)
	playerEsprunning = val
	if val then
		playerEspThread = task.spawn(function()
			while playerEsprunning do
				pcall(updatePlayerESP)
				task.wait(1.0)
			end
		end)
	else
		if playerEspThread then
			task.cancel(playerEspThread)
			playerEspThread = nil
		end
		updatePlayerESP()
	end
end

hub:CreateModule("Visuals", {
	name = "ESP Gardens",
	on = false,
	bind = "None",
	desc = "Plot ESP.",
	callback = function(enabled)
		toggleGardenESP(enabled)
	end,
	opts = {
		{type = "checkbox", label = "Show Path (Beams)", value = false, callback = function(value)
			gardenEspshowpath = value
			if not value then
				clearEspBeamTable(gardenEspBeams)
			end
			pcall(updateGardenESP)
		end},
		{type = "slider", label = "Max Distance", value = 1000, min = 100, max = 5000, suffix = " studs", callback = function(value)
			gardenEspmaxdist = value
		end}
	}
})

hub:CreateModule("Visuals", {
	name = "ESP Players",
	on = false,
	bind = "None",
	desc = "Player ESP.",
	callback = function(enabled)
		togglePlayerESP(enabled)
	end,
	opts = {
		{type = "checkbox", label = "Show Beam", value = false, callback = function(value)
			playerEspshowbeam = value
			if not value then
				clearEspBeamTable(playerEspBeams)
			end
			pcall(updatePlayerESP)
		end},
		{type = "checkbox", label = "Show Outline Highlight (Chams)", value = true, callback = function(value)
			playerEsphighlight = value
			pcall(updatePlayerESP)
		end},
		{type = "checkbox", label = "Show Health", value = true, callback = function(value)
			playerEspshowhealth = value
		end},
		{type = "checkbox", label = "Show Friends Only", value = false, callback = function(value)
			playerEspshowfriends = value
		end},
		{type = "slider", label = "Max Distance", value = 1500, min = 100, max = 5000, suffix = " studs", callback = function(value)
			playerEspmaxdist = value
		end}
	}
})

hub:CreateModule("Visuals", {
	name = "ESP Fruits",
	beta = true,
	on = false,
	bind = "None",
	desc = "Fruit ESP.",
	callback = function(enabled)
		toggleESP(enabled)
	end,
	opts = {
		{type = "checkbox", label = "Show Beam", value = false, callback = function(value)
			espshowbeam = value
			if not value then
				clearEspBeamTable(espBeams)
			end
			pcall(updateESP)
		end},
		{type = "checkbox", label = "Show Others", value = false, callback = function(value)
			espshowothers = value
		end},
		{type = "slider", label = "Max Distance", value = 300, min = 50, max = 2000, suffix = " studs", callback = function(value)
			espmaxdist = value
		end},
		{type = "dropdown", label = "Filter Type", value = "Blacklist", list = {"Whitelist","Blacklist"}, callback = function(value)
			espftype = value
		end},
		{type = "multiselect", label = "Filter Fruits", value = "None", list = gameLists.crops, callback = function(value)
			espflist = value
		end},
		{type = "dropdown", label = "Filter Mutation Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			espmuttype = value
		end},
		{type = "multiselect", label = "Filter Mutations", value = "None", list = gameLists.mutations, callback = function(value)
			espmutlist = value
		end},
		{type = "textbox", label = "Min Weight Filter (kg)", value = "0", placeholder = "Enter min weight in kg...", callback = function(value)
			local num = tonumber(value)
			espminweight = num or 0
		end},
		{type = "textbox", label = "Max Weight Filter (kg)", value = "0", placeholder = "Enter max weight in kg...", callback = function(value)
			local num = tonumber(value)
			espmaxweight = num or 0
		end},
	}
})
hub:CreateModule("Visuals", {
	name = "ESP Plants",
	on = false,
	bind = "None",
	desc = "Plant ESP.",
	callback = function(enabled)
		togglePlantESP(enabled)
	end,
	opts = {
		{type = "checkbox", label = "Show Beam", value = false, callback = function(value)
			plantEspshowbeam = value
			if not value then
				clearEspBeamTable(plantEspBeams)
			end
			pcall(updatePlantESP)
		end},
		{type = "checkbox", label = "Show Others", value = false, callback = function(value)
			plantEspshowothers = value
		end},
		{type = "slider", label = "Max Distance", value = 300, min = 50, max = 2000, suffix = " studs", callback = function(value)
			plantEspmaxdist = value
		end},
		{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			plantEspftype = value
		end},
		{type = "multiselect", label = "Filter Fruits", value = "None", list = gameLists.crops, callback = function(value)
			plantEspflist = value
		end},
		{type = "dropdown", label = "Filter Mutation Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			plantEspmuttype = value
		end},
		{type = "multiselect", label = "Filter Mutations", value = "None", list = gameLists.mutations, callback = function(value)
			plantEspmutlist = value
		end},
		{type = "textbox", label = "Min Weight Filter (kg)", value = "0", placeholder = "Enter min weight in kg...", callback = function(value)
			local num = tonumber(value)
			plantEspminweight = num or 0
		end},
		{type = "textbox", label = "Max Weight Filter (kg)", value = "0", placeholder = "Enter max weight in kg...", callback = function(value)
			local num = tonumber(value)
			plantEspmaxweight = num or 0
		end},
	}
})
petEsprunning = false
petEspmaxdist = 300
petEspshowbeam = false
petEspBills = {}
petEspBeams = {}
petEspThread = nil
petEspflist = ""
petEspftype = "Blacklist"
petEspmutlist = ""
petEspmuttype = "Whitelist"
petEsprarities = ""
local function petEspallowed(petName)
	local set = {}
	for name in (petEspflist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	if petEspflist == "" then
		if petEspftype == "Whitelist" then
			return false
		else
			return true
		end
	end
	if petEspftype == "Whitelist" then
		return set[petName] == true
	end
	return set[petName] == nil
end
local function petEspmutallowed(mut, size, typ)
	if not mut or mut == "" then mut = "None" end
	if petEspmutlist == "" then
		return true
	end
	local set = {}
	for name in (petEspmutlist .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	local isMatch = false
	if set[mut] or (size and set[size]) or (typ and set[typ]) then
		isMatch = true
	end
	if set["None"] and (mut == "None" or mut == "Normal") and (not size or size == "Normal") and (not typ or typ == "Normal") then
		isMatch = true
	end
	if petEspmuttype == "Whitelist" then
		return isMatch
	end
	return not isMatch
end
local function petEsprarityallowed(rarity)
	if petEsprarities == "" then return true end
	local set = {}
	for name in (petEsprarities .. ","):gmatch("([^,]+),") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
	return set[rarity] == true
end

local PET_LEAVE_TIMER_ICON = "rbxassetid://101182513682775"

local function formatPetLeaveTime(seconds)
	if not seconds then
		return nil
	end
	local total = math.max(0, math.ceil(seconds))
	if total < 60 then
		return string.format("%ds", total)
	end
	local minutes = math.floor(total / 60)
	local secs = total % 60
	if secs == 0 then
		return string.format("%dm", minutes)
	end
	return string.format("%dm %ds", minutes, secs)
end

local function getWildPetLeaveTimeText(model)
	local refPart = model.PrimaryPart or model:FindFirstChild("RootPart") or model:FindFirstChildWhichIsA("BasePart")
	if not refPart then
		return nil
	end
	if refPart:GetAttribute("NoTimer") == true then
		return nil
	end
	local ownerId = refPart:GetAttribute("OwnerUserId")
	if type(ownerId) == "number" and ownerId ~= 0 then
		return nil
	end
	local spawnedAt = refPart:GetAttribute("SpawnedAt")
	local lifetime = refPart:GetAttribute("Lifetime")
	if type(spawnedAt) == "number" and type(lifetime) == "number" then
		return formatPetLeaveTime(spawnedAt + lifetime - workspace:GetServerTimeNow())
	end
	local timerGui = refPart:FindFirstChild("PetLeaveTimer")
	if timerGui then
		local lbl = timerGui:FindFirstChildWhichIsA("TextLabel", true)
		if lbl and lbl.Text ~= "" then
			return lbl.Text
		end
	end
	return nil
end

local function setPetEspTimerTag(container, timerText)
	local timerTag = container:FindFirstChild("TimerTag")
	if not timerText or timerText == "" then
		if timerTag then
			timerTag:Destroy()
		end
		return
	end
	if not timerTag then
		timerTag = Instance.new("Frame")
		timerTag.Name = "TimerTag"
		timerTag.Size = UDim2.new(0, 0, 1, 0)
		timerTag.AutomaticSize = Enum.AutomaticSize.X
		timerTag.BackgroundTransparency = 1
		timerTag.Parent = container
		local timerLay = Instance.new("UIListLayout")
		timerLay.FillDirection = Enum.FillDirection.Horizontal
		timerLay.VerticalAlignment = Enum.VerticalAlignment.Center
		timerLay.Padding = UDim.new(0, 4)
		timerLay.Parent = timerTag
		local timerImg = Instance.new("ImageLabel")
		timerImg.Name = "TimerImg"
		timerImg.Size = UDim2.new(0, 11, 0, 11)
		timerImg.BackgroundTransparency = 1
		timerImg.ScaleType = Enum.ScaleType.Fit
		timerImg.Image = PET_LEAVE_TIMER_ICON
		timerImg.Parent = timerTag
		local timerLbl = Instance.new("TextLabel")
		timerLbl.Name = "TimerLbl"
		timerLbl.BackgroundTransparency = 1
		timerLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
		timerLbl.TextSize = 10
		timerLbl.Font = Enum.Font.MontserratBold
		timerLbl.Size = UDim2.new(0, 0, 1, 0)
		timerLbl.AutomaticSize = Enum.AutomaticSize.X
		timerLbl.Parent = timerTag
	end
	local timerLbl = timerTag:FindFirstChild("TimerLbl")
	if timerLbl then
		timerLbl.Text = timerText
	end
end

local function updatePetEspPriceTag(container, model, map)
	local refPartName = model.Name:gsub("^WildPet_[^_]+_", "")
	local wildPetRef = map and map:FindFirstChild("WildPetRef")
	local refPart = wildPetRef and wildPetRef:FindFirstChild(refPartName)
	local price = refPart and (refPart:GetAttribute("Price") or 0) or 0
	local priceTag = container:FindFirstChild("PriceTag")
	if price > 0 then
		if not priceTag then
			priceTag = Instance.new("Frame")
			priceTag.Name = "PriceTag"
			priceTag.Size = UDim2.new(0, 0, 1, 0)
			priceTag.AutomaticSize = Enum.AutomaticSize.X
			priceTag.BackgroundTransparency = 1
			priceTag.Parent = container
			local priceLay = Instance.new("UIListLayout")
			priceLay.FillDirection = Enum.FillDirection.Horizontal
			priceLay.VerticalAlignment = Enum.VerticalAlignment.Center
			priceLay.Padding = UDim.new(0, 4)
			priceLay.Parent = priceTag
			local coinImg = Instance.new("ImageLabel")
			coinImg.Name = "CoinImg"
			coinImg.Size = UDim2.new(0, 11, 0, 11)
			coinImg.BackgroundTransparency = 1
			coinImg.ScaleType = Enum.ScaleType.Fit
			coinImg.Parent = priceTag
			getFruitAsset("SheckleCoin", nil, coinImg)
			local priceLbl = Instance.new("TextLabel")
			priceLbl.Name = "PriceLbl"
			priceLbl.BackgroundTransparency = 1
			priceLbl.TextColor3 = Color3.fromRGB(80, 220, 100)
			priceLbl.TextSize = 10
			priceLbl.Font = Enum.Font.MontserratBold
			priceLbl.Size = UDim2.new(0, 0, 1, 0)
			priceLbl.AutomaticSize = Enum.AutomaticSize.X
			priceLbl.Parent = priceTag
		end
		local priceLbl = priceTag:FindFirstChild("PriceLbl")
		if priceLbl then
			priceLbl.Text = string.format("%.0f", price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		end
	elseif priceTag then
		priceTag:Destroy()
	end
end

local function updatepetesp()
	if not petEsprunning then
		for _, bill in pairs(petEspBills) do
			pcall(function() bill:Destroy() end)
		end
		table.clear(petEspBills)
		clearEspBeamTable(petEspBeams)
		return
	end
	local map = workspace:FindFirstChild("Map")
	local spawnsFolder = map and map:FindFirstChild("WildPetSpawns")
	if not spawnsFolder then return end
	local currentBills = {}
	local currentBeams = {}
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	for _, model in spawnsFolder:GetChildren() do
		if model:IsA("Model") then
			local petName = model:GetAttribute("PetName") or model.Name
			local cleanName = petName:gsub("^WildPet_[^_]+_", "")
			local petSize = model:GetAttribute("PetSize") or model:GetAttribute("Size") or "Normal"
			local petType = model:GetAttribute("PetType") or model:GetAttribute("Type") or model:GetAttribute("Variant") or "Normal"
			local mutation = model:GetAttribute("Mutation")
			if not mutation or mutation == "" or mutation == "None" then
				if petType ~= "Normal" and petType ~= "" then
					mutation = petType
				elseif petSize ~= "Normal" and petSize ~= "" then
					mutation = petSize
				else
					mutation = "None"
				end
			end
			local rarity = "Common"
			local info = getPetInfo(cleanName)
			if info then
				rarity = info.Rarity or "Common"
			end
			if petEspallowed(cleanName) and petEspmutallowed(mutation, petSize, petType) and petEsprarityallowed(rarity) then
				local hp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				if hp then
					local distOk = true
					if rootPart then
						local dist = (hp.Position - rootPart.Position).Magnitude
						if dist > petEspmaxdist then distOk = false end
					end
					if distOk then
						local bb = hp:FindFirstChild("PetESP")
						if not bb then
							bb = Instance.new("BillboardGui")
							bb.Name = "PetESP"
							bb.Size = UDim2.new(0, 320, 0, 30)
							bb.StudsOffset = Vector3.new(0, 3.5, 0)
							bb.AlwaysOnTop = true
							bb.Adornee = hp
							bb.Parent = hp
						end
						currentBills[bb] = true
						petEspBills[bb] = bb
						local container = bb:FindFirstChild("Container")
						if not container then
							container = Instance.new("Frame")
							container.Name = "Container"
							container.Size = UDim2.new(0, 0, 1, 0)
							container.AutomaticSize = Enum.AutomaticSize.X
							container.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
							container.BorderSizePixel = 0
							container.AnchorPoint = Vector2.new(0.5, 0.5)
							container.Position = UDim2.new(0.5, 0, 0.5, 0)
							container.Parent = bb
						end
						local nameLbl = container:FindFirstChild("NameLbl")
						if not nameLbl then
							container:ClearAllChildren()
							rnd(container, 15)
							stk(container, Color3.fromRGB(35, 30, 35), 1)
							pad(container, 6, 6, 12, 12)
							local lay = Instance.new("UIListLayout")
							lay.FillDirection = Enum.FillDirection.Horizontal
							lay.VerticalAlignment = Enum.VerticalAlignment.Center
							lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
							lay.Padding = UDim.new(0, 8)
							lay.Parent = container
							local info = getPetInfo(cleanName)
							if info and info.IconUrl ~= "" then
								local img = Instance.new("ImageLabel")
								img.Size = UDim2.new(0, 18, 0, 18)
								img.BackgroundTransparency = 1
								img.ScaleType = Enum.ScaleType.Fit
								img.Parent = container
								getOnlineAsset(cleanName, info.IconUrl, img)
							end
							local function createLabel(text, color)
								local lbl = Instance.new("TextLabel")
								lbl.BackgroundTransparency = 1
								lbl.Text = text
								lbl.TextColor3 = color
								lbl.TextSize = 10
								lbl.Font = Enum.Font.MontserratBold
								lbl.Size = UDim2.new(0, 0, 1, 0)
								lbl.AutomaticSize = Enum.AutomaticSize.X
								lbl.Parent = container
								return lbl
							end
							local nameLbl = createLabel(cleanName, Color3.fromRGB(255, 255, 255))
							nameLbl.Name = "NameLbl"
							local petColor = petColors[rarity] or Color3.fromRGB(255, 255, 255)
							local mutCol = petColor
							local useGrad = false
							local gradColors = nil
							local animateGrad = false
							local animSpeed = 0.3
							if rarity == "Super" then
								mutCol = Color3.fromRGB(255, 255, 255)
								useGrad = true
								gradColors = {
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
									ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
									ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
									ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
									ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))
								}
								animateGrad = true
								animSpeed = 0.4
							end
							local rarityLbl = createLabel("[" .. rarity .. "]", mutCol)
							if useGrad and gradColors then
								local grad = Instance.new("UIGradient")
								grad.Color = ColorSequence.new(gradColors)
								grad.Parent = rarityLbl
								if animateGrad then
									task.spawn(function()
										while rarityLbl and rarityLbl.Parent do
											local t = (os.clock() * animSpeed) % 1
											grad.Offset = Vector2.new(-t * 2 + 1, 0)
											task.wait()
										end
									end)
								end
							end
							if mutation ~= "None" then
								createLabel("[" .. mutation .. "]", Color3.fromRGB(255, 100, 100))
							end
							updatePetEspPriceTag(container, model, map)
							setPetEspTimerTag(container, getWildPetLeaveTimeText(model))
						else
							updatePetEspPriceTag(container, model, map)
							setPetEspTimerTag(container, getWildPetLeaveTimeText(model))
						end
						if petEspshowbeam and rootPart and hp then
							local beamColor = petColors[rarity] or Color3.fromRGB(200, 120, 255)
							ensureEspBeam(petEspBeams, "PetESP_" .. hp:GetFullName(), true, rootPart, hp, beamColor, currentBeams)
						end
					end
				end
			end
		end
	end
	syncEspBeamTable(petEspBeams, currentBeams)
	for bill, _ in pairs(petEspBills) do
		if not currentBills[bill] then
			pcall(function() bill:Destroy() end)
			petEspBills[bill] = nil
		end
	end
end
local function togglePetESP(val)
	petEsprunning = val
	if val then
		petEspThread = task.spawn(function()
			while petEsprunning do
				updatepetesp()
				task.wait(1)
			end
		end)
	else
		if petEspThread then
			task.cancel(petEspThread)
			petEspThread = nil
		end
		updatepetesp()
	end
end
hub:CreateModule("Visuals", {
	name = "ESP Pets",
	on = false,
	bind = "None",
	desc = "Wild pet ESP.",
	callback = function(enabled)
		togglePetESP(enabled)
	end,
	opts = {
		{type = "checkbox", label = "Show Beam", value = false, callback = function(value)
			petEspshowbeam = value
			if not value then
				clearEspBeamTable(petEspBeams)
			end
			pcall(updatepetesp)
		end},
		{type = "slider", label = "Max Distance", value = 300, min = 50, max = 2000, suffix = " studs", callback = function(value)
			petEspmaxdist = value
		end},
		{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			petEspftype = value
		end},
		{type = "multiselect", label = "Filter Pets", value = "", list = gameLists.pets, callback = function(value)
			petEspflist = value
		end},
		{type = "dropdown", label = "Filter Variations Type", value = "Whitelist", list = {"Whitelist","Blacklist"}, callback = function(value)
			petEspmuttype = value
		end},
		{type = "multiselect", label = "Filter Variations / Sizes", value = "None", list = gameLists.petMutations, callback = function(value)
			petEspmutlist = value
		end},
		{type = "multiselect", label = "Filter Rarities", value = "", list = gameLists.rarities, callback = function(value)
			petEsprarities = value
		end, onCreate = function(widget)
			registerGameListWidget(widget, "rarities")
		end},
	}
})
end)()
;(function()
	local PARTICLE_AURA_DATA = {
		{ "starlight", "rbxassetid://134645216613107" },
		{ "heavenly", "rbxassetid://139300897520961" },
		{ "ribbon", "rbxassetid://132069507632161" },
		{ "sakura", "rbxassetid://81755778619404" },
		{ "angel", "rbxassetid://97658130917593" },
		{ "wind", "rbxassetid://80694081850877" },
		{ "flow", "rbxassetid://119913533725648" },
		{ "star", "rbxassetid://73754563740680" },
	}
	local PARTICLE_AURA_NAMES = {}
	local particleAuraIdByName = {}
	for _, row in ipairs(PARTICLE_AURA_DATA) do
		table.insert(PARTICLE_AURA_NAMES, row[1])
		particleAuraIdByName[row[1]] = row[2]
	end
	local loadedParticleAuras = {}
	local selfAuraParticles = {}
	local otherAuraParticles = {}
	local showAuraOnOthers = false

	local Toggles = {
		SelfAuraEnabled = { Value = false },
	}
	local Options = {
		SelfAuraType = { Value = "None" },
		SelfAuraColor = { Value = Color3.fromRGB(133, 220, 255) },
	}

	local AURA_PART_ALIASES = {
		Head = "Head",
		UpperTorso = "Torso",
		LowerTorso = "Torso",
		Torso = "Torso",
		LeftUpperArm = "Left Arm",
		LeftLowerArm = "Left Arm",
		LeftHand = "Left Arm",
		["Left Arm"] = "Left Arm",
		RightUpperArm = "Right Arm",
		RightLowerArm = "Right Arm",
		RightHand = "Right Arm",
		["Right Arm"] = "Right Arm",
		LeftUpperLeg = "Left Leg",
		LeftLowerLeg = "Left Leg",
		LeftFoot = "Left Leg",
		["Left Leg"] = "Left Leg",
		RightUpperLeg = "Right Leg",
		RightLowerLeg = "Right Leg",
		RightFoot = "Right Leg",
		["Right Leg"] = "Right Leg",
		HumanoidRootPart = "HumanoidRootPart",
	}

	local function mapCharacterParts(character)
		local parts = {}
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("BasePart") then
				parts[child.Name] = child
			end
		end
		return parts
	end

	local function resolveAuraTargetPart(localParts, templatePartName)
		local direct = localParts[templatePartName]
		if direct then
			return direct
		end
		local alias = AURA_PART_ALIASES[templatePartName]
		if alias then
			return localParts[alias]
		end
		return localParts.HumanoidRootPart or localParts.Torso
	end

	local function getParticleAuraTemplate(name)
		local cached = loadedParticleAuras[name]
		if cached then return cached end
		local id = particleAuraIdByName[name]
		if not id then return nil end
		local ok, result = pcall(function()
			return game:GetObjects(id)[1]
		end)
		if ok and result then
			loadedParticleAuras[name] = result
			return result
		end
		return nil
	end

	local function clearAuraFromCharacter(character)
		local stored = character == localPlayer.Character and selfAuraParticles or otherAuraParticles[character]
		if stored then
			for _, p in ipairs(stored) do
				if p then p:Destroy() end
			end
		end
		if character == localPlayer.Character then
			table.clear(selfAuraParticles)
		elseif character then
			otherAuraParticles[character] = nil
		end
		if character then
			for _, inst in ipairs(character:GetDescendants()) do
				if inst.Name == "LarpticAuraParticle" then
					inst:Destroy()
				end
			end
		end
	end

	local function clearSelfAura()
		clearAuraFromCharacter(localPlayer.Character)
	end

	local function clearOtherAuras()
		for character in pairs(otherAuraParticles) do
			clearAuraFromCharacter(character)
		end
		table.clear(otherAuraParticles)
	end

	local function applyAuraToCharacter(character)
		if not character then return end
		local isLocal = character == localPlayer.Character
		if isLocal then
			clearAuraFromCharacter(character)
		else
			if not showAuraOnOthers then
				clearAuraFromCharacter(character)
				return
			end
			clearAuraFromCharacter(character)
		end
		if not (Toggles.SelfAuraEnabled and Toggles.SelfAuraEnabled.Value) then return end
		local auraName = (Options.SelfAuraType and Options.SelfAuraType.Value) or "None"
		if auraName == "None" or not particleAuraIdByName[auraName] then return end
		local col = Options.SelfAuraColor.Value or Color3.fromRGB(133, 220, 255)
		local created = applyParticleAuraToCharacter(character, auraName, col, true)
		if isLocal then
			selfAuraParticles = created
		else
			otherAuraParticles[character] = created
		end
	end

	local function refreshSelfAura()
		applyAuraToCharacter(localPlayer.Character)
	end

	local function refreshOtherAuras()
		if not showAuraOnOthers then
			clearOtherAuras()
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Character then
				applyAuraToCharacter(player.Character)
			end
		end
	end

	local function refreshAllAuras()
		refreshSelfAura()
		refreshOtherAuras()
	end

	local function bindOtherAuraPlayer(player)
		if player == localPlayer then return end
		player.CharacterAdded:Connect(function(character)
			task.delay(0.75, function()
				if showAuraOnOthers then
					applyAuraToCharacter(character)
				end
			end)
			character.AncestryChanged:Connect(function(_, parent)
				if not parent then
					otherAuraParticles[character] = nil
				end
			end)
		end)
		if player.Character then
			task.defer(function()
				if showAuraOnOthers then
					applyAuraToCharacter(player.Character)
				end
			end)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bindOtherAuraPlayer(player)
	end
	Players.PlayerAdded:Connect(bindOtherAuraPlayer)

	local function tintParticleSubtree(root, color)
		if not color or not root then return end
		local seq = ColorSequence.new(color)
		local function tintOne(obj)
			if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
				obj.Color = seq
			elseif obj:IsA("PointLight") then
				obj.Color = color
			end
		end
		tintOne(root)
		for _, d in ipairs(root:GetDescendants()) do
			tintOne(d)
		end
	end

	local function setParticleEmittersEnabledInSubtree(root, enabled)
		if not root then return end
		if root:IsA("ParticleEmitter") then
			root.Enabled = enabled
		end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d.Enabled = enabled
			end
		end
	end

	local function applyParticleAuraToCharacter(character, auraName, color, isPersistent)
		local auraObj = getParticleAuraTemplate(auraName)
		if not auraObj then return {} end

		local localParts = mapCharacterParts(character)
		local cloned = auraObj:Clone()
		local created = {}

		for _, part in ipairs(cloned:GetChildren()) do
			local targetPart = resolveAuraTargetPart(localParts, part.Name)
			if targetPart then
				for _, child in ipairs(part:GetChildren()) do
					local inst = child:Clone()
					inst.Name = "LarpticAuraParticle"
					inst.Parent = targetPart
					if color then
						tintParticleSubtree(inst, color)
					end
					table.insert(created, inst)
				end
			end
		end
		cloned:Destroy()

		for _, p in ipairs(created) do
			setParticleEmittersEnabledInSubtree(p, true)
		end

		if not isPersistent then
			task.delay(1.6, function()
				for _, p in ipairs(created) do
					if p and p.Parent then
						setParticleEmittersEnabledInSubtree(p, false)
					end
				end
			end)
			task.delay(2.5, function()
				for _, p in ipairs(created) do
					if p then p:Destroy() end
				end
			end)
		end

		return created
	end

	localPlayer.CharacterAdded:Connect(function()
		if Toggles.SelfAuraEnabled and Toggles.SelfAuraEnabled.Value then
			task.delay(0.75, refreshAllAuras)
		end
	end)

	local selfAuraTypeValues = { "None" }
	for _, n in ipairs(PARTICLE_AURA_NAMES) do
		table.insert(selfAuraTypeValues, n)
	end

	hub:CreateModule("Visuals", {
		name = "Particle Aura",
		on = false,
		bind = "None",
		desc = "Custom particle aura on your character.",
		callback = function(enabled)
			Toggles.SelfAuraEnabled.Value = enabled
			if enabled then
				refreshAllAuras()
			else
				clearSelfAura()
				clearOtherAuras()
			end
		end,
		opts = {
			{type = "dropdown", label = "Aura Type", value = "None", list = selfAuraTypeValues, callback = function(value)
				Options.SelfAuraType.Value = value
				if Toggles.SelfAuraEnabled.Value then
					refreshAllAuras()
				end
			end},
			{type = "color", label = "Aura Color", value = Color3.fromRGB(133, 220, 255), callback = function(color)
				Options.SelfAuraColor.Value = color
				if Toggles.SelfAuraEnabled.Value then
					refreshAllAuras()
				end
			end},
			{type = "checkbox", label = "Show On Others", value = false, callback = function(value)
				showAuraOnOthers = value
				if Toggles.SelfAuraEnabled.Value then
					refreshAllAuras()
				else
					clearOtherAuras()
				end
			end},
		}
	})
	local chamsEnabled = false
	local showChamsOnOthers = false
	local chamsColor = Color3.new(1, 1, 1)
	local savedChamState = {}
	local CHAM_PART_NAMES = {
		"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
		"LeftFoot", "LeftHand", "LeftLowerArm", "LeftLowerLeg",
		"LeftUpperArm", "LeftUpperLeg", "LowerTorso", "RightFoot",
		"RightHand", "RightLowerArm", "RightLowerLeg",
		"RightUpperArm", "RightUpperLeg", "UpperTorso",
	}
	local function captureBodyColors(bodyColors)
		if not bodyColors then
			return nil
		end
		return {
			HeadColor = bodyColors.HeadColor,
			TorsoColor = bodyColors.TorsoColor,
			LeftArmColor = bodyColors.LeftArmColor,
			RightArmColor = bodyColors.RightArmColor,
			LeftLegColor = bodyColors.LeftLegColor,
			RightLegColor = bodyColors.RightLegColor,
		}
	end
	local function restoreBodyColors(bodyColors, saved)
		if not bodyColors or not saved then
			return
		end
		bodyColors.HeadColor = saved.HeadColor
		bodyColors.TorsoColor = saved.TorsoColor
		bodyColors.LeftArmColor = saved.LeftArmColor
		bodyColors.RightArmColor = saved.RightArmColor
		bodyColors.LeftLegColor = saved.LeftLegColor
		bodyColors.RightLegColor = saved.RightLegColor
	end
	local function captureChamAppearance(char)
		if not char or savedChamState[char] then
			return
		end
		local save = {
			parts = {},
			bodyColors = captureBodyColors(char:FindFirstChildOfClass("BodyColors")),
		}
		for _, name in ipairs(CHAM_PART_NAMES) do
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				save.parts[name] = {
					Color = part.Color,
					Material = part.Material,
				}
			end
		end
		savedChamState[char] = save
	end
	local function applyChamsToCharacter(char)
		if not char then return end
		captureChamAppearance(char)
		for _, name in ipairs(CHAM_PART_NAMES) do
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Material = Enum.Material.ForceField
				part.Color = chamsColor
			end
		end
	end
	local function removeChamsFromCharacter(char)
		if not char then return end
		local save = savedChamState[char]
		if not save then
			for _, name in ipairs(CHAM_PART_NAMES) do
				local part = char:FindFirstChild(name)
				if part and part:IsA("BasePart") and part.Material == Enum.Material.ForceField then
					part.Material = Enum.Material.Plastic
				end
			end
			return
		end
		for name, state in pairs(save.parts) do
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Material = state.Material
				part.Color = state.Color
			end
		end
		restoreBodyColors(char:FindFirstChildOfClass("BodyColors"), save.bodyColors)
		savedChamState[char] = nil
	end
	local function refreshChamsForCharacter(char)
		if not char then return end
		if chamsEnabled then
			applyChamsToCharacter(char)
		else
			removeChamsFromCharacter(char)
		end
	end
	local function refreshChams()
		refreshChamsForCharacter(localPlayer.Character)
		if showChamsOnOthers then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= localPlayer then
					refreshChamsForCharacter(player.Character)
				end
			end
		else
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= localPlayer then
					removeChamsFromCharacter(player.Character)
				end
			end
		end
	end
	local function bindOtherChamsPlayer(player)
		if player == localPlayer then return end
		player.CharacterAdded:Connect(function(character)
			task.delay(0.5, function()
				if chamsEnabled and showChamsOnOthers then
					applyChamsToCharacter(character)
				end
			end)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		bindOtherChamsPlayer(player)
	end
	Players.PlayerAdded:Connect(bindOtherChamsPlayer)
	localPlayer.CharacterAdded:Connect(function(character)
		character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				savedChamState[character] = nil
			end
		end)
		task.delay(0.5, refreshChams)
	end)
	hub:CreateModule("Visuals", {
		name = "Chams",
		on = false,
		bind = "None",
		desc = "ForceField material overlay on your character.",
		callback = function(enabled)
			chamsEnabled = enabled
			refreshChams()
		end,
		opts = {
			{type = "color", label = "Chams Color", value = Color3.new(1, 1, 1), callback = function(color)
				chamsColor = color
				if chamsEnabled then refreshChams() end
			end},
			{type = "checkbox", label = "Show On Others", value = false, callback = function(value)
				showChamsOnOthers = value
				refreshChams()
			end},
		}
	})
	local Lighting = game:GetService("Lighting")
	local worldLightingMode = false
	local worldLightingTech = "ShadowMap"
	local worldTimeEnabled = false
	local worldTimeHour = 4.5
	local worldBetterShadows = false
	local worldRtxEnabled = false
	local worldAtmEnabled = false
	local worldAtmDensity = 0.35
	local worldAtmOffset = 0
	local worldAtmHaze = 1
	local worldAtmGlare = 10
	local worldAtmColor = Color3.fromRGB(199, 212, 255)
	local worldAtmDecay = Color3.fromRGB(106, 112, 125)
	local worldAmbientEnabled = false
	local worldAmbientColor = Color3.fromRGB(178, 178, 178)
	local worldOutdoorAmbientColor = Color3.fromRGB(178, 178, 178)
	local worldWeatherEnabled = false
	local worldWeatherType = "rain"
	local worldWeatherRate = 100
	local worldWeatherColor = Color3.fromRGB(255, 255, 255)
	local worldSkyboxEnabled = false
	local worldSkyboxType = "realistic"
	local casualAtmosphere = nil
	local casualSky = nil
	local casualWeatherPart = nil
	local casualWeatherConn = nil
	local casualWeatherRainEmitter = nil
	local casualWeatherLightRainEmitter = nil
	local casualConfigureWeather = nil
	local casualRtxBloom = nil
	local casualRtxSunRays = nil
	local casualRtxColorCorrection = nil
	local worldHeartbeatConn = nil
	local lightingController = nil
	local WEATHER_MAP_SIZE = Vector3.new(1024, 1, 1024)
	local WEATHER_MAP_HEIGHT = 85
	local function getLightingController()
		if lightingController ~= nil then
			return lightingController
		end
		local ok, ctrl = pcall(function()
			local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
			local controllers = playerScripts and playerScripts:FindFirstChild("Controllers")
			local module = controllers and controllers:FindFirstChild("LightingController")
			if module then
				return require(module)
			end
			return require(game:GetService("StarterPlayer").StarterPlayerScripts.Controllers.LightingController)
		end)
		if ok and ctrl then
			lightingController = ctrl
		end
		return lightingController
	end
	local function pushLightingOverride(props)
		if not props then
			return
		end
		local ctrl = getLightingController()
		if ctrl and ctrl.SetImmediate then
			pcall(function()
				ctrl:SetImmediate(props)
			end)
		end
		for key, value in props do
			pcall(function()
				Lighting[key] = value
			end)
		end
	end
	local function applyLightingTech()
		if not worldLightingMode then
			return
		end
		pcall(function()
			Lighting.Technology = Enum.Technology[worldLightingTech]
		end)
		if sethiddenproperty then
			pcall(function()
				sethiddenproperty(Lighting, "Technology", Enum.Technology[worldLightingTech])
			end)
		end
	end
	local function applyBetterShadows()
		if not worldBetterShadows then
			return
		end
		pushLightingOverride({
			GlobalShadows = true,
			ShadowSoftness = 0.1,
		})
		pcall(function()
			if Enum.Technology.Future then
				Lighting.Technology = Enum.Technology.Future
			else
				Lighting.Technology = Enum.Technology.ShadowMap
			end
		end)
		if sethiddenproperty then
			pcall(function()
				sethiddenproperty(Lighting, "Technology", Enum.Technology.Future or Enum.Technology.ShadowMap)
			end)
		end
	end
	local function clearBetterShadows()
		pushLightingOverride({
			GlobalShadows = true,
			ShadowSoftness = 0.2,
		})
	end
	local function applyRtxEffects()
		if not worldRtxEnabled then
			return
		end
		pushLightingOverride({
			GlobalShadows = true,
			ShadowSoftness = 0.02,
			ExposureCompensation = 0.15,
		})
		pcall(function()
			if Enum.Technology.Future then
				Lighting.Technology = Enum.Technology.Future
			end
		end)
		if not casualRtxBloom then
			casualRtxBloom = Lighting:FindFirstChild("CasualRTXBloom") or Instance.new("BloomEffect")
			casualRtxBloom.Name = "CasualRTXBloom"
			casualRtxBloom.Intensity = 0.7
			casualRtxBloom.Size = 24
			casualRtxBloom.Threshold = 0.95
			casualRtxBloom.Parent = Lighting
		end
		if not casualRtxSunRays then
			casualRtxSunRays = Lighting:FindFirstChild("CasualRTXSunRays") or Instance.new("SunRaysEffect")
			casualRtxSunRays.Name = "CasualRTXSunRays"
			casualRtxSunRays.Intensity = 0.25
			casualRtxSunRays.Spread = 0.6
			casualRtxSunRays.Parent = Lighting
		end
		if not casualRtxColorCorrection then
			casualRtxColorCorrection = Lighting:FindFirstChild("CasualRTXCC") or Instance.new("ColorCorrectionEffect")
			casualRtxColorCorrection.Name = "CasualRTXCC"
			casualRtxColorCorrection.Brightness = 0.03
			casualRtxColorCorrection.Contrast = 0.12
			casualRtxColorCorrection.Saturation = 0.18
			casualRtxColorCorrection.Parent = Lighting
		end
		casualRtxBloom.Enabled = true
		casualRtxSunRays.Enabled = true
		casualRtxColorCorrection.Enabled = true
	end
	local function clearRtxEffects()
		if casualRtxBloom then casualRtxBloom.Enabled = false end
		if casualRtxSunRays then casualRtxSunRays.Enabled = false end
		if casualRtxColorCorrection then casualRtxColorCorrection.Enabled = false end
	end
	local function needsWorldHeartbeat()
		return worldTimeEnabled or worldAmbientEnabled or worldLightingMode or worldBetterShadows or worldRtxEnabled
	end
	local function refreshWorldOverrides()
		if worldTimeEnabled then
			pushLightingOverride({ ClockTime = worldTimeHour })
		end
		if worldAmbientEnabled then
			pushLightingOverride({
				Ambient = worldAmbientColor,
				OutdoorAmbient = worldOutdoorAmbientColor,
				Brightness = 3,
			})
		end
		if worldLightingMode then
			applyLightingTech()
		end
		if worldBetterShadows then
			applyBetterShadows()
		end
		if worldRtxEnabled then
			applyRtxEffects()
		end
	end
	local function startWorldHeartbeat()
		if worldHeartbeatConn then
			return
		end
		worldHeartbeatConn = RS.Heartbeat:Connect(function()
			if needsWorldHeartbeat() then
				refreshWorldOverrides()
			end
		end)
	end
	local function stopWorldHeartbeat()
		if worldHeartbeatConn then
			worldHeartbeatConn:Disconnect()
			worldHeartbeatConn = nil
		end
	end
	local function syncWorldHeartbeat()
		if needsWorldHeartbeat() then
			startWorldHeartbeat()
			refreshWorldOverrides()
		else
			stopWorldHeartbeat()
		end
	end
	local function applyAtmosphere()
		if not casualAtmosphere or not casualAtmosphere.Parent then
			casualAtmosphere = Instance.new("Atmosphere")
			casualAtmosphere.Name = "CasualAtmosphere"
			casualAtmosphere.Parent = Lighting
		end
		pcall(function()
			casualAtmosphere.Density = worldAtmDensity
			casualAtmosphere.Offset = worldAtmOffset
			casualAtmosphere.Haze = worldAtmHaze
			casualAtmosphere.Glare = worldAtmGlare
			casualAtmosphere.Color = worldAtmColor
			casualAtmosphere.Decay = worldAtmDecay
		end)
	end
	local function clearAtmosphere()
		if casualAtmosphere then
			pcall(function() casualAtmosphere:Destroy() end)
			casualAtmosphere = nil
		end
	end
	local function applyAmbient()
		pushLightingOverride({
			Ambient = worldAmbientColor,
			OutdoorAmbient = worldOutdoorAmbientColor,
			Brightness = 3,
		})
		syncWorldHeartbeat()
	end
	local function clearAmbient()
		local ctrl = getLightingController()
		if ctrl and ctrl.GetDefault then
			local ok, defaults = pcall(function()
				return ctrl:GetDefault()
			end)
			if ok and defaults then
				pushLightingOverride({
					Ambient = defaults.Ambient,
					OutdoorAmbient = defaults.OutdoorAmbient,
					Brightness = defaults.Brightness,
				})
				return
			end
		end
		pushLightingOverride({
			Ambient = Color3.fromRGB(0, 0, 0),
			OutdoorAmbient = Color3.fromRGB(70, 70, 70),
		})
		syncWorldHeartbeat()
	end
	local function applySkyboxPreset(sky, preset)
		if not sky then return end
		preset = preset or worldSkyboxType
		if preset == "realistic" then
			sky.MoonTextureId = "rbxasset://sky/moon.jpg"
			sky.SkyboxBk = "rbxassetid://15502511288"
			sky.SkyboxDn = "rbxassetid://15502508460"
			sky.SkyboxFt = "rbxassetid://15502510289"
			sky.SkyboxLf = "rbxassetid://15502507918"
			sky.SkyboxRt = "rbxassetid://15502509398"
			sky.SkyboxUp = "rbxassetid://15502511911"
			sky.StarCount = 3000
			sky.CelestialBodiesShown = true
		end
	end
	local function clearWeatherPart()
		if casualWeatherPart then
			pcall(function() casualWeatherPart:Destroy() end)
			casualWeatherPart = nil
		end
		casualWeatherRainEmitter = nil
		casualWeatherLightRainEmitter = nil
	end
	local function configureRainEmitters()
		local isLightRain = worldWeatherType == "light rain"
		local rate = math.max(worldWeatherRate * 6, 600)
		if casualWeatherRainEmitter then
			casualWeatherRainEmitter.Color = ColorSequence.new(worldWeatherColor)
			casualWeatherRainEmitter.Rate = isLightRain and 0 or rate
			casualWeatherRainEmitter.Enabled = not isLightRain
		end
		if casualWeatherLightRainEmitter then
			casualWeatherLightRainEmitter.Color = ColorSequence.new(worldWeatherColor)
			casualWeatherLightRainEmitter.Rate = rate
			casualWeatherLightRainEmitter.Enabled = isLightRain
		end
	end
	local function createMapRain()
		clearWeatherPart()
		local part = Instance.new("Part")
		part.Name = "CasualWeatherRain"
		part.Size = WEATHER_MAP_SIZE
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = workspace
		local rain = Instance.new("ParticleEmitter")
		rain.Name = "WeatherEmitterPrimary"
		rain.Texture = "rbxassetid://1822883048"
		rain.Brightness = 1
		rain.Color = ColorSequence.new(worldWeatherColor)
		rain.LightEmission = 0.05
		rain.LightInfluence = 0.9
		rain.Orientation = Enum.ParticleOrientation.FacingCamera
		rain.Size = NumberSequence.new(10)
		rain.Squash = NumberSequence.new(2)
		rain.Transparency = NumberSequence.new(0.5)
		rain.ZOffset = 0
		rain.EmissionDirection = Enum.NormalId.Bottom
		rain.Enabled = true
		rain.Lifetime = NumberRange.new(0.8, 0.8)
		rain.Rotation = NumberRange.new(0, 0)
		rain.RotSpeed = NumberRange.new(0, 0)
		rain.Speed = NumberRange.new(60, 60)
		rain.SpreadAngle = Vector2.new(0, 0)
		rain.VelocityInheritance = 0
		rain.Drag = 0
		rain.LockedToPart = true
		rain.Parent = part
		casualWeatherRainEmitter = rain
		local lightRain = Instance.new("ParticleEmitter")
		lightRain.Name = "LightRainEffect"
		lightRain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		lightRain.Brightness = 1
		lightRain.Color = ColorSequence.new(worldWeatherColor)
		lightRain.LightEmission = 0.05
		lightRain.LightInfluence = 0.9
		lightRain.Orientation = Enum.ParticleOrientation.FacingCamera
		lightRain.Size = NumberSequence.new(1)
		lightRain.Squash = NumberSequence.new(4)
		lightRain.Transparency = NumberSequence.new(0.5)
		lightRain.ZOffset = 0
		lightRain.EmissionDirection = Enum.NormalId.Bottom
		lightRain.Enabled = false
		lightRain.Lifetime = NumberRange.new(0.8, 0.8)
		lightRain.Rotation = NumberRange.new(0, 0)
		lightRain.RotSpeed = NumberRange.new(0, 0)
		lightRain.Speed = NumberRange.new(60, 60)
		lightRain.SpreadAngle = Vector2.new(0, 0)
		lightRain.VelocityInheritance = 0
		lightRain.Drag = 0
		lightRain.LockedToPart = true
		lightRain.Parent = part
		casualWeatherLightRainEmitter = lightRain
		casualWeatherPart = part
		configureRainEmitters()
	end
	local function clearWeather()
		if casualWeatherConn then
			casualWeatherConn:Disconnect()
			casualWeatherConn = nil
		end
		casualConfigureWeather = nil
		clearWeatherPart()
	end
	local function buildWeather()
		clearWeather()
		local kind = worldWeatherType
		if kind == "rain" or kind == "light rain" then
			createMapRain()
			casualConfigureWeather = configureRainEmitters
			casualWeatherConn = RS.RenderStepped:Connect(function()
				if casualWeatherPart and casualWeatherPart.Parent then
					local cam = workspace.CurrentCamera
					if cam then
						casualWeatherPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, WEATHER_MAP_HEIGHT, 0))
					end
				end
			end)
			return
		end
		local part = Instance.new("Part")
		part.Name = "CasualWeatherSnow"
		part.Size = Vector3.new(260, 1, 260)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = workspace
		local tertiary = Instance.new("ParticleEmitter")
		tertiary.Name = "WeatherEmitterTertiary"
		tertiary.Parent = part
		casualWeatherPart = part
		casualConfigureWeather = function()
			local primaryRate = math.max(worldWeatherRate, 0)
			tertiary.Texture = "rbxassetid://99851851"
			tertiary.Brightness = 1
			tertiary.LightEmission = 0.5
			tertiary.LightInfluence = 0
			tertiary.Orientation = Enum.ParticleOrientation.FacingCamera
			tertiary.Lifetime = NumberRange.new(5, 10)
			tertiary.Speed = NumberRange.new(30, 30)
			tertiary.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.33),
				NumberSequenceKeypoint.new(0.5, 0.551),
				NumberSequenceKeypoint.new(1, 0.401),
			})
			tertiary.Color = ColorSequence.new(worldWeatherColor)
			tertiary.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.74),
				NumberSequenceKeypoint.new(0.35, 0.973),
				NumberSequenceKeypoint.new(0.7, 0.77),
				NumberSequenceKeypoint.new(1, 1),
			})
			tertiary.SpreadAngle = Vector2.new(50, 50)
			tertiary.Rate = math.max(primaryRate * 10, 1000)
			tertiary.EmissionDirection = Enum.NormalId.Bottom
			tertiary.Enabled = true
		end
		casualConfigureWeather()
		casualWeatherConn = RS.RenderStepped:Connect(function()
			if part and part.Parent then
				local cam = workspace.CurrentCamera
				if cam then
					part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 85, 0))
				end
			end
		end)
	end
	hub:CreateModule("Visuals", {
		name = "Lighting",
		notoggle = true,
		on = false,
		bind = "None",
		callback = function() end,
		opts = {
			{type = "checkbox", label = "Lighting Mode", value = false, callback = function(value)
				worldLightingMode = value
				syncWorldHeartbeat()
			end},
			{type = "dropdown", label = "Lighting Technology", value = "ShadowMap", list = {"Compatibility", "Voxel", "ShadowMap", "Future", "Legacy"}, callback = function(value)
				worldLightingTech = value
				if worldLightingMode then
					syncWorldHeartbeat()
				end
			end},
			{type = "checkbox", label = "World Time", value = false, callback = function(value)
				worldTimeEnabled = value
				syncWorldHeartbeat()
			end},
			{type = "slider", label = "Hour", value = 4.5, min = 0, max = 24, increment = 0.1, callback = function(value)
				worldTimeHour = value
				if worldTimeEnabled then
					syncWorldHeartbeat()
				end
			end},
			{type = "checkbox", label = "RTX", value = false, callback = function(value)
				worldRtxEnabled = value
				if value then
					applyRtxEffects()
				else
					clearRtxEffects()
				end
				syncWorldHeartbeat()
			end},
			{type = "checkbox", label = "Better Shadows", value = false, callback = function(value)
				worldBetterShadows = value
				if value then
					applyBetterShadows()
				else
					clearBetterShadows()
				end
				syncWorldHeartbeat()
			end},
		}
	})
	hub:CreateModule("Visuals", {
		name = "Ambience",
		notoggle = true,
		on = false,
		bind = "None",
		callback = function() end,
		opts = {
			{type = "checkbox", label = "Ambient", value = false, callback = function(value)
				worldAmbientEnabled = value
				if value then applyAmbient() else clearAmbient() end
			end},
			{type = "color", label = "Ambient Color", value = Color3.fromRGB(178, 178, 178), callback = function(color)
				worldAmbientColor = color
				if worldAmbientEnabled then applyAmbient() end
			end},
			{type = "color", label = "Outdoor Ambient Color", value = Color3.fromRGB(178, 178, 178), callback = function(color)
				worldOutdoorAmbientColor = color
				if worldAmbientEnabled then applyAmbient() end
			end},
			{type = "checkbox", label = "Atmosphere", value = false, callback = function(value)
				worldAtmEnabled = value
				if value then applyAtmosphere() else clearAtmosphere() end
			end},
			{type = "color", label = "Atmosphere Color", value = Color3.fromRGB(199, 212, 255), callback = function(color)
				worldAtmColor = color
				if worldAtmEnabled then applyAtmosphere() end
			end},
			{type = "color", label = "Atmosphere Decay", value = Color3.fromRGB(106, 112, 125), callback = function(color)
				worldAtmDecay = color
				if worldAtmEnabled then applyAtmosphere() end
			end},
			{type = "slider", label = "Atmosphere Density", value = 0.35, min = 0, max = 1, increment = 0.01, callback = function(value)
				worldAtmDensity = value
				if worldAtmEnabled then applyAtmosphere() end
			end},
			{type = "slider", label = "Atmosphere Haze", value = 1, min = 0, max = 10, increment = 0.1, callback = function(value)
				worldAtmHaze = value
				if worldAtmEnabled then applyAtmosphere() end
			end},
			{type = "slider", label = "Atmosphere Glare", value = 10, min = 0, max = 10, increment = 0.1, callback = function(value)
				worldAtmGlare = value
				if worldAtmEnabled then applyAtmosphere() end
			end},
			{type = "slider", label = "Atmosphere Offset", value = 0, min = 0, max = 1, increment = 0.01, callback = function(value)
				worldAtmOffset = value
				if worldAtmEnabled then applyAtmosphere() end
			end},
		}
	})
	hub:CreateModule("Visuals", {
		name = "Weather",
		notoggle = true,
		on = false,
		bind = "None",
		callback = function() end,
		opts = {
			{type = "checkbox", label = "Weather", value = false, callback = function(value)
				worldWeatherEnabled = value
				if value then buildWeather() else clearWeather() end
			end},
			{type = "dropdown", label = "Weather Type", value = "rain", list = {"light rain", "rain", "snow"}, callback = function(value)
				worldWeatherType = value
				if worldWeatherEnabled then buildWeather() end
			end},
			{type = "color", label = "Weather Color", value = Color3.fromRGB(255, 255, 255), callback = function(color)
				worldWeatherColor = color
				if worldWeatherEnabled then buildWeather() end
			end},
			{type = "slider", label = "Weather Rate", value = 100, min = 0, max = 100, increment = 1, callback = function(value)
				worldWeatherRate = value
				if worldWeatherEnabled and casualConfigureWeather then
					casualConfigureWeather()
				end
			end},
		}
	})
	hub:CreateModule("Visuals", {
		name = "Skybox",
		notoggle = true,
		on = false,
		bind = "None",
		callback = function() end,
		opts = {
			{type = "checkbox", label = "Skybox", value = false, callback = function(value)
				worldSkyboxEnabled = value
				if value then
					local existing = Lighting:FindFirstChildOfClass("Sky")
					if existing and existing ~= casualSky then
						pcall(function() existing.Parent = nil end)
					end
					if not (casualSky and casualSky.Parent) then
						casualSky = Instance.new("Sky")
						casualSky.Name = "CasualSky"
						applySkyboxPreset(casualSky)
						casualSky.Parent = Lighting
					else
						applySkyboxPreset(casualSky)
						casualSky.Parent = Lighting
					end
				elseif casualSky then
					pcall(function() casualSky.Parent = nil end)
				end
			end},
			{type = "dropdown", label = "Skybox Preset", value = "realistic", list = {"realistic"}, callback = function(value)
				worldSkyboxType = value
				if worldSkyboxEnabled and casualSky then
					applySkyboxPreset(casualSky, value)
				end
			end},
		}
	})
end)()
;(function()
	local autocodesrunning = false
	hub:CreateModule("Misc", {
		name = "Auto Claim Codes",
		on = false,
		bind = "None",
		desc = "Redeem promo codes.",
		callback = function(enabled)
			autocodesrunning = enabled
			if not enabled then return end
			task.spawn(function()
				local codes = {"TEAMGREENBEAN", "WATERYOPLANTS", "REMEMBERTODRINKWATER"}
				local stealNet = nil
				pcall(function()
					local sm = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules") or game:GetService("ReplicatedStorage"):WaitForChild("SharedModules", 5)
					local netMod = sm and (sm:FindFirstChild("Networking") or sm:WaitForChild("Networking", 3))
					if netMod then
						stealNet = require(netMod)
					end
				end)
				if not stealNet then
					autocodesrunning = false
					return
				end
				local submitted = 0
				for _, code in codes do
					if not autocodesrunning then break end
					pcall(function()
						stealNet.Settings.SubmitCode:Fire(code)
					end)
					task.wait(1.5)
				end
				autocodesrunning = false
			end)
		end,
		opts = {
			{type = "button", label = "Claim Now", callback = function()
				local stealNet = nil
				pcall(function()
					local sm = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules") or game:GetService("ReplicatedStorage"):WaitForChild("SharedModules", 5)
					local netMod = sm and (sm:FindFirstChild("Networking") or sm:WaitForChild("Networking", 3))
					if netMod then
						stealNet = require(netMod)
					end
				end)
				if not stealNet then return end
				local codes = {"TEAMGREENBEAN", "WATERYOPLANTS", "REMEMBERTODRINKWATER"}
				task.spawn(function()
					for _, code in codes do
						pcall(function() stealNet.Settings.SubmitCode:Fire(code) end)
						task.wait(1.5)
					end
				end)
			end},
		}
	})
	local antiragdollenabled = false
	local antiragdollconn = nil
	local antiragdollcharconn = nil
	function dounragdoll(char)
		local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		if not torso then return end
		for _, v in pairs(torso:GetDescendants()) do
			if v:IsA("Motor6D") then
				v.Enabled = true
			end
		end
		for _, v in pairs(torso:GetChildren()) do
			if v.Name == "RagdollConstraint" then
				pcall(function()
					if v.Attachment0 then v.Attachment0:Destroy() end
					if v.Attachment1 then v.Attachment1:Destroy() end
					v:Destroy()
				end)
			end
			if v:IsA("Motor6D") then
				pcall(function() v.Part1.CollisionGroup = "Default" end)
			end
		end
		for _, v in pairs(char:GetChildren()) do
			if v.Name == "Collider" or v:IsA("ForceField") or v.Name == "RagdollConstraint" then
				pcall(function() v:Destroy() end)
			end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = true
			hum.PlatformStand = false
			char:SetAttribute("Ragdolled", nil)
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
	local function setupAntiRagdoll()
		local char = localPlayer.Character
		if not char then return end
		if antiragdollconn then
			antiragdollconn:Disconnect()
			antiragdollconn = nil
		end
		antiragdollconn = char:GetAttributeChangedSignal("Ragdolled"):Connect(function()
			if not antiragdollenabled then return end
			if not char:GetAttribute("Ragdolled") then return end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = true
				hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
			dounragdoll(char)
			task.spawn(function()
				for i = 1, 5 do
					if hrp then
						hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
						hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					end
					task.wait(0.02)
				end
				if hrp then
					hrp.Anchored = false
				end
			end)
		end)
	end
	hub:CreateModule("Misc", {
		name = "Anti Ragdoll",
		on = false,
		bind = "None",
		desc = "Anti ragdoll.",
		callback = function(enabled)
			antiragdollenabled = enabled
			if enabled then
				setupAntiRagdoll()
				if antiragdollcharconn then
					antiragdollcharconn:Disconnect()
				end
				antiragdollcharconn = localPlayer.CharacterAdded:Connect(function()
					if antiragdollenabled then
						task.wait(1)
						setupAntiRagdoll()
					end
				end)
			else
				if antiragdollconn then
					antiragdollconn:Disconnect()
					antiragdollconn = nil
				end
				if antiragdollcharconn then
					antiragdollcharconn:Disconnect()
					antiragdollcharconn = nil
				end
			end
		end,
		opts = {}
	})

	local antiWheelbarrowEnabled = false
	local antiWheelbarrowConns = {}

	local function isWheelbarrowTool(tool)
		return tool and tool:IsA("Tool") and (tool:GetAttribute("Wheelbarrow") ~= nil or tool.Name == "Wheelbarrow")
	end

	local function getSeatOwner(seat)
		if not seat then
			return nil
		end
		local model = seat:FindFirstAncestorOfClass("Model")
		while model do
			local player = game.Players:GetPlayerFromCharacter(model)
			if player then
				return player
			end
			if model.Parent and model.Parent:IsA("Model") then
				model = model.Parent
			else
				break
			end
		end
		return nil
	end

	local function isForeignWheelbarrowSeat(seat)
		if not seat or not (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
			return false
		end
		local tool = seat:FindFirstAncestorWhichIsA("Tool")
		if not isWheelbarrowTool(tool) then
			return false
		end
		local owner = getSeatOwner(seat)
		return owner ~= nil and owner ~= localPlayer
	end

	local function escapeWheelbarrowSeat(hum)
		if not hum then
			return
		end
		hum.Sit = false
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end)
		pcall(function()
			hum.Jump = true
		end)
	end

	local function onAntiWheelbarrowSeated(hum, active, seat)
		if not antiWheelbarrowEnabled or not active then
			return
		end
		if isForeignWheelbarrowSeat(seat) then
			escapeWheelbarrowSeat(hum)
		end
	end

	local function bindAntiWheelbarrowCharacter(char)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		table.insert(antiWheelbarrowConns, hum.Seated:Connect(function(active, seat)
			onAntiWheelbarrowSeated(hum, active, seat)
		end))
		table.insert(antiWheelbarrowConns, game:GetService("RunService").Heartbeat:Connect(function()
			if not antiWheelbarrowEnabled then
				return
			end
			local seat = hum.SeatPart
			if isForeignWheelbarrowSeat(seat) then
				escapeWheelbarrowSeat(hum)
			end
		end))
	end

	local function clearAntiWheelbarrowConnections()
		for _, conn in antiWheelbarrowConns do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		table.clear(antiWheelbarrowConns)
	end

	hub:CreateModule("Misc", {
		name = "Anti Wheelbarrow",
		on = false,
		bind = "None",
		desc = "Block other players from seating you in their wheelbarrow.",
		callback = function(enabled)
			antiWheelbarrowEnabled = enabled
			clearAntiWheelbarrowConnections()
			if enabled and localPlayer.Character then
				bindAntiWheelbarrowCharacter(localPlayer.Character)
			end
			if enabled then
				table.insert(antiWheelbarrowConns, localPlayer.CharacterAdded:Connect(function(char)
					if antiWheelbarrowEnabled then
						task.wait(0.2)
						bindAntiWheelbarrowCharacter(char)
					end
				end))
			end
		end,
		opts = {}
	})
end)()
;(function()
	local invValActive = false
	local invValSetupDone = false
	local invValConns = {}
	local invValUpdatePending = false
	local invValUpdateRun = nil
	local invValLastTotalText = ""
	local invValLastSlotText = setmetatable({}, { __mode = "k" })
	local invValSellFlags = nil
	local invValNetworking = nil
	local invValDailyDealCache = { at = 0, available = false, timeRemaining = 0 }
	local INV_VAL_LABEL = "CasualInvValue"
	local INV_VAL_TOTAL = "CasualInvTotal"
	local invValFont = nil
	local invValFontSize = 9
	local updateInvValLabels
	local function ensureInvSellFlags()
		if invValSellFlags then return invValSellFlags end
		local flagsMod = findModule and findModule("SellFlags")
		if flagsMod and safeRequire then
			invValSellFlags = safeRequire(flagsMod)
		end
		return invValSellFlags
	end
	local function getDailyDealInfo()
		local now = os.clock()
		if now - invValDailyDealCache.at < 12 then
			return invValDailyDealCache.available, invValDailyDealCache.timeRemaining
		end
		invValDailyDealCache.at = now
		local ok, deal = pcall(function()
			if not invValNetworking then
				invValNetworking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
			end
			return invValNetworking.NPCS.CheckDailyDeal:Fire()
		end)
		if ok and deal then
			invValDailyDealCache.available = deal.Available == true
			invValDailyDealCache.timeRemaining = tonumber(deal.TimeRemaining) or 0
		end
		return invValDailyDealCache.available, invValDailyDealCache.timeRemaining
	end
	local function scheduleInvValUpdate()
		if not invValActive then return end
		if invValUpdatePending then return end
		invValUpdatePending = true
		invValUpdateRun = task.delay(0.25, function()
			invValUpdatePending = false
			invValUpdateRun = nil
			if invValActive then
				pcall(updateInvValLabels)
			end
		end)
	end
	local function resolveInvUIFont()
		if invValFont then
			return invValFont, invValFontSize
		end
		for _, gui in localPlayer.PlayerGui:GetChildren() do
			if gui.Name:find("Syde", 1, true) then
				local sample = gui:FindFirstChildWhichIsA("TextLabel", true)
				if sample and sample.TextSize > 0 then
					invValFont = sample.Font
					invValFontSize = math.clamp(sample.TextSize - 1, 8, 14)
					return invValFont, invValFontSize
				end
			end
		end
		local bg = localPlayer.PlayerGui:FindFirstChild("BackpackGui")
		local backpack = bg and bg:FindFirstChild("Backpack")
		local hotbar = backpack and backpack:FindFirstChild("Hotbar")
		if hotbar then
			for _, slot in hotbar:GetChildren() do
				local lbl = slot:FindFirstChild("ToolName", true)
				if lbl and lbl:IsA("TextLabel") then
					invValFont = lbl.Font
					invValFontSize = math.clamp(lbl.TextSize - 1, 8, 14)
					return invValFont, invValFontSize
				end
			end
		end
		invValFont = Enum.Font.GothamBold
		invValFontSize = 9
		return invValFont, invValFontSize
	end
	local function formatInvVal(n)
		n = tonumber(n) or 0
		if n <= 0 then return "0" end
		if n >= 1e15 then
			local v = n / 1e15
			return (string.format("%.2fQa", v):gsub("%.?0+([Qa])$", "%1"))
		elseif n >= 1e12 then
			local v = n / 1e12
			return (string.format("%.2fT", v):gsub("%.?0+([T])$", "%1"))
		elseif n >= 1e9 then
			local v = n / 1e9
			return (string.format("%.2fB", v):gsub("%.?0+([B])$", "%1"))
		elseif n >= 1e6 then
			local v = n / 1e6
			return (string.format("%.2fM", v):gsub("%.?0+([M])$", "%1"))
		elseif n >= 1000 then
			local v = n / 1000
			return (string.format("%.2fK", v):gsub("%.?0+([K])$", "%1"))
		else
			return tostring(math.floor(n))
		end
	end
	local function resolveSlotCropName(displayName)
		if not displayName or displayName == "" then return nil end
		if displayCropMap[displayName] then
			return displayCropMap[displayName]
		end
		local clean = displayName:gsub("%s+", ""):lower()
		for k, v in pairs(displayCropMap) do
			if k:gsub("%s+", ""):lower() == clean then
				return v
			end
		end
		return getcropname(displayName) or displayName
	end
	local function weightKey(weight)
		return string.format("%.2f", tonumber(weight) or 0)
	end
	local function getFruitToolCalcInputs(item)
		if not item or (not item:IsA("Tool") and not item:IsA("Configuration")) then return end
		local fruitName = item:GetAttribute("FruitName")
			or item:GetAttribute("Fruit")
			or item:GetAttribute("SeedName")
			or item:GetAttribute("CorePartName")
		if not fruitName or fruitName == "" then
			local nameClean = item.Name:gsub("%[.-%]", ""):match("^%s*(.-)%s*$")
			fruitName = getcropname(nameClean) or displayCropMap[nameClean] or nameClean
		end
		if not fruitName or fruitName == "" then return end
		local sizeMulti = tonumber(item:GetAttribute("SizeMultiplier")) or tonumber(item:GetAttribute("SizeMulti"))
		if not sizeMulti then
			local w = tonumber(item:GetAttribute("Weight"))
			local baseW = getbaseweight(fruitName) or 1
			if w and baseW > 0 then
				sizeMulti = w > 50 and (w / 1000 / baseW) or (w / baseW)
			end
		end
		if not sizeMulti or sizeMulti <= 0 then sizeMulti = 1 end
		local mutation = item:GetAttribute("Mutation") or "None"
		local decay = tonumber(item:GetAttribute("DecayAlpha")) or 0
		return fruitName, sizeMulti, mutation, decay
	end
	local function calcFruitToolBasePrice(item)
		local fruitName, sizeMulti, mutation, decay = getFruitToolCalcInputs(item)
		if not fruitName then return 0 end
		local vc = getValCalc()
		if vc and typeof(vc) == "function" then
			local ok, res = pcall(vc, fruitName, sizeMulti, mutation ~= "None" and mutation or nil, localPlayer, decay or 0)
			if ok and res and res > 0 then
				return math.floor(res)
			end
		end
		return 0
	end
	local function calcFruitToolPrice(item)
		local fruitName, sizeMulti, mutation, decay = getFruitToolCalcInputs(item)
		if not fruitName then return 0 end
		return calcGamePrice(fruitName, sizeMulti, mutation, decay)
	end
	local function collectFruitTools()
		local items = {}
		local function addItem(item)
			if not item or (not item:IsA("Tool") and not item:IsA("Configuration")) then return end
			local isFruit = item:GetAttribute("HarvestedFruit") or item:GetAttribute("FruitName") or item:GetAttribute("Fruit") or item:GetAttribute("FruitProxy")
			local fruitName = item:GetAttribute("FruitName") or item:GetAttribute("Fruit")
			if not fruitName then
				local clean = item.Name:gsub("%[.-%]", ""):match("^%s*(.-)%s*$")
				if clean and clean ~= "Shovel" and clean ~= "Лопата" and clean ~= "Build" and clean ~= "Построить" then
					local mapped = resolveSlotCropName(clean)
					if mapped and mapped ~= clean then
						fruitName = mapped
						isFruit = true
					end
				end
			end
			if isFruit or fruitName then
				local crop = resolveSlotCropName(fruitName) or fruitName
				local basePrice = calcFruitToolBasePrice(item)
				local price = calcFruitToolPrice(item)
				local itemId = item:GetAttribute("Id")
				table.insert(items, {
					id = itemId,
					itemRef = item,
					fruitName = fruitName,
					cropName = crop,
					weight = tonumber(item:GetAttribute("Weight")) or 0,
					weightKey = weightKey(item:GetAttribute("Weight")),
					basePrice = basePrice,
					price = price,
				})
			end
		end
		local bp = localPlayer:FindFirstChildOfClass("Backpack")
		if bp then
			for _, child in bp:GetChildren() do
				addItem(child)
			end
		end
		local char = localPlayer.Character
		if char then
			for _, child in char:GetChildren() do
				addItem(child)
			end
		end
		return items
	end
	local function parseSlotWeight(text)
		if not text or text == "" then return nil end
		local numStr = text:match("([%d%.]+)")
		return tonumber(numStr)
	end
	local function isFruitSlot(slotBtn)
		local toolNameLbl = slotBtn:FindFirstChild("ToolName", true)
		local toolCountLbl = slotBtn:FindFirstChild("ToolCount", true)
		local displayName = toolNameLbl and toolNameLbl.Text or ""
		if displayName == "" or displayName == "Shovel" or displayName == "Build" or displayName == "Построить" or displayName == "Лопата" then
			return nil
		end
		local cropName = resolveSlotCropName(displayName)
		if not cropName then return nil end
		local countText = toolCountLbl and toolCountLbl.Text or ""
		local parsedWeight = parseSlotWeight(countText)
		return cropName, parsedWeight, weightKey(parsedWeight)
	end
	local function getSlotTool(slotBtn)
		for _, child in slotBtn:GetChildren() do
			if child:IsA("Tool") then
				return child
			end
		end
		for _, desc in slotBtn:GetDescendants() do
			if desc:IsA("ObjectValue") and desc.Value and desc.Value:IsA("Tool") then
				return desc.Value
			end
		end
		return nil
	end
	local function matchFruitForSlot(cropName, weightKg, weightKey, pool, slotTool)
		if slotTool then
			local slotId = slotTool:GetAttribute("Id")
			if slotId then
				for i, entry in pool do
					if entry.id == slotId then
						return table.remove(pool, i)
					end
				end
			end
			for i, entry in pool do
				if entry.itemRef == slotTool then
					return table.remove(pool, i)
				end
			end
		end
		local bestIdx, bestDiff = nil, math.huge
		for i, entry in pool do
			if entry.cropName == cropName or entry.fruitName == cropName then
				if weightKey and entry.weightKey == weightKey then
					return table.remove(pool, i)
				end
				if weightKg and entry.weight then
					local diff = math.abs(entry.weight - weightKg)
					if diff < 0.08 and diff < bestDiff then
						bestIdx = i
						bestDiff = diff
					end
				end
			end
		end
		if bestIdx then
			return table.remove(pool, bestIdx)
		end
		if cropName then
			local onlyIdx, count = nil, 0
			for i, entry in pool do
				if entry.cropName == cropName or entry.fruitName == cropName then
					onlyIdx = i
					count = count + 1
				end
			end
			if count == 1 then
				return table.remove(pool, onlyIdx)
			end
		end
		return nil
	end
	local function ensureSlotValueLabel(slotBtn)
		local lbl = slotBtn:FindFirstChild(INV_VAL_LABEL)
		if lbl then return lbl end
		lbl = Instance.new("TextLabel")
		lbl.Name = INV_VAL_LABEL
		lbl.BackgroundTransparency = 1
		lbl.Parent = slotBtn
		local font, size = resolveInvUIFont()
		lbl.Size = UDim2.new(1, -6, 0, 12)
		lbl.Position = UDim2.new(0.5, 0, 0, 1)
		lbl.AnchorPoint = Vector2.new(0.5, 0)
		lbl.ZIndex = slotBtn.ZIndex + 5
		lbl.Font = font
		lbl.TextSize = size
		lbl.TextColor3 = Color3.fromRGB(110, 255, 140)
		lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		lbl.TextStrokeTransparency = 0
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.TextYAlignment = Enum.TextYAlignment.Center
		return lbl
	end
	local function removeSlotValueLabel(slotBtn)
		local lbl = slotBtn:FindFirstChild(INV_VAL_LABEL)
		if lbl then
			lbl:Destroy()
		end
	end
	local function ensureInvTotalLabel(inv)
		local totalLbl = inv:FindFirstChild(INV_VAL_TOTAL)
		if totalLbl then return totalLbl end
		totalLbl = Instance.new("TextLabel")
		totalLbl.Name = INV_VAL_TOTAL
		totalLbl.BackgroundTransparency = 1
		totalLbl.Parent = inv
		totalLbl.AnchorPoint = Vector2.new(0, 0)
		totalLbl.Position = UDim2.new(0, 170, 0, 7)
		totalLbl.Size = UDim2.new(0, 340, 0, 24)
		local font, size = resolveInvUIFont()
		totalLbl.Font = font
		totalLbl.TextSize = math.max(size + 3, 13)
		totalLbl.TextColor3 = Color3.fromRGB(255, 220, 90)
		totalLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		totalLbl.TextStrokeTransparency = 0
		totalLbl.TextXAlignment = Enum.TextXAlignment.Left
		totalLbl.ZIndex = 6
		return totalLbl
	end
	local function cleanInvValLabels(backpack)
		if not backpack then return end
		local function cleanContainer(container)
			if not container then return end
			for _, child in container:GetChildren() do
				if child:IsA("GuiButton") then
					removeSlotValueLabel(child)
				end
			end
		end
		cleanContainer(backpack:FindFirstChild("Hotbar"))
		local inv = backpack:FindFirstChild("Inventory")
		if inv then
			local totalLbl = inv:FindFirstChild(INV_VAL_TOTAL)
			if totalLbl then
				totalLbl:Destroy()
			end
			local scroll = inv:FindFirstChild("ScrollingFrame")
			cleanContainer(scroll and scroll:FindFirstChild("UIGridFrame"))
		end
	end
	updateInvValLabels = function()
		if not invValActive then return end
		local bg = localPlayer.PlayerGui:FindFirstChild("BackpackGui")
		if not bg then return end
		local backpack = bg:FindFirstChild("Backpack")
		if not backpack then return end
		local tools = collectFruitTools()
		local totalValue = 0
		local totalBaseValue = 0
		for _, entry in tools do
			totalValue = totalValue + entry.price
			totalBaseValue = totalBaseValue + (entry.basePrice or entry.price)
		end
		local sellFlags = ensureInvSellFlags()
		local dailyPrice = 0
		if sellFlags and sellFlags.DailyDealPrice and totalBaseValue > 0 then
			dailyPrice = sellFlags.DailyDealPrice(totalBaseValue)
		end
		local pool = {}
		for _, entry in tools do
			table.insert(pool, entry)
		end
		local seenSlots = {}
		local function processContainer(container)
			if not container then return end
			for _, slotBtn in container:GetChildren() do
				if slotBtn:IsA("GuiButton") then
					seenSlots[slotBtn] = true
					local cropName, weightKg, weightKey = isFruitSlot(slotBtn)
					if cropName then
						local matched = matchFruitForSlot(cropName, weightKg, weightKey, pool, getSlotTool(slotBtn))
						if matched and matched.price > 0 then
							local lbl = ensureSlotValueLabel(slotBtn)
							local slotText = formatInvVal(matched.price)
							if invValLastSlotText[slotBtn] ~= slotText then
								lbl.Text = slotText
								invValLastSlotText[slotBtn] = slotText
							end
							lbl.Visible = true
						else
							removeSlotValueLabel(slotBtn)
							invValLastSlotText[slotBtn] = nil
						end
					else
						removeSlotValueLabel(slotBtn)
						invValLastSlotText[slotBtn] = nil
					end
				end
			end
		end
		processContainer(backpack:FindFirstChild("Hotbar"))
		local inv = backpack:FindFirstChild("Inventory")
		if inv then
			local scroll = inv:FindFirstChild("ScrollingFrame")
			processContainer(scroll and scroll:FindFirstChild("UIGridFrame"))
			local totalLbl = ensureInvTotalLabel(inv)
			local totalText = "Total: " .. formatInvVal(totalValue)
			if dailyPrice > 0 then
				local dealAvailable = getDailyDealInfo()
				if dealAvailable then
					totalText = totalText .. " | Daily: " .. formatInvVal(dailyPrice)
				else
					totalText = totalText .. " | Daily: " .. formatInvVal(dailyPrice) .. " (CD)"
				end
			end
			if invValLastTotalText ~= totalText then
				totalLbl.Text = totalText
				invValLastTotalText = totalText
			end
			totalLbl.Visible = true
		end
		for slotBtn in invValLastSlotText do
			if not seenSlots[slotBtn] or not slotBtn.Parent then
				invValLastSlotText[slotBtn] = nil
			end
		end
	end
	function stopInvValCalc()
		invValActive = false
		invValSetupDone = false
		if invValUpdateRun then
			pcall(function() task.cancel(invValUpdateRun) end)
			invValUpdateRun = nil
		end
		invValUpdatePending = false
		invValLastTotalText = ""
		table.clear(invValLastSlotText)
		invValDailyDealCache.at = 0
		for _, conn in invValConns do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(invValConns)
		local bg = localPlayer.PlayerGui:FindFirstChild("BackpackGui")
		if bg then
			cleanInvValLabels(bg:FindFirstChild("Backpack"))
		end
	end
	function startInvValCalc()
		pcall(refreshGameLists)
		if not valCalc then
			local fvc = findModule and findModule("FruitValueCalc")
			if fvc and safeRequire then
				valCalc = safeRequire(fvc)
			end
		end
		ensureInvSellFlags()
		if invValSetupDone then
			scheduleInvValUpdate()
			return
		end
		invValSetupDone = true
		task.spawn(function()
			local bg = localPlayer.PlayerGui:WaitForChild("BackpackGui", 30)
			if not bg or not invValActive then return end
			local backpack = bg:WaitForChild("Backpack", 10)
			if not backpack then return end
			local function hookContainer(container)
				if not container then return end
				table.insert(invValConns, container.ChildAdded:Connect(scheduleInvValUpdate))
				table.insert(invValConns, container.ChildRemoved:Connect(scheduleInvValUpdate))
			end
			hookContainer(backpack:FindFirstChild("Hotbar"))
			local inv = backpack:FindFirstChild("Inventory")
			if inv then
				local scroll = inv:FindFirstChild("ScrollingFrame")
				hookContainer(scroll and scroll:FindFirstChild("UIGridFrame"))
			end
			local bp = localPlayer:WaitForChild("Backpack")
			table.insert(invValConns, bp.ChildAdded:Connect(scheduleInvValUpdate))
			table.insert(invValConns, bp.ChildRemoved:Connect(scheduleInvValUpdate))
			if localPlayer.Character then
				table.insert(invValConns, localPlayer.Character.ChildAdded:Connect(scheduleInvValUpdate))
				table.insert(invValConns, localPlayer.Character.ChildRemoved:Connect(scheduleInvValUpdate))
			end
			table.insert(invValConns, localPlayer.CharacterAdded:Connect(function(char)
				table.insert(invValConns, char.ChildAdded:Connect(scheduleInvValUpdate))
				table.insert(invValConns, char.ChildRemoved:Connect(scheduleInvValUpdate))
				scheduleInvValUpdate()
			end))
			scheduleInvValUpdate()
		end)
	end
	hub:CreateModule("Misc", {
		name = "Inventory Value Calc",
		on = false,
		bind = "None",
		desc = "Show fruit sell prices in inventory.",
		callback = function(enabled)
			invValActive = enabled
			if enabled then
				startInvValCalc()
			else
				stopInvValCalc()
			end
		end,
		opts = {}
	})
end)()
local jobidInput = ""
local rollbackEnabled = false
local rollbackRestoreKbps = 1024
local function setRollbackActive(enabled)
	rollbackEnabled = enabled == true
	local nc = game:GetService("NetworkClient")
	if rollbackEnabled then
		pcall(function()
			nc:SetOutgoingKBPSLimit(0)
		end)
		hub:Notify("Rollback on. Changes after this will not save.")
	else
		pcall(function()
			nc:SetOutgoingKBPSLimit(rollbackRestoreKbps)
		end)
		hub:Notify("Rollback off. Saving is enabled again.")
	end
end
function rejoinServer()
	if rollbackEnabled then
		pcall(function()
			game:GetService("NetworkClient"):SetOutgoingKBPSLimit(0)
		end)
	end
	pcall(function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, localPlayer)
	end)
end
function serverHop()
	local HttpService = game:GetService("HttpService")
	local TeleportService = game:GetService("TeleportService")
	local placeId = game.PlaceId
	if rollbackEnabled then
		pcall(function()
			game:GetService("NetworkClient"):SetOutgoingKBPSLimit(0)
		end)
	end
	local ok, result = pcall(function()
		return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
	end)
	if ok and result and result.data then
		local servers = {}
		for _, server in result.data do
			if server.playing < server.maxPlayers and server.id ~= game.JobId then
				table.insert(servers, server.id)
			end
		end
		if #servers > 0 then
			pcall(function()
				TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)], localPlayer)
			end)
			return
		end
	end
	hub:Notify("No public servers found.")
end
function joinJobId()
	if jobidInput == "" then
		hub:Notify("Enter a Job ID first.")
		return
	end
	if rollbackEnabled then
		pcall(function()
			game:GetService("NetworkClient"):SetOutgoingKBPSLimit(0)
		end)
	end
	pcall(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, jobidInput, localPlayer)
	end)
end
;(function()
	local AuctioneerMod = nil
	local NumberUtilsMod = nil
	local auctionSnapshot = nil
	local auctionLots = {}
	local auctionStock = {}
	local auctionLotByLabel = {}
	local auctionSelectedLotId = nil
	local auctionStatusParagraph = nil
	local auctionLotDropdown = nil
	local auctionAutoBuy = false
	local auctionSnipeMode = false
	local auctionSnipeSeconds = 5
	local auctionMinPrice = 0
	local auctionMaxPrice = 0
	local auctionBuyFilter = ""
	local auctionItemList = {}
	local auctionBuyItemsWidget = nil
	local auctionRarityColors = {
		Common = "rgb(200,200,210)",
		Uncommon = "rgb(100,220,140)",
		Rare = "rgb(100,180,255)",
		Epic = "rgb(180,100,255)",
		Legendary = "rgb(255,200,80)",
		Mythic = "rgb(255,100,100)",
		Secret = "rgb(255,120,200)",
	}
	local function colorToRgb(color)
		if typeof(color) ~= "Color3" then
			return "rgb(255,255,255)"
		end
		return string.format("rgb(%d,%d,%d)", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
	end
	local function getLotRarityColor(lot)
		local rarity = lot.rarity or lot.Rarity or lot.tier
		if typeof(rarity) == "string" and auctionRarityColors[rarity] then
			return auctionRarityColors[rarity]
		end
		local rarityGradients = nil
		pcall(function()
			rarityGradients = require(game:GetService("ReplicatedStorage").SharedModules.RarityData).Gradients
		end)
		if rarityGradients and typeof(rarity) == "string" and rarityGradients[rarity] then
			local gradient = rarityGradients[rarity]
			if typeof(gradient) == "ColorSequence" and gradient.Keypoints[1] then
				return colorToRgb(gradient.Keypoints[1].Value)
			end
		end
		return auctionRarityColors.Rare
	end
	local function getAuctioneer()
		if AuctioneerMod then
			return AuctioneerMod
		end
		pcall(function()
			AuctioneerMod = require(game:GetService("ReplicatedStorage").SharedModules.Auctioneer)
		end)
		return AuctioneerMod
	end
	local function getNumberUtils()
		if NumberUtilsMod then
			return NumberUtilsMod
		end
		pcall(function()
			NumberUtilsMod = require(game:GetService("ReplicatedStorage").SharedModules.NumberUtils)
		end)
		return NumberUtilsMod
	end
	local function auctionServerNow()
		local ok, now = pcall(function()
			return workspace:GetServerTimeNow()
		end)
		return ok and now or os.time()
	end
	local function formatAuctionMoney(amount)
		amount = tonumber(amount) or 0
		local suffix = getCurrencySuffix()
		local nu = getNumberUtils()
		if nu and nu.Abbreviate then
			local ok, text = pcall(nu.Abbreviate, amount)
			if ok and text then
				if text:find("¢") or text:find(suffix, 1, true) then
					return text
				end
				return text .. suffix
			end
		end
		if amount >= 1e6 then
			return string.format("%.2fM%s", amount / 1e6, suffix)
		elseif amount >= 1e3 then
			return string.format("%.2fK%s", amount / 1e3, suffix)
		end
		return tostring(math.floor(amount)) .. suffix
	end
	local function formatAuctionStockCount(count)
		count = tonumber(count) or 0
		local nu = getNumberUtils()
		if nu and nu.FormatWithCommas then
			local ok, text = pcall(nu.FormatWithCommas, math.floor(count))
			if ok and text then
				return "x" .. text
			end
		end
		return "x" .. tostring(math.floor(count))
	end
	local function getLotDisplayName(lot)
		local ae = getAuctioneer()
		if ae and ae.DisplayName then
			local ok, name = pcall(ae.DisplayName, lot)
			if ok and name and name ~= "" then
				return name
			end
		end
		return lot.displayName or lot.item or lot.lotId or "Lot"
	end
	local function getLotPriceKind(lot)
		if lot.robuxOnly or (lot.robuxPrice and not lot.dualCurrency and not lot.startPrice and not lot.guiPrice) then
			return "robux"
		end
		return "currency"
	end
	local function applyAuctionSnapshot(snap)
		if typeof(snap) ~= "table" then
			return false
		end
		auctionSnapshot = snap
		if typeof(snap.stock) == "table" then
			for lotId, count in snap.stock do
				auctionStock[lotId] = count
			end
		end
		table.clear(auctionLots)
		local manifest = snap.manifest
		if typeof(manifest) == "table" and typeof(manifest.lots) == "table" then
			for _, lot in manifest.lots do
				if typeof(lot) == "table" and typeof(lot.lotId) == "string" then
					table.insert(auctionLots, lot)
				end
			end
		end
		return true
	end
	local function parseAuctionPriceText(text)
		if typeof(text) ~= "string" or text == "" then
			return 0
		end
		local cleaned = text:gsub("\194\162", ""):gsub("¢", ""):gsub(",", ""):gsub("%s+", "")
		local numberPart, suffix = cleaned:match("^([%d%.]+)([KMBkmb]?)$")
		local amount = tonumber(numberPart) or 0
		local mult = ({ K = 1e3, M = 1e6, B = 1e9 })[string.upper(suffix or "")] or 1
		return math.floor(amount * mult)
	end
	local function parseAuctionRobuxText(text)
		if typeof(text) ~= "string" or text == "" then
			return 0
		end
		local cleaned = text:gsub("R%$", ""):gsub(",", ""):gsub("%s+", "")
		cleaned = cleaned:gsub("^[%D]+", "")
		return tonumber(cleaned) or 0
	end
	local function getAuctionRowMainFrame(frame)
		local inner = frame:FindFirstChild("Frame")
		if inner then
			return inner:FindFirstChild("Main_Frame")
		end
		return frame:FindFirstChild("Main_Frame")
	end
	local function findAuctionButtonPriceText(button)
		if not button then
			return nil
		end
		local textHolder = button:FindFirstChild("Text")
		local label = textHolder and textHolder:FindFirstChildWhichIsA("TextLabel", true)
		if label and label.Text ~= "" then
			return label.Text
		end
		label = button:FindFirstChildWhichIsA("TextLabel", true)
		if label and label.Text ~= "" then
			return label.Text
		end
		return nil
	end
	local function isAuctionCurrencyPriceText(text)
		if typeof(text) ~= "string" or text == "" then
			return false
		end
		if text:find("R%$", 1, true) or string.lower(text):find("robux", 1, true) then
			return false
		end
		if text:find("¢", 1, true) or text:find("\194\162", 1, true) then
			return true
		end
		return text:match("^%s*[%d%.]+[KMBkmb]?%s*$") ~= nil
	end
	local function getAuctionGuiRow(lotId)
		if typeof(lotId) ~= "string" or lotId == "" then
			return nil
		end
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		local auctionGui = playerGui and playerGui:FindFirstChild("Auction")
		local scroll = auctionGui and auctionGui:FindFirstChild("Frame") and auctionGui.Frame:FindFirstChild("ScrollingFrame")
		if not scroll then
			return nil
		end
		return scroll:FindFirstChild("Lot_" .. lotId)
	end
	local function readAuctionGuiPrices(main)
		if not main then
			return nil, nil
		end
		local buyButton = main:FindFirstChild("BuyButton")
		local robuxButton = main:FindFirstChild("RobuxButton")
		local buyText = findAuctionButtonPriceText(buyButton)
		local robuxText = findAuctionButtonPriceText(robuxButton)
		local robuxVisible = robuxButton and robuxButton.Visible
		local guiPrice = nil
		local robuxPrice = nil
		if buyText and isAuctionCurrencyPriceText(buyText) then
			guiPrice = parseAuctionPriceText(buyText)
		elseif buyText and buyText ~= "" then
			robuxPrice = parseAuctionRobuxText(buyText)
		end
		if robuxVisible and robuxText and robuxText ~= "" then
			robuxPrice = parseAuctionRobuxText(robuxText)
		end
		return guiPrice, robuxPrice
	end
	local function getLiveAuctionPrices(lotId)
		local row = getAuctionGuiRow(lotId)
		if not row then
			return nil, nil
		end
		return readAuctionGuiPrices(getAuctionRowMainFrame(row))
	end
	local function getLotPrice(lot, now)
		if getLotPriceKind(lot) == "robux" then
			if typeof(lot.lotId) == "string" then
				local _, liveRobux = getLiveAuctionPrices(lot.lotId)
				if liveRobux and liveRobux > 0 then
					lot.robuxPrice = liveRobux
					return liveRobux
				end
			end
			return lot.robuxPrice or 0
		end
		if typeof(lot.lotId) == "string" then
			local livePrice = getLiveAuctionPrices(lot.lotId)
			if livePrice and livePrice > 0 then
				lot.guiPrice = livePrice
				return livePrice
			end
		end
		if typeof(lot.guiPrice) == "number" and lot.guiPrice > 0 then
			return lot.guiPrice
		end
		local ae = getAuctioneer()
		if ae and ae.CurrentPrice and typeof(lot.rolledAt) == "number" then
			local ok, price = pcall(ae.CurrentPrice, lot, now)
			if ok and typeof(price) == "number" and price > 0 then
				return price
			end
		end
		return lot.startPrice or 0
	end
	local function formatAuctionLotPrice(lot, now)
		local price = getLotPrice(lot, now)
		if getLotPriceKind(lot) == "robux" then
			return string.format("%d R$", math.floor(price))
		end
		local text = formatAuctionMoney(price)
		local robuxPrice = lot.robuxPrice
		if typeof(lot.lotId) == "string" then
			local _, liveRobux = getLiveAuctionPrices(lot.lotId)
			if liveRobux and liveRobux > 0 then
				robuxPrice = liveRobux
				lot.robuxPrice = liveRobux
			end
		end
		if lot.dualCurrency and typeof(robuxPrice) == "number" and robuxPrice > 0 then
			text = text .. " / " .. string.format("%d R$", math.floor(robuxPrice))
		end
		return text
	end
	local function findAuctionRowName(frame)
		local main = getAuctionRowMainFrame(frame)
		local itemName = main and main:FindFirstChild("ItemName")
		if itemName then
			if itemName:IsA("TextLabel") and itemName.Text ~= "" then
				return itemName.Text
			end
			local nested = itemName:FindFirstChildWhichIsA("TextLabel")
			if nested and nested.Text ~= "" then
				return nested.Text
			end
		end
		for _, desc in frame:GetDescendants() do
			if desc.Name == "ItemName" and desc:IsA("TextLabel") and desc.Text ~= "" then
				return desc.Text
			end
		end
		return nil
	end
	local function parseAuctionMoneyInput(text)
		if typeof(text) ~= "string" then
			return 0
		end
		local trimmed = text:match("^%s*(.-)%s*$")
		if trimmed == "" or trimmed == "0" then
			return 0
		end
		return parseAuctionPriceText(trimmed)
	end
	local function parseAuctionTimerSeconds(text)
		local seconds = tonumber(typeof(text) == "string" and text:match("^%s*(.-)%s*$") or text) or 0
		if seconds < 0 then
			seconds = 0
		elseif seconds > 30 then
			seconds = 30
		end
		return seconds
	end
	local function buildAuctionItemList()
		local set = {}
		local function addName(name)
			if typeof(name) == "string" and name ~= "" then
				set[name] = true
			end
		end
		for _, name in gameLists.gears do
			addName(name)
		end
		for _, name in gameLists.seeds do
			addName(name)
		end
		for _, name in gameLists.crates do
			addName(name)
		end
		for _, name in gameLists.crops do
			addName(name)
		end
		for _, name in gameLists.eventSeeds do
			addName(name)
		end
		pcall(function()
			local packs = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
			packs = packs and packs:FindFirstChild("SeedPacks")
			if packs then
				for _, pack in packs:GetChildren() do
					addName(pack.Name)
				end
			end
		end)
		for _, lot in auctionLots do
			addName(getLotDisplayName(lot))
		end
		table.clear(auctionItemList)
		for name in set do
			table.insert(auctionItemList, name)
		end
		table.sort(auctionItemList)
		if auctionBuyItemsWidget and auctionBuyItemsWidget.SetOptions then
			pcall(function()
				auctionBuyItemsWidget:SetOptions(auctionItemList)
			end)
		end
		return auctionItemList
	end
	local function parseAuctionStockText(text)
		if typeof(text) ~= "string" or text == "" then
			return nil
		end
		local lower = string.lower(text)
		if lower == "sold out" or lower:find("^0 stock") or lower:find("out of stock") then
			return 0
		end
		if lower == "expired" then
			return nil
		end
		local count = text:match("[xX]([%d,]+)")
		if count then
			local cleaned = count:gsub(",", "")
			return tonumber(cleaned)
		end
		return nil
	end
	local function getLiveAuctionStock(lotId)
		if typeof(lotId) ~= "string" or lotId == "" then
			return nil
		end
		local row = getAuctionGuiRow(lotId)
		if not row then
			return nil
		end
		local main = getAuctionRowMainFrame(row)
		local stockLabel = main and main:FindFirstChild("Stock_Text")
		local stockText = stockLabel and stockLabel:IsA("TextLabel") and stockLabel.Text or ""
		return parseAuctionStockText(stockText)
	end
	local function resolveLotStockCount(lot)
		if not lot or typeof(lot.lotId) ~= "string" then
			return lot and lot.stockQuantity or nil
		end
		local liveStock = getLiveAuctionStock(lot.lotId)
		if liveStock ~= nil then
			auctionStock[lot.lotId] = liveStock
			return liveStock
		end
		local stock = auctionStock[lot.lotId]
		if stock == nil and typeof(lot.stockQuantity) == "number" then
			stock = lot.stockQuantity
		end
		return stock
	end
	local function isLotBuyable(lot, now)
		if lot.soldOut == true then
			return false
		end
		if lot.expired == true then
			return false
		end
		local stock = resolveLotStockCount(lot)
		local ae = getAuctioneer()
		if ae and ae.IsActive and typeof(lot.expiresAt) == "number" then
			local ok, active = pcall(ae.IsActive, lot, now, stock)
			if ok then
				return active == true
			end
		end
		if typeof(lot.expiresAt) == "number" and lot.expiresAt <= now then
			return false
		end
		if stock ~= nil and stock <= 0 then
			return false
		end
		return true
	end
	local function getLotStockDisplay(lot, now)
		local stock = resolveLotStockCount(lot)
		if lot.soldOut == true or stock == 0 then
			return "sold out"
		end
		if lot.expired == true or (typeof(lot.expiresAt) == "number" and lot.expiresAt <= now) then
			return "expired"
		end
		if stock ~= nil and stock > 0 then
			return formatAuctionStockCount(stock) .. " in stock"
		end
		if not isLotBuyable(lot, now) then
			return "sold out"
		end
		return "in stock"
	end
	local function readAuctionGuiRow(frame)
		local lotId = frame.Name:match("^Lot_(.+)$")
		if not lotId then
			return nil
		end
		local main = getAuctionRowMainFrame(frame)
		if not main then
			return nil
		end
		local displayName = findAuctionRowName(frame)
		local buyButton = main:FindFirstChild("BuyButton")
		local robuxButton = main:FindFirstChild("RobuxButton")
		local guiPrice, robuxPrice = readAuctionGuiPrices(main)
		local robuxVisible = robuxButton and robuxButton.Visible
		local stockLabel = main:FindFirstChild("Stock_Text")
		local stockText = stockLabel and stockLabel:IsA("TextLabel") and stockLabel.Text or ""
		local outOfStock = main:FindFirstChild("OUT_OF_STOCK")
		local expiredOverlay = main:FindFirstChild("EXPIRED")
		local soldOut = (outOfStock and outOfStock.Visible) or string.lower(stockText) == "sold out"
		local expired = expiredOverlay and expiredOverlay.Visible
		local robuxOnly = false
		local dualCurrency = false
		local buyText = findAuctionButtonPriceText(buyButton)
		if buyText and buyText ~= "" and not isAuctionCurrencyPriceText(buyText) and (not guiPrice or guiPrice <= 0) then
			robuxOnly = true
		end
		if robuxVisible and robuxPrice and robuxPrice > 0 then
			if guiPrice and guiPrice > 0 then
				dualCurrency = true
			elseif not robuxOnly then
				robuxOnly = true
			end
		end
		local stockCount = parseAuctionStockText(stockText)
		if soldOut then
			stockCount = 0
		end
		return {
			lotId = lotId,
			displayName = displayName or lotId,
			item = displayName,
			guiPrice = guiPrice,
			startPrice = guiPrice,
			robuxPrice = robuxPrice,
			robuxOnly = robuxOnly,
			dualCurrency = dualCurrency,
			soldOut = soldOut,
			expired = expired,
			stockQuantity = stockCount,
		}, stockCount
	end
	local function mergeAuctionLot(existing, incoming)
		if not existing then
			return incoming
		end
		for key, value in pairs(incoming) do
			if value ~= nil then
				if key == "startPrice" then
					if typeof(value) == "number" and value > 0 then
						existing[key] = value
					end
				elseif key == "guiPrice" or key == "robuxPrice" then
					if typeof(value) == "number" and value > 0 then
						existing[key] = value
					end
				elseif key == "displayName" or key == "item" then
					if value ~= "" then
						existing[key] = value
					end
				else
					existing[key] = value
				end
			end
		end
		return existing
	end
	local function syncAuctionFromGui()
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		local auctionGui = playerGui and playerGui:FindFirstChild("Auction")
		local scroll = auctionGui and auctionGui:FindFirstChild("Frame") and auctionGui.Frame:FindFirstChild("ScrollingFrame")
		if not scroll then
			return false
		end
		local lotsById = {}
		for _, lot in auctionLots do
			lotsById[lot.lotId] = lot
		end
		local found = 0
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				local lotData, stockCount = readAuctionGuiRow(child)
				if lotData then
					found = found + 1
					local merged = mergeAuctionLot(lotsById[lotData.lotId], lotData)
					lotsById[lotData.lotId] = merged
					if stockCount ~= nil then
						auctionStock[lotData.lotId] = stockCount
					elseif lotData.soldOut then
						auctionStock[lotData.lotId] = 0
					end
				end
			end
		end
		if found == 0 then
			return false
		end
		table.clear(auctionLots)
		for _, lot in lotsById do
			table.insert(auctionLots, lot)
		end
		auctionSnapshot = auctionSnapshot or { source = "gui" }
		auctionSnapshot.stock = auctionStock
		return true
	end
	local function fetchAuctionSnapshotFromGui()
		if not syncAuctionFromGui() then
			return false
		end
		return true
	end
	local auctionSnapshotListenerSetup = false
	local function ensureAuctionListeners()
		if auctionSnapshotListenerSetup then
			return
		end
		local net = getGameNetworking()
		if not net or not net.Auctioneer then
			return
		end
		auctionSnapshotListenerSetup = true
		if net.Auctioneer.Snapshot and net.Auctioneer.Snapshot.OnClientEvent then
			net.Auctioneer.Snapshot.OnClientEvent:Connect(function(snap)
				applyAuctionSnapshot(snap)
			end)
		end
		if net.Auctioneer.StockUpdate and net.Auctioneer.StockUpdate.OnClientEvent then
			net.Auctioneer.StockUpdate.OnClientEvent:Connect(function(update)
				if typeof(update) == "table" and typeof(update.stock) == "table" then
					for lotId, count in update.stock do
						auctionStock[lotId] = count
					end
				end
			end)
		end
	end
	local function fetchAuctionSnapshot()
		ensureAuctionListeners()
		local net = getGameNetworking()
		if net and net.Auctioneer and net.Auctioneer.RequestSnapshot then
			local eventSnap = nil
			local listener = nil
			if net.Auctioneer.Snapshot and net.Auctioneer.Snapshot.OnClientEvent then
				listener = net.Auctioneer.Snapshot.OnClientEvent:Connect(function(snap)
					eventSnap = snap
				end)
			end
			for _ = 1, 3 do
				pcall(function()
					net.Auctioneer.RequestSnapshot:Fire()
				end)
				if eventSnap and applyAuctionSnapshot(eventSnap) then
					if listener then
						listener:Disconnect()
					end
					syncAuctionFromGui()
					return eventSnap
				end
				task.wait(0.25)
			end
			if listener then
				listener:Disconnect()
			end
		end
		if fetchAuctionSnapshotFromGui() then
			return auctionSnapshot
		end
		return nil
	end
	local function buildLotOptions()
		local now = auctionServerNow()
		local labels = {}
		table.clear(auctionLotByLabel)
		for _, lot in auctionLots do
			local stockDisplay = getLotStockDisplay(lot, now)
			local label = string.format("%s — %s — %s", getLotDisplayName(lot), formatAuctionLotPrice(lot, now), stockDisplay)
			labels[#labels + 1] = label
			auctionLotByLabel[label] = lot
		end
		table.sort(labels)
		return labels
	end
	local function formatAuctionListRichText()
		local now = auctionServerNow()
		local lines = { string.format('<font color="rgb(255,255,255)">%d lots</font>', #auctionLots) }
		for _, lot in ipairs(auctionLots) do
			local stockDisplay = getLotStockDisplay(lot, now)
			local lotColor = getLotRarityColor(lot)
			local timeLeft = lot.expiresAt and math.max(0, lot.expiresAt - now) or nil
			local timeText = timeLeft and string.format(" · %ss", string.format("%.1f", timeLeft)) or ""
			lines[#lines + 1] = string.format(
				'<font color="%s">%s</font> — <font color="rgb(255,255,255)">%s</font> — <font color="rgb(255,255,255)">%s</font>%s',
				lotColor,
				getLotDisplayName(lot),
				formatAuctionLotPrice(lot, now),
				stockDisplay,
				timeText
			)
		end
		return table.concat(lines, "\n")
	end
	local auctionStatusRetryCount = 0
	local function updateAuctionStatus()
		if not auctionStatusParagraph then
			auctionStatusRetryCount = auctionStatusRetryCount + 1
			if auctionStatusRetryCount < 20 then
				task.delay(0.25, updateAuctionStatus)
			end
			return
		end
		auctionStatusRetryCount = 0
		local ok, content = pcall(function()
			if #auctionLots == 0 then
				return "No lots found. Open the in-game Auction shop once, then press Refresh."
			end
			return formatAuctionListRichText()
		end)
		if not ok then
			warn("[Auction] Status update failed:", content)
			setHubParagraph(auctionStatusParagraph, "Auction data error. Press Refresh.", "Auction")
			return
		end
		setHubParagraph(auctionStatusParagraph, content, "Auction")
	end
	local function refreshAuctionUi()
		local ok, err = pcall(function()
			fetchAuctionSnapshot()
			syncAuctionFromGui()
			buildAuctionItemList()
			local labels = buildLotOptions()
			if auctionLotDropdown and auctionLotDropdown.SetOptions then
				pcall(function()
					auctionLotDropdown:SetOptions(labels)
				end)
			end
			if labels[1] then
				local lot = auctionLotByLabel[labels[1]]
				auctionSelectedLotId = lot and lot.lotId or nil
			else
				auctionSelectedLotId = nil
			end
		end)
		if not ok then
			warn("[Auction] Refresh failed:", err)
			if auctionStatusParagraph then
				setHubParagraph(auctionStatusParagraph, "Auction refresh failed. Press Refresh again.", "Auction")
			end
			return
		end
		updateAuctionStatus()
	end
	local function findSelectedLot()
		if auctionSelectedLotId then
			for _, lot in auctionLots do
				if lot.lotId == auctionSelectedLotId then
					return lot
				end
			end
		end
		for _, lot in pairs(auctionLotByLabel) do
			return lot
		end
		return nil
	end
	local function buyLot(lot, now)
		if not lot or not isLotBuyable(lot, now) then
			return false
		end
		local net = getGameNetworking()
		if not net or not net.Auctioneer then
			return false
		end
		if getLotPriceKind(lot) == "robux" then
			if not net.Auctioneer.PrepareRobux then
				return false
			end
			pcall(function()
				net.Auctioneer.PrepareRobux:Fire(lot.lotId)
			end)
			return true
		end
		if not net.Auctioneer.PurchaseLot then
			return false
		end
		local price = getLotPrice(lot, now)
		if auctionMinPrice > 0 and price < auctionMinPrice then
			return false
		end
		if auctionMaxPrice > 0 and price > auctionMaxPrice then
			return false
		end
		pcall(function()
			net.Auctioneer.PurchaseLot:Fire(lot.lotId, price)
		end)
		return true
	end
	local function buySelectedLot()
		local lot = findSelectedLot()
		if not lot then
			hub:Notify("No lot selected.")
			return
		end
		local now = auctionServerNow()
		if not isLotBuyable(lot, now) then
			hub:Notify("This lot is sold out.")
			return
		end
		if buyLot(lot, now) then
			hub:Notify(string.format("Buy sent: %s (%s)", getLotDisplayName(lot), formatAuctionLotPrice(lot, now)))
			task.delay(0.6, refreshAuctionUi)
		else
			hub:Notify("Auction remote not found.")
		end
	end
	local function lotMatchesAutoBuy(lot)
		if auctionBuyFilter == "" or auctionBuyFilter == "None" then
			return false
		end
		local label = getLotDisplayName(lot)
		for entry in (auctionBuyFilter .. ","):gmatch("([^,]+),") do
			entry = entry:match("^%s*(.-)%s*$")
			if entry ~= "" and (label == entry or label:find(entry, 1, true)) then
				return true
			end
		end
		return false
	end
	local function runAuctionAutoBuyLoop()
		task.spawn(function()
			while auctionAutoBuy do
				local now = auctionServerNow()
				for _, lot in ipairs(auctionLots) do
					if not auctionAutoBuy then
						break
					end
					if lotMatchesAutoBuy(lot) and isLotBuyable(lot, now) and getLotPriceKind(lot) ~= "robux" then
						local price = getLotPrice(lot, now)
						local withinBudget = (auctionMinPrice <= 0 or price >= auctionMinPrice)
							and (auctionMaxPrice <= 0 or price <= auctionMaxPrice)
						local timeLeft = lot.expiresAt and (lot.expiresAt - now) or math.huge
						local shouldBuy = withinBudget and ((not auctionSnipeMode) or timeLeft <= auctionSnipeSeconds)
						if shouldBuy then
							if buyLot(lot, now) then
								hub:Notify(string.format("Auto buy: %s (%s)", getLotDisplayName(lot), formatAuctionLotPrice(lot, now)))
								task.wait(0.35)
							end
						end
					end
				end
				task.wait(0.1)
			end
		end)
	end
	task.defer(function()
		local net = getGameNetworking()
		if not net or not net.Auctioneer then
			return
		end
		if net.Auctioneer.Snapshot and net.Auctioneer.Snapshot.OnClientEvent then
			net.Auctioneer.Snapshot.OnClientEvent:Connect(function(snap)
				if applyAuctionSnapshot(snap) then
					syncAuctionFromGui()
					buildAuctionItemList()
					local labels = buildLotOptions()
					if auctionLotDropdown and auctionLotDropdown.SetOptions then
						pcall(function()
							auctionLotDropdown:SetOptions(labels)
						end)
					end
					updateAuctionStatus()
				end
			end)
		end
		if net.Auctioneer.StockUpdate and net.Auctioneer.StockUpdate.OnClientEvent then
			net.Auctioneer.StockUpdate.OnClientEvent:Connect(function(update)
				if typeof(update) == "table" and typeof(update.stock) == "table" then
					auctionStock = update.stock
					syncAuctionFromGui()
					updateAuctionStatus()
				end
			end)
		end
		if net.Auctioneer.PurchaseResult and net.Auctioneer.PurchaseResult.OnClientEvent then
			net.Auctioneer.PurchaseResult.OnClientEvent:Connect(function(lotId, success, reason)
				if success then
					hub:Notify("Auction buy success.")
				elseif reason and reason ~= "" then
					hub:Notify("Auction buy failed: " .. tostring(reason))
				end
				task.defer(refreshAuctionUi)
			end)
		end
	end)
	hub:CreateTab("Auction", "rbxassetid://16000149927")
	hub:CreateModule("Auction", {
		name = "Auction Shop",
		notoggle = true,
		on = false,
		bind = "None",
		desc = "View and buy auction lots.",
		callback = function() end,
		opts = {
			{type = "paragraph", title = "Auction", content = "Loading...", onCreate = function(widget)
				auctionStatusParagraph = widget
				enableParagraphRichText(widget)
				pcall(refreshAuctionUi)
			end},
			{type = "button", label = "Refresh Lots", callback = refreshAuctionUi},
			{type = "dropdown", label = "Select Lot", value = nil, list = {}, callback = function(value)
				local lot = auctionLotByLabel[value]
				auctionSelectedLotId = lot and lot.lotId or nil
			end, onCreate = function(widget)
				auctionLotDropdown = widget
			end},
			{type = "button", label = "Buy Selected", callback = buySelectedLot},
		}
	})
	hub:CreateModule("Auction", {
		name = "Auto Buy",
		on = false,
		bind = "None",
		desc = "Auto buy selected auction items within price range.",
		callback = function(enabled)
			auctionAutoBuy = enabled
			if enabled then
				if auctionBuyFilter == "" or auctionBuyFilter == "None" then
					hub:Notify("Select items to buy first.")
					auctionAutoBuy = false
					return
				end
				runAuctionAutoBuyLoop()
			end
		end,
		opts = {
			{type = "textbox", label = "Min Price", value = "0", placeholder = "0 = no minimum (e.g. 500K, 1M)", callback = function(value)
				auctionMinPrice = parseAuctionMoneyInput(value or "0")
			end},
			{type = "textbox", label = "Max Price", value = "0", placeholder = "0 = no maximum (e.g. 2M, 5M)", callback = function(value)
				auctionMaxPrice = parseAuctionMoneyInput(value or "0")
			end},
			{type = "multiselect", label = "What To Buy", value = "None", list = auctionItemList, callback = function(value)
				auctionBuyFilter = value or ""
			end, onCreate = function(widget)
				auctionBuyItemsWidget = widget
				pcall(refreshGameLists)
				buildAuctionItemList()
				if widget.SetOptions then
					pcall(function()
						widget:SetOptions(auctionItemList)
					end)
				end
			end},
			{type = "paragraph", title = "Lowest Price", content = "Auction price drops while the lot timer runs. Enable wait mode to buy near the end instead of immediately."},
			{type = "checkbox", label = "Wait For Lowest Price", value = false, callback = function(value)
				auctionSnipeMode = value
			end},
			{type = "textbox", label = "Lot Timer Left (seconds)", value = "5", numberOnly = true, placeholder = "Seconds left on lot timer (0-30). 0 = buy when timer hits zero.", callback = function(value)
				auctionSnipeSeconds = parseAuctionTimerSeconds(value or "5")
			end},
		}
	})
	table.insert(hubStore.paragraphBootstraps, refreshAuctionUi)
end)()
hub:CreateModule("Misc", {
	name = "Rollback",
	on = false,
	bind = "None",
	desc = "Block saves after enable. Rejoin to restore old progress.",
	callback = function(enabled)
		setRollbackActive(enabled)
	end,
	opts = {
		{type = "button", label = "Rejoin Now", callback = rejoinServer},
	}
})
local function buildPetsFinderTab(parentFrame)
	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(1, -20, 1, -20)
	msg.Position = UDim2.new(0, 10, 0, 10)
	msg.BackgroundTransparency = 1
	msg.Text = "These features are temporarily removed."
	msg.TextColor3 = Color3.fromRGB(180, 180, 190)
	msg.TextSize = 14
	msg.Font = Enum.Font.MontserratBold
	msg.TextWrapped = true
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextYAlignment = Enum.TextYAlignment.Top
	msg.Parent = parentFrame
end
hub:CreateTab("Pet Finder", "rbxassetid://13001190533", buildPetsFinderTab)
hub:CreateModule("Pet Finder", {
	name = "Wild Pets Scanner",
	notoggle = true,
	on = false,
	bind = "None",
	desc = "Temporarily removed.",
	callback = function() end,
	opts = {}
})
hub:CreateModule("Settings", {
	name = "Worlds",
	notoggle = true,
	on = false,
	bind = "None",
	callback = function() end,
	opts = {
		{type = "paragraph", title = "Current World", content = getWorldDisplayName() .. " · " .. getCurrencyName() .. " (" .. getCurrencySuffix() .. ")"},
		{type = "button", label = "Teleport to Garden Valley", callback = function()
			teleportToWorld("Main")
		end},
		{type = "button", label = "Teleport to Fall Harvest", callback = function()
			teleportToWorld("FallHarvest")
		end},
	}
})
hub:CreateModule("Settings", {
	name = "Server Utilities",
	notoggle = true,
	on = false,
	bind = "None",
	desc = "Rejoin or hop servers.",
	callback = function() end,
	opts = {
		{type = "button", label = "Rejoin Current Server", callback = function()
			rejoinServer()
		end},
		{type = "button", label = "Hop to Public Server", callback = function()
			serverHop()
		end},
		{type = "textbox", label = "Connect to Job ID", value = "", placeholder = "Enter Job ID...", callback = function(val)
			jobidInput = val
		end},
		{type = "button", label = "Connect by Job ID", callback = function()
			joinJobId()
		end}
	}
})
;(function()
	local infoParagraph = nil
	local infoThread = nil
	local cachedFps = 60
	local fpsAccum, fpsFrames = 0, 0
	RS.RenderStepped:Connect(function(dt)
		fpsAccum = fpsAccum + dt
		fpsFrames = fpsFrames + 1
		if fpsAccum >= 0.5 then
			cachedFps = math.floor(fpsFrames / fpsAccum)
			fpsAccum, fpsFrames = 0, 0
		end
	end)

	local function formatInfoMoney(n)
		n = tonumber(n) or 0
		if n >= 1000000000 then
			return string.format("%.2fB", n / 1000000000)
		elseif n >= 1000000 then
			return string.format("%.2fM", n / 1000000)
		elseif n >= 1000 then
			return string.format("%.2fK", n / 1000)
		end
		return tostring(math.floor(n))
	end

	local function formatFruitStat(entry)
		if not entry then
			return "None"
		end
		return string.format("%s · %.2fkg · %s", entry.seedName, entry.weight, formatCurrencyAmount(entry.price, true))
	end

	local function getWalletBalanceText()
		return tostring(getPlayerCurrency())
	end

	local function buildInfoText()
		local ping = 0
		pcall(function()
			ping = math.floor(localPlayer:GetNetworkPing() * 1000 + 0.5)
		end)
		local timeLabel, timeColor = getTimeOfDayInfo()
		local serverBestPrice, serverBestWeight = nil, nil
		pcall(function()
			serverBestPrice, serverBestWeight = scanServerFruitStats(true)
		end)
		local myBestPrice, myBestWeight = nil, nil
		pcall(function()
			local farm = getPlayerFarm()
			if farm then
				myBestPrice, myBestWeight = scanGardenFruitStats(farm, true)
			end
		end)
		local session = formatSessionTime(os.clock() - scriptSessionStart)
		local serverAge = formatSessionTime(workspace.DistributedGameTime)
		return table.concat({
			string.format('<font color="rgb(255,255,255)">Username:</font> %s', predictWhite(localPlayer.Name)),
			string.format('<font color="rgb(200,200,210)">Display:</font> %s', predictWhite(localPlayer.DisplayName)),
			string.format('<font color="rgb(120,200,255)">World:</font> %s', predictWhite(getWorldDisplayName())),
			string.format('<font color="rgb(255,220,90)">%s:</font> %s', getCurrencyName(), predictWhite(getWalletBalanceText())),
			string.format('<font color="rgb(120,200,255)">FPS:</font> %s   <font color="rgb(120,200,255)">Ping:</font> %s', predictWhite(cachedFps), predictWhite(ping .. "ms")),
			string.format('<font color="rgb(200,200,210)">Account Age:</font> %s', predictWhite(string.format("%d days", localPlayer.AccountAge or 0))),
			string.format('<font color="rgb(200,200,210)">Job ID:</font> %s', predictWhite(game.JobId)),
			string.format('<font color="rgb(200,200,210)">Server Age:</font> %s', predictWhite(serverAge)),
			string.format('<font color="rgb(200,200,210)">Session:</font> %s', predictWhite(session)),
			string.format('<font color="%s">Time:</font> %s', timeColor, predictWhite(timeLabel)),
			"",
			string.format('<font color="rgb(110,255,140)">Best Fruit In Server:</font> %s', predictWhite(formatFruitStat(serverBestPrice))),
			string.format('<font color="rgb(255,200,120)">Biggest Fruit In Server:</font> %s', predictWhite(formatFruitStat(serverBestWeight))),
			string.format('<font color="rgb(110,255,140)">Best Fruit In Your Garden:</font> %s', predictWhite(formatFruitStat(myBestPrice))),
			string.format('<font color="rgb(255,200,120)">Biggest Fruit In Your Garden:</font> %s', predictWhite(formatFruitStat(myBestWeight))),
			"",
			'<font color="rgb(140,140,150)">Executor:</font> ' .. predictWhite(executor),
		}, "\n")
	end

	local function refreshInfoParagraph()
		if not infoParagraph then
			return
		end
		local ok, textOrErr = pcall(buildInfoText)
		if ok then
			setHubParagraph(infoParagraph, textOrErr, "Live Info")
		else
			setHubParagraph(infoParagraph, "Error loading info:\n" .. tostring(textOrErr), "Live Info")
		end
	end

	local function startInfoLoop()
		if infoThread then
			return
		end
		infoThread = task.spawn(function()
			while infoParagraph do
				refreshInfoParagraph()
				task.wait(1)
			end
			infoThread = nil
		end)
	end

	hub:CreateModule("Settings", {
		name = "Info",
		notoggle = true,
		on = false,
		bind = "None",
		desc = "Account and server info.",
		callback = function() end,
		opts = {
			{type = "paragraph", title = "Live Info", content = "Loading...", onCreate = function(widget)
				infoParagraph = widget
				enableParagraphRichText(widget)
			end},
		}
	})
	table.insert(hubStore.paragraphBootstraps, function()
		refreshInfoParagraph()
		startInfoLoop()
	end)
end)()
;(function()
	local hideForeignPlants = false
	local hiddenPlantState = {}
	local hidePlantConnections = {}

	local function isMyGardenPlot(plot)
		local farm = getPlayerFarm()
		return farm ~= nil and plot == farm
	end

	local function rememberPartState(part)
		if hiddenPlantState[part] then
			return
		end
		hiddenPlantState[part] = {
			localTransparencyModifier = part.LocalTransparencyModifier,
			canCollide = part.CanCollide,
			castShadow = part.CastShadow,
		}
	end

	local function hideDescendant(inst)
		if inst:IsA("BasePart") then
			rememberPartState(inst)
			inst.LocalTransparencyModifier = 1
			inst.CanCollide = false
			inst.CastShadow = false
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			if not hiddenPlantState[inst] then
				hiddenPlantState[inst] = {transparency = inst.Transparency}
			end
			inst.Transparency = 1
		elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") then
			if not hiddenPlantState[inst] then
				hiddenPlantState[inst] = {enabled = inst.Enabled}
			end
			inst.Enabled = false
		elseif inst:IsA("ProximityPrompt") then
			if not hiddenPlantState[inst] then
				hiddenPlantState[inst] = {enabled = inst.Enabled}
			end
			inst.Enabled = false
		end
	end

	local function hidePlantModel(plant)
		for _, desc in plant:GetDescendants() do
			hideDescendant(desc)
		end
		hideDescendant(plant)
	end

	local function restoreHidden(inst)
		local state = hiddenPlantState[inst]
		if not state or not inst.Parent then
			hiddenPlantState[inst] = nil
			return
		end
		if inst:IsA("BasePart") then
			inst.LocalTransparencyModifier = state.localTransparencyModifier or 0
			inst.CanCollide = state.canCollide ~= false
			if state.castShadow ~= nil then
				inst.CastShadow = state.castShadow
			end
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			inst.Transparency = state.transparency or 0
		elseif inst:IsA("BillboardGui") or inst:IsA("SurfaceGui") or inst:IsA("ProximityPrompt") then
			inst.Enabled = state.enabled ~= false
		end
		hiddenPlantState[inst] = nil
	end

	local function restoreAllHiddenPlants()
		for inst in hiddenPlantState do
			restoreHidden(inst)
		end
		table.clear(hiddenPlantState)
	end

	local function hidePlotPlants(plot)
		if isMyGardenPlot(plot) then
			return
		end
		local plants = plot:FindFirstChild("Plants")
		if not plants then
			return
		end
		local count = 0
		for _, plant in plants:GetChildren() do
			if not hideForeignPlants then
				return
			end
			hidePlantModel(plant)
			count = count + 1
			if count % 30 == 0 then
				task.wait()
			end
		end
	end

	local function hideAllForeignPlants()
		task.spawn(function()
			local gardens = workspace:FindFirstChild("Gardens")
			if not gardens then
				return
			end
			for _, plot in gardens:GetChildren() do
				if hideForeignPlants then
					hidePlotPlants(plot)
				end
			end
		end)
	end

	local function bindPlotListeners(plot)
		if hidePlantConnections[plot] then
			return
		end
		local plants = plot:FindFirstChild("Plants")
		if not plants then
			return
		end
		hidePlantConnections[plot] = plants.ChildAdded:Connect(function(plant)
			if hideForeignPlants and not isMyGardenPlot(plot) then
				task.defer(function()
					if hideForeignPlants then
						hidePlantModel(plant)
					end
				end)
			end
		end)
	end

	local function connectHideForeignPlants()
		local gardens = workspace:FindFirstChild("Gardens")
		if not gardens then
			return
		end
		if not hidePlantConnections._gardens then
			hidePlantConnections._gardens = gardens.ChildAdded:Connect(function(plot)
				if hideForeignPlants then
					task.defer(function()
						hidePlotPlants(plot)
						bindPlotListeners(plot)
					end)
				end
			end)
		end
		for _, plot in gardens:GetChildren() do
			bindPlotListeners(plot)
		end
	end

	local function disconnectHideForeignPlants()
		for key, conn in hidePlantConnections do
			if conn and conn.Connected then
				conn:Disconnect()
			end
			hidePlantConnections[key] = nil
		end
	end

	local function setHideForeignPlants(enabled)
		hideForeignPlants = enabled
		if enabled then
			connectHideForeignPlants()
			hideAllForeignPlants()
		else
			disconnectHideForeignPlants()
			restoreAllHiddenPlants()
		end
	end

	local screenCover = nil
	local whiteScreen = false
	local blackScreen = false
	local origDecals = {}
	local origEffects = {}
	local function updateScreenCover()
		if screenCover then
			screenCover:Destroy()
			screenCover = nil
		end
		local runService = game:GetService("RunService")
		local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if whiteScreen or blackScreen then
			screenCover = Instance.new("ScreenGui")
			screenCover.Name = "PerformanceCover"
			screenCover.DisplayOrder = -99999
			screenCover.IgnoreGuiInset = true
			screenCover.Parent = playerGui
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 1, 0)
			frame.BackgroundColor3 = whiteScreen and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
			frame.BorderSizePixel = 0
			frame.Active = true
			frame.Parent = screenCover
			if runService.Set3dRenderingEnabled then
				pcall(function() runService:Set3dRenderingEnabled(false) end)
			end
		else
			if runService.Set3dRenderingEnabled then
				pcall(function() runService:Set3dRenderingEnabled(true) end)
			end
		end
	end
	local origFog = {}
	hub:CreateModule("Settings", {
		name = "Performance",
		notoggle = true,
		on = false,
		bind = "None",
		desc = "FPS boost.",
		callback = function() end,
		opts = {
			{type = "toggle", label = "Hide Other Gardens", value = false, callback = function(val)
				setHideForeignPlants(val)
			end},
			{type = "toggle", label = "No Fog", value = false, callback = function(val)
				if val then
					origFog.FogEnd = game:GetService("Lighting").FogEnd
					origFog.FogStart = game:GetService("Lighting").FogStart
					game:GetService("Lighting").FogEnd = 999999
					game:GetService("Lighting").FogStart = 999998
					local atm = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
					if atm then
						origFog.Density = atm.Density
						atm.Density = 0
					end
				else
					if origFog.FogEnd then
						game:GetService("Lighting").FogEnd = origFog.FogEnd
						game:GetService("Lighting").FogStart = origFog.FogStart
					end
					local atm = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
					if atm and origFog.Density then
						atm.Density = origFog.Density
					end
				end
			end},
			{type = "toggle", label = "Boost FPS", value = false, callback = function(val)
				if val then
					table.clear(origDecals)
					local count = 0
					for _, v in workspace:GetDescendants() do
						if v:IsA("Decal") or v:IsA("Texture") then
							local ok, err = pcall(function()
								origDecals[v] = v.Transparency
								v.Transparency = 1
							end)
							if ok then count = count + 1 end
						end
					end
					pcall(function()
						originalQuality = settings().Rendering.QualityLevel
						settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
					end)
				else
					local count = 0
					local errors = 0
					for v, trans in pairs(origDecals) do
						local ok, err = pcall(function()
							if v and v.Parent then
								v.Transparency = trans
								count = count + 1
							end
						end)
						if not ok then errors = errors + 1 end
					end
					table.clear(origDecals)
					pcall(function()
						if originalQuality then
							settings().Rendering.QualityLevel = originalQuality
						else
							settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
						end
					end)
				end
			end},
			{type = "toggle", label = "Low Graphic", value = false, callback = function(val)
				if val then
					table.clear(origEffects)
					local count = 0
					for _, v in workspace:GetDescendants() do
						if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("PostEffect") then
							local ok, err = pcall(function()
								origEffects[v] = v.Enabled
								v.Enabled = false
							end)
							if ok then count = count + 1 end
						end
					end
				else
					local count = 0
					local errors = 0
					for v, enabled in pairs(origEffects) do
						local ok, err = pcall(function()
							if v and v.Parent then
								v.Enabled = enabled
								count = count + 1
							end
						end)
						if not ok then errors = errors + 1 end
					end
					table.clear(origEffects)
				end
			end},
			{type = "toggle", label = "Unlock FPS", value = false, callback = function(val)
				local setfps = setfpscap or (syn and syn.set_fps_cap)
				if setfps then
					pcall(setfps, val and 999 or 60)
				end
			end},
			{type = "toggle", label = "White Screen", value = false, callback = function(val)
				whiteScreen = val
				if val and blackScreen then
					blackScreen = false
				end
				updateScreenCover()
			end},
			{type = "toggle", label = "Black Screen", value = false, callback = function(val)
				blackScreen = val
				if val and whiteScreen then
					whiteScreen = false
				end
				updateScreenCover()
			end}
		}
	})
end)()
;(function()
	local HttpService = game:GetService("HttpService")
	local webhookUrls = {}
	local webhookUrlParagraph = nil
	local webhookGardenEnabled = false
	local webhookGardenMinWeight = 0
	local webhookGardenMaxWeight = 0
	local webhookGardenMinPrice = 0
	local webhookGardenMaxPrice = 0
	local webhookGardenMutations = ""
	local webhookGardenFruits = ""
	local webhookGardenFruitType = "Whitelist"
	local webhookGardenMutationType = "Whitelist"
	local webhookMoonEnabled = false
	local webhookPhaseEnabled = false
	local webhookStockSeeds = false
	local webhookStockGears = false
	local webhookStockCrates = false
	local webhookStockFilter = ""
	local webhookStockFilterType = "Whitelist"
	local webhookPetsEnabled = false
	local webhookPetFilter = ""
	local webhookPetFilterType = "Whitelist"
	local webhookPetRarities = ""
	local webhookPetRarityType = "Whitelist"
	local webhookPetMutations = ""
	local webhookPetMutationType = "Whitelist"
	local webhookStealEnabled = false
	local webhookWeatherEnabled = false
	local webhookState = {
		garden = {},
		stock = {},
		pets = {},
		weather = {},
		moonPhase = nil,
		moonName = nil,
	}
	local webhookThread = nil
	local webhookBootstrapped = false

	local function parseWebhookMoneyInput(text)
		if typeof(text) ~= "string" then
			return 0
		end
		local trimmed = text:match("^%s*(.-)%s*$")
		if trimmed == "" or trimmed == "0" then
			return 0
		end
		local cleaned = trimmed:gsub("\194\162", ""):gsub("¢", ""):gsub(",", ""):gsub("%s+", "")
		local numberPart, suffix = cleaned:match("^([%d%.]+)([KMBkmb]?)$")
		local amount = tonumber(numberPart) or 0
		local mult = ({ K = 1e3, M = 1e6, B = 1e9 })[string.upper(suffix or "")] or 1
		return math.floor(amount * mult)
	end

	local function maskWebhookUrl(url)
		local id, token = url:match("^https://discord%.com/api/webhooks/(%d+)/([%w_-]+)$")
		if not id or not token then
			return url
		end
		if #token <= 8 then
			return string.format("https://discord.com/api/webhooks/%s/%s", id, token)
		end
		return string.format("https://discord.com/api/webhooks/%s/%s...%s", id, token:sub(1, 4), token:sub(-4))
	end

	local WEBHOOK_HUB_NAME = "Casual Hub"

	local function getWebhookTimestamp()
		local ok, timestamp = pcall(function()
			return DateTime.now():ToIsoDate()
		end)
		if ok and timestamp then
			return timestamp
		end
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end

	local function getWebhookFooterText()
		local worldName = "Unknown"
		pcall(function()
			worldName = getWorldDisplayName()
		end)
		return WEBHOOK_HUB_NAME .. " · " .. worldName .. " · " .. localPlayer.Name
	end

	local function resolveHttpRequest()
		if typeof(http_request) == "function" then
			return http_request
		end
		if typeof(request) == "function" then
			return request
		end
		if typeof(HttpPost) == "function" then
			return function(options)
				local url = options.Url or options.url
				local body = options.Body or options.body
				local method = options.Method or options.method or "POST"
				local headers = options.Headers or options.headers
				return HttpPost(url, body, method, headers)
			end
		end
		if syn and typeof(syn.request) == "function" then
			return syn.request
		end
		if http and typeof(http.request) == "function" then
			return http.request
		end
		return nil
	end

	local function normalizeDiscordWebhookUrl(url)
		if typeof(url) ~= "string" then
			return nil
		end
		local trimmed = url:match("^%s*(.-)%s*$")
		trimmed = trimmed:gsub("/+$", "")
		trimmed = trimmed:gsub("discordapp%.com", "discord.com")
		trimmed = trimmed:gsub("^https://www%.", "https://")
		if trimmed:match("^https://discord%.com/api/webhooks/%d+/[%w_-]+$") then
			return trimmed
		end
		return nil
	end

	local function isValidDiscordWebhook(url)
		return normalizeDiscordWebhookUrl(url) ~= nil
	end

	local function webhookRequestSucceeded(response)
		if response == false then
			return false
		end
		if response == nil then
			return true
		end
		if typeof(response) ~= "table" then
			return true
		end
		if response.Success == false then
			return false
		end
		local status = response.StatusCode or response.status_code or response.Status or response.status
		if status and (status < 200 or status >= 300) then
			return false
		end
		return true
	end

	local function tryWebhookHttpRequest(requestFn, url, body)
		local headers = { ["content-type"] = "application/json" }
		local ok, response = pcall(requestFn, {
			Url = url,
			Body = body,
			Method = "POST",
			Headers = headers,
		})
		return ok and webhookRequestSucceeded(response)
	end

	local function tryWebhookPostAsync(url, body)
		return pcall(function()
			HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
		end)
	end

	local function postDiscordWebhook(url, payload)
		local normalizedUrl = normalizeDiscordWebhookUrl(url)
		if not normalizedUrl then
			return false
		end
		local body = HttpService:JSONEncode(payload)
		local requestFn = resolveHttpRequest()
		if requestFn then
			if tryWebhookHttpRequest(requestFn, normalizedUrl, body) then
				return true
			end
			local proxyUrl = normalizedUrl:gsub("discord%.com", "webhook.lewisakura.dev")
			if tryWebhookHttpRequest(requestFn, proxyUrl, body) then
				return true
			end
		end
		if tryWebhookPostAsync(normalizedUrl, body) then
			return true
		end
		local proxyUrl = normalizedUrl:gsub("discord%.com", "webhook.lewisakura.dev")
		return tryWebhookPostAsync(proxyUrl, body)
	end

	local function buildWebhookPayload(title, description, color)
		return {
			username = WEBHOOK_HUB_NAME,
			embeds = {
				{
					title = tostring(title or "Notification"),
					description = tostring(description or ""),
					color = color or 3553599,
					footer = {
						text = getWebhookFooterText(),
					},
					timestamp = getWebhookTimestamp(),
				},
			},
		}
	end

	local function sendWebhookPayload(payload, forceSend)
		if #webhookUrls == 0 then
			return 0, 0, "No webhooks saved"
		end
		if not forceSend and not webhookMonitoringActive() then
			return 0, 0, "No alerts enabled"
		end
		local sent, failed = 0, 0
		for _, url in ipairs(webhookUrls) do
			local ok = postDiscordWebhook(url, payload)
			if ok then
				sent = sent + 1
			else
				failed = failed + 1
			end
		end
		return sent, failed
	end

	local function formatWebhookUrlList()
		if #webhookUrls == 0 then
			return "No webhooks saved.\nPaste a Discord webhook URL below to add one."
		end
		local lines = { string.format("Saved webhooks (%d):", #webhookUrls) }
		for index, url in ipairs(webhookUrls) do
			lines[#lines + 1] = string.format("%d. %s", index, maskWebhookUrl(url))
		end
		return table.concat(lines, "\n")
	end

	local function refreshWebhookUrlParagraph()
		if webhookUrlParagraph then
			setHubParagraph(webhookUrlParagraph, formatWebhookUrlList(), "Saved Webhooks")
		end
	end

	local function broadcastWebhook(title, description, color, forceSend)
		local ok, payload = pcall(buildWebhookPayload, title, description, color)
		if not ok or not payload then
			return 0, 1
		end
		if forceSend then
			return sendWebhookPayload(payload, true)
		end
		task.spawn(function()
			sendWebhookPayload(payload, false)
		end)
	end

	local function bootstrapWebhookState()
		if webhookBootstrapped then
			return
		end
		webhookBootstrapped = true
		local stockValues = game:GetService("ReplicatedStorage"):FindFirstChild("StockValues")
		if stockValues then
			for _, shopName in { "SeedShop", "GearShop", "CrateShop" } do
				local itemsFolder = stockValues:FindFirstChild(shopName) and stockValues[shopName]:FindFirstChild("Items")
				if itemsFolder then
					for _, itemVal in itemsFolder:GetChildren() do
						webhookState.stock[shopName .. ":" .. itemVal.Name] = tonumber(itemVal.Value) or 0
					end
				end
			end
		end
		local spawnsFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WildPetSpawns")
		if spawnsFolder then
			for _, model in spawnsFolder:GetChildren() do
				if model:IsA("Model") then
					webhookState.pets[model] = true
				end
			end
		end
		local weatherValues = game:GetService("ReplicatedStorage"):FindFirstChild("WeatherValues")
		if weatherValues then
			for weatherName in pairs(predictWeatherMeta) do
				webhookState.weather[weatherName] = weatherValues:GetAttribute(weatherName .. "_Playing") == true
			end
		end
		if ensurePredictModules() then
			local now = getPredictServerNow()
			local _, phaseName = getPredictCycleInfo(now)
			webhookState.moonPhase = phaseName
			local moonName = workspace:GetAttribute("ActiveWeather")
			if typeof(moonName) ~= "string" or moonName == "" then
				local cycleId = select(1, getPredictCycleInfo(now))
				moonName = predictNightMoon(cycleId)
			end
			webhookState.moonName = moonName
		end
	end

	local function csvToSet(csv)
		local set = {}
		if typeof(csv) ~= "string" or csv == "" or csv == "None" then
			return set
		end
		for entry in (csv .. ","):gmatch("([^,]+),") do
			local name = entry:match("^%s*(.-)%s*$")
			if name ~= "" then
				set[name] = true
			end
		end
		return set
	end

	local function webhookCsvIsEmpty(csv)
		return typeof(csv) ~= "string" or csv == "" or csv == "None"
	end

	local function webhookMatchesNameList(value, listCsv, filterType, normalizeFn)
		normalizeFn = normalizeFn or function(v)
			return v
		end
		local normalizedValue = normalizeFn(value)
		if webhookCsvIsEmpty(listCsv) then
			return filterType ~= "Whitelist"
		end
		local matched = false
		for entry in (listCsv .. ","):gmatch("([^,]+),") do
			local name = entry:match("^%s*(.-)%s*$")
			if name ~= "" and normalizeFn(name) == normalizedValue then
				matched = true
				break
			end
		end
		if filterType == "Whitelist" then
			return matched
		end
		return not matched
	end

	local function webhookMatchesMutationList(mutation, listCsv, filterType)
		mutation = mutation or "None"
		if mutation == "" then
			mutation = "None"
		end
		if webhookCsvIsEmpty(listCsv) then
			return true
		end
		return webhookMatchesNameList(mutation, listCsv, filterType)
	end

	local function normalizeGardenCropName(name)
		if typeof(name) ~= "string" or name == "" then
			return ""
		end
		if displayCropMap[name] then
			return displayCropMap[name]
		end
		local lower = name:lower()
		if displayCropMap[lower] then
			return displayCropMap[lower]
		end
		return getcropname(name) or name
	end

	local function resetGardenWebhookState()
		table.clear(webhookState.garden)
	end

	local function resetPetWebhookState()
		table.clear(webhookState.pets)
	end

	local function normalizePetFilterName(name)
		if typeof(name) ~= "string" or name == "" then
			return ""
		end
		local info = getPetInfo(name)
		if info and typeof(info.AssetName) == "string" and info.AssetName ~= "" then
			return info.AssetName
		end
		return name
	end

	local function gardenFruitMatchesFilters(fruit)
		local cropName = normalizeGardenCropName(fruit.seedName)
		if not webhookMatchesNameList(cropName, webhookGardenFruits, webhookGardenFruitType, normalizeGardenCropName) then
			return false
		end
		if webhookGardenMinWeight > 0 and fruit.weight < webhookGardenMinWeight then
			return false
		end
		if webhookGardenMaxWeight > 0 and fruit.weight > webhookGardenMaxWeight then
			return false
		end
		if webhookGardenMinPrice > 0 and fruit.price < webhookGardenMinPrice then
			return false
		end
		if webhookGardenMaxPrice > 0 and fruit.price > webhookGardenMaxPrice then
			return false
		end
		if not webhookMatchesMutationList(fruit.mutation, webhookGardenMutations, webhookGardenMutationType) then
			return false
		end
		return true
	end

	local function stockItemMatchesFilter(itemName)
		return webhookMatchesNameList(itemName, webhookStockFilter, webhookStockFilterType)
	end

	local function getWildPetSpawnInfo(model)
		local petName = model:GetAttribute("PetName") or model.Name
		local cleanName = petName:gsub("^WildPet_[^_]+_", "")
		local petSize = model:GetAttribute("PetSize") or model:GetAttribute("Size") or "Normal"
		local petType = model:GetAttribute("PetType") or model:GetAttribute("Type") or model:GetAttribute("Variant") or "Normal"
		local mutation = model:GetAttribute("Mutation")
		if not mutation or mutation == "" or mutation == "None" then
			if petType ~= "Normal" and petType ~= "" then
				mutation = petType
			elseif petSize ~= "Normal" and petSize ~= "" then
				mutation = petSize
			else
				mutation = "None"
			end
		end
		local info = getPetInfo(cleanName)
		local rarity = info and info.Rarity or "Unknown"
		return cleanName, rarity, mutation, petSize, petType
	end

	local function petVariationMatches(mutation, petSize, petType, listCsv, filterType)
		if webhookCsvIsEmpty(listCsv) then
			return true
		end
		local mutSet = csvToSet(listCsv)
		local isMatch = mutSet[mutation] == true
		if not isMatch and petSize and mutSet[petSize] then
			isMatch = true
		end
		if not isMatch and petType and mutSet[petType] then
			isMatch = true
		end
		if mutSet["None"] and (mutation == "None" or mutation == "Normal")
			and (petSize == "Normal" or petSize == "")
			and (petType == "Normal" or petType == "") then
			isMatch = true
		end
		if filterType == "Whitelist" then
			return isMatch
		end
		return not isMatch
	end

	local function petWebhookMatchesFilters(cleanName, rarity, mutation, petSize, petType)
		local petName = normalizePetFilterName(cleanName)
		if not webhookMatchesNameList(petName, webhookPetFilter, webhookPetFilterType, normalizePetFilterName) then
			return false
		end
		if not webhookMatchesNameList(rarity, webhookPetRarities, webhookPetRarityType) then
			return false
		end
		if not petVariationMatches(mutation, petSize, petType, webhookPetMutations, webhookPetMutationType) then
			return false
		end
		return true
	end

	local function checkGardenWebhooks()
		if not webhookGardenEnabled then
			return
		end
		for _, fruit in enumerateMyGardenFruits(true) do
			if gardenFruitMatchesFilters(fruit) and not webhookState.garden[fruit.key] then
				webhookState.garden[fruit.key] = true
				broadcastWebhook(
					"Garden Fruit",
					table.concat({
						"Crop: " .. fruit.seedName,
						"Weight: " .. string.format("%.2f kg", fruit.weight),
						"Value: " .. formatCurrencyAmount(fruit.price, true),
						"Mutation: " .. fruit.mutation,
					}, "\n"),
					5763719
				)
			end
		end
	end

	local function checkMoonWebhooks()
		if (not webhookMoonEnabled and not webhookPhaseEnabled) or not ensurePredictModules() then
			return
		end
		local now = getPredictServerNow()
		local cycleId, phaseName = getPredictCycleInfo(now)
		local moonName = workspace:GetAttribute("ActiveWeather")
		if typeof(moonName) ~= "string" or moonName == "" then
			moonName = predictNightMoon(cycleId)
		end
		local phaseChanged = webhookState.moonPhase ~= nil and webhookState.moonPhase ~= phaseName
		local moonChanged = webhookState.moonName ~= nil and webhookState.moonName ~= moonName
		local wasKnown = webhookState.moonPhase ~= nil
		if phaseChanged and webhookPhaseEnabled and wasKnown then
			broadcastWebhook(
				"Phase Change",
				table.concat({
					"New phase: " .. phaseName,
					"Server time: " .. formatPredictClock(now),
				}, "\n"),
				9807270
			)
		end
		if wasKnown and phaseName == "Night" and (phaseChanged or moonChanged) and webhookMoonEnabled and moonName and moonName ~= "" then
			broadcastWebhook(
				"Moon Event",
				table.concat({
					"Phase: Night",
					"Moon: " .. moonName,
					"Server time: " .. formatPredictClock(now),
				}, "\n"),
				10181046
			)
		end
		webhookState.moonPhase = phaseName
		webhookState.moonName = moonName
	end

	local function checkStockWebhooks()
		if not webhookStockSeeds and not webhookStockGears and not webhookStockCrates then
			return
		end
		local stockValues = game:GetService("ReplicatedStorage"):FindFirstChild("StockValues")
		if not stockValues then
			return
		end
		local shops = {}
		if webhookStockSeeds then
			table.insert(shops, { "SeedShop", "Seeds" })
		end
		if webhookStockGears then
			table.insert(shops, { "GearShop", "Gear" })
		end
		if webhookStockCrates then
			table.insert(shops, { "CrateShop", "Crates" })
		end
		for _, shop in shops do
			local shopName, shopLabel = shop[1], shop[2]
			local itemsFolder = stockValues:FindFirstChild(shopName) and stockValues[shopName]:FindFirstChild("Items")
			if itemsFolder then
				for _, itemVal in itemsFolder:GetChildren() do
					local itemName = itemVal.Name:gsub("Seed$", "")
					if shopName == "CrateShop" and not itemName:find("Crate") then
						itemName = itemName .. " Crate"
					end
					if not isShopItemInCurrentWorld(shopName, itemName) then
						continue
					end
					if not stockItemMatchesFilter(itemName) then
						continue
					end
					local stateKey = shopName .. ":" .. itemVal.Name
					local amount = tonumber(itemVal.Value) or 0
					local previous = webhookState.stock[stateKey] or 0
					webhookState.stock[stateKey] = amount
					if amount > 0 and previous <= 0 then
						broadcastWebhook(
							shopLabel .. " Restock",
							table.concat({
								"Item: " .. itemName,
								"Stock: " .. tostring(amount),
								"Shop: " .. shopLabel,
							}, "\n"),
							15844367
						)
					end
				end
			end
		end
	end

	local function checkPetWebhooks()
		if not webhookPetsEnabled then
			return
		end
		local map = workspace:FindFirstChild("Map")
		local spawnsFolder = map and map:FindFirstChild("WildPetSpawns")
		if not spawnsFolder then
			return
		end
		local seen = {}
		for _, model in spawnsFolder:GetChildren() do
			if model:IsA("Model") then
				seen[model] = true
				if not webhookState.pets[model] then
					local cleanName, rarity, mutation, petSize, petType = getWildPetSpawnInfo(model)
					if not petWebhookMatchesFilters(cleanName, rarity, mutation, petSize, petType) then
						continue
					end
					webhookState.pets[model] = true
					local lines = {
						"Pet: " .. cleanName,
						"Rarity: " .. rarity,
						"Variation: " .. mutation,
					}
					if petSize ~= "Normal" and petSize ~= "" then
						table.insert(lines, "Size: " .. petSize)
					end
					if petType ~= "Normal" and petType ~= "" and petType ~= mutation then
						table.insert(lines, "Type: " .. petType)
					end
					broadcastWebhook(
						"Wild Pet Spawn",
						table.concat(lines, "\n"),
						16744272
					)
				end
			end
		end
		for model in pairs(webhookState.pets) do
			if not seen[model] or not model.Parent then
				webhookState.pets[model] = nil
			end
		end
	end

	local function checkWeatherWebhooks()
		if not webhookWeatherEnabled then
			return
		end
		local weatherValues = game:GetService("ReplicatedStorage"):FindFirstChild("WeatherValues")
		if not weatherValues then
			return
		end
		for weatherName in pairs(predictWeatherMeta) do
			local playing = weatherValues:GetAttribute(weatherName .. "_Playing") == true
			local previous = webhookState.weather[weatherName]
			webhookState.weather[weatherName] = playing
			if playing and previous ~= true and (previous == false or previous == nil) then
				local endTime = weatherValues:GetAttribute(weatherName .. "_EndTime") or 0
				local timeLeft = math.max(0, endTime - DateTime.now().UnixTimestamp)
				broadcastWebhook(
					"Weather Started",
					table.concat({
						"Weather: " .. weatherName,
						"Time left: " .. formatPredictCountdown(timeLeft),
					}, "\n"),
					3447003
				)
			end
		end
	end

	local function webhookMonitoringActive()
		return webhookGardenEnabled
			or webhookMoonEnabled
			or webhookPhaseEnabled
			or webhookWeatherEnabled
			or webhookStockSeeds
			or webhookStockGears
			or webhookStockCrates
			or webhookPetsEnabled
			or webhookStealEnabled
	end

	local function startWebhookMonitor()
		if webhookThread then
			return
		end
		webhookThread = task.spawn(function()
			while #webhookUrls > 0 do
				if webhookMonitoringActive() then
					bootstrapWebhookState()
					pcall(checkGardenWebhooks)
					pcall(checkMoonWebhooks)
					pcall(checkStockWebhooks)
					pcall(checkPetWebhooks)
					pcall(checkWeatherWebhooks)
				end
				task.wait(3)
			end
			webhookThread = nil
		end)
	end

	webhookHooks.onSteal = function(target)
		if not webhookStealEnabled or not target then
			return
		end
		broadcastWebhook(
			"Auto Steal Success",
			table.concat({
				"Crop: " .. tostring(target.seedName),
				"Garden: " .. tostring(target.plotLabel or "Unknown"),
				"Weight: " .. string.format("%.2f kg", target.weight or 0),
				"Value: " .. formatCurrencyAmount(target.price or 0, true),
				"Mutation: " .. tostring(target.mutation or "None"),
			}, "\n"),
			15158332
		)
	end

	hub:CreateTab("Webhook", "rbxassetid://16000149927")
	hub:CreateModule("Webhook", {
		name = "Webhooks",
		notoggle = true,
		on = false,
		bind = "None",
		desc = "Discord webhook URLs and alert filters.",
		callback = function() end,
		opts = {
			{type = "paragraph", title = "Saved Webhooks", content = "Loading...", onCreate = function(widget)
				webhookUrlParagraph = widget
				refreshWebhookUrlParagraph()
			end},
			{type = "textbox", label = "Add Webhook URL", value = "", placeholder = "https://discord.com/api/webhooks/...", callback = function(value)
				local url = typeof(value) == "string" and value:match("^%s*(.-)%s*$") or ""
				if url == "" then
					return
				end
				url = normalizeDiscordWebhookUrl(url)
				if not url then
					hub:Notify("Invalid Discord webhook URL.")
					return
				end
				for _, existing in ipairs(webhookUrls) do
					if existing == url then
						hub:Notify("Webhook already saved.")
						refreshWebhookUrlParagraph()
						return
					end
				end
				table.insert(webhookUrls, url)
				refreshWebhookUrlParagraph()
				webhookBootstrapped = false
				startWebhookMonitor()
				hub:Notify("Webhook added (" .. #webhookUrls .. " total).")
			end},
			{type = "button", label = "Send Test Message", callback = function()
				if #webhookUrls == 0 then
					hub:Notify("Add a webhook URL first.")
					return
				end
				task.spawn(function()
					local ok, payload = pcall(buildWebhookPayload,
						"Webhook Test",
						table.concat({
							"Connection successful.",
							"Player: " .. localPlayer.Name,
							"World: " .. getWorldDisplayName(),
						}, "\n"),
						5763719
					)
					if not ok or not payload then
						hub:Notify("Failed to build test message.")
						return
					end
					local sent, failed = sendWebhookPayload(payload, true)
					if sent > 0 and failed == 0 then
						hub:Notify("Test message sent (" .. sent .. ").")
					elseif sent > 0 then
						hub:Notify("Sent: " .. sent .. ", failed: " .. failed .. ".")
					else
						hub:Notify("Webhook send failed. Check URL or executor HTTP support.")
					end
				end)
			end},
			{type = "button", label = "Clear All Webhooks", callback = function()
				table.clear(webhookUrls)
				refreshWebhookUrlParagraph()
				hub:Notify("All webhooks removed.")
			end},
			{type = "section", label = "Garden"},
			{type = "checkbox", label = "My Garden Fruits", value = false, callback = function(value)
				webhookGardenEnabled = value
				if value then
					resetGardenWebhookState()
				end
			end},
			{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
				webhookGardenFruitType = value
				resetGardenWebhookState()
			end},
			{type = "multiselect", label = "Filter Fruits", value = "", list = gameLists.seeds, callback = function(value)
				webhookGardenFruits = value or ""
				resetGardenWebhookState()
			end, onCreate = function(widget)
				registerGameListWidget(widget, "seeds")
			end},
			{type = "textbox", label = "Min Weight (kg)", value = "0", placeholder = "0 = no minimum", callback = function(value)
				webhookGardenMinWeight = tonumber(value) or 0
			end},
			{type = "textbox", label = "Max Weight (kg)", value = "0", placeholder = "0 = no maximum", callback = function(value)
				webhookGardenMaxWeight = tonumber(value) or 0
			end},
			{type = "textbox", label = "Min Value", value = "0", placeholder = "0 = no minimum (e.g. 500K)", callback = function(value)
				webhookGardenMinPrice = parseWebhookMoneyInput(value or "0")
			end},
			{type = "textbox", label = "Max Value", value = "0", placeholder = "0 = no maximum (e.g. 2M)", callback = function(value)
				webhookGardenMaxPrice = parseWebhookMoneyInput(value or "0")
			end},
			{type = "dropdown", label = "Filter Mutation Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
				webhookGardenMutationType = value
				resetGardenWebhookState()
			end},
			{type = "multiselect", label = "Filter Mutations", value = "None", list = gameLists.mutations, callback = function(value)
				webhookGardenMutations = value or ""
				resetGardenWebhookState()
			end},
			{type = "section", label = "World Events"},
			{type = "checkbox", label = "Moon Events", value = false, callback = function(value)
				webhookMoonEnabled = value
			end},
			{type = "checkbox", label = "Day/Night Phase Change", value = false, callback = function(value)
				webhookPhaseEnabled = value
			end},
			{type = "checkbox", label = "Weather Started", value = false, callback = function(value)
				webhookWeatherEnabled = value
			end},
			{type = "section", label = "Shop Restocks"},
			{type = "checkbox", label = "Seed Shop", value = false, callback = function(value)
				webhookStockSeeds = value
			end},
			{type = "checkbox", label = "Gear Shop", value = false, callback = function(value)
				webhookStockGears = value
			end},
			{type = "checkbox", label = "Crate Shop", value = false, callback = function(value)
				webhookStockCrates = value
			end},
			{type = "dropdown", label = "Stock Filter Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
				webhookStockFilterType = value
			end},
			{type = "multiselect", label = "Stock Item Filter", value = "None", list = {}, callback = function(value)
				webhookStockFilter = value or ""
			end, onCreate = function(widget)
				local combined = {}
				for _, name in gameLists.seeds do table.insert(combined, name) end
				for _, name in gameLists.gears do table.insert(combined, name) end
				for _, name in gameLists.crates do table.insert(combined, name) end
				table.sort(combined)
				if widget.SetOptions then
					pcall(function() widget:SetOptions(combined) end)
				end
			end},
			{type = "section", label = "Wild Pets"},
			{type = "checkbox", label = "Wild Pet Spawns", value = false, callback = function(value)
				webhookPetsEnabled = value
				if value then
					resetPetWebhookState()
				end
			end},
			{type = "dropdown", label = "Filter Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
				webhookPetFilterType = value
				resetPetWebhookState()
			end},
			{type = "multiselect", label = "Filter Pets", value = "", list = gameLists.pets, callback = function(value)
				webhookPetFilter = value or ""
				resetPetWebhookState()
			end, onCreate = function(widget)
				registerGameListWidget(widget, "pets")
			end},
			{type = "dropdown", label = "Filter Rarity Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
				webhookPetRarityType = value
				resetPetWebhookState()
			end},
			{type = "multiselect", label = "Filter Rarities", value = "", list = gameLists.rarities, callback = function(value)
				webhookPetRarities = value or ""
				resetPetWebhookState()
			end, onCreate = function(widget)
				registerGameListWidget(widget, "rarities")
			end},
			{type = "dropdown", label = "Filter Variation Type", value = "Whitelist", list = {"Whitelist", "Blacklist"}, callback = function(value)
				webhookPetMutationType = value
				resetPetWebhookState()
			end},
			{type = "multiselect", label = "Filter Variations", value = "None", list = gameLists.petMutations, callback = function(value)
				webhookPetMutations = value or ""
				resetPetWebhookState()
			end, onCreate = function(widget)
				registerGameListWidget(widget, "petMutations")
			end},
			{type = "section", label = "Other"},
			{type = "checkbox", label = "Auto Steal Success", value = false, callback = function(value)
				webhookStealEnabled = value
			end},
		}
	})
	table.insert(hubStore.paragraphBootstraps, refreshWebhookUrlParagraph)
end)()
local function createMobileToggleBtn()
	local screenGui = getZenithGUI()
	if not screenGui then return end
	local existing = screenGui:FindFirstChild("ZenithMobileToggle")
	if existing then
		existing:Destroy()
	end
	local toggleBtn = Instance.new("ImageButton")
	toggleBtn.Name = "ZenithMobileToggle"
	toggleBtn.Size = UDim2.new(0, 42, 0, 42)
	toggleBtn.Position = UDim2.new(0.02, 0, 0.45, 0)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	toggleBtn.Image = "rbxassetid://107758724327938"
	toggleBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.ScaleType = Enum.ScaleType.Fit
	toggleBtn.Parent = screenGui
	rnd(toggleBtn, 21)
	stk(toggleBtn, Color3.fromRGB(30, 30, 35), 1)
	toggleBtn.MouseButton1Click:Connect(function()
		hub:Toggle()
	end)
	local dragging = false
	local dragInput, dragStart, startPos
	toggleBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = toggleBtn.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end
hub:Init("Casual Hub", nil, nil, "rbxassetid://107758724327938")
pcall(refreshGameLists)
pcall(refreshAllGameListWidgets)
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled
if isMobile then
	task.spawn(createMobileToggleBtn)
end
task.spawn(function()
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") and instantPromptsEnabled then
			d.HoldDuration = 0
		end
	end)
end)
