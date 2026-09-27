-- MINING EMPIRE COMPLETE SETUP SCRIPT
-- Paste this into Roblox Studio Command Bar to generate everything

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

print("🔧 Starting Mining Empire setup...")

-- ==================================================
-- STEP 1: CREATE FOLDER STRUCTURE
-- ==================================================

print("📁 Creating folder structure...")

-- ReplicatedStorage structure
local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
if not sharedFolder then
	sharedFolder = Instance.new("Folder")
	sharedFolder.Name = "Shared"
	sharedFolder.Parent = ReplicatedStorage
end

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- ServerScriptService structure
local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
if not servicesFolder then
	servicesFolder = Instance.new("Folder")
	servicesFolder.Name = "Services"
	servicesFolder.Parent = game:GetService("ServerScriptService")
end

-- Workspace structure
local miningArea = Workspace:FindFirstChild("MiningArea")
if miningArea then
	miningArea:Destroy()
end

miningArea = Instance.new("Folder")
miningArea.Name = "MiningArea"
miningArea.Parent = Workspace

local nodesFolder = Instance.new("Folder")
nodesFolder.Name = "Nodes"
nodesFolder.Parent = miningArea

local structuresFolder = Instance.new("Folder")
structuresFolder.Name = "Structures"
structuresFolder.Parent = miningArea

local lightsFolder = Instance.new("Folder")
lightsFolder.Name = "Lights"
lightsFolder.Parent = miningArea

-- ==================================================
-- STEP 2: CREATE REMOTE EVENTS
-- ==================================================

print("🔌 Creating remote events...")

