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
local RemovePlantEvent = ReplicatedStorage.Remotes.RemovePlant
local ShootRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlantRush"):WaitForChild("Shoot")
local RuntimeFolder = workspace:WaitForChild("InteractiveEvents").PlantRush.Runtime
local rollPrompt = workspace.Map.Plots:FindFirstChild("RollSeeds", true)

-- Constant Plot Tracking setup immediately after rollPrompt
local plot = nil
if rollPrompt then
    local plotsFolder = workspace.Map.Plots
    local current = rollPrompt
    while current and current ~= workspace do
        if current.Parent == plotsFolder then
            plot = current
            break
        end
        current = current.Parent
    end
end

-- Fast local variables for toggles
local autoSellEnabled = true
local autoHoneycombEnabled = true
local autoShootEnabled = true
local autoRollEnabled = false
local autoBuyEnabled = false
local autoEquipEnabled = false
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

-- Core Smart Equip Logic (Used by both button and auto-loop)
local function equipBestSeed()
    if not Seeds then return end
    
    local currentCharacter = Player.Character or character
    local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
    local backpack = Player:FindFirstChild("Backpack")
    
    if not humanoid or not backpack then return end
    
    local bestTool = nil
    local highestIndex = -1
    local lowestCount = math.huge

    local function scanContainer(container)
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and string.find(tool.Name, "Seed") then
                for index = 1, #OrderedSeeds do
                    local seedName = OrderedSeeds[index]
                    if seedName and string.find(tool.Name, "^" .. seedName) then
                        -- Extract seed quantity count from syntax: (x5) -> 5. Fallback to 1 if not parsed.
                        local countStr = string.match(tool.Name, "%(x(%d+)%)")
                        local seedCount = countStr and tonumber(countStr) or 1
                        
                        -- Prioritization checklist logic
                        if index > highestIndex then
                            highestIndex = index
                            lowestCount = seedCount
                            bestTool = tool
                        elseif index == highestIndex then
                            -- Same rarity tier, prioritize the item variant with the lower count
                            if seedCount < lowestCount then
                                lowestCount = seedCount
                                bestTool = tool
                            end
                        end
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
end

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

            -- Priority 2: Look for Honeycomb
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

-- LOOP 6: Auto Equip Best Seed Loop
local function startAutoEquip()
    task.spawn(function()
        while autoEquipEnabled and ScriptID == CurrentScriptID do
            equipBestSeed()
            task.wait(1)
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

MainTab:CreateToggle({
    Name = "Auto Equip Best Seed",
    CurrentValue = autoEquipEnabled,
    Flag = "AutoEquipToggle",
    Callback = function(Value)
        autoEquipEnabled = Value
        if Value then startAutoEquip() end
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
    Name = "Equip Best Seed",
    Callback = equipBestSeed,
})

MainTab:CreateButton({
    Name = "Teleport to Plot",
    Callback = function()
        if not plot then 
            Rayfield:Notify({Title = "Error", Content = "Your Plot instance could not be determined at startup!", Duration = 3})
            return 
        end
        if not root or not root.Parent then return end

        local spawnPoint = plot:FindFirstChild("OwnerSpawnPoint", true)
        if spawnPoint and spawnPoint:IsA("Attachment") then
            root.CFrame = spawnPoint.WorldCFrame
        elseif spawnPoint and spawnPoint:IsA("BasePart") then
            root.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0)
        else
            Rayfield:Notify({Title = "Error", Content = "OwnerSpawnPoint structure missing from plot!", Duration = 3})
        end
    end,
})

MainTab:CreateButton({
    Name = "Clear All Plants",
    Callback = function()
        if not plot then
            Rayfield:Notify({Title = "Error", Content = "Plot not found, cannot clear plants!", Duration = 3})
            return
        end

        local farmPlot = plot:FindFirstChild("FarmPlot")
        if not farmPlot then
            Rayfield:Notify({Title = "Error", Content = "FarmPlot folder missing from your plot!", Duration = 3})
            return
        end

        task.spawn(function()
            local x = -1
            while x ~= 0 do
                x = 0
                for _, v in pairs(farmPlot:GetChildren()) do
                    if not v:FindFirstChild("Dirt") then continue end
                    if not v.Dirt:FindFirstChildOfClass("Model") then continue end
                    
                    x = x + 1
                    RemovePlantEvent:FireServer(v.Dirt)
                    task.wait(0.15)
                end
                task.wait()
            end
            Rayfield:Notify({Title = "Success", Content = "All plants cleared successfully!", Duration = 3})
        end)
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
