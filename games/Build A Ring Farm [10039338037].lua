-- Set the script ID globally once (no need to call getgenv again anywhere else)
getgenv().ScriptID = os.clock()
local CurrentScriptID = ScriptID

-- Load Rayfield Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Base Setup
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CollectionService = cloneref(game:GetService("CollectionService"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local Players = cloneref(game:GetService("Players"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))

local Player = Players.LocalPlayer
local character = Player.Character or Player.CharacterAdded:Wait()
local root = character:FindFirstChild("HumanoidRootPart")
local EventsRoot = CoreGui:WaitForChild("RobloxGui"):WaitForChild("EventsInExperienceRoot")

-- Shared Utilities & Registries
local SharedUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SharedUtils"))
local PlantsRegistry = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Registry"):WaitForChild("Plants")

-- Isolate the data table to prevent changing the global module cache reference
local RegistryData = require(PlantsRegistry)
local OrderedSeeds = RegistryData.GetPlantsForIndex()

-- Create our own clean local reference table of the seed metadata entries
local Seeds = {}
for k, v in pairs(RegistryData) do
    if k ~= "GetPlantsForIndex" then
        Seeds[k] = v
    end
end
RegistryData = nil -- Clear local pointer copy reference

-- Folder, Remote & Map References
local Honeycombs = workspace.InteractiveEvents.QueenBee.RuntimeHoneycombs
local SellEvent = ReplicatedStorage.Remotes.SellCrates
local RemovePlantEvent = ReplicatedStorage.Remotes.RemovePlant
local PlantSeedEvent = ReplicatedStorage.Remotes.PlantSeed
local ShootRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlantRush"):WaitForChild("Shoot")
local SetSettingRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Settings"):WaitForChild("SetSetting")
local SubmitCodeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SubmitCode")
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
local autoPlantEnabled = false
local autoClearEnabled = false
local waitForServerConfirmation = true
local disableManualRoll = false
local disableManualBuy = false
local antiAfkEnabled = true
local lowPerformanceEnabled = true
local antiEventPopupEnabled = true

-- Dynamic Calculation Settings
local ignoreMutation = false
local ignoreLevel = false

-- Advanced Economic & Strategy Variables
local lowCashStrategy = "Skip Seed"
local lowCashWaitTimeLimit = 10
local seedSkippedByPrice = false
local targetCodeText = ""

-- Code Pool Table Configuration
local promoCodesList = {
    "PLANTRUSH",
    "UPDATE2",
    "THANKYOU",
    "BARF:3",
    "100KVISITS",
    "2KLIKES",
    "UPDATE1"
}

-- Shared State Tracker & Cache for Seeds
local AutoRollIndex = 1 
local goodSeedPresent = false 
local activeGoodSeeds = {}

Player.CharacterAdded:Connect(function(char)
    character = char
    root = char:WaitForChild("HumanoidRootPart")
end)

-- Parses numbers with suffixes (e.g., "$325.24M", "10.5K") into accurate raw doubles
local function parsePrice(text)
    if not text or text == "" then return 0 end
    local clean = string.gsub(tostring(text), "[%,%$%s]", "")
    local numStr, suffix = string.match(clean, "^([%d%.]+)([KMBkmb]?)$")
    local num = tonumber(numStr) or 0
    
    if suffix == "K" or suffix == "k" then
        return num * 1000
    elseif suffix == "M" or suffix == "m" then
        return num * 1000000
    elseif suffix == "B" or suffix == "b" then
        return num * 1000000000
    end
    return num
end

-- Safely extracts value from leaderstats StringValue format
local function getPlayerCash()
    local leaderstats = Player:FindFirstChild("leaderstats")
    local cashObj = leaderstats and leaderstats:FindFirstChild("Cash")
    return cashObj and parsePrice(cashObj.Value) or 0
end

-- Helper function to find the first valid shootout target
local function getShootTarget()
    for _, child in ipairs(RuntimeFolder:GetChildren()) do
        local rootPart = child:FindFirstChild("HumanoidRootPart")
        if rootPart then
            return rootPart
        end
    end
end

-- Helper to check if seed qualifies based on its registry array object matching
local function isGoodSeed(seedName)
    if not OrderedSeeds then return false end
    
    local seedIndex = nil
    for idx, data in ipairs(OrderedSeeds) do
        if data and data.Name == seedName then
            seedIndex = idx
            break
        end
    end
    
    return seedIndex and seedIndex > AutoRollIndex
end

-- Helper engine to get the clean dynamic price of a physical seed instance
local function getSeedPrice(targetSeed)
    if not targetSeed or not targetSeed.Parent then return 0 end
    
    local buyPrompt = targetSeed:FindFirstChild("BuySeed", true)
    local gui = buyPrompt and buyPrompt.Parent and buyPrompt.Parent:FindFirstChild("SeedGui")
    local textObj = gui and gui:FindFirstChild("Cost", true)
    
    if textObj then
        return parsePrice(textObj.Text)
    elseif Seeds and Seeds[targetSeed.Name] then
        return tonumber(Seeds[targetSeed.Name].Price) or 0
    end
    return 0
end

-- Cache Management for Seeds
local function onSeedAdded(instance)
    if isGoodSeed(instance.Name) then
        activeGoodSeeds[instance] = true
        seedSkippedByPrice = false 
        
        if disableManualBuy then
            local buyPrompt = instance:FindFirstChild("BuySeed", true)
            if buyPrompt then buyPrompt.Enabled = false end
        end
    end
end

CollectionService:GetInstanceAddedSignal("FloatSeed"):Connect(onSeedAdded)
CollectionService:GetInstanceRemovedSignal("FloatSeed"):Connect(function(instance)
    activeGoodSeeds[instance] = nil
    seedSkippedByPrice = false 
end)

-- Anti AFK Setup (VirtualUser prevents IDLE kick)
Player.Idled:Connect(function()
    if antiAfkEnabled and ScriptID == CurrentScriptID then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Core Sorted Layout Collector for FarmPlots
local function getSortedFarmPlots()
    if not plot then return {} end
    local farmPlot = plot:FindFirstChild("FarmPlot")
    if not farmPlot then return {} end

    local validPlots = {}
    for _, child in ipairs(farmPlot:GetChildren()) do
        local dirt = child:FindFirstChild("Dirt")
        local ringVal = dirt and dirt:GetAttribute("PlotRing")
        if ringVal then
            table.insert(validPlots, {instance = child, ring = tonumber(ringVal) or 999})
        end
    end

    table.sort(validPlots, function(a, b)
        return a.ring < b.ring
    end)

    -- Return unpacked sequential instances
    local sortedInstances = {}
    for i, data in ipairs(validPlots) do
        sortedInstances[i] = data.instance
    end
    return sortedInstances
end

-- Upgraded Best Seed Equipper Logic (Pure Base Value Comparison Pass)
local function equipBestSeed()
    local currentCharacter = Player.Character or character
    local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
    local backpack = Player:FindFirstChild("Backpack")
    
    if not humanoid or not backpack then return end
    
    local bestTool = nil
    local highestIncome = -1

    local function scanContainer(container)
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local plantName = tool:GetAttribute("Plant") or tool:GetAttribute("trueName")
                if not plantName then continue end
                
                -- Process dynamic filters based on user configurations
                local plantLevel = ignoreLevel and 1 or (tool:GetAttribute("Level") or 1)
                local plantMutation = ignoreMutation and "Normal" or (tool:GetAttribute("Mutation") or "Normal")
                
                if plantName and plantMutation and plantLevel then
                    local income = SharedUtils.CalculateIncome(plantName, plantMutation, plantLevel, 1)
                    
                    if income and income > highestIncome then
                        highestIncome = income
                        bestTool = tool
                    end
                end
            end
        end
    end

    scanContainer(backpack)
    scanContainer(currentCharacter)

    -- Only execute equip if a superior tool is identified outside the character
    if bestTool and bestTool.Parent ~= currentCharacter then
        humanoid:EquipTool(bestTool)
    end
end

-- Helper logic processor to automatically target and dismiss Event Popups safely
local function handleEventPopup(child)
    if not antiEventPopupEnabled or ScriptID ~= CurrentScriptID then return end
    task.wait(0.2)
    
    local success, button = pcall(function()
        return child.FocusNavigationCoreScriptsWrapper.Prompt.AlertContents.TitleContainer.TitleArea.Title.CloseButton
    end)

    if success and button then
        local x = button.AbsolutePosition.X + (button.AbsoluteSize.X / 2)
        local y = button.AbsolutePosition.Y + (button.AbsoluteSize.Y / 2) + 58

        VirtualInputManager:SendMouseMoveEvent(x, y, game)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end
end

EventsRoot.ChildAdded:Connect(handleEventPopup)

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
            local hasSeeds = false
            local currentValidSeed = nil
            
            for targetSeed, _ in pairs(activeGoodSeeds) do
                if targetSeed and targetSeed.Parent then
                    hasSeeds = true
                    currentValidSeed = targetSeed
                    break
                end
            end
            
            -- Fallback price evaluator if AutoBuy is completely turned off
            if hasSeeds and currentValidSeed and not autoBuyEnabled and lowCashStrategy == "Skip Seed" then
                local cost = getSeedPrice(currentValidSeed)
                if getPlayerCash() < cost then
                    seedSkippedByPrice = true
                    activeGoodSeeds[currentValidSeed] = nil
                    hasSeeds = false
                end
            end
            
            if hasSeeds and seedSkippedByPrice then
                hasSeeds = false
            end

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

-- LOOP 5: Auto Buy Loop (Bankruptcy Safeguard Engine Only)
local function startAutoBuy()
    task.spawn(function()
        while autoBuyEnabled and ScriptID == CurrentScriptID do
            for targetSeed, _ in pairs(activeGoodSeeds) do
                if targetSeed and targetSeed.Parent and not seedSkippedByPrice then
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
                        local seedCost = getSeedPrice(targetSeed)
                        local walletCash = getPlayerCash()
                        
                        -- Execute checks dynamically based on current configuration rules
                        if walletCash < seedCost then
                            if lowCashStrategy == "Skip Seed" then
                                seedSkippedByPrice = true
                                activeGoodSeeds[targetSeed] = nil 
                                break
                            elseif lowCashStrategy == "Wait Infinitely" then
                                -- Break loop item iteration, let the engine retry on next pass naturally without blocking
                                break
                            elseif lowCashStrategy == "Wait Custom Time" then
                                local startTime = os.clock()
                                while autoBuyEnabled and getPlayerCash() < seedCost and (os.clock() - startTime) < lowCashWaitTimeLimit do
                                    task.wait(0.5)
                                end
                                if getPlayerCash() < seedCost then
                                    seedSkippedByPrice = true
                                    activeGoodSeeds[targetSeed] = nil 
                                    break
                                end
                            end
                        end
                        
                        -- Execution gatepass clearance
                        if getPlayerCash() >= seedCost and not seedSkippedByPrice then
                            fireproximityprompt(buyPrompt)
                        end
                    end
                else
                    if not seedSkippedByPrice then
                        activeGoodSeeds[targetSeed] = nil 
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end

-- LOOP 6: Auto Equip Loop End Execution
local function startAutoEquip()
    task.spawn(function()
        while autoEquipEnabled and ScriptID == CurrentScriptID do
            equipBestSeed()
            task.wait(1)
        end
    end)
end

-- LOOP 7: Auto Plant Seeds Background Handler Loop
local function startAutoPlant()
    task.spawn(function()
        while autoPlantEnabled and ScriptID == CurrentScriptID do
            local sortedPlots = getSortedFarmPlots()
            for _, v in ipairs(sortedPlots) do
                if not autoPlantEnabled or ScriptID ~= CurrentScriptID then break end
                
                local dirt = v:FindFirstChild("Dirt")
                if not dirt then continue end
                if dirt:GetAttribute("PlantName") then continue end 
                
                PlantSeedEvent:FireServer(dirt)
                
                if waitForServerConfirmation then
                    local startTime = os.clock()
                    -- Polling loop with a hard 1-second safety timeout
                    while autoPlantEnabled and ScriptID == CurrentScriptID and dirt:IsDescendantOf(workspace) and not dirt:GetAttribute("PlantName") do
                        if os.clock() - startTime >= 1.0 then
                            -- Server dropped the remote package; re-fire once as a fallback step
                            if not dirt:GetAttribute("PlantName") and dirt:IsDescendantOf(workspace) then
                                PlantSeedEvent:FireServer(dirt)
                            end
                            break
                        end
                        task.wait()
                    end
                else
                    task.wait(0.15)
                end
            end
            task.wait(0.5)
        end
    end)
end

-- LOOP 8: Auto Clear / Remove Plants Background Handler Loop
local function startAutoClearPlants()
    task.spawn(function()
        while autoClearEnabled and ScriptID == CurrentScriptID do
            local sortedPlots = getSortedFarmPlots()
            for _, v in ipairs(sortedPlots) do
                if not autoClearEnabled or ScriptID ~= CurrentScriptID then break end
                
                local dirt = v:FindFirstChild("Dirt")
                if not dirt then continue end
                if not dirt:GetAttribute("PlantName") then continue end
                
                RemovePlantEvent:FireServer(dirt)
                
                if waitForServerConfirmation then
                    local startTime = os.clock()
                    -- Polling loop with a hard 1-second safety timeout
                    while autoClearEnabled and ScriptID == CurrentScriptID and dirt:IsDescendantOf(workspace) and dirt:GetAttribute("PlantName") do
                        if os.clock() - startTime >= 1.0 then
                            -- Server dropped the remote package; re-fire once as a fallback step
                            if dirt:GetAttribute("PlantName") and dirt:IsDescendantOf(workspace) then
                                RemovePlantEvent:FireServer(dirt)
                            end
                            break
                        end
                        task.wait()
                    end
                else
                    task.wait(0.15)
                end
            end
            task.wait(0.5)
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

MainTab:CreateToggle({
    Name = "Ignore Mutation (Best Seed)",
    CurrentValue = ignoreMutation,
    Flag = "IgnoreMutationToggle",
    Callback = function(Value)
        ignoreMutation = Value
    end,
})

MainTab:CreateToggle({
    Name = "Ignore Level (Best Seed)",
    CurrentValue = ignoreLevel,
    Flag = "IgnoreLevelToggle",
    Callback = function(Value)
        ignoreLevel = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Plant Seeds",
    CurrentValue = autoPlantEnabled,
    Flag = "AutoPlantToggle",
    Callback = function(Value)
        autoPlantEnabled = Value
        if Value then startAutoPlant() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Clear All Plants",
    CurrentValue = autoClearEnabled,
    Flag = "AutoClearToggle",
    Callback = function(Value)
        autoClearEnabled = Value
        if Value then startAutoClearPlants() end
    end,
})

MainTab:CreateToggle({
    Name = "Wait For Server Confirmation",
    CurrentValue = waitForServerConfirmation,
    Flag = "WaitConfirmationToggle",
    Callback = function(Value)
        waitForServerConfirmation = Value
    end,
})

-- Dynamic Label tracking your selections safely
local RarityLabel = MainTab:CreateLabel("Selected Min Tier: None")

-- Core Slider Logic Handler Function
local function handleSliderUpdate(Value)
    AutoRollIndex = Value
    
    local seedData = OrderedSeeds and OrderedSeeds[Value]
    if seedData then
        local seedName = seedData.Name or "Unknown"
        local rarity = seedData.Rarity or "Unknown"
        RarityLabel:Set("Selected Min Tier: " .. seedName .. " [" .. rarity .. "]")
    else
        RarityLabel:Set("Selected Min Tier: Index " .. tostring(Value))
    end

    table.clear(activeGoodSeeds)
    seedSkippedByPrice = false
    for _, instance in ipairs(CollectionService:GetTagged("FloatSeed")) do
        onSeedAdded(instance)
    end
end

-- Auto Roll Index Slider Element using Range parameter configuration
local maxRange = OrderedSeeds and #OrderedSeeds or 1
MainTab:CreateSlider({
    Name = "Min Roll Rarity Index",
    Range = {1, maxRange},
    Increment = 1,
    CurrentValue = AutoRollIndex,
    Flag = "RollIndexSlider",
    Callback = handleSliderUpdate,
})

MainTab:CreateSection("--- Advanced Economic Controls ---")

-- UI Elements for Safeguard 1 (Don't have enough money)
MainTab:CreateDropdown({
    Name = "If Wallet Balance Insufficient",
    Options = {"Skip Seed", "Wait Infinitely", "Wait Custom Time"},
    CurrentOption = lowCashStrategy,
    Flag = "LowCashStrategyDropdown",
    Callback = function(Value)
        if type(Value) == "table" then
            lowCashStrategy = Value[1]
        else
            lowCashStrategy = Value
        end
    end,
})

MainTab:CreateSlider({
    Name = "Insufficient Cash Wait Limit (Sec)",
    Range = {5, 120},
    Increment = 5,
    CurrentValue = lowCashWaitTimeLimit,
    Flag = "LowCashWaitTimeLimitSlider",
    Callback = function(Value)
        lowCashWaitTimeLimit = Value
    end,
})

MainTab:CreateSection("--- Performance & Codes ---")

MainTab:CreateToggle({
    Name = "Low Performance Mode",
    CurrentValue = lowPerformanceEnabled,
    Flag = "LowPerformanceToggle",
    Callback = function(Value)
        lowPerformanceEnabled = Value
        SetSettingRemote:FireServer("LowPerformanceMode", Value)
    end,
})

MainTab:CreateInput({
    Name = "Enter Promo Code",
    PlaceholderText = "Type code here...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        targetCodeText = Text
    end,
})

MainTab:CreateButton({
    Name = "Submit Entered Code",
    Callback = function()
        if targetCodeText and targetCodeText ~= "" then
            local success, result = pcall(function()
                return SubmitCodeRemote:InvokeServer(targetCodeText)
            end)
            if success then
                Rayfield:Notify({Title = "Code System", Content = "Submitted code: " .. tostring(targetCodeText), Duration = 3})
            else
                Rayfield:Notify({Title = "Error", Content = "Submission invocation failed!", Duration = 3})
            end
        else
            Rayfield:Notify({Title = "Warning", Content = "Code field is currently empty!", Duration = 3})
        end
    end,
})

MainTab:CreateButton({
    Name = "Redeem All Promo Codes",
    Callback = function()
        task.spawn(function()
            for _, code in ipairs(promoCodesList) do
                pcall(function()
                    SubmitCodeRemote:InvokeServer(code)
                end)
                task.wait(0.3) -- Yield slightly between invokes to avoid rate limits
            end
            Rayfield:Notify({Title = "Success", Content = "All known code streams processed!", Duration = 3})
        end)
    end,
})

MainTab:CreateSection("--- Protection & Safety ---")

MainTab:CreateToggle({
    Name = "Anti Event Popup Window",
    CurrentValue = antiEventPopupEnabled,
    Flag = "AntiEventToggle",
    Callback = function(Value)
        antiEventPopupEnabled = Value
    end,
})

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
    end
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

-- Execute Low Performance Optimization initial sequence immediately on run
pcall(function()
    SetSettingRemote:FireServer("LowPerformanceMode", true)
end)

-- Process active event windows that loaded before execution
task.spawn(function()
    for _, child in ipairs(EventsRoot:GetChildren()) do
        task.spawn(handleEventPopup, child)
    end
end)

-- Fire default executing threads automatically at load time
startAutoSell()
startAutoFarm()
startAutoShoot()
