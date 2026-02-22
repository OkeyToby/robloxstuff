local EconomyService = {}
EconomyService.__index = EconomyService

local UPGRADE_CONFIG = {
    SoilLevel = {
        baseCost = 150,
        growth = 1.45,
        maxLevel = 20,
    },
    HiveLevel = {
        baseCost = 300,
        growth = 1.6,
        maxLevel = 10,
    },
    ZoneLevel = {
        baseCost = 800,
        growth = 2.0,
        maxLevel = 3,
    },
}

function EconomyService.new(dataService)
    local self = setmetatable({}, EconomyService)
    self._dataService = dataService
    return self
end

function EconomyService:GetCoins(player)
    local profile = self._dataService:GetProfile(player)
    return profile and profile.Coins or 0
end

function EconomyService:AddCoins(player, amount, reason)
    if amount <= 0 then
        return false
    end

    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false
    end

    profile.Coins += math.floor(amount)
    if reason then
        print(string.format("[Economy] %s +%d coins (%s)", player.Name, amount, reason))
    end

    return true, profile.Coins
end

function EconomyService:TrySpendCoins(player, amount)
    if amount <= 0 then
        return false
    end

    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false
    end

    if profile.Coins < amount then
        return false
    end

    profile.Coins -= amount
    return true, profile.Coins
end

function EconomyService:GetUpgradeCost(profile, upgradeName)
    local config = UPGRADE_CONFIG[upgradeName]
    if not config then
        return nil
    end

    local level = profile.Upgrades[upgradeName] or 1
    local rawCost = config.baseCost * (config.growth ^ (level - 1))
    return math.floor(rawCost)
end

function EconomyService:BuyUpgrade(player, upgradeName)
    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false, "Missing profile"
    end

    local config = UPGRADE_CONFIG[upgradeName]
    if not config then
        return false, "Unknown upgrade"
    end

    local level = profile.Upgrades[upgradeName] or 1
    if level >= config.maxLevel then
        return false, "Max level reached"
    end

    local cost = self:GetUpgradeCost(profile, upgradeName)
    if profile.Coins < cost then
        return false, "Not enough coins"
    end

    profile.Coins -= cost
    profile.Upgrades[upgradeName] = level + 1

    return true, {
        coins = profile.Coins,
        newLevel = profile.Upgrades[upgradeName],
        spent = cost,
    }
end

return EconomyService
