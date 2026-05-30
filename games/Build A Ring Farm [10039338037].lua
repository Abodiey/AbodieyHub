-- Set the script ID globally once (no need to call getgenv again anywhere else)
getgenv().ScriptID = os.clock()
local CurrentScriptID = ScriptID

-- 1. Load the Seeds Data Table for Auto Roll/Buy
local Seeds = loadstring(game:HttpGet("https://raw.githubusercontent.com/Abodiey/AbodieyHub/refs/heads/main/helpers/Build%20A%20Ring%20Farm%20%5B10039338037%5D.lua"))()

-- Load Rayfield Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Base Setup
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CollectionService = cloneref(game:GetService("CollectionService"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local Players = cloneref(game:GetService("Players"))
local Player = Players.LocalPlayer
local character = Player.Character or Player.CharacterAdded:Wait()
local root = character:FindFirstChild("HumanoidRootPart")

-- Folder, Remote & Map References
local Honeycombs = workspace.InteractiveEvents.QueenBee.RuntimeHoneycombs
local SellEvent = ReplicatedStorage.Remotes.SellCrates
local ShootRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlantRush"):WaitForChild("Shoot")
local RuntimeFolder = workspace:WaitForChild("InteractiveEvents").PlantRush.Runtime
local rollPrompt = workspace.Map.Plots:FindFirstChild("RollSeeds", true)

-- Fast local variables for toggles
local autoSellEnabled = true
local autoHoneycombEnabled = true
local autoShootEnabled = true
local autoRollEnabled = false
local autoBuyEnabled = false
local disableManualRoll = false
local disableManualBuy = false
local antiAfkEnabled = true

-- Shared State Tracker & Cache for Seeds
local AutoRollIndex = 1 
local goodSeedPresent = false 
local activeGoodSeeds = {}

-- Pre-order seed data array keys to cleanly extract length
local OrderedSeeds = {}
if Seeds then
    for seedName, seedData in pairs(Seeds) do
        local idx = tonumber(seedData.index)
        if idx then
            OrderedSeeds[idx] = seedName
        end
    end
end

Player.CharacterAdded:Connect(function(char)
    character = char
    root = char:WaitForChild("HumanoidRootPart")
end)

-- Helper function to find the first valid shootout target
local function getShootTarget()
    for _, child in ipairs(RuntimeFolder:GetChildren()) do
        local rootPart = child:FindFirstChild("HumanoidRootPart")
        if rootPart then
            return rootPart
        end
    end
end

-- Helper to check if seed qualifies
local function isGoodSeed(seedName)
    if not Seeds then return false end
    local seedData = Seeds[seedName]
    return seedData and seedData.index > AutoRollIndex
end

-- Cache Management for Seeds
local function onSeedAdded(instance)
    if isGoodSeed(instance.Name) then
        activeGoodSeeds[instance] = true
        
        -- Misclick Protection: Instantly disable the prompt if user requested it
        if disableManualBuy then
            local buyPrompt = instance:FindFirstChild("BuySeed", true)
            if buyPrompt then buyPrompt.Enabled = false end
        end
    end
end

CollectionService:GetInstanceAddedSignal("FloatSeed"):Connect(onSeedAdded)
CollectionService:GetInstanceRemovedSignal("FloatSeed"):Connect(function(instance)
    activeGoodSeeds[instance] = nil
end)

-- Anti AFK Setup (VirtualUser prevents IDLE kick)
local VirtualUser = cloneref(game:GetService("VirtualUser"))
Player.Idled:Connect(function()
    if antiAfkEnabled and ScriptID == CurrentScriptID then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Create Rayfield Window
local Window = Rayfield:CreateWindow({
    Name = "Farm Hub",
    LoadingTitle = "Loading Script...",
    LoadingSubtitle = "by User",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

-- Single Tab Consolidation
local MainTab = Window:CreateTab("Main Hub", 4483362458)

-- ==========================================
-- RUNTIME LOOPS
-- ==========================================

-- LOOP 1: Auto Sell Loop
local function startAutoSell()
    task.spawn(function()
        while autoSellEnabled and ScriptID == CurrentScriptID do
            SellEvent:FireServer()
            task.wait(1)
        end
    end)
end

-- LOOP 2: Auto Farm Loop (Honeycombs & Plant Drops)
local function startAutoFarm()
    task.spawn(function()
        local previousCFrame = nil

        while autoHoneycombEnabled and ScriptID == CurrentScriptID do
            if not root or not root.Parent then task.wait(0.5) continue end

            local targetPrompt = nil

            -- Priority 1: Look for Plant Drop
            for _, child in pairs(workspace:GetChildren()) do
                if string.find(child.Name, "PlantRushLocalDrop") then
                    targetPrompt = child:FindFirstChild("ProximityPrompt")
                    if targetPrompt then break end
                end
            end

            -- Priority 2: Look for Honeycomb (Using updated fixed path structure)
            if not targetPrompt then
                for _, hc in pairs(Honeycombs:GetChildren()) do
                    local honeycombPart = hc:FindFirstChild("Honeycomb")
                    if honeycombPart then
                        targetPrompt = honeycombPart:FindFirstChild("CollectPrompt") or honeycombPart:FindFirstChild("ProximityPrompt")
                        if targetPrompt then break end
                    end
                end
            end

            if targetPrompt and targetPrompt.Parent then
                if not previousCFrame then
                    previousCFrame = root.CFrame
                end

                root.CFrame = CFrame.new(targetPrompt.Parent.Position) * root.CFrame.Rotation
                task.wait(0.2)
                fireproximityprompt(targetPrompt)
                task.wait(0.1)
            else
                if previousCFrame then
                    root.CFrame = previousCFrame
                    previousCFrame = nil
                    task.wait(0.2)
                end
                task.wait(0.1)
            end
        end
    end)
end

-- LOOP 3: Auto Shoot Loop
local function startAutoShoot()
    task.spawn(function()
        while autoShootEnabled and ScriptID == CurrentScriptID do
            local targetPart = getShootTarget()
            if targetPart and targetPart.Parent then
                local pos = targetPart.Position
                ShootRemote:FireServer(pos, Vector3.new(0, 1, 0), pos)
            end
            task.wait() 
        end
    end)
end

-- LOOP 4: Auto Roll Loop
local function startAutoRoll()
    task.spawn(function()
        while autoRollEnabled and ScriptID == CurrentScriptID do
            local hasSeeds = next(activeGoodSeeds) ~= nil
            
            if hasSeeds and not goodSeedPresent then
                goodSeedPresent = true
            elseif not hasSeeds and goodSeedPresent then
                goodSeedPresent = false
            end
            
            if not goodSeedPresent and rollPrompt then
                -- Direct automated script access ignores prompt execution blocks
                fireproximityprompt(rollPrompt)
            end
            
            task.wait(0.3)
        end
    end)
end

-- LOOP 5: Auto Buy Loop
local function startAutoBuy()
    task.spawn(function()
        while autoBuyEnabled and ScriptID == CurrentScriptID do
            for targetSeed, _ in pairs(activeGoodSeeds) do
                if targetSeed and targetSeed.Parent then
                    -- Adaptive structural parsing logic for seed model definitions
                    local buyPrompt = nil
                    
                    local union = targetSeed:FindFirstChild("Union")
                    if union then buyPrompt = union:FindFirstChild("BuySeed") end
                    
                    if not buyPrompt then
                        local fruit = targetSeed:FindFirstChild("Fruit")
                        if fruit then buyPrompt = fruit:FindFirstChild("BuySeed") end
                    end
                    
                    if not buyPrompt then
                        buyPrompt = targetSeed:FindFirstChild("BuySeed", true)
                    end
                    
                    if buyPrompt and buyPrompt:IsA("ProximityPrompt") then
                        fireproximityprompt(buyPrompt)
                    end
                else
                    activeGoodSeeds[targetSeed] = nil 
                end
            end
            task.wait(0.1)
        end
    end)
end

-- ==========================================
-- SINGLE TAB UI LAYOUT WITH SEPARATORS
-- ==========================================

MainTab:CreateSection("--- Main Farming Features ---")

MainTab:CreateToggle({
    Name = "Auto Sell",
    CurrentValue = autoSellEnabled,
    Flag = "AutoSellToggle",
    Callback = function(Value)
        autoSellEnabled = Value
        if Value then startAutoSell() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Farm Honey/Plants",
    CurrentValue = autoHoneycombEnabled,
    Flag = "AutoFarmToggle",
    Callback = function(Value)
        autoHoneycombEnabled = Value
        if Value then startAutoFarm() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Shoot Plants",
    CurrentValue = autoShootEnabled,
    Flag = "AutoShootToggle",
    Callback = function(Value)
        autoShootEnabled = Value
        if Value then startAutoShoot() end
    end,
})

MainTab:CreateSection("--- Seed Operations ---")

MainTab:CreateToggle({
    Name = "Auto Roll Seeds",
    CurrentValue = autoRollEnabled,
    Flag = "AutoRollToggle",
    Callback = function(Value)
        autoRollEnabled = Value
        if Value then startAutoRoll() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Buy Seeds",
    CurrentValue = autoBuyEnabled,
    Flag = "AutoBuyToggle",
    Callback = function(Value)
        autoBuyEnabled = Value
        if Value then startAutoBuy() end
    end,
})

-- Dynamic Label tracking your selections safely
local RarityLabel = MainTab:CreateLabel("Selected Min Tier: None")

-- Core Slider Logic Handler Function
local function handleSliderUpdate(Value)
    AutoRollIndex = Value
    
    local seedName = OrderedSeeds[Value]
    local seedData = seedName and Seeds and Seeds[seedName]
    
    if seedData and seedName then
        local rarity = seedData.rarity or "Unknown"
        RarityLabel:Set("Selected Min Tier: " .. seedName .. " [" .. rarity .. "]")
    else
        RarityLabel:Set("Selected Min Tier: Index " .. tostring(Value))
    end

    table.clear(activeGoodSeeds)
    for _, instance in ipairs(CollectionService:GetTagged("FloatSeed")) do
        onSeedAdded(instance)
    end
end

-- Auto Roll Index Slider Element using Range parameter configuration
local maxRange = #OrderedSeeds > 0 and #OrderedSeeds or 1
MainTab:CreateSlider({
    Name = "Min Roll Rarity Index",
    Range = {1, maxRange},
    Increment = 1,
    CurrentValue = AutoRollIndex,
    Flag = "RollIndexSlider",
    Callback = handleSliderUpdate,
})

MainTab:CreateSection("--- Protection & Safety ---")

MainTab:CreateToggle({
    Name = "Disable Manual Roll Interaction",
    CurrentValue = disableManualRoll,
    Flag = "DisableRollToggle",
    Callback = function(Value)
        disableManualRoll = Value
        if rollPrompt then
            rollPrompt.Enabled = not Value
        end
    end,
})

MainTab:CreateToggle({
    Name = "Disable Manual Buy Interaction",
    CurrentValue = disableManualBuy,
    Flag = "DisableBuyToggle",
    Callback = function(Value)
        disableManualBuy = Value
        -- Dynamically cycle map elements to toggle prompt visibility
        for _, instance in ipairs(CollectionService:GetTagged("FloatSeed")) do
            local buyPrompt = instance:FindFirstChild("BuySeed", true)
            if buyPrompt then
                buyPrompt.Enabled = not Value
            end
        end
    end,
})

MainTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = antiAfkEnabled,
    Flag = "AntiAfkToggle",
    Callback = function(Value)
        antiAfkEnabled = Value
    end,
})

MainTab:CreateSection("--- Utilities ---")

MainTab:CreateButton({
    Name = "Teleport to Plot",
    Callback = function()
        if not rollPrompt then 
            Rayfield:Notify({Title = "Error", Content = "RollSeeds prompt not found on the map!", Duration = 3})
            return 
        end
        if not root or not root.Parent then return end

        -- Climb ancestors until the parent is workspace.Plots
        local plotsFolder = workspace.Map.Plots
        local current = rollPrompt
        local plot = nil

        while current and current ~= workspace do
            if current.Parent == plotsFolder then
                plot = current
                break
            end
            current = current.Parent
        end

        if plot then
            local spawnPoint = plot:FindFirstChild("OwnerSpawnPoint", true)
            if spawnPoint and spawnPoint:IsA("Attachment") then
                root.CFrame = spawnPoint.WorldCFrame
            elseif spawnPoint and spawnPoint:IsA("BasePart") then
                root.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0)
            else
                Rayfield:Notify({Title = "Error", Content = "OwnerSpawnPoint structure missing from plot!", Duration = 3})
            end
        else
            Rayfield:Notify({Title = "Error", Content = "Could not track down your plot instance!", Duration = 3})
        end
    end,
})

MainTab:CreateButton({
    Name = "Equip Best Seed",
    Callback = function()
        if not Seeds then return end
        
        local currentCharacter = Player.Character or character
        local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
        local backpack = Player:FindFirstChild("Backpack")
        
        if not humanoid or not backpack then return end
        
        local bestTool = nil
        local highestIndex = -1

        local function scanContainer(container)
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    for index = 1, #OrderedSeeds do
                        local seedName = OrderedSeeds[index]
                        if seedName and string.find(tool.Name, "^" .. seedName) and index > highestIndex then
                            highestIndex = index
                            bestTool = tool
                            break
                        end
                    end
                end
            end
        end

        scanContainer(backpack)
        scanContainer(currentCharacter)

        if bestTool and bestTool.Parent ~= currentCharacter then
            humanoid:EquipTool(bestTool)
        end
    end,
})

MainTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        if #Players:GetPlayers() <= 1 then
            TeleportService:Teleport(game.PlaceId, Player)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
        end
    end,
})

-- Run initial configuration rules explicitly at setup time
handleSliderUpdate(AutoRollIndex)

-- Fire default executing threads automatically at load time
startAutoSell()
startAutoFarm()
startAutoShoot()