local function getRemote(name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

getRemote("MineRequest")
getRemote("ShopRequest")
getRemote("MergeRequest")
getRemote("ArmyRequest")
getRemote("StateUpdate")

-- ==================================================
-- STEP 3: CREATE GAMECONFIG MODULE
-- ==================================================

print("📋 Creating GameConfig...")

local gameConfigCode = [[local Config = {}

Config.Mining = {
	BaseDamage = 1,
	BaseMiningCooldown = 0.35,

	Resources = {
		Copper = {
			MaxHealth = 10,
			MinReward = 2,
			MaxReward = 5,
			RespawnTime = 3,
		},

		Iron = {
			MaxHealth = 30,
			MinReward = 5,
			MaxReward = 12,
			RespawnTime = 5,
		},

		Gold = {
			MaxHealth = 75,
			MinReward = 15,
			MaxReward = 40,
			RespawnTime = 8,
		},

		Crystal = {
			MaxHealth = 200,
			MinReward = 50,
			MaxReward = 150,
			RespawnTime = 15,
		},
	},
}

Config.SellValues = {
	Copper = 2,
	Iron = 5,
	Gold = 15,
	Crystal = 50,
}

Config.Upgrades = {
	PickaxePower = {
		BaseCost = 50,
		CostMultiplier = 1.55,
	},

	MiningSpeed = {
		BaseCost = 100,
		CostMultiplier = 1.7,
	},

	Backpack = {
		BaseCost = 75,
		CostMultiplier = 1.5,
	},

	Luck = {
		BaseCost = 250,
		CostMultiplier = 2,
	},
}

Config.Units = {
	Recruit = {
		Power = 10,
		Rarity = "Common",
	},

	Soldier = {
		Power = 25,
		Rarity = "Uncommon",
	},

	Elite = {
		Power = 75,
		Rarity = "Rare",
	},

	Commander = {
		Power = 250,
		Rarity = "Epic",
	},

	Legend = {
		Power = 1000,
		Rarity = "Legendary",
	},
}

Config.Merge = {
	RequiredDuplicates = 3,
}

return Config]]

local gameConfig = sharedFolder:FindFirstChild("GameConfig")
if gameConfig then
	gameConfig:Destroy()
end

gameConfig = Instance.new("ModuleScript")
gameConfig.Name = "GameConfig"
gameConfig.Source = gameConfigCode
gameConfig.Parent = sharedFolder

-- ==================================================
-- STEP 4: CREATE SERVICE MODULES
-- ==================================================

print("⚙️ Creating service modules...")

-- PlayerDataService
local playerDataServiceCode = [[local Players = game:GetService("Players")

local PlayerDataService = {}
local playerData = {}

local DEFAULT_DATA = {
	Coins = 0,

	Inventory = {
		Copper = 0,
		Iron = 0,
		Gold = 0,
		Crystal = 0,
	},

	Upgrades = {
		PickaxePower = 1,
		MiningSpeed = 1,
		Backpack = 1,
		Luck = 1,
	},

	Units = {
		Recruit = 0,
		Soldier = 0,
		Elite = 0,
		Commander = 0,
		Legend = 0,
	},

	ArmyPower = 0,
}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, childValue in pairs(value) do
		copy[key] = deepCopy(childValue)
	end

	return copy
end

function PlayerDataService.CreatePlayer(player)
	playerData[player] = deepCopy(DEFAULT_DATA)
	return playerData[player]
end

function PlayerDataService.Get(player)
	return playerData[player]
end

function PlayerDataService.Remove(player)
	playerData[player] = nil
end

function PlayerDataService.GetPublicState(player)
	local data = playerData[player]

	if not data then
		return nil
	end

	return {
		Coins = data.Coins,
		Inventory = deepCopy(data.Inventory),
		Upgrades = deepCopy(data.Upgrades),
		Units = deepCopy(data.Units),
		ArmyPower = data.ArmyPower,
	}
end

Players.PlayerAdded:Connect(function(player)
	PlayerDataService.CreatePlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataService.Remove(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	PlayerDataService.CreatePlayer(player)
end

return PlayerDataService]]

local pds = servicesFolder:FindFirstChild("PlayerDataService")
if pds then pds:Destroy() end
pds = Instance.new("ModuleScript")
pds.Name = "PlayerDataService"
pds.Source = playerDataServiceCode
pds.Parent = servicesFolder

-- MiningService
local miningServiceCode = [[local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)

local PlayerDataService = require(script.Parent.PlayerDataService)

local MiningService = {}

local nodeStates = {}
local playerCooldowns = {}

local function getResourceName(node)
	return node:GetAttribute("ResourceType") or "Copper"
end

local function isValidNode(node)
	if typeof(node) ~= "Instance" then
		return false
	end

	local miningArea = workspace:FindFirstChild("MiningArea")
	local nodes = miningArea and miningArea:FindFirstChild("Nodes")

	return nodes
		and node:IsA("BasePart")
		and node:IsDescendantOf(nodes)
end

function MiningService.RegisterNode(node)
	if not isValidNode(node) then
		return false
	end

	local resourceName = getResourceName(node)
	local resource = Config.Mining.Resources[resourceName]

	if not resource then
		warn("Invalid resource type on node:", node:GetFullName())
		return false
	end

	nodeStates[node] = {
		Health = resource.MaxHealth,
		MaxHealth = resource.MaxHealth,
		Broken = false,
	}

	node:SetAttribute("MaxHealth", resource.MaxHealth)
	node:SetAttribute("Health", resource.MaxHealth)

	return true
end

function MiningService.Mine(player, node)
	if not isValidNode(node) then
		return false, "Invalid mining node"
	end

	local data = PlayerDataService.Get(player)

	if not data then
		return false, "Player data missing"
	end

	local now = os.clock()
	local cooldown = Config.Mining.BaseMiningCooldown
	local speedLevel = data.Upgrades.MiningSpeed

	cooldown /= 1 + ((speedLevel - 1) * 0.1)

	if playerCooldowns[player]
		and now - playerCooldowns[player] < cooldown then
		return false, "Mining too fast"
	end

	playerCooldowns[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return false, "Character unavailable"
	end

	if (root.Position - node.Position).Magnitude > 20 then
		return false, "Too far away"
	end

	local state = nodeStates[node]

	if not state then
		MiningService.RegisterNode(node)
		state = nodeStates[node]
	end

	if not state or state.Broken then
		return false, "Node unavailable"
	end

	local resourceName = getResourceName(node)
	local resource = Config.Mining.Resources[resourceName]

	local damage = Config.Mining.BaseDamage
	damage += data.Upgrades.PickaxePower - 1

	state.Health = math.max(0, state.Health - damage)
	node:SetAttribute("Health", state.Health)

	if state.Health > 0 then
		return true, {
			Resource = resourceName,
			Damage = damage,
			Broken = false,
		}
	end

	state.Broken = true

	local luckLevel = data.Upgrades.Luck
	local reward = math.random(resource.MinReward, resource.MaxReward)

	reward = math.floor(
		reward * (1 + ((luckLevel - 1) * 0.1))
	)

	local carried = 0

	for _, amount in pairs(data.Inventory) do
		carried += amount
	end

	local capacity = data.Upgrades.Backpack * 20
	local availableSpace = math.max(0, capacity - carried)
	local actualReward = math.min(reward, availableSpace)

	data.Inventory[resourceName] =
		(data.Inventory[resourceName] or 0) + actualReward

	node.Transparency = 1
	node.CanCollide = false

	task.delay(resource.RespawnTime, function()
		if node.Parent and nodeStates[node] then
			state.Health = state.MaxHealth
			state.Broken = false

			node:SetAttribute("Health", state.Health)
			node.Transparency = 0
			node.CanCollide = true
		end
	end)

	return true, {
		Resource = resourceName,
		Amount = actualReward,
		Damage = damage,
		Broken = true,
	}
end

function MiningService.SellAll(player)
	local data = PlayerDataService.Get(player)

	if not data then
		return false, "Player data missing"
	end

	local total = 0

	for resourceName, amount in pairs(data.Inventory) do
		local sellValue = Config.SellValues[resourceName]

		if sellValue then
			total += amount * sellValue
			data.Inventory[resourceName] = 0
		end
	end

	data.Coins += total

	return true, total
end

function MiningService.Cleanup(player)
	playerCooldowns[player] = nil
end

return MiningService]]

local ms = servicesFolder:FindFirstChild("MiningService")
if ms then ms:Destroy() end
ms = Instance.new("ModuleScript")
ms.Name = "MiningService"
ms.Source = miningServiceCode
ms.Parent = servicesFolder

-- ShopService
local shopServiceCode = [[local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)

local PlayerDataService = require(script.Parent.PlayerDataService)

local ShopService = {}

function ShopService.GetCost(upgradeName, currentLevel)
	local upgrade = Config.Upgrades[upgradeName]

	if not upgrade then
		return nil
	end

	return math.floor(
		upgrade.BaseCost
			* (upgrade.CostMultiplier ^ (currentLevel - 1))
	)
end

function ShopService.BuyUpgrade(player, upgradeName)
	local data = PlayerDataService.Get(player)
	local upgrade = Config.Upgrades[upgradeName]

	if not data then
		return false, "Player data missing"
	end

	if not upgrade then
		return false, "Invalid upgrade"
	end

	local currentLevel = data.Upgrades[upgradeName]

	if not currentLevel then
		return false, "Upgrade unavailable"
	end

	local cost = ShopService.GetCost(upgradeName, currentLevel)

	if data.Coins < cost then
		return false, "Not enough coins"
	end

	data.Coins -= cost
	data.Upgrades[upgradeName] += 1

	return true, {
		Upgrade = upgradeName,
		NewLevel = data.Upgrades[upgradeName],
		Cost = cost,
	}
end

return ShopService]]

local ss = servicesFolder:FindFirstChild("ShopService")
if ss then ss:Destroy() end
ss = Instance.new("ModuleScript")
ss.Name = "ShopService"
ss.Source = shopServiceCode
ss.Parent = servicesFolder

-- MergeService
local mergeServiceCode = [[local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)

local PlayerDataService = require(script.Parent.PlayerDataService)

local MergeService = {}

local UNIT_ORDER = {
	"Recruit",
	"Soldier",
	"Elite",
	"Commander",
	"Legend",
}

local function getNextUnit(unitName)
	for index, currentName in ipairs(UNIT_ORDER) do
		if currentName == unitName then
			return UNIT_ORDER[index + 1]
		end
	end

	return nil
end

function MergeService.Merge(player, unitName)
	local data = PlayerDataService.Get(player)

	if not data then
		return false, "Player data missing"
	end

	if not Config.Units[unitName] then
		return false, "Invalid unit"
	end

	local nextUnit = getNextUnit(unitName)

	if not nextUnit then
		return false, "Unit is already max tier"
	end

	local amount = data.Units[unitName] or 0
	local required = Config.Merge.RequiredDuplicates

	if amount < required then
		return false, "Not enough duplicate units"
	end

	data.Units[unitName] -= required
	data.Units[nextUnit] += 1

	return true, {
		From = unitName,
		To = nextUnit,
	}
end

return MergeService]]

local mers = servicesFolder:FindFirstChild("MergeService")
if mers then mers:Destroy() end
mers = Instance.new("ModuleScript")
mers.Name = "MergeService"
mers.Source = mergeServiceCode
mers.Parent = servicesFolder

-- ArmyService
local armyServiceCode = [[local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)

local PlayerDataService = require(script.Parent.PlayerDataService)

local ArmyService = {}

function ArmyService.CalculatePower(player)
	local data = PlayerDataService.Get(player)

	if not data then
		return 0
	end

	local totalPower = 0

	for unitName, amount in pairs(data.Units) do
		local unitConfig = Config.Units[unitName]

		if unitConfig then
			totalPower += unitConfig.Power * amount
		end
	end

	data.ArmyPower = totalPower

	return totalPower
end

function ArmyService.GetArmy(player)
	local data = PlayerDataService.Get(player)

	if not data then
		return nil
	end

	ArmyService.CalculatePower(player)

	return {
		Units = data.Units,
		Power = data.ArmyPower,
	}
end

return ArmyService]]

