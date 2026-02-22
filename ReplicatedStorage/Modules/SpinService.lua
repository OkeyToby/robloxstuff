local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpinService = {}
SpinService.__index = SpinService

local SPIN_COST = 250
local BOOST_DURATION = 120

local REWARDS = {
    { kind = "coins", amount = 100, weight = 35 },
    { kind = "coins", amount = 350, weight = 20 },
    { kind = "boost", boost = "Bloom2x", seconds = BOOST_DURATION, weight = 20 },
    { kind = "bee", beeId = "ForestBee", weight = 15 },
    { kind = "bee", beeId = "RiverBee", weight = 7 },
    { kind = "cosmetic", cosmeticId = "PollenTrail", weight = 3 },
}

function SpinService.new(dataService, economyService)
    local self = setmetatable({}, SpinService)
    self._dataService = dataService
    self._economyService = economyService
    self._spinRemote = nil
    self._resultRemote = nil
    return self
end

function SpinService:BindRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
    remotes.Name = "RemoteEvents"
    remotes.Parent = ReplicatedStorage

    self._spinRemote = remotes:FindFirstChild("RequestSpin") or Instance.new("RemoteEvent")
    self._spinRemote.Name = "RequestSpin"
    self._spinRemote.Parent = remotes

    self._resultRemote = remotes:FindFirstChild("SpinResult") or Instance.new("RemoteEvent")
    self._resultRemote.Name = "SpinResult"
    self._resultRemote.Parent = remotes

    self._spinRemote.OnServerEvent:Connect(function(player)
        local success, payload = self:HandleSpin(player)
        self._resultRemote:FireClient(player, success, payload)
    end)
end

function SpinService:PickReward()
    local totalWeight = 0
    for _, reward in ipairs(REWARDS) do
        totalWeight += reward.weight
    end

    local pick = math.random() * totalWeight
    local cumulative = 0

    for _, reward in ipairs(REWARDS) do
        cumulative += reward.weight
        if pick <= cumulative then
            return reward
        end
    end

    return REWARDS[1]
end

function SpinService:HandleSpin(player)
    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false, "Missing profile"
    end

    local spent = self._economyService:TrySpendCoins(player, SPIN_COST)
    if not spent then
        return false, "Not enough coins"
    end

    local reward = self:PickReward()

    if reward.kind == "coins" then
        self._economyService:AddCoins(player, reward.amount, "SpinReward")
    elseif reward.kind == "boost" then
        profile.Boosts[reward.boost] = os.time() + reward.seconds
    elseif reward.kind == "bee" then
        profile.OwnedBees[reward.beeId] = true
    elseif reward.kind == "cosmetic" then
        profile.Cosmetic = reward.cosmeticId
    end

    return true, {
        reward = reward,
        coins = profile.Coins,
        spinCost = SPIN_COST,
    }
end

return SpinService
