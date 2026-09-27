-- Mining Empire - Main Game Manager
-- Handles core game loop, player initialization, and system coordination

local GameManager = {}
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- Data Store
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local leaderboardStore = DataStoreService:GetDataStore("Leaderboard_v1")

-- Player data structure
local function createDefaultPlayerData()
    return {
        -- Currency
        coins = 100,
        gems = 0,
        energy = 100,
        scrap = 0,
        brainrotShards = 0,
        
        -- Progression
        currentDepth = 0,
        maxDepth = 0,
        rebirthCount = 0,
        
        -- Upgrades
        drillPower = 1,
        miningSpeed = 1,
        luck = 1,
        backpackCapacity = 20,
        movementSpeed = 1,
        workerCount = 1,
        armySlots = 5,
        passiveIncomeMultiplier = 1,
        
        -- Army
        soldiers = {},
        workers = {},
        robots = {},
        
        -- Inventory
        inventory = {},
        collection = {},
        
        -- Unlocks
        unlockedZones = {"starter"},
        unlockedUpgrades = {},
        
        -- Last Save
        lastPlayed = os.time(),
        playtime = 0
    }
end

-- Load player data
local function loadPlayerData(player)
    local success, data = pcall(function()
        return playerDataStore:GetAsync(player.UserId)
    end)
    
    if success and data then
        return data
    else
        return createDefaultPlayerData()
    end
end

-- Save player data
local function savePlayerData(player, data)
    local success = pcall(function()
        playerDataStore:SetAsync(player.UserId, data)
    end)
    
    if success then
        print("Saved data for", player.Name)
    else
        warn("Failed to save data for", player.Name)
    end
end

-- Calculate offline earnings
local function calculateOfflineEarnings(data)
    local timeSinceLastPlay = os.time() - data.lastPlayed
    local maxOfflineHours = 24
    local offlineTime = math.min(timeSinceLastPlay / 3600, maxOfflineHours)
    
    -- Base passive income per second
    local passivePerSecond = 10 * data.passiveIncomeMultiplier * (1 + data.rebirthCount * 0.5)
    local offlineEarnings = math.floor(passivePerSecond * offlineTime * 3600)
    
    return offlineEarnings
end

-- Player joining
local function onPlayerAdded(player)
    print(player.Name .. " joined the game!")
    
    local data = loadPlayerData(player)
    
    -- Add offline earnings
    local offlineEarnings = calculateOfflineEarnings(data)
    data.coins = data.coins + offlineEarnings
    
    -- Store in player for easy access
    local playerFolder = Instance.new("Folder")
    playerFolder.Name = "PlayerData"
    playerFolder.Parent = player
    
    -- Create value objects for replication
    local coinsValue = Instance.new("IntValue")
    coinsValue.Name = "Coins"
    coinsValue.Value = data.coins
    coinsValue.Parent = playerFolder
    
    local depthValue = Instance.new("IntValue")
    depthValue.Name = "Depth"
    depthValue.Value = data.currentDepth
    depthValue.Parent = playerFolder
    
    local armySizeValue = Instance.new("IntValue")
    armySizeValue.Name = "ArmySize"
    armySizeValue.Value = #data.soldiers
    armySizeValue.Parent = playerFolder
    
    -- Store full data
    local dataValue = Instance.new("ObjectValue")
    dataValue.Name = "FullData"
    dataValue.Value = data
    dataValue.Parent = playerFolder
    
    savePlayerData(player, data)
end

-- Player leaving
local function onPlayerRemoving(player)
    print(player.Name .. " left the game")
    
    local playerFolder = player:FindFirstChild("PlayerData")
    if playerFolder then
        local dataValue = playerFolder:FindFirstChild("FullData")
        if dataValue and dataValue.Value then
            dataValue.Value.lastPlayed = os.time()
            savePlayerData(player, dataValue.Value)
        end
    end
end

-- Autosave loop
local function startAutosave()
    game:GetService("RunService").Heartbeat:Connect(function()
        -- Save every 30 seconds
        wait(30)
        for _, player in pairs(Players:GetPlayers()) do
            local playerFolder = player:FindFirstChild("PlayerData")
            if playerFolder then
                local dataValue = playerFolder:FindFirstChild("FullData")
                if dataValue and dataValue.Value then
                    savePlayerData(player, dataValue.Value)
                end
            end
        end
    end)
end

-- Initialize
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
startAutosave()

print("✅ Game Manager loaded")
return GameManager