local as = servicesFolder:FindFirstChild("ArmyService")
if as then as:Destroy() end
as = Instance.new("ModuleScript")
as.Name = "ArmyService"
as.Source = armyServiceCode
as.Parent = servicesFolder

-- ==================================================
-- STEP 5: CREATE MODERN TERRAIN
-- ==================================================

print("🌍 Generating modern sci-fi terrain...")

local terrain = Workspace.Terrain
terrain:Clear()

-- Palette
local Palette = {
	Wall = Color3.fromRGB(35, 40, 50),
	Metal = Color3.fromRGB(70, 78, 90),
	DarkMetal = Color3.fromRGB(20, 24, 32),
	Cyan = Color3.fromRGB(0, 220, 255),
	Purple = Color3.fromRGB(150, 60, 255),
	Orange = Color3.fromRGB(255, 120, 25),
	Warning = Color3.fromRGB(255, 190, 40),
}

-- Main underground rock mass
terrain:FillBlock(
	CFrame.new(0, -80, 0),
	Vector3.new(300, 150, 300),
	Enum.Material.Rock
)

-- Main tunnel
terrain:FillBlock(
	CFrame.new(0, -20, 0),
	Vector3.new(200, 30, 60),
	Enum.Material.Air
)

-- Entrance shaft
terrain:FillBlock(
	CFrame.new(0, 40, 0),
	Vector3.new(30, 100, 30),
	Enum.Material.Air
)

