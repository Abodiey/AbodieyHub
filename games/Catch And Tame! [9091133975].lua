-- REMINDER: Never use the getgenv prefix anywhere else in the script after setting getgenv().ScriptID once at the top. Use ScriptID == CurrentScriptID for all loop and event checks.
getgenv().ScriptID = os.clock()
local CurrentScriptID = ScriptID

-- Service Retrieval
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))

-- Remotes & Paths
local minigameRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("minigameRequest")
local UpdateProgress = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateProgress")
local collectAllPetCash = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("collectAllPetCash")
local LocalPlayer = Players.LocalPlayer

-- Knit AFK Remotes
local AFKServiceFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("AFKService"):WaitForChild("RF")
local StartAFK = AFKServiceFolder:WaitForChild("StartAFK")
local StopAFK = AFKServiceFolder:WaitForChild("StopAFK")

-- State Toggles & Config Variables (No _G or shared)
local autoFarmActive = false
local afkRewardsActive = true
local antiAfkActive = true
local autoCollectMoney = false
local autoCollectFruits = false
local ignoreBossPets = true
local selectedIsland = nil

local loopCooldownCount = 5
local maxCaptureDistance = 65
local teleportWaitTime = 0.3

-- Item Modifiers Default Settings
local defaultSpeed = 60       -- Default speed for Fins
local maxJetpackSpeed = 100   -- Custom biggest speed value for Jetpacks

-- Dynamic Folders Cache Tables
local activePetsFolders = {}
local activeFruitsFolders = {}

-- Tracking Cache Variables (With Weak Key Metatable Configuration for Garbage Collection Integrity)
local lastUsedPet = nil
local permanentIgnore = setmetatable({}, {__mode = "k"})
local dynamicBlacklist = setmetatable({}, {__mode = "k"})
local afkConnection = nil

-- Unified Garbage Collector Gear Upgrader Mod (Oxygen, Suits, Fins, Jetpacks)
local function applyGearModifications()
    local oxygenKey1 = "Basic Tank"
    local oxygenKey2 = "Normal Oxygen Tank"
    local suitKey = "Basic Lava Suit"
    local finsKey = "Yellow Fins"
    local jetpackKey = "Starter Jetpack"

    local costStr = string.char(67, 111, 115, 116)          -- "Cost"
    local oxygenStr = string.char(79, 120, 121, 103, 101, 110) -- "Oxygen"
    local timeStr = string.char(84, 105, 109, 104)          -- "Time"
    local speedStr = string.char(83, 112, 101, 101, 100)    -- "Speed"

    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" then
            
            -- Oxygen Tanks
            if rawget(v, oxygenKey1) or rawget(v, oxygenKey2) then
                for _, data in pairs(v) do
                    if type(data) == "table" then
                        if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                        if rawget(data, oxygenStr) ~= nil then rawset(data, oxygenStr, math.huge) end
                    end
                end
            end
            
            -- Lava Suits
            if rawget(v, suitKey) then
                for _, data in pairs(v) do
                    if type(data) == "table" then
                        if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                        if rawget(data, timeStr) ~= nil then rawset(data, timeStr, math.huge) end
                    end
                end
            end

            -- Fins
            if rawget(v, finsKey) then
                for _, data in pairs(v) do
                    if type(data) == "table" then
                        if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                        if rawget(data, speedStr) ~= nil then rawset(data, speedStr, defaultSpeed) end
                    end
                end
            end

            -- Jetpacks
            if rawget(v, jetpackKey) then
                for _, data in pairs(v) do
                    if type(data) == "table" then
                        if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                        if rawget(data, speedStr) ~= nil then rawset(data, speedStr, maxJetpackSpeed) end
                    end
                end
            end

        end
    end

    -- Force updates equipped attributes instantly
    if LocalPlayer then
        task.spawn(function()
            LocalPlayer:SetAttribute("equippedTank", "Basic Tank")
            task.wait()
            LocalPlayer:SetAttribute("equippedTank", "Fusion Tank")

            LocalPlayer:SetAttribute("equippedSuit", "Basic Lava Suit")
            task.wait()
            LocalPlayer:SetAttribute("equippedSuit", "OP Lava Suit")

            LocalPlayer:SetAttribute("equippedJetpack", "Starter Jetpack")
            task.wait()
            LocalPlayer:SetAttribute("equippedJetpack", "OP Jetpack")

            LocalPlayer:SetAttribute("equippedFins", "Yellow Fins")
            task.wait()
            LocalPlayer:SetAttribute("equippedFins", "Abyss Fins")
        end)
    end
    print("Gear modifiers and stat tables successfully upgraded.")
