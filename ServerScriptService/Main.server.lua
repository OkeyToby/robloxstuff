local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(ReplicatedStorage.Modules.DataService)
local EconomyService = require(ReplicatedStorage.Modules.EconomyService)
local PollinationService = require(ReplicatedStorage.Modules.PollinationService)
local BeeService = require(ReplicatedStorage.Modules.BeeService)
local SpinService = require(ReplicatedStorage.Modules.SpinService)

local dataService = DataService.new()
local economyService = EconomyService.new(dataService)
local pollinationService = PollinationService.new(economyService)
local beeService = BeeService.new(dataService, pollinationService)
local spinService = SpinService.new(dataService, economyService)

local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name) or Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function disableLegacyCashScripts()
    local keywords = { "cash", "drop", "collector", "moneydrop" }

    local function shouldDisable(name)
        local lowered = string.lower(name)
        for _, keyword in ipairs(keywords) do
            if string.find(lowered, keyword, 1, true) then
                return true
            end
        end
        return false
    end

    local containers = { workspace, game:GetService("ServerScriptService") }
    for _, container in ipairs(containers) do
        for _, item in ipairs(container:GetDescendants()) do
            if (item:IsA("Script") or item:IsA("LocalScript")) and shouldDisable(item.Name) then
                item.Enabled = false
            end
        end
    end
end

local function createForestThemePlaceholders()
    local decor = workspace:FindFirstChild("ForestTheme") or Instance.new("Folder")
    decor.Name = "ForestTheme"
    decor.Parent = workspace

    if #decor:GetChildren() > 0 then
        return
    end

    for i = 1, 12 do
        local trunk = Instance.new("Part")
        trunk.Name = "TreeTrunk"
        trunk.Size = Vector3.new(2, 10, 2)
        trunk.Position = Vector3.new(math.random(-120, 120), 5, math.random(-120, 120))
        trunk.Material = Enum.Material.Wood
        trunk.Color = Color3.fromRGB(120, 78, 45)
        trunk.Anchored = true
        trunk.Parent = decor

        local crown = Instance.new("Part")
        crown.Name = "TreeCrown"
        crown.Shape = Enum.PartType.Ball
        crown.Size = Vector3.new(8, 8, 8)
        crown.Position = trunk.Position + Vector3.new(0, 7, 0)
        crown.Material = Enum.Material.Grass
        crown.Color = Color3.fromRGB(50, 130, 58)
        crown.Anchored = true
        crown.Parent = decor
    end
end

local function setupLeaderstats(player)
    local profile = dataService:GetProfile(player)
    if not profile then
        return
    end

    local leaderstats = ensureFolder(player, "leaderstats")
    local coins = leaderstats:FindFirstChild("Coins") or Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = profile.Coins
    coins.Parent = leaderstats

    local beePower = leaderstats:FindFirstChild("BeePower") or Instance.new("NumberValue")
    beePower.Name = "BeePower"
    beePower.Value = #profile.EquippedBeeIds
    beePower.Parent = leaderstats
end

local function bindPlayer(player)
    if not dataService:GetProfile(player) then
        dataService:LoadProfile(player)
    end

    setupLeaderstats(player)

    player.CharacterAdded:Connect(function()
        beeService:EnsureBeeState(player)
    end)
end

local function bindRemotes()
    local remotes = ensureFolder(ReplicatedStorage, "RemoteEvents")

    local buyUpgrade = remotes:FindFirstChild("BuyUpgrade") or Instance.new("RemoteEvent")
    buyUpgrade.Name = "BuyUpgrade"
    buyUpgrade.Parent = remotes

    local equipBee = remotes:FindFirstChild("EquipBee") or Instance.new("RemoteEvent")
    equipBee.Name = "EquipBee"
    equipBee.Parent = remotes

    local sync = remotes:FindFirstChild("SyncEconomy") or Instance.new("RemoteEvent")
    sync.Name = "SyncEconomy"
    sync.Parent = remotes

    buyUpgrade.OnServerEvent:Connect(function(player, upgradeName)
        local success, payload = economyService:BuyUpgrade(player, upgradeName)
        sync:FireClient(player, success, payload)
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats and leaderstats:FindFirstChild("Coins") then
            leaderstats.Coins.Value = economyService:GetCoins(player)
        end
    end)

    equipBee.OnServerEvent:Connect(function(player, beeIds)
        if type(beeIds) ~= "table" then
            return
        end

        local equipped = beeService:SetEquippedBees(player, beeIds)
        if equipped then
            beeService:EnsureBeeState(player)
        end
    end)

    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            while player.Parent do
                task.wait(1)
                local leaderstats = player:FindFirstChild("leaderstats")
                if leaderstats and leaderstats:FindFirstChild("Coins") then
                    leaderstats.Coins.Value = economyService:GetCoins(player)
                    sync:FireClient(player, true, {
                        coins = leaderstats.Coins.Value,
                        ownedBees = dataService:GetProfile(player).OwnedBees,
                        equippedBees = beeService:GetEquippedBees(player),
                    })
                end
            end
        end)
    end)
end

disableLegacyCashScripts()
createForestThemePlaceholders()
dataService:BindPlayerEvents()
pollinationService:BindRemotes()
spinService:BindRemotes()
bindRemotes()
beeService:Start()

for _, player in ipairs(Players:GetPlayers()) do
    bindPlayer(player)
end
Players.PlayerAdded:Connect(bindPlayer)