-- Side mining chamber (Copper zone)
terrain:FillBall(
	Vector3.new(80, -30, 0),
	35,
	Enum.Material.Air
)

-- Deep mining chamber (Gold zone)
terrain:FillBall(
	Vector3.new(-80, -60, 0),
	40,
	Enum.Material.Air
)

-- Crystal cavern
terrain:FillBall(
	Vector3.new(0, -50, 80),
	50,
	Enum.Material.Air
)

-- Secret hidden cave
terrain:FillBall(
	Vector3.new(-100, -70, -80),
	25,
	Enum.Material.Air
)

-- Paint terrain for variety
terrain:PaintTerrain(
	CFrame.new(0, -30, 0),
	100,
	Enum.Material.Slate
)

terrain:PaintTerrain(
	CFrame.new(-80, -60, 0),
	40,
	Enum.Material.Basalt
)

terrain:PaintTerrain(
	CFrame.new(0, -50, 80),
	50,
	Enum.Material.Rock
)

-- ==================================================
-- STEP 6: CREATE STRUCTURES
-- ==================================================

print("🏗️ Creating mining hub structures...")

-- Hub platform
local hubPlatform = Instance.new("Part")
hubPlatform.Name = "HubPlatform"
hubPlatform.Size = Vector3.new(60, 2, 60)
hubPlatform.Position = Vector3.new(0, 0, 0)
hubPlatform.Anchored = true
hubPlatform.TopSurface = Enum.SurfaceType.Smooth
hubPlatform.BottomSurface = Enum.SurfaceType.Smooth
hubPlatform.Material = Enum.Material.Metal
hubPlatform.Color = Palette.Metal
hubPlatform.Parent = structuresFolder