end
applyGearModifications()

-- Scan workspace completely for target subfolders on startup
local function internalInitializeFolders()
    table.clear(activePetsFolders)
    table.clear(activeFruitsFolders)
    
    for _, child in ipairs(workspace:GetChildren()) do
        -- Cache Pet Folders
        local petsMatch = child:FindFirstChild("Pets")
        if petsMatch and petsMatch:IsA("Folder") then
            table.insert(activePetsFolders, petsMatch)
        end
        
        -- Cache Fruit Folders
        local fruitsMatch = child:FindFirstChild("Fruits")
        if fruitsMatch and fruitsMatch:IsA("Folder") then
            table.insert(activeFruitsFolders, fruitsMatch)
        end
    end
    print(string.format("Index Scanning Complete! Cached %d 'Pets' folders and %d 'Fruits' folders.", #activePetsFolders, #activeFruitsFolders))
end
internalInitializeFolders()

-- Island Data Setup
local islandConfigs = {
    ["Roaming"] = {
        Target = function()
            local floor = workspace:FindFirstChild("LOCKED_FLOOR")
            return floor and (floor:GetPivot().Position + Vector3.new(0, 15, 0))
        end,
        Boxes = function() return workspace:FindFirstChild("RoamingPets") and workspace.RoamingPets:FindFirstChild("SpawnBoxes") end,
        Required = 1
    },
    ["VolcanoIsland"] = {
        Target = function()
            local qt = workspace:FindFirstChild("QuickTravel")
            local volcano = qt and qt:FindFirstChild("VolcanoIsland")
            return volcano and volcano:FindFirstChild("Marker")
        end,
        Boxes = function() return workspace:FindFirstChild("VolcanoIslandPets") and workspace.VolcanoIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 13
    },
    ["SkyIsland / DragonIsland"] = {
        Target = function()
            local qt = workspace:FindFirstChild("QuickTravel")
            local dragon = qt and qt:FindFirstChild("DragonIsland")
            return dragon and dragon:FindFirstChild("Marker")
        end,
        Boxes = function() return workspace:FindFirstChild("SkyIslandPets") and workspace.SkyIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 13
    },
    ["WaterIsland"] = {
        Target = function()
            local qt = workspace:FindFirstChild("QuickTravel")
            local depths = qt and qt:FindFirstChild("ForgottenDepths")
            local marker = depths and depths:FindFirstChild("Marker")
            if marker then return marker end
            
            local cage = workspace:FindFirstChild("CAGE")
            return cage and cage:FindFirstChild("Part")
        end,
        Boxes = function() return workspace:FindFirstChild("WaterIslandPets") and workspace.WaterIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 9
    },
    ["BeeIsland"] = {
        Target = function()
            local qt = workspace:FindFirstChild("QuickTravel")
            local bee = qt and qt:FindFirstChild("BeeIsland")
            return bee and bee:FindFirstChild("Marker")
        end,
        Boxes = function() return workspace:FindFirstChild("BeeIslandPets") and workspace.BeeIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 15
    },
    ["LavaIsland"] = {
        Target = function()
            local zones = workspace:FindFirstChild("EnterZones")
            local volcanoZone = zones and zones:FindFirstChild("- Volcano Island -")
            if volcanoZone then return volcanoZone end
            
            local qt = workspace:FindFirstChild("QuickTravel")
            local volcano = qt and qt:FindFirstChild("VolcanoIsland")
            return volcano and volcano:FindFirstChild("Marker")
        end,
        Boxes = function() return workspace:FindFirstChild("LavaIslandPets") and workspace.LavaIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 2
    },
    ["SafariIsland"] = {
        Target = function()
            local qt = workspace:FindFirstChild("QuickTravel")
            local safari = qt and qt:FindFirstChild("SafariIsland")
            return safari and safari:FindFirstChild("Marker")
        end,
        Boxes = function() return workspace:FindFirstChild("SafariIslandPets") and workspace.SafariIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 17
    },
    ["CaveIsland"] = {
        Target = function()
            local qt = workspace:FindFirstChild("QuickTravel")
            local cave = qt and qt:FindFirstChild("CaveIsland")
            local marker = cave and cave:FindFirstChild("Marker")
            if marker then return marker end
            
            local topCave = workspace:FindFirstChild("TopCaveArea")
            return topCave and topCave:FindFirstChild("Tp")
        end,
        Boxes = function() return workspace:FindFirstChild("CaveIslandPets") and workspace.CaveIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 14
    },
    ["DeepCave"] = {
        Target = function()
            local portal = workspace:FindFirstChild("Workspace") and workspace.Workspace:FindFirstChild("TeleportPortal") or workspace:FindFirstChild("TeleportPortal")
            return portal and portal:FindFirstChild("Tp")
        end,
        Boxes = function() return workspace:FindFirstChild("DeepCavePets") and workspace.DeepCavePets:FindFirstChild("SpawnBoxes") end,
        Required = 4
    },
    ["AbyssIslandPets"] = {
        Target = function()
            local coral = workspace:FindFirstChild("Coral")
            if coral and coral.PrimaryPart then return coral.PrimaryPart end
            
            local crystal = workspace:FindFirstChild("AbyssCrystal")
            if crystal and crystal.PrimaryPart then return crystal.PrimaryPart end
        end,
        Boxes = function() return workspace:FindFirstChild("AbyssIslandPets") and workspace.AbyssIslandPets:FindFirstChild("SpawnBoxes") end,
        Required = 16
    }
}

-- Helper function to tick down blacklist clocks
local function updateTrackingClocks()
    for petInstance, loopsLeft in pairs(dynamicBlacklist) do
        if loopsLeft <= 1 then
            dynamicBlacklist[petInstance] = nil
        else
            dynamicBlacklist[petInstance] = loopsLeft - 1
        end
    end
end

-- Track current targeting instance dynamically for condition exclusion
local activelyFarmingPet = nil

-- Helper function to acquire targeted model searching across all indexed folders
local function findBestValidPet()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil, nil, nil end
    
    local myPos = character.HumanoidRootPart.Position
    local bestPet = nil
    local highestRPS = -math.huge
    local shortestDistanceForHighestRPS = math.huge
    local currentTime = os.time()

    -- Multi-folder table parse iteration
    for _, folder in ipairs(activePetsFolders) do
        if folder.Parent then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj.PrimaryPart and obj:GetAttribute("Captured") ~= true then
                    local lifetime = obj:GetAttribute("Lifetime")
                    if obj == activelyFarmingPet or (lifetime and lifetime >= currentTime) then
                        
                        local rarity = obj:GetAttribute("Rarity")
                        if ignoreBossPets and (not rarity or rarity == "Boss") then
                            continue
                        end

                        if not obj:GetAttribute("LuckyBlockLuck") then
                            if not permanentIgnore[obj] and obj ~= lastUsedPet and not dynamicBlacklist[obj] then
                                local rpsValue = obj:GetAttribute("RPS") or 0
                                local petPos = obj.PrimaryPart.Position
                                local distance = (myPos - petPos).Magnitude
                                
                                if rpsValue > highestRPS then
                                    highestRPS = rpsValue
                                    shortestDistanceForHighestRPS = distance
                                    bestPet = obj
                                elseif rpsValue == highestRPS and distance < shortestDistanceForHighestRPS then
                                    shortestDistanceForHighestRPS = distance
                                    bestPet = obj
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestPet, highestRPS, shortestDistanceForHighestRPS
end

-- Independent Self-Terminating Loop Function
local function startAutoFarmLoop()
    task.spawn(function()
        print("Automated Lasso Farm Loop Started.")
        while ScriptID == CurrentScriptID do
            if not autoFarmActive then break end
            
            updateTrackingClocks()
            local pet, rps, distance = findBestValidPet()
            
            if pet and distance ~= math.huge then
                print(string.format("Current Best Target: %s | RPS: %s | Distance: %.1f studs", pet.Name, tostring(rps), distance))
            end
            
            if not pet then
                repeat
                    task.wait()
                    if not autoFarmActive or ScriptID ~= CurrentScriptID then return end
                    pet, rps, distance = findBestValidPet()
                until pet ~= nil
            end
            
            activelyFarmingPet = pet
            
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart and pet.PrimaryPart then
                if distance > maxCaptureDistance then
                    print("Target outside optimal range. Teleporting...")
                    rootPart.CFrame = CFrame.new(pet.PrimaryPart.Position)
                    task.wait(teleportWaitTime)
                end
            else
                activelyFarmingPet = nil
                task.wait(0.1)
                continue
            end
            
            if ScriptID ~= CurrentScriptID then 
                activelyFarmingPet = nil
                break 
            end
            
            print("Executing capture handshake on: " .. pet.Name)
            local pivot = pet:GetPivot()
            local success, canStart = pcall(function()
                return minigameRequest:InvokeServer(pet, pivot)
            end)
            
            if success and canStart == true then
                print("Minigame entered successfully! Running progression...")
                
                local stickyConnection = nil
                
                pcall(function()
                    stickyConnection = RunService.RenderStepped:Connect(function()
                        if ScriptID ~= CurrentScriptID or not pet or not pet.PrimaryPart then
                            if stickyConnection then stickyConnection:Disconnect() end
                            return
                        end
                        
                        local currentCharacter = LocalPlayer.Character
                        local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
                        if currentRoot and pet.PrimaryPart then
                            currentRoot.CFrame = CFrame.new(pet.PrimaryPart.Position)
                        end
                    end)
                end)
                
                for percent = 0, 100, 5 do
                    if ScriptID ~= CurrentScriptID then 
                        if stickyConnection then stickyConnection:Disconnect() end
                        activelyFarmingPet = nil
                        return 
                    end
                    UpdateProgress:FireServer(percent)
                    task.wait()
                end
                
                lastUsedPet = pet
                print("Progress sequence complete. Waiting for target clearance...")
                
                while pet.Parent and pet:GetAttribute("Captured") ~= true and ScriptID == CurrentScriptID do
                    task.wait()
                end
                
                if stickyConnection then
                    stickyConnection:Disconnect()
                    stickyConnection = nil
                end
                print("Target cleared successfully.")
            else
                local errorReason = tostring(canStart)
                warn("Could not start minigame. Server response: " .. errorReason)
                
                if errorReason == "pet_already_captured" or errorReason == "pet_destroyed" then
                    permanentIgnore[pet] = true
                    print("Target flagged as permanently excluded from search scans.")
                else
                    lastUsedPet = pet
                end
                
                task.wait(0.2)
            end
            
            activelyFarmingPet = nil
            task.wait()
        end
        print("Automated Lasso Farm Loop Completely Terminated.")
    end)
end

-- Independent Self-Terminating Loop Function for Collecting Cash
local function startAutoCollectMoney()
    task.spawn(function()
        print("Auto Collect Money Loop Started.")
        while autoCollectMoney and ScriptID == CurrentScriptID do
            pcall(function()
                collectAllPetCash:FireServer()
            end)
            task.wait(0.9)
        end
        print("Auto Collect Money Loop Completely Terminated.")
    end)
end

-- Independent Self-Terminating Loop Function for Collecting Fruits
local function startAutoCollectFruits()
    task.spawn(function()
        print("Auto Collect Fruits Loop Started.")
        while autoCollectFruits and ScriptID == CurrentScriptID do
            for _, folder in ipairs(activeFruitsFolders) do
                if folder.Parent and autoCollectFruits and ScriptID == CurrentScriptID then
                    for _, fruit in ipairs(folder:GetChildren()) do
                        local handle = fruit:FindFirstChild("Handle")
                        local prompt = handle and handle:FindFirstChildOfClass("ProximityPrompt")
                        
                        if prompt then
                            pcall(function()
                                fireproximityprompt(prompt)
                            end)
                        end
                    end
                end
            end
            task.wait(0.5)
        end
        print("Auto Collect Fruits Loop Completely Terminated.")
    end)
end

-- Anti AFK Handler Execution
local function startAntiAFK()
    local function handleAFKState()
        if ScriptID ~= CurrentScriptID or not antiAfkActive then 
            if afkConnection then 
                afkConnection:Disconnect() 
                afkConnection = nil 
            end 
            return 
        end
        LocalPlayer:SetAttribute("AFK_Active", false)
    end
    
    handleAFKState()
    
    if afkConnection then afkConnection:Disconnect() end
    afkConnection = LocalPlayer:GetAttributeChangedSignal("AFK_Active"):Connect(handleAFKState)
end

-- Handle initial on-by-default execution configurations on startup
local function handleInitialStateSetup()
    if LocalPlayer:GetAttribute("AFK_NextRewardTime") == nil then
        pcall(function() StartAFK:InvokeServer() end)
    end
    startAntiAFK()
end
handleInitialStateSetup()

-- Area Teleporter Action Function
local function executeAreaTeleport(islandName)
    local config = islandConfigs[islandName]
    if not config then 
        warn("No teleport configurations found for: " .. tostring(islandName))
        return 
    end
    
    task.spawn(function()
        print("Initiating Area Teleport process for: " .. islandName)
        
        while ScriptID == CurrentScriptID do
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if not rootPart then 
                task.wait(0.5)
                continue 
            end
            
            local boxesObj = config.Boxes()
            local currentCount = boxesObj and #boxesObj:GetChildren() or 0
            
            if currentCount >= config.Required then
                print(string.format("Spawnbox target condition reached (%d/%d). Teleport complete.", currentCount, config.Required))
                break
            end
            
            local targetSource = config.Target()
            if targetSource then
                local targetCFrame
                if typeof(targetSource) == "Vector3" then
                    targetCFrame = CFrame.new(targetSource)
                elseif targetSource:IsA("UnreliableRemoteEvent") or not targetSource:IsA("Instance") then
                    -- Safety catch-all for bad logic
                elseif targetSource:IsA("Model") then
                    targetCFrame = targetSource:GetPivot()
                elseif targetSource:IsA("BasePart") then
                    targetCFrame = targetSource.CFrame
                end
                
                if targetCFrame then
                    rootPart.CFrame = targetCFrame
                end
            else
                warn("Teleport target source instance or vector is missing! retrying verification loop...")
            end
            
            task.wait(0.5)
        end
    end)
end

-- Rayfield UI Integration
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "AbodieyHUB",
    LoadingTitle = "Loading Script...",
    LoadingSubtitle = "by Abodiey",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main Hub", 4483362458)

MainTab:CreateSection("--- Automation Features ---")

MainTab:CreateToggle({
    Name = "Auto Farm Lasso Minigame",
    CurrentValue = autoFarmActive,
    Flag = "LassoAutoFarmToggle",
    Callback = function(Value)
        autoFarmActive = Value
        if Value then
            startAutoFarmLoop()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Fruits",
    CurrentValue = autoCollectFruits,
    Flag = "AutoCollectFruitsToggle",
    Callback = function(Value)
        autoCollectFruits = Value
        if Value then
            startAutoCollectFruits()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Pet Cash",
    CurrentValue = autoCollectMoney,
    Flag = "AutoCollectMoneyToggle",
    Callback = function(Value)
        autoCollectMoney = Value
        if Value then
            startAutoCollectMoney()
        end
    end,
})

MainTab:CreateButton({
    Name = "Collect Pet Cash (One-Time)",
    Callback = function()
        pcall(function()
            collectAllPetCash:FireServer()
        end)
    end,
})

MainTab:CreateToggle({
    Name = "AFK Rewards",
    CurrentValue = afkRewardsActive,
    Flag = "AFKRewardsToggle",
    Callback = function(Value)
        afkRewardsActive = Value
        local nextRewardTime = LocalPlayer:GetAttribute("AFK_NextRewardTime")
        
        if Value then
            if nextRewardTime == nil then
                pcall(function() StartAFK:InvokeServer() end)
            end
        else
            if nextRewardTime ~= nil then
                pcall(function() StopAFK:InvokeServer() end)
            end
        end
    end,
})

MainTab:CreateToggle({
    Name = "Anti AFK Rewards UI",
    CurrentValue = antiAfkActive,
    Flag = "AntiAFKToggle",
    Callback = function(Value)
        antiAfkActive = Value
        if Value then
            startAntiAFK()
        else
            if afkConnection then
                afkConnection:Disconnect()
                afkConnection = nil
            end
            local isAFK = LocalPlayer:GetAttribute("AFK_NextRewardTime") ~= nil
            LocalPlayer:SetAttribute("AFK_Active", isAFK)
        end
    end,
})

MainTab:CreateSection("--- Navigation ---")

MainTab:CreateDropdown({
    Name = "Select Teleport Island",
    Options = {"Roaming", "VolcanoIsland", "SkyIsland / DragonIsland", "WaterIsland", "BeeIsland", "LavaIsland", "SafariIsland", "CaveIsland", "DeepCave", "AbyssIslandPets"},
    CurrentOption = "",
    Flag = "IslandSelectionDropdown",
    Callback = function(Value)
        selectedIsland = type(Value) == "table" and Value[1] or Value
    end,
})

MainTab:CreateButton({
    Name = "Teleport to Selected Area",
    Callback = function()
        if selectedIsland and selectedIsland ~= "" then
            executeAreaTeleport(selectedIsland)
        else
            warn("Cannot complete teleport request: No destination selected in dropdown.")
        end
    end,
})

MainTab:CreateSection("--- Configuration ---")

MainTab:CreateToggle({
    Name = "Ignore Boss Pets",
    CurrentValue = ignoreBossPets,
    Flag = "IgnoreBossPetsToggle",
    Callback = function(Value)
        ignoreBossPets = Value
    end,
})

MainTab:CreateSlider({
    Name = "Max Capture Range",
    Range = {10, 250},
    Increment = 5,
    CurrentValue = maxCaptureDistance,
    Flag = "MaxCaptureRangeFlag",
    Callback = function(Value)
        maxCaptureDistance = Value
    end,
})

MainTab:CreateSlider({
    Name = "Loop Cooldown Count",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = loopCooldownCount,
    Flag = "LoopCooldownCountFlag",
    Callback = function(Value)
        loopCooldownCount = Value
    end,
})

MainTab:CreateSlider({
    Name = "Teleport Sync Delay",
    Range = {0, 2},
    Increment = 0.1,
    CurrentValue = teleportWaitTime,
    Flag = "TeleportSyncDelayFlag",
    Callback = function(Value)
        teleportWaitTime = Value
    end,
})

MainTab:CreateSlider({
    Name = "Fins Default Speed Mod",
    Range = {10, 300},
    Increment = 5,
    CurrentValue = defaultSpeed,
    Flag = "FinsSpeedModSlider",
    Callback = function(Value)
        defaultSpeed = Value
        applyGearModifications()
    end,
})

MainTab:CreateSlider({
    Name = "Max Jetpack Speed Mod",
    Range = {10, 300},
    Increment = 5,
    CurrentValue = maxJetpackSpeed,
    Flag = "JetpackSpeedModSlider",
    Callback = function(Value)
        maxJetpackSpeed = Value
        applyGearModifications()
    end,
})
