local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DataService = {}
DataService.__index = DataService

local PROFILE_STORE = DataStoreService:GetDataStore("BeeForestPollinationProfiles_v1")

local DEFAULT_PROFILE = {
    Coins = 0,
    EquippedBeeIds = { "BasicBee" },
    OwnedBees = {
        BasicBee = true,
    },
    Upgrades = {
        SoilLevel = 1,
        HiveLevel = 1,
        ZoneLevel = 1,
    },
    Boosts = {},
}

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, nested in pairs(value) do
        clone[key] = deepCopy(nested)
    end
    return clone
end

function DataService.new()
    local self = setmetatable({}, DataService)
    self._profiles = {}
    return self
end

function DataService:GetProfile(player)
    return self._profiles[player]
end

function DataService:LoadProfile(player)
    local key = string.format("user_%d", player.UserId)
    local success, data = pcall(function()
        return PROFILE_STORE:GetAsync(key)
    end)

    if not success then
        warn("[DataService] Failed to load profile for", player.UserId, data)
    end

    local profile = deepCopy(DEFAULT_PROFILE)
    if type(data) == "table" then
        for keyName, value in pairs(data) do
            profile[keyName] = value
        end
    end

    self._profiles[player] = profile
    return profile
end

function DataService:SaveProfile(player)
    local profile = self._profiles[player]
    if not profile then
        return
    end

    local key = string.format("user_%d", player.UserId)
    local success, err = pcall(function()
        PROFILE_STORE:SetAsync(key, profile)
    end)

    if not success then
        warn("[DataService] Failed to save profile for", player.UserId, err)
    end
end

function DataService:BindPlayerEvents()
    Players.PlayerAdded:Connect(function(player)
        self:LoadProfile(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        self:SaveProfile(player)
        self._profiles[player] = nil
    end)

    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            self:SaveProfile(player)
        end
    end)
end

return DataService