-- Support beams
for i = 0, 3 do
	local angle = (i / 4) * math.pi * 2
	local offset = Vector3.new(
		math.cos(angle) * 30,
		0,
		math.sin(angle) * 30
	)
	
	local beam = Instance.new("Part")
	beam.Name = "SupportBeam_" .. i
	beam.Size = Vector3.new(4, 30, 4)
	beam.Position = hubPlatform.Position + offset + Vector3.new(0, -15, 0)
	beam.Anchored = true
	beam.Material = Enum.Material.Metal
	beam.Color = Palette.DarkMetal
	beam.Parent = structuresFolder
end

-- Elevator platform
local elevator = Instance.new("Part")
elevator.Name = "Elevator"
elevator.Size = Vector3.new(20, 2, 20)
elevator.Position = Vector3.new(0, -35, 0)
elevator.Anchored = true
elevator.TopSurface = Enum.SurfaceType.Smooth
elevator.Material = Enum.Material.DiamondPlate
elevator.Color = Palette.Orange
elevator.Parent = structuresFolder

-- Spawn platform
local spawnPlatform = Instance.new("Part")
spawnPlatform.Name = "SpawnPlatform"
spawnPlatform.Size = Vector3.new(40, 1, 40)
spawnPlatform.Position = Vector3.new(0, 50, 0)
spawnPlatform.Anchored = true
spawnPlatform.TopSurface = Enum.SurfaceType.Smooth
spawnPlatform.Material = Enum.Material.Metal
spawnPlatform.Color = Palette.Metal
spawnPlatform.Parent = structuresFolder

-- Shop terminal
local shopTerminal = Instance.new("Part")
shopTerminal.Name = "ShopTerminal"
shopTerminal.Size = Vector3.new(3, 5, 3)
shopTerminal.Position = Vector3.new(-15, 2, 0)
shopTerminal.Anchored = true
shopTerminal.Material = Enum.Material.SmoothPlastic
shopTerminal.Color = Palette.DarkMetal
shopTerminal.Parent = structuresFolder

local shopScreen = Instance.new("Part")
shopScreen.Name = "ShopScreen"
shopScreen.Size = Vector3.new(4, 6, 0.3)
shopScreen.Position = shopTerminal.Position + Vector3.new(2, 0, 0)
shopScreen.Anchored = true
shopScreen.Material = Enum.Material.Neon
shopScreen.Color = Palette.Cyan
shopScreen.Parent = structuresFolder

-- Sell station
local sellStation = Instance.new("Part")
sellStation.Name = "SellStation"
sellStation.Size = Vector3.new(3, 5, 3)
sellStation.Position = Vector3.new(15, 2, 0)
sellStation.Anchored = true
sellStation.Material = Enum.Material.SmoothPlastic
sellStation.Color = Palette.DarkMetal
sellStation.Parent = structuresFolder

local sellScreen = Instance.new("Part")
sellScreen.Name = "SellScreen"
sellScreen.Size = Vector3.new(4, 6, 0.3)
sellScreen.Position = sellStation.Position + Vector3.new(2, 0, 0)
sellScreen.Anchored = true
sellScreen.Material = Enum.Material.Neon
sellScreen.Color = Palette.Warning
sellScreen.Parent = structuresFolder

-- ==================================================
-- STEP 7: CREATE MINING NODES WITH LIGHTS
-- ==================================================

print("⛏️ Creating mining nodes...")

-- Copper node
local copperNodeBase = Instance.new("Part")
copperNodeBase.Name = "CopperNode"
copperNodeBase.Size = Vector3.new(6, 6, 6)
copperNodeBase.Position = Vector3.new(30, -20, 10)
copperNodeBase.Anchored = true
copperNodeBase.Material = Enum.Material.Rock
copperNodeBase.Color = Palette.Wall
copperNodeBase.TopSurface = Enum.SurfaceType.Smooth
copperNodeBase.BottomSurface = Enum.SurfaceType.Smooth
copperNodeBase:SetAttribute("ResourceType", "Copper")
copperNodeBase:SetAttribute("MaxHealth", 10)
copperNodeBase:SetAttribute("Health", 10)
copperNodeBase.Parent = nodesFolder

