local RunService = game:GetService("RunService")

local BeeService = {}
BeeService.__index = BeeService

local BEE_DEFS = {
    BasicBee = { Power = 2.5, Speed = 12, Capacity = 8, Color = Color3.fromRGB(255, 213, 70) },
    ForestBee = { Power = 4, Speed = 14, Capacity = 10, Color = Color3.fromRGB(255, 176, 64) },
    RiverBee = { Power = 6, Speed = 16, Capacity = 12, Color = Color3.fromRGB(137, 226, 255) },
}

function BeeService.new(dataService, pollinationService)
    local self = setmetatable({}, BeeService)
    self._dataService = dataService
    self._pollinationService = pollinationService
    self._beeStates = {}
    self._accumulator = 0
    return self
end

function BeeService:GetBeeDefinition(beeId)
    return BEE_DEFS[beeId] or BEE_DEFS.BasicBee
end

function BeeService:GetEquippedBees(player)
    local profile = self._dataService:GetProfile(player)
    if not profile then
        return { "BasicBee" }
    end

    return profile.EquippedBeeIds or { "BasicBee" }
end

function BeeService:SetEquippedBees(player, beeIds)
    local profile = self._dataService:GetProfile(player)
    if not profile then
        return false
    end

    local sanitized = {}
    for _, beeId in ipairs(beeIds) do
        if profile.OwnedBees[beeId] then
            table.insert(sanitized, beeId)
        end
    end

    if #sanitized == 0 then
        table.insert(sanitized, "BasicBee")
    end

    profile.EquippedBeeIds = sanitized
    self._beeStates[player] = nil
    return true
end

function BeeService:GetPollinationPoints(player)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return {}
    end

    local plot = plots:FindFirstChild(player.Name)
    if not plot then
        return {}
    end

    local pointsFolder = plot:FindFirstChild("PollinationPoints")
    if not pointsFolder then
        return {}
    end

    return pointsFolder:GetChildren()
end

function BeeService:CreateBeeVisual(player, beeId, index)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local def = self:GetBeeDefinition(beeId)
    local part = Instance.new("Part")
    part.Name = string.format("%s_%d", beeId, index)
    part.Size = Vector3.new(1, 0.6, 1)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = def.Color
    part.CFrame = root.CFrame * CFrame.new(index * 1.5, 3, -2)
    part.Parent = workspace
    return part
end

function BeeService:EnsureBeeState(player)
    if self._beeStates[player] then
        return self._beeStates[player]
    end

    local bees = {}
    for index, beeId in ipairs(self:GetEquippedBees(player)) do
        table.insert(bees, {
            id = beeId,
            pollinated = 0,
            target = nil,
            visual = self:CreateBeeVisual(player, beeId, index),
        })
    end

    local state = { bees = bees }
    self._beeStates[player] = state
    return state
end

function BeeService:GetIdleAnchor(player, index)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local angle = (index / 6) * math.pi * 2
    local offset = Vector3.new(math.cos(angle) * 4, 3 + math.sin(os.clock() * 2), math.sin(angle) * 4)
    return root.Position + offset
end

function BeeService:StepBee(player, bee, dt, index)
    if not bee.visual or not bee.visual.Parent then
        bee.visual = self:CreateBeeVisual(player, bee.id, index)
        if not bee.visual then
            return
        end
    end

    local points = self:GetPollinationPoints(player)
    if #points == 0 then
        local idlePos = self:GetIdleAnchor(player, index)
        if idlePos then
            bee.visual.Position = bee.visual.Position:Lerp(idlePos, math.clamp(dt * 6, 0, 1))
        end
        return
    end

    if not bee.target or not bee.target:IsDescendantOf(workspace) then
        bee.target = points[math.random(1, #points)]
    end

    local def = self:GetBeeDefinition(bee.id)
    local targetPosition = bee.target.Position + Vector3.new(0, 2.5, 0)
    local alpha = math.clamp((def.Speed * dt) / math.max((bee.visual.Position - targetPosition).Magnitude, 0.2), 0, 1)
    bee.visual.Position = bee.visual.Position:Lerp(targetPosition, alpha)

    if (bee.visual.Position - targetPosition).Magnitude < 1.5 then
        self._pollinationService:IncrementBloom(player, bee.target, def.Power * dt)
        bee.pollinated += def.Power * dt

        if bee.pollinated >= def.Capacity then
            bee.pollinated = 0
            bee.target = nil
        end
    end
end

function BeeService:Start()
    RunService.Heartbeat:Connect(function(dt)
        self._accumulator += dt
        if self._accumulator < 0.1 then
            return
        end

        dt = self._accumulator
        self._accumulator = 0

        for player, state in pairs(self._beeStates) do
            if not player.Parent then
                self._beeStates[player] = nil
            else
                for index, bee in ipairs(state.bees) do
                    self:StepBee(player, bee, dt, index)
                end
            end
        end
    end)
end

return BeeService
