local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local PollinationService = {}
PollinationService.__index = PollinationService

local MONEY_FLOWER_LIFETIME = 60

function PollinationService.new(economyService)
    local self = setmetatable({}, PollinationService)
    self._economyService = economyService
    self._collectRemote = nil
    self._flowerFolder = workspace:FindFirstChild("MoneyFlowers") or Instance.new("Folder")
    self._flowerFolder.Name = "MoneyFlowers"
    self._flowerFolder.Parent = workspace
    self._flowerOwnership = {}
    return self
end

function PollinationService:BindRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
    remotes.Name = "RemoteEvents"
    remotes.Parent = ReplicatedStorage

    self._collectRemote = remotes:FindFirstChild("CollectFlower") or Instance.new("RemoteEvent")
    self._collectRemote.Name = "CollectFlower"
    self._collectRemote.Parent = remotes

    self._collectRemote.OnServerEvent:Connect(function(player, flower)
        self:CollectFlower(player, flower)
    end)
end

function PollinationService:EnsurePointValues(point)
    local bloom = point:FindFirstChild("Bloom") or Instance.new("NumberValue")
    bloom.Name = "Bloom"
    bloom.Value = bloom.Value > 0 and bloom.Value or 0
    bloom.Parent = point

    local multiplier = point:FindFirstChild("BloomRateMultiplier") or Instance.new("NumberValue")
    multiplier.Name = "BloomRateMultiplier"
    multiplier.Value = multiplier.Value > 0 and multiplier.Value or 1
    multiplier.Parent = point
end

function PollinationService:RegisterPlot(plot)
    local pointsFolder = plot:FindFirstChild("PollinationPoints")
    if not pointsFolder then
        return
    end

    for _, point in ipairs(pointsFolder:GetChildren()) do
        self:EnsurePointValues(point)
    end
end

function PollinationService:IncrementBloom(player, point, amount)
    if not point or not point:IsDescendantOf(workspace) then
        return
    end

    self:EnsurePointValues(point)

    local bloom = point.Bloom
    local multiplier = point.BloomRateMultiplier
    bloom.Value += amount * multiplier.Value

    if bloom.Value >= 100 then
        bloom.Value -= 100
        self:SpawnMoneyFlower(player, point)
    end
end

function PollinationService:GetSpawnPart(point)
    local plot = point:FindFirstAncestor("Plots") and point.Parent and point.Parent.Parent
    if not plot then
        plot = point:FindFirstAncestorOfClass("Model")
    end

    if plot then
        local spawnFolder = plot:FindFirstChild("MoneyFlowerSpawns")
        if spawnFolder and #spawnFolder:GetChildren() > 0 then
            local options = spawnFolder:GetChildren()
            return options[math.random(1, #options)]
        end
    end

    return point
end

function PollinationService:SpawnMoneyFlower(player, point)
    local spawnPart = self:GetSpawnPart(point)
    local flower = Instance.new("Part")
    flower.Name = "MoneyFlower"
    flower.Shape = Enum.PartType.Ball
    flower.Material = Enum.Material.Grass
    flower.Color = Color3.fromRGB(255, 225, 82)
    flower.Size = Vector3.new(1.6, 1.6, 1.6)
    flower.Anchored = true
    flower.CanCollide = false
    flower.CFrame = spawnPart.CFrame + Vector3.new(0, 2, 0)
    flower.Parent = self._flowerFolder

    local value = Instance.new("IntValue")
    value.Name = "Value"
    value.Value = 20
    value.Parent = flower

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "Collect"
    prompt.ObjectText = "Money Flower"
    prompt.ActionText = "Collect"
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = flower

    self._flowerOwnership[flower] = player.UserId

    prompt.Triggered:Connect(function(triggeringPlayer)
        self:CollectFlower(triggeringPlayer, flower)
    end)

    Debris:AddItem(flower, MONEY_FLOWER_LIFETIME)
end

function PollinationService:CollectFlower(player, flower)
    if typeof(flower) ~= "Instance" or flower.Name ~= "MoneyFlower" then
        return
    end

    if not flower:IsDescendantOf(self._flowerFolder) then
        return
    end

    local ownerId = self._flowerOwnership[flower]
    if ownerId and ownerId ~= player.UserId then
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local distance = (root.Position - flower.Position).Magnitude
    if distance > 15 then
        return
    end

    local valueObject = flower:FindFirstChild("Value")
    local value = valueObject and valueObject.Value or 0

    if value > 0 then
        self._economyService:AddCoins(player, value, "CollectFlower")
    end

    self._flowerOwnership[flower] = nil
    flower:Destroy()
end

return PollinationService