local copperVein = Instance.new("Part")
copperVein.Name = "CopperVein"
copperVein.Size = Vector3.new(4, 4, 4)
copperVein.Position = copperNodeBase.Position
copperVein.Anchored = true
copperVein.CanCollide = false
copperVein.Material = Enum.Material.Metal
copperVein.Color = Palette.Orange
copperVein.Parent = nodesFolder

local copperLight = Instance.new("PointLight")
copperLight.Color = Palette.Orange
copperLight.Brightness = 2
copperLight.Range = 15
copperLight.Parent = copperVein

-- Iron node
local ironNodeBase = Instance.new("Part")
ironNodeBase.Name = "IronNode"
ironNodeBase.Size = Vector3.new(6, 6, 6)
ironNodeBase.Position = Vector3.new(30, -20, -10)
ironNodeBase.Anchored = true
ironNodeBase.Material = Enum.Material.Rock
ironNodeBase.Color = Palette.Wall
ironNodeBase.TopSurface = Enum.SurfaceType.Smooth
ironNodeBase.BottomSurface = Enum.SurfaceType.Smooth
ironNodeBase:SetAttribute("ResourceType", "Iron")
ironNodeBase:SetAttribute("MaxHealth", 30)
ironNodeBase:SetAttribute("Health", 30)
ironNodeBase.Parent = nodesFolder

local ironVein = Instance.new("Part")
ironVein.Name = "IronVein"
ironVein.Size = Vector3.new(4, 4, 4)
ironVein.Position = ironNodeBase.Position
ironVein.Anchored = true
ironVein.CanCollide = false
ironVein.Material = Enum.Material.Metal
ironVein.Color = Color3.fromRGB(100, 100, 120)
ironVein.Parent = nodesFolder

local ironLight = Instance.new("PointLight")
ironLight.Color = Color3.fromRGB(100, 150, 200)
ironLight.Brightness = 2
ironLight.Range = 15
ironLight.Parent = ironVein

-- Gold node
local goldNodeBase = Instance.new("Part")
goldNodeBase.Name = "GoldNode"
goldNodeBase.Size = Vector3.new(8, 8, 8)
goldNodeBase.Position = Vector3.new(-80, -60, 0)
goldNodeBase.Anchored = true
goldNodeBase.Material = Enum.Material.Rock
goldNodeBase.Color = Palette.Wall
goldNodeBase.TopSurface = Enum.SurfaceType.Smooth
goldNodeBase.BottomSurface = Enum.SurfaceType.Smooth
goldNodeBase:SetAttribute("ResourceType", "Gold")
goldNodeBase:SetAttribute("MaxHealth", 75)
goldNodeBase:SetAttribute("Health", 75)
goldNodeBase.Parent = nodesFolder

local goldVein = Instance.new("Part")
goldVein.Name = "GoldVein"
goldVein.Size = Vector3.new(5, 5, 5)
goldVein.Position = goldNodeBase.Position
goldVein.Anchored = true
goldVein.CanCollide = false
goldVein.Material = Enum.Material.Neon
goldVein.Color = Color3.fromRGB(255, 215, 0)
goldVein.Parent = nodesFolder

local goldLight = Instance.new("PointLight")
goldLight.Color = Color3.fromRGB(255, 215, 0)
goldLight.Brightness = 3
goldLight.Range = 25
goldLight.Parent = goldVein

-- Crystal node
local crystalNodeBase = Instance.new("Part")
crystalNodeBase.Name = "CrystalNode"
crystalNodeBase.Size = Vector3.new(10, 10, 10)
crystalNodeBase.Position = Vector3.new(0, -50, 80)
crystalNodeBase.Anchored = true
crystalNodeBase.Material = Enum.Material.Rock
crystalNodeBase.Color = Palette.Wall
crystalNodeBase.TopSurface = Enum.SurfaceType.Smooth
crystalNodeBase.BottomSurface = Enum.SurfaceType.Smooth
crystalNodeBase:SetAttribute("ResourceType", "Crystal")
crystalNodeBase:SetAttribute("MaxHealth", 200)
crystalNodeBase:SetAttribute("Health", 200)
crystalNodeBase.Parent = nodesFolder

