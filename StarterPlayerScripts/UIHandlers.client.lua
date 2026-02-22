local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

local syncEconomy = remotes:WaitForChild("SyncEconomy")
local requestSpin = remotes:WaitForChild("RequestSpin")
local spinResult = remotes:WaitForChild("SpinResult")
local equipBee = remotes:WaitForChild("EquipBee")

local gui = Instance.new("ScreenGui")
gui.Name = "BeeForestUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local coinLabel = Instance.new("TextLabel")
coinLabel.Size = UDim2.fromOffset(260, 40)
coinLabel.Position = UDim2.fromOffset(16, 16)
coinLabel.Text = "Coins: 0"
coinLabel.TextScaled = true
coinLabel.BackgroundTransparency = 0.2
coinLabel.BackgroundColor3 = Color3.fromRGB(29, 61, 38)
coinLabel.TextColor3 = Color3.new(1, 1, 1)
coinLabel.Parent = gui

local spinButton = Instance.new("TextButton")
spinButton.Size = UDim2.fromOffset(180, 45)
spinButton.Position = UDim2.fromOffset(16, 66)
spinButton.Text = "Spin Wheel (250)"
spinButton.TextScaled = true
spinButton.BackgroundColor3 = Color3.fromRGB(227, 195, 63)
spinButton.TextColor3 = Color3.fromRGB(30, 30, 30)
spinButton.Parent = gui

local beeButton = Instance.new("TextButton")
beeButton.Size = UDim2.fromOffset(180, 45)
beeButton.Position = UDim2.fromOffset(16, 116)
beeButton.Text = "Equip Basic Bee"
beeButton.TextScaled = true
beeButton.BackgroundColor3 = Color3.fromRGB(104, 170, 69)
beeButton.TextColor3 = Color3.fromRGB(30, 30, 30)
beeButton.Parent = gui

local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.fromOffset(350, 50)
resultLabel.Position = UDim2.fromOffset(16, 170)
resultLabel.Text = ""
resultLabel.TextScaled = true
resultLabel.BackgroundTransparency = 1
resultLabel.TextColor3 = Color3.new(1, 1, 1)
resultLabel.Parent = gui

spinButton.MouseButton1Click:Connect(function()
    requestSpin:FireServer()
end)

beeButton.MouseButton1Click:Connect(function()
    equipBee:FireServer({ "BasicBee" })
end)

syncEconomy.OnClientEvent:Connect(function(success, payload)
    if not success or type(payload) ~= "table" then
        return
    end

    if payload.coins then
        coinLabel.Text = string.format("Coins: %d", payload.coins)
    end
end)

spinResult.OnClientEvent:Connect(function(success, payload)
    if not success then
        resultLabel.Text = "Spin failed: " .. tostring(payload)
        return
    end

    local reward = payload.reward
    if reward.kind == "coins" then
        resultLabel.Text = string.format("Spin reward: +%d coins!", reward.amount)
    elseif reward.kind == "bee" then
        resultLabel.Text = "Spin reward: New Bee " .. reward.beeId
    elseif reward.kind == "boost" then
        resultLabel.Text = "Spin reward: 2x Bloom boost"
    elseif reward.kind == "cosmetic" then
        resultLabel.Text = "Spin reward: Cosmetic " .. reward.cosmeticId
    end

    if payload.coins then
        coinLabel.Text = string.format("Coins: %d", payload.coins)
    end
end)