local crystalVein = Instance.new("Part")
crystalVein.Name = "CrystalVein"
crystalVein.Size = Vector3.new(6, 6, 6)
crystalVein.Position = crystalNodeBase.Position
crystalVein.Anchored = true
crystalVein.CanCollide = false
crystalVein.Material = Enum.Material.Neon
crystalVein.Color = Palette.Cyan
crystalVein.Parent = nodesFolder

local crystalLight = Instance.new("PointLight")
crystalLight.Color = Palette.Cyan
crystalLight.Brightness = 4
crystalLight.Range = 35
crystalLight.Parent = crystalVein

-- ==================================================
-- STEP 8: SET UP LIGHTING
-- ==================================================

print("💡 Setting up world lighting...")

local ambientLight = Instance.new("PointLight")
ambientLight.Color = Color3.fromRGB(50, 100, 150)
ambientLight.Brightness = 1
ambientLight.Range = 100
ambientLight.Parent = hubPlatform

local entranceLight = Instance.new("PointLight")
entranceLight.Color = Palette.Warning
entranceLight.Brightness = 1.5
entranceLight.Range = 40
entranceLight.Parent = spawnPlatform

-- Global lighting
Lighting.Brightness = 1
Lighting.ClockTime = 0

-- Atmosphere
local atmosphere = Lighting:FindFirstChild("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end

atmosphere.Density = 0.25
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(30, 50, 80)
atmosphere.Decay = Color3.fromRGB(100, 60, 150)
atmosphere.Haze = 0.5
atmosphere.Glare = 0.1

-- Color correction
local colorCorrection = Lighting:FindFirstChild("ColorCorrectionEffect")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Parent = Lighting
end

colorCorrection.Brightness = -0.1
colorCorrection.Contrast = 0.15
colorCorrection.Saturation = 0.05
colorCorrection.TintColor = Color3.fromRGB(200, 220, 255)

-- ==================================================
-- STEP 9: CREATE GAME SERVER SCRIPT
-- ==================================================

print("🖥️ Creating game server script...")

local gameServerCode = [[local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local MineRequest = remotes:WaitForChild("MineRequest")
local ShopRequest = remotes:WaitForChild("ShopRequest")
local MergeRequest = remotes:WaitForChild("MergeRequest")
local ArmyRequest = remotes:WaitForChild("ArmyRequest")
local StateUpdate = remotes:WaitForChild("StateUpdate")

local PlayerDataService =
	require(script.Parent.Services.PlayerDataService)

local MiningService =
	require(script.Parent.Services.MiningService)

local ShopService =
	require(script.Parent.Services.ShopService)

local MergeService =
	require(script.Parent.Services.MergeService)

local ArmyService =
	require(script.Parent.Services.ArmyService)

local function sendState(player, eventName, payload)
	StateUpdate:FireClient(player, eventName, payload)
end

-- Register all mining nodes
local miningArea = workspace:FindFirstChild("MiningArea")

if miningArea then
	local nodesFolder = miningArea:FindFirstChild("Nodes")
	
	if nodesFolder then
		for _, node in ipairs(nodesFolder:GetChildren()) do
			if node:IsA("BasePart") then
				MiningService.RegisterNode(node)
			end
		end
	end
end

-- Mine request
MineRequest.OnServerEvent:Connect(function(player, node)
	local success, result = MiningService.Mine(player, node)

	if success then
		sendState(player, "MineResult", result)
	else
		sendState(player, "Error", result)
	end
end)

-- Shop request
ShopRequest.OnServerEvent:Connect(function(player, action, upgradeName)
	if action == "BuyUpgrade" then
		local success, result =
			ShopService.BuyUpgrade(player, upgradeName)

		sendState(player, "ShopResult", {
			Success = success,
			Result = result,
		})
	elseif action == "SellAll" then
		local success, result =
			MiningService.SellAll(player)

		sendState(player, "SellResult", {
			Success = success,
			Coins = result,
		})
	end
end)

-- Merge request
MergeRequest.OnServerEvent:Connect(function(player, unitName)
	local success, result =
		MergeService.Merge(player, unitName)

	if success then
		ArmyService.CalculatePower(player)
	end

	sendState(player, "MergeResult", {
		Success = success,
		Result = result,
	})
end)

-- Army request
ArmyRequest.OnServerEvent:Connect(function(player, action)
	if action == "GetArmy" then
		sendState(player, "ArmyUpdate", ArmyService.GetArmy(player))
	elseif action == "GetState" then
		sendState(
			player,
			"StateUpdate",
			PlayerDataService.GetPublicState(player)
		)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	MiningService.Cleanup(player)
end)

print("✅ Mining Empire server loaded")]]

local gameServerScript = game:GetService("ServerScriptService"):FindFirstChild("GameServer")
if gameServerScript then
	gameServerScript:Destroy()
end

gameServerScript = Instance.new("Script")
gameServerScript.Name = "GameServer"
gameServerScript.Source = gameServerCode
gameServerScript.Parent = game:GetService("ServerScriptService")

-- ==================================================
-- STEP 10: CREATE GAME CLIENT SCRIPT
-- ==================================================

print("📱 Creating game client script...")

local gameClientCode = [[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local MineRequest = remotes:WaitForChild("MineRequest")
local ShopRequest = remotes:WaitForChild("ShopRequest")
local MergeRequest = remotes:WaitForChild("MergeRequest")
local ArmyRequest = remotes:WaitForChild("ArmyRequest")
local StateUpdate = remotes:WaitForChild("StateUpdate")

local function getMouse()
	return player:GetMouse()
end

-- Click a mining node
getMouse().Button1Down:Connect(function()
	local target = getMouse().Target

	if not target then
		return
	end

	local miningArea = workspace:FindFirstChild("MiningArea")
	local nodes = miningArea and miningArea:FindFirstChild("Nodes")

	if not nodes or not target:IsDescendantOf(nodes) then
		return
	end

	MineRequest:FireServer(target)
end)

-- Keyboard controls
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		ShopRequest:FireServer("SellAll")
	elseif input.KeyCode == Enum.KeyCode.One then
		ShopRequest:FireServer("BuyUpgrade", "PickaxePower")
	elseif input.KeyCode == Enum.KeyCode.Two then
		ShopRequest:FireServer("BuyUpgrade", "MiningSpeed")
	elseif input.KeyCode == Enum.KeyCode.Three then
		ShopRequest:FireServer("BuyUpgrade", "Backpack")
	elseif input.KeyCode == Enum.KeyCode.Four then
		ShopRequest:FireServer("BuyUpgrade", "Luck")
	elseif input.KeyCode == Enum.KeyCode.M then
		MergeRequest:FireServer("Recruit")
	elseif input.KeyCode == Enum.KeyCode.A then
		ArmyRequest:FireServer("GetArmy")
	end
end)

-- Server results
StateUpdate.OnClientEvent:Connect(function(eventName, data)
	if eventName == "MineResult" then
		if data.Broken then
			print("⛏️ Collected", data.Amount, data.Resource)
		else
			print("⛏️ Damage dealt:", data.Damage)
		end
	elseif eventName == "SellResult" then
		print("💰 Sold resources for", data.Coins, "coins")
	elseif eventName == "ShopResult" then
		print("🛒 Shop:", data.Success, data.Result)
	elseif eventName == "MergeResult" then
		print("🔀 Merge:", data.Success, data.Result)
	elseif eventName == "ArmyUpdate" then
		print("⚔️ Army power:", data.Power)
	elseif eventName == "Error" then
		warn("Server rejected request:", data)
	end
end)

-- Request initial state
ArmyRequest:FireServer("GetState")

print("✅ Game client loaded")]]

local gameClientScript = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("GameClient")
if gameClientScript then
	gameClientScript:Destroy()
end

gameClientScript = Instance.new("LocalScript")
gameClientScript.Name = "GameClient"
gameClientScript.Source = gameClientCode
gameClientScript.Parent = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

-- ==================================================
-- COMPLETE
-- ==================================================

print("✅✅✅ MINING EMPIRE SETUP COMPLETE! ✅✅✅")
print("")
print("📋 CONTROLS:")
print("  Click nodes to mine")
print("  E - Sell all resources")
print("  1 - Buy Pickaxe Power")
print("  2 - Buy Mining Speed")
print("  3 - Buy Backpack")
print("  4 - Buy Luck")
print("  M - Merge 3 Recruits into Soldier")
print("  A - View army status")
print("")
print("🎮 Ready to play! Press Play to start.")
