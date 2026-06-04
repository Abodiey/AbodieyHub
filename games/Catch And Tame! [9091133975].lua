-- REMINDER: Never use the getgenv prefix anywhere else in the script after setting getgenv().ScriptID once at the top. Use ScriptID == CurrentScriptID for all loop and event checks.
getgenv().ScriptID = os.clock()
local CurrentScriptID = ScriptID

-- Service Retrieval
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))

-- Config Requirements
local strengthConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("Lassos"):WaitForChild("strengthConfig"))
local DifficultyConfig = require(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("lassoUI"):WaitForChild("lassoMinigameUI"):WaitForChild("DifficultyConfig"))
local petsindex = require(game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("IndexMenu"))

-- Create custom rarity weights mapping from module order
local orderofpets = petsindex.RarityOrder
local customOrder = table.clone(orderofpets)
table.insert(customOrder, "Secret")

local rarityWeights = {}
for index, rarityName in ipairs(customOrder) do
    rarityWeights[rarityName] = index
end

-- Remotes & Paths
local minigameRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("minigameRequest")
local UpdateProgress = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateProgress")
local CancelMinigame = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CancelMinigame")
local collectAllPetCash = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("collectAllPetCash")
local retrieveData = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("retrieveData")
local sellPet = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("sellPet")
local removeTool = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("removeTool")
local pickupRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("pickupRequest")
local RequestPlacePet = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPlacePet")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Knit RF Services
local AFKServiceFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("AFKService"):WaitForChild("RF")
local StartAFK = AFKServiceFolder:WaitForChild("StartAFK")
local StopAFK = AFKServiceFolder:WaitForChild("StopAFK")

local PenServiceFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("PenService"):WaitForChild("RF")
local getMaxPetsForPlayer = PenServiceFolder:WaitForChild("getMaxPetsForPlayer")

-- State Toggles & Config Variables (No _G or shared)
local autoFarmActive = false
local afkRewardsActive = true
local antiAfkActive = true
local autoCollectMoney = false
local autoCollectFruits = false
local autoCollectFoodRain = false
local autoCollectEasterEggs = false
local autoUniversalCollect = false
local autoTeleportToBoss = false
local autoSellWorstPet = false
local autoPlaceBestPets = false
local autoPlaceLuckyBlocks = false
local selectedIsland = nil

-- Filter Configs
local targetSelectionMode = "All" -- Options: "All", "Bosses Only", "Lucky Blocks Only", "Non-Boss Pets Only"
local ignoreNonMutated = false

local minRpsThreshold = 0
local minStrengthThreshold = 100
local loopCooldownCount = 5
local maxCaptureDistance = 45
local teleportWaitTime = 0.3
local maxCaptureTimeLimit = 10
local interactionDelay = 0.2 
local sellRpsThreshold = 50

-- Universal Collect Dynamic Variables
local universalPreDelay = 0.1
local universalPostDelay = 0.2

-- Inventory Caching & Cycle Controls
local cachedInventoryData = nil
local lastDataFetchTime = 0
local cacheDurationLimit = 300 -- 5 Minutes
-- Booleans to prevent execution spam once criteria is exhausted
local dataCycleDone = false
local placeCycleDone = false
local blockCycleDone = false

-- Metatable Namecall Interception Engine for retrieveData Sync Cache
local function initiateNamecallInterception()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if ScriptID == CurrentScriptID and self == retrieveData and (method == "InvokeServer" or method == "invokeServer") then
            -- Let original invocation fire to capture the real data payload safely
            local results = {oldNamecall(self, unpack(args))}
            local data = results[1]
            
            if data and type(data) == "table" and data.inventory and data.inventory.pets then
                cachedInventoryData = data.inventory.pets
                lastDataFetchTime = os.clock()
                dataCycleDone = false   -- Open loops up on a clean inventory update
                placeCycleDone = false  -- Open loops up on a clean inventory update
                blockCycleDone = false  -- Open loops up on a clean inventory update
            end
            return unpack(results)
        end
        
        return oldNamecall(self, ...)
    end)
end
initiateNamecallInterception()

-- Suffix Parsing Map
local suffixMultipliers = {
    k = 1e3, m = 1e6, b = 1e9, t = 1e12
}

local function parseStringToNumber(text)
    if not text or text == "" then return 0 end
    text = string.lower(string.gsub(text, "%s+", ""))
    local numericStr, suffix = string.match(text, "^([%d%.]+)([a-z]?)$")
    if not numericStr then return 0 end
    
    local num = tonumber(numericStr) or 0
    if suffix and suffixMultipliers[suffix] then
        num = num * suffixMultipliers[suffix]
    end
    return num
end

-- Dynamic Folders Cache Tables
local activePetsFolders = {}
local activeFruitsFolders = {}

-- Tracking Cache Variables
local lastUsedPet = nil
local permanentIgnore = setmetatable({}, {__mode = "k"})
local dynamicBlacklist = setmetatable({}, {__mode = "k"})
local afkConnection = nil
local afkScreenConnection = nil

-- Modifiers scanning state tracker
local foundOxygen = false
local foundSuit = false
local foundFins = false
local foundJetpack = false

local function applyGearModifications()
    task.spawn(function()
        local oxygenKey1 = "Basic Tank"
        local oxygenKey2 = "Normal Oxygen Tank"
        local suitKey = "Basic Lava Suit"
        local finsKey = "Yellow Fins"
        local jetpackKey = "Starter Jetpack"

        local costStr = string.char(67, 111, 115, 116)          -- "Cost"
        local oxygenStr = string.char(79, 120, 121, 103, 101, 110) -- "Oxygen"
        local timeStr = string.char(84, 105, 109, 104)          -- "Time"
        local speedStr = string.char(83, 112, 101, 101, 100)    -- "Speed"

        while ScriptID == CurrentScriptID and not (foundOxygen and foundSuit and foundFins and foundJetpack) do
            local gc = getgc(true)
            local chunkCounter = 0
            
            for i = 1, #gc do
                if ScriptID ~= CurrentScriptID then return end
                
                chunkCounter = chunkCounter + 1
                if chunkCounter % 2000 == 0 then
                    task.wait()
                end
                
                local v = gc[i]
                if type(v) == "table" then
                    -- Oxygen Mod Lookup Check
                    if not foundOxygen and (rawget(v, oxygenKey1) or rawget(v, oxygenKey2)) then
                        for _, data in pairs(v) do
                            if type(data) == "table" then
                                if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                                if rawget(data, oxygenStr) ~= nil then rawset(data, oxygenStr, math.huge) end
                            end
                        end
                        foundOxygen = true
                        if LocalPlayer then
                            task.spawn(function()
                                LocalPlayer:SetAttribute("equippedTank", "Basic Tank")
                                task.wait()
                                LocalPlayer:SetAttribute("equippedTank", "Fusion Tank")
                            end)
                        end
                        print("[Mod GC] Oxygen Tank modifications locked successfully.")
                    end
                    
                    -- Lava Suit Mod Lookup Check
                    if not foundSuit and rawget(v, suitKey) then
                        for _, data in pairs(v) do
                            if type(data) == "table" then
                                if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                                if rawget(data, timeStr) ~= nil then rawset(data, timeStr, math.huge) end
                            end
                        end
                        foundSuit = true
                        if LocalPlayer then
                            task.spawn(function()
                                LocalPlayer:SetAttribute("equippedSuit", "Basic Lava Suit")
                                task.wait()
                                LocalPlayer:SetAttribute("equippedSuit", "OP Lava Suit")
                            end)
                        end
                        print("[Mod GC] Lava Suit modifications locked successfully.")
                    end

                    -- Fins Mod Lookup Check
                    if not foundFins and rawget(v, finsKey) then
                        for _, data in pairs(v) do
                            if type(data) == "table" then
                                if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                                if rawget(data, speedStr) ~= nil then rawset(data, speedStr, defaultSpeed) end
                            end
                        end
                        foundFins = true
                        if LocalPlayer then
                            task.spawn(function()
                                LocalPlayer:SetAttribute("equippedFins", "Yellow Fins")
                                task.wait()
                                LocalPlayer:SetAttribute("equippedFins", "Abyss Fins")
                            end)
                        end
                        print("[Mod GC] Fins modifications locked successfully.")
                    end

                    -- Jetpacks Mod Lookup Check
                    if not foundJetpack and rawget(v, jetpackKey) then
                        for _, data in pairs(v) do
                            if type(data) == "table" then
                                if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                                if rawget(data, speedStr) ~= nil then rawset(data, speedStr, maxJetpackSpeed) end
                            end
                        end
                        foundJetpack = true
                        if LocalPlayer then
                            task.spawn(function()
                                LocalPlayer:SetAttribute("equippedJetpack", "Starter Jetpack")
                                task.wait()
                                LocalPlayer:SetAttribute("equippedJetpack", "OP Jetpack")
                            end)
                        end
                        print("[Mod GC] Jetpack modifications locked successfully.")
                    end
                end
            end
            task.wait(2) 
        end
    end)
end
applyGearModifications()

-- Scan workspace completely for target subfolders on startup
local function internalInitializeFolders()
    table.clear(activePetsFolders)
    table.clear(activeFruitsFolders)
    
    for _, child in ipairs(workspace:GetChildren()) do
        local petsMatch = child:FindFirstChild("Pets")
        if petsMatch and petsMatch:IsA("Folder") then
            table.insert(activePetsFolders, petsMatch)
        end
        
        local fruitsMatch = child:FindFirstChild("Fruits")
        if fruitsMatch and fruitsMatch:IsA("Folder") then
            table.insert(activeFruitsFolders, fruitsMatch)
        end
    end
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
    
    -- Comparison metrics trackers
    local highestRps = -math.huge
    local highestRarityWeight = -math.huge
    local shortestDistance = math.huge
    local currentTime = os.time()

    for _, folder in ipairs(activePetsFolders) do
        if folder.Parent then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj.PrimaryPart and obj:GetAttribute("Captured") ~= true then
                    local lifetime = obj:GetAttribute("Lifetime")
                    if obj == activelyFarmingPet or (lifetime and lifetime >= currentTime) then
                        
                        if permanentIgnore[obj] or obj == lastUsedPet or dynamicBlacklist[obj] then
                            continue
                        end

                        -- Identify Classification using HasTag and Rarity Attribute
                        local isLuckyBlock = obj:HasTag("LuckyBlock")
                        local isBoss = (obj:GetAttribute("Rarity") == "Boss")
                        local isNonBossPet = (not isBoss and not isLuckyBlock)

                        -- Target Mode Selection Verification Filter Check
                        if targetSelectionMode == "Bosses Only" and not isBoss then continue end
                        if targetSelectionMode == "Lucky Blocks Only" and not isLuckyBlock then continue end
                        if targetSelectionMode == "Non-Boss Pets Only" and not isNonBossPet then continue end

                        -- Mutation Check Filters
                        if ignoreNonMutated then
                            local mutation = obj:GetAttribute("Mutation")
                            if not mutation or mutation == "None" then
                                continue
                            end
                        end

                        -- Threshold Validations (Always apply filters based on data values)
                        local rpsValue = obj:GetAttribute("RPS") or 0
                        local strengthValue = obj:GetAttribute("Strength") or 0
                        if rpsValue < minRpsThreshold or strengthValue < minStrengthThreshold then
                            continue
                        end

                        local distance = (myPos - obj.PrimaryPart.Position).Magnitude

                        if isLuckyBlock then
                            -- Sort by Rarity using weights extracted from IndexMenu configuration
                            local rarityAttr = obj:GetAttribute("Rarity") or "Common"
                            local rarityWeight = rarityWeights[rarityAttr] or 0
                            
                            -- Prioritize Lucky Blocks based on Rarity Weight, then shortest distance
                            if not bestPet or not bestPet:HasTag("LuckyBlock") then
                                highestRarityWeight = rarityWeight
                                shortestDistance = distance
                                bestPet = obj
                            elseif rarityWeight > highestRarityWeight then
                                highestRarityWeight = rarityWeight
                                shortestDistance = distance
                                bestPet = obj
                            elseif rarityWeight == highestRarityWeight and distance < shortestDistance then
                                shortestDistance = distance
                                bestPet = obj
                            end
                        else
                            -- Regular pets and bosses: Sort by higher RPS value primarily
                            if not bestPet then
                                highestRps = rpsValue
                                shortestDistance = distance
                                bestPet = obj
                            -- If current candidate is a lucky block, standard pet immediately takes precedence if applicable, or handles pure RPS rank
                            elseif bestPet:HasTag("LuckyBlock") then
                                highestRps = rpsValue
                                shortestDistance = distance
                                bestPet = obj
                            elseif rpsValue > highestRps then
                                highestRps = rpsValue
                                shortestDistance = distance
                                bestPet = obj
                            elseif rpsValue == highestRps and distance < shortestDistance then
                                shortestDistance = distance
                                bestPet = obj
                            end
                        end

                    end
                end
            end
        end
    end
    
    return bestPet, (bestPet and (bestPet:GetAttribute("RPS") or bestPet:GetAttribute("Rarity")) or nil), shortestDistance
end

-- Dedicated Background Teleport Loop for Boss Tracking Independent Actions
local function startBossTrackingTeleportLoop()
    task.spawn(function()
        print("[Service Hook] Background Boss Teleport Worker Started.")
        while autoTeleportToBoss and ScriptID == CurrentScriptID do
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart then
                local myPos = rootPart.Position
                local closestBoss = nil
                local shortestDistance = math.huge

                for _, folder in ipairs(activePetsFolders) do
                    if folder.Parent then
                        for _, obj in ipairs(folder:GetChildren()) do
                            if obj:IsA("Model") and obj.PrimaryPart and obj:GetAttribute("Captured") ~= true and obj:GetAttribute("Rarity") == "Boss" then
                                local distance = (myPos - obj.PrimaryPart.Position).Magnitude
                                if distance < shortestDistance then
                                    shortestDistance = distance
                                    closestBoss = obj
                                end
                            end
                        end
                    end
                end

                if closestBoss and closestBoss.PrimaryPart then
                    rootPart.CFrame = CFrame.new(closestBoss.PrimaryPart.Position)
                end
            end
            task.wait(0.1) 
        end
        print("[Service Hook] Background Boss Teleport Worker Halted.")
    end)
end

-- Independent Self-Terminating Loop Function
local function startAutoFarmLoop()
    task.spawn(function()
        print("Automated Lasso Farm Loop Started.")
        while ScriptID == CurrentScriptID do
            if not autoFarmActive then break end
            
            updateTrackingClocks()
            local pet, statValue, distance = findBestValidPet()
            
            if pet and distance ~= math.huge then
                print(string.format("Current Best Target: %s | Sorted By value: %s | Distance: %.1f studs", pet.Name, tostring(statValue), distance))
            end
            
            if not pet then
                repeat
                    task.wait()
                    if not autoFarmActive or ScriptID ~= CurrentScriptID then return end
                    pet, statValue, distance = findBestValidPet()
                until pet ~= nil
            end
            
            activelyFarmingPet = pet
            
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart and pet.PrimaryPart then
                if distance > maxCaptureDistance and not autoTeleportToBoss then
                    print(string.format("Target outside configured range (%.1f > %d). Teleporting to target location...", distance, maxCaptureDistance))
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
                local captureStartTime = os.clock()
                local sequenceTimedOut = false
                local isBossPet = (pet:GetAttribute("Rarity") == "Boss")
                
                pcall(function()
                    stickyConnection = RunService.RenderStepped:Connect(function()
                        if ScriptID ~= CurrentScriptID or not pet or not pet.PrimaryPart then
                            if stickyConnection then stickyConnection:Disconnect() end
                            return
                        end
                        if autoTeleportToBoss then return end
                        
                        local currentCharacter = LocalPlayer.Character
                        local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
                        if currentRoot and pet.PrimaryPart then
                            currentRoot.CFrame = CFrame.new(pet.PrimaryPart.Position)
                        end
                    end)
                end)
                
                if isBossPet then
                    print("[Farming Engine] Target identified as Boss. Firing progression fallback value: 1 (Timeout Ignored)")
                    while pet.Parent and pet:GetAttribute("Captured") ~= true and ScriptID == CurrentScriptID do
                        UpdateProgress:FireServer(1)
                        task.wait()
                    end
                else
                    -- Dynamic Dynamic Progress Per Click (PPP) Calculation Engine
                    local lasso = LocalPlayer:GetAttribute("equippedLasso")
                    local petStrength = pet:GetAttribute("Strength") or 1
                    local difficulty = petStrength <= 14 and 1 or strengthConfig(lasso, petStrength)
                    local ppp = 100 / DifficultyConfig.Settings[difficulty].clicksRequired.min
                    
                    local currentPercent = 0
                    while pet.Parent and pet:GetAttribute("Captured") ~= true and ScriptID == CurrentScriptID do
                        if (os.clock() - captureStartTime) >= maxCaptureTimeLimit then
                            sequenceTimedOut = true
                            warn(string.format("Minigame capture runtime exceeded threshold limit (%s seconds). Force cancellation sequence initiated.", tostring(maxCaptureTimeLimit)))
                            pcall(function() CancelMinigame:FireServer() end)
                            break
                        end
                        
                        UpdateProgress:FireServer(currentPercent)
                        
                        -- Progress incremental tracking steps sequence logic
                        if currentPercent < 100 then
                            currentPercent = math.min(currentPercent + ppp, 100)
                        end
                        task.wait()
                    end
                end
                
                if not sequenceTimedOut then
                    lastUsedPet = pet
                    print("Progress sequence complete.")
                else
                    dynamicBlacklist[pet] = loopCooldownCount
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

-- Independent Self-Terminating Loop Function for Auto Collect Food Rain Event
local function startAutoCollectFoodRain()
    task.spawn(function()
        print("Auto Collect Food Rain Event Loop Started.")
        while autoCollectFoodRain and ScriptID == CurrentScriptID do
            local foodRainFolder = workspace:FindFirstChild("FoodRainEvent")
            local spawnedFolder = foodRainFolder and foodRainFolder:FindFirstChild("Spawned")
            
            if spawnedFolder then
                local descendants = spawnedFolder:GetDescendants()
                for i = 1, #descendants do
                    if not autoCollectFoodRain or ScriptID ~= CurrentScriptID then break end
                    
                    local prompt = descendants[i]
                    if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Enabled then
                        local parentPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
                        if parentPart then
                            local character = LocalPlayer.Character
                            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                            
                            if rootPart then
                                rootPart.CFrame = parentPart.CFrame
                                task.wait(interactionDelay)
                                
                                if prompt.Parent and prompt.Enabled then
                                    pcall(function()
                                        fireproximityprompt(prompt)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
        print("Auto Collect Food Rain Loop Completely Terminated.")
    end)
end

-- Independent Self-Terminating Loop Function for Auto Collect Easter Eggs
local function startAutoCollectEasterEggs()
    task.spawn(function()
        print("Auto Collect Easter Eggs Loop Started.")
        while autoCollectEasterEggs and ScriptID == CurrentScriptID do
            local easterEggsFolder = workspace:FindFirstChild("EasterEggs")
            
            if easterEggsFolder then
                local descendants = easterEggsFolder:GetDescendants()
                for i = 1, #descendants do
                    if not autoCollectEasterEggs or ScriptID ~= CurrentScriptID then break end
                    
                    local prompt = descendants[i]
                    if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Enabled then
                        local parentPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
                        if parentPart then
                            local character = LocalPlayer.Character
                            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                            
                            if rootPart then
                                rootPart.CFrame = parentPart.CFrame
                                task.wait(interactionDelay)
                                
                                if prompt.Parent and prompt.Enabled then
                                    pcall(function()
                                        fireproximityprompt(prompt)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
        print("Auto Collect Easter Eggs Loop Completely Terminated.")
    end)
end

-- Auto Universal Collect Loop (Excludes BeeHives, FoodRainEvent, and EasterEggs branches)
local function startAutoUniversalCollect()
    task.spawn(function()
        print("Auto Universal Collect Loop Started.")
        local beeHives = workspace:FindFirstChild("BeeHives")
        local foodRain = workspace:FindFirstChild("FoodRainEvent")
        local easterEggs = workspace:FindFirstChild("EasterEggs")
        
        while autoUniversalCollect and ScriptID == CurrentScriptID do
            local descendants = workspace:GetDescendants()
            
            for i = 1, #descendants do
                if not autoUniversalCollect or ScriptID ~= CurrentScriptID then break end
                
                local prompt = descendants[i]
                if prompt:IsA("ProximityPrompt") and prompt.ActionText == "Collect" and prompt.Enabled then
                    -- Hierarchy filter safety exclusions constraints mapping path verification
                    if beeHives and prompt:IsDescendantOf(beeHives) then continue end
                    if foodRain and prompt:IsDescendantOf(foodRain) then continue end
                    if easterEggs and prompt:IsDescendantOf(easterEggs) then continue end
                    
                    local targetPosition = nil
                    local firstPartAncestor = prompt:FindFirstAncestorWhichIsA("BasePart")
                    
                    if firstPartAncestor then
                        targetPosition = firstPartAncestor.CFrame
                    else
                        local firstModelAncestor = prompt:FindFirstAncestorWhichIsA("Model")
                        if firstModelAncestor then
                            targetPosition = firstModelAncestor:GetPivot()
                        end
                    end
                    
                    if targetPosition then
                        local character = LocalPlayer.Character
                        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                        
                        if rootPart then
                            rootPart.CFrame = targetPosition
                            task.wait(universalPreDelay)
                            
                            if prompt.Parent and prompt.Enabled then
                                pcall(function()
                                    fireproximityprompt(prompt)
                                end)
                            end
                            task.wait(universalPostDelay)
                        end
                    end
                end
            end
            task.wait(0.5)
        end
        print("Auto Universal Collect Loop Terminated.")
    end)
end

-- Unified Inventory Sync Fetcher (Cached via Metatable Interception)
local function updateInventoryCache(forceRefresh)
    local now = os.clock()
    if forceRefresh or not cachedInventoryData or (now - lastDataFetchTime) >= cacheDurationLimit then
        local success, data = pcall(function() return retrieveData:InvokeServer() end)
        if success and data and data.inventory and data.inventory.pets then
            cachedInventoryData = data.inventory.pets
            lastDataFetchTime = now
            dataCycleDone = false   
            placeCycleDone = false  
            blockCycleDone = false
            return true
        else
            warn("Inventory data evaluation retrieval failed via remote proxy handshake.")
            return false
        end
    end
    return true
end

-- Inventory Management Utilities (Sell Worst Pet)
local function sellWorstPetAction(isAutomatedCall)
    if dataCycleDone and isAutomatedCall then
        return false
    end

    if not updateInventoryCache(false) or not cachedInventoryData then
        return false
    end
    
    local pets = cachedInventoryData
    local excludeKeyword = "Lucky Block"
    
    local lowestRPS = math.huge
    local lowestPetUUID = nil
    local lowestPetData = nil
    
    for uuid, pet in pairs(pets) do
        local RPS = pet.revPerSec
        local name = pet.name
        
        if not string.find(name, excludeKeyword) then
            if RPS < lowestRPS then
                lowestRPS = RPS
                lowestPetUUID = uuid
                lowestPetData = pet
            end
        end
    end
    
    if lowestPetUUID and lowestPetData then
        if lowestPetData.revPerSec < sellRpsThreshold then
            print(string.format("[Inventory Engine] Lowest pet RPS (%.1f) below threshold (%d). Selling UUID: %s", lowestPetData.revPerSec, sellRpsThreshold, lowestPetUUID))
            local sellSuccess = sellPet:InvokeServer(lowestPetUUID, false)
            if sellSuccess then
                removeTool:InvokeServer(lowestPetUUID)
                pets[lowestPetUUID] = nil
                print("Successfully sold and cleared inventory tool instance mapping for pet: " .. lowestPetData.name)
                return true
            else
                warn("Server denied execution request to sell target pet.")
            end
        else
            if not isAutomatedCall then
                print(string.format("[Inventory Engine] Lowest pet RPS (%.1f) is above threshold limit (%d). Operations bypassed.", lowestPetData.revPerSec, sellRpsThreshold))
            else
                dataCycleDone = true 
            end
        end
    else
        if not isAutomatedCall then
            print("[Inventory Engine] No valid pets found inside inventory tables parsing sequence.")
        end
    end
    return false
end

local function startAutoSellWorstPetLoop()
    task.spawn(function()
        print("Auto Sell Worst Pet Engine Active.")
        while autoSellWorstPet and ScriptID == CurrentScriptID do
            local executedSale = sellWorstPetAction(true)
            if dataCycleDone then
                local remainingCacheTime = math.max(0, cacheDurationLimit - (os.clock() - lastDataFetchTime))
                if remainingCacheTime > 0 then
                    task.wait(math.min(remainingCacheTime, 5))
                else
                    updateInventoryCache(true)
                end
            elseif not executedSale then
                task.wait(2)
            else
                task.wait(0.3)
            end
        end
        print("Auto Sell Worst Pet Engine Deactivated.")
    end)
end

-- Inventory Management Utilities (Auto Place Best Pets)
local function placeBestPetAction(isAutomatedCall)
    if placeCycleDone and isAutomatedCall then
        return false
    end

    local canPlaceSuccess, canPlace = pcall(function() return getMaxPetsForPlayer:InvokeServer() end)
    if not canPlaceSuccess or not canPlace then
        if not isAutomatedCall then
            warn("[Pen Service] Player placement limit checks failed or pen space is completely full.")
        else
            placeCycleDone = true 
        end
        return false
    end

    if not updateInventoryCache(false) or not cachedInventoryData then
        return false
    end

    local pets = cachedInventoryData
    local excludeKeyword = "Lucky Block"
    
    local highestRPS = -math.huge
    local highestPetUUID = nil
    local highestPetData = nil
    
    for uuid, pet in pairs(pets) do
        local RPS = pet.revPerSec
        local name = pet.name
        
        if not string.find(name, excludeKeyword) then
            if RPS > highestRPS then
                highestRPS = RPS
                highestPetUUID = uuid
                highestPetData = pet
            end
        end
    end

    if highestPetUUID and highestPetData then
        print(string.format("[Placement Engine] Highest pet found: %s (RPS: %.1f). Placing into base pen...", highestPetData.name, highestPetData.revPerSec))
        
        local success = pcall(function()
            RequestPlacePet:FireServer(highestPetUUID, Vector3.zero, CFrame.new())
        end)
        
        if success then
            pets[highestPetUUID] = nil
            return true
        end
    else
        if not isAutomatedCall then
            print("[Placement Engine] No eligible pets detected in inventory caches.")
        else
            placeCycleDone = true 
        end
    end
    return false
end

local function startAutoPlaceBestPetsLoop()
    task.spawn(function()
        print("Auto Place Best Pets Engine Active.")
        while autoPlaceBestPets and ScriptID == CurrentScriptID do
            local executedPlacement = placeBestPetAction(true)
            if placeCycleDone then
                local remainingCacheTime = math.max(0, cacheDurationLimit - (os.clock() - lastDataFetchTime))
                if remainingCacheTime > 0 then
                    task.wait(math.min(remainingCacheTime, 5))
                else
                    updateInventoryCache(true)
                end
            elseif not executedPlacement then
                task.wait(2)
            else
                task.wait(0.3)
            end
        end
        print("Auto Place Best Pets Engine Deactivated.")
    end)
end

-- Inventory Management Utilities (Auto Place Lucky Blocks)
local function placeLuckyBlockAction(isAutomatedCall)
    if blockCycleDone and isAutomatedCall then
        return false
    end

    local canPlaceSuccess, canPlace = pcall(function() return getMaxPetsForPlayer:InvokeServer() end)
    if not canPlaceSuccess or not canPlace then
        if not isAutomatedCall then
            warn("[Pen Service] Player placement limit checks failed or pen space is completely full.")
        else
            blockCycleDone = true
        end
        return false
    end

    if not updateInventoryCache(false) or not cachedInventoryData then
        return false
    end

    local pets = cachedInventoryData
    local matchKeyword = "Lucky Block"
    
    local highestWeight = -math.huge
    local bestBlockUUID = nil
    local bestBlockData = nil
    
    for uuid, pet in pairs(pets) do
        local name = pet.name
        
        if string.find(name, matchKeyword) then
            local blockRarity = pet.Rarity or "Common"
            local currentWeight = rarityWeights[blockRarity] or 0
            
            if currentWeight > highestWeight then
                highestWeight = currentWeight
                bestBlockUUID = uuid
                bestBlockData = pet
            end
        end
    end

    if bestBlockUUID and bestBlockData then
        print(string.format("[Lucky Block Engine] Best lucky block found: %s (Rarity: %s). Placing into pen...", bestBlockData.name, tostring(bestBlockData.Rarity)))
        
        local success = pcall(function()
            RequestPlacePet:FireServer(bestBlockUUID, Vector3.zero, CFrame.new())
        end)
        
        if success then
            pets[bestBlockUUID] = nil
            return true
        end
    else
        if not isAutomatedCall then
            print("[Lucky Block Engine] No lucky blocks detected in inventory cache tables.")
        else
            blockCycleDone = true
        end
    end
    return false
end

local function startAutoPlaceLuckyBlocksLoop()
    task.spawn(function()
        print("Auto Place Lucky Blocks Engine Active.")
        while autoPlaceLuckyBlocks and ScriptID == CurrentScriptID do
            local executedPlacement = placeLuckyBlockAction(true)
            if blockCycleDone then
                local remainingCacheTime = math.max(0, cacheDurationLimit - (os.clock() - lastDataFetchTime))
                if remainingCacheTime > 0 then
                    task.wait(math.min(remainingCacheTime, 5))
                else
                    updateInventoryCache(true)
                end
            elseif not executedPlacement then
                task.wait(2)
            else
                task.wait(0.3)
            end
        end
        print("Auto Place Lucky Blocks Engine Deactivated.")
    end)
end

-- Map Extraction Pen Actions
local function pickupAllMapPetsAction()
    local pensFolder = workspace:FindFirstChild("PlayerPens")
    if not pensFolder then return end
    
    local targetPen = nil
    for _, pen in ipairs(pensFolder:GetChildren()) do
        if pen:GetAttribute("Owner") == LocalPlayer.Name then
            targetPen = pen
            break
        end
    end
    
    if targetPen and targetPen:FindFirstChild("Pets") then
        local petsToCollect = targetPen.Pets:GetChildren()
        print(string.format("[Pen Sync Engine] Gathering %d pets from active base pen.", #petsToCollect))
        for i = 1, #petsToCollect do
            local petObj = petsToCollect[i]
            pcall(function()
                pickupRequest:InvokeServer("Pet", petObj.Name, petObj)
            end)
        end
        print("[Pen Sync Engine] All eligible pen pets processed.")
    else
        warn("Could not determine base player pen zone verification match.")
    end
end

local function pickupLowestRpsPlacedPetAction()
    local pensFolder = workspace:FindFirstChild("PlayerPens")
    if not pensFolder then return end
    
    local targetPen = nil
    for _, pen in ipairs(pensFolder:GetChildren()) do
        if pen:GetAttribute("Owner") == LocalPlayer.Name then
            targetPen = pen
            break
        end
    end
    
    if targetPen and targetPen:FindFirstChild("Pets") then
        local petsPlaced = targetPen.Pets:GetChildren()
        if #petsPlaced == 0 then
            print("[Pen Sync Engine] Placed pets table is empty.")
            return
        end
        
        -- Fallback to network parsing layer index lookup to access attributes cleanly from workspace models
        local lowestRPS = math.huge
        local targetPetModel = nil
        
        for i = 1, #petsPlaced do
            local pModel = petsPlaced[i]
            local rpsAttr = pModel:GetAttribute("RPS") or 0
            
            if rpsAttr < lowestRPS then
                lowestRPS = rpsAttr
                targetPetModel = pModel
            end
        end
        
        if targetPetModel then
            print(string.format("[Pen Sync Engine] Placed lowest RPS target discovered: %s (RPS: %.1f). Extracting to inventory...", targetPetModel.Name, lowestRPS))
            pcall(function()
                pickupRequest:InvokeServer("Pet", targetPetModel.Name, targetPetModel)
            end)
        end
    else
        warn("Could not target owner pen node workspace allocations.")
    end
end

-- Anti AFK UI & Core State Handler Execution
local function handleAFKScreenState()
    local afkGui = PlayerGui:FindFirstChild("AFK")
    if not afkGui then return end
    
    if antiAfkActive then
        if afkGui.Enabled == true then
            afkGui.Enabled = false
        end
    end
end

local function startAntiAFK()
    local function handleAFKState()
        if ScriptID ~= CurrentScriptID or not antiAfkActive then 
            if afkConnection then afkConnection:Disconnect() afkConnection = nil end 
            if afkScreenConnection then afkScreenConnection:Disconnect() afkScreenConnection = nil end
            
            local afkGui = PlayerGui:FindFirstChild("AFK")
            if afkGui then
                local isAFK = LocalPlayer:GetAttribute("AFK_NextRewardTime") ~= nil
                afkGui.Enabled = isAFK
            end
            return 
        end
        LocalPlayer:SetAttribute("AFK_Active", false)
    end
    
    handleAFKState()
    
    if afkConnection then afkConnection:Disconnect() end
    afkConnection = LocalPlayer:GetAttributeChangedSignal("AFK_Active"):Connect(handleAFKState)
    
    local afkGui = PlayerGui:FindFirstChild("AFK")
    if afkGui then
        if afkScreenConnection then afkScreenConnection:Disconnect() end
        handleAFKScreenState()
        afkScreenConnection = afkGui:GetPropertyChangedSignal("Enabled"):Connect(handleAFKScreenState)
    end
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
                    -- Safety catch-all
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

MainTab:CreateSection("--- Toggles Automation ---")

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
    Name = "Auto Universal Collect ('Collect')",
    CurrentValue = autoUniversalCollect,
    Flag = "AutoUniversalCollectToggle",
    Callback = function(Value)
        autoUniversalCollect = Value
        if Value then
            startAutoUniversalCollect()
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
    Name = "Auto Collect Food Rain Event",
    CurrentValue = autoCollectFoodRain,
    Flag = "AutoCollectFoodRainToggle",
    Callback = function(Value)
        autoCollectFoodRain = Value
        if Value then
            startAutoCollectFoodRain()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Easter Eggs",
    CurrentValue = autoCollectEasterEggs,
    Flag = "AutoCollectEasterEggsToggle",
    Callback = function(Value)
        autoCollectEasterEggs = Value
        if Value then
            startAutoCollectEasterEggs()
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

MainTab:CreateToggle({
    Name = "Auto Teleport to Closest Boss",
    CurrentValue = autoTeleportToBoss,
    Flag = "AutoTeleportToBossToggle",
    Callback = function(Value)
        autoTeleportToBoss = Value
        if Value then
            startBossTrackingTeleportLoop()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Sell Worst Pet",
    CurrentValue = autoSellWorstPet,
    Flag = "AutoSellWorstPetToggleFlag",
    Callback = function(Value)
        autoSellWorstPet = Value
        if Value then
            dataCycleDone = false
            startAutoSellWorstPetLoop()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Place Best Pets",
    CurrentValue = autoPlaceBestPets,
    Flag = "AutoPlaceBestPetsToggleFlag",
    Callback = function(Value)
        autoPlaceBestPets = Value
        if Value then
            placeCycleDone = false
            startAutoPlaceBestPetsLoop()
        end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Place Lucky Blocks",
    CurrentValue = autoPlaceLuckyBlocks,
    Flag = "AutoPlaceLuckyBlocksToggleFlag",
    Callback = function(Value)
        autoPlaceLuckyBlocks = Value
        if Value then
            blockCycleDone = false
            startAutoPlaceLuckyBlocksLoop()
        end
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
        startAntiAFK()
    end,
})

MainTab:CreateSection("--- Instant One-Time Actions ---")

MainTab:CreateButton({
    Name = "Sell Worst Pet",
    Callback = function()
        sellWorstPetAction(false)
    end,
})

MainTab:CreateButton({
    Name = "Place Best Pet",
    Callback = function()
        placeBestPetAction(false)
    end,
})

MainTab:CreateButton({
    Name = "Pickup Lowest Placed Pet",
    Callback = function()
        pickupLowestRpsPlacedPetAction()
    end,
})

MainTab:CreateButton({
    Name = "Pickup All Pen Pets",
    Callback = function()
        pickupAllMapPetsAction()
    end,
})

MainTab:CreateButton({
    Name = "Collect Pet Cash",
    Callback = function()
        pcall(function()
            collectAllPetCash:FireServer()
        end)
    end,
})

MainTab:CreateButton({
    Name = "Force Cancel Minigame",
    Callback = function()
        pcall(function()
            CancelMinigame:FireServer()
        end)
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

MainTab:CreateSection("--- Targeting Filters & Modes ---")

MainTab:CreateDropdown({
    Name = "Farming Mode Filter Target",
    Options = {"All", "Bosses Only", "Lucky Blocks Only", "Non-Boss Pets Only"},
    CurrentOption = targetSelectionMode,
    Flag = "FarmingModeFilterDropdown",
    Callback = function(Value)
        targetSelectionMode = type(Value) == "table" and Value[1] or Value
        print("[Config System] Core farm selection mode changed to: " .. targetSelectionMode)
    end
})

MainTab:CreateToggle({
    Name = "Ignore All Non-Mutated Pets",
    CurrentValue = ignoreNonMutated,
    Flag = "IgnoreNonMutatedToggleFlag",
    Callback = function(Value)
        ignoreNonMutated = Value
        print("[Config System] Filter ignore non-mutated parameter set to: " .. tostring(Value))
    end
})

MainTab:CreateSection("--- Tuning Configurations ---")

MainTab:CreateInput({
    Name = "Sell Pet Minimum RPS Threshold",
    PlaceholderText = "Default: 50",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local val = tonumber(Text)
        if val then
            sellRpsThreshold = val
            dataCycleDone = false 
            print(string.format("[Config System] Sell Pet threshold configuration adjusted: %d RPS", val))
        end
    end,
})

MainTab:CreateInput({
    Name = "Minimum RPS Threshold",
    PlaceholderText = "Ex: 1.5k, 50M, 2B...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        minRpsThreshold = parseStringToNumber(Text)
        print(string.format("[Config System] Filter minimum RPS metric updated: %d RPS", minRpsThreshold))
    end,
})

MainTab:CreateInput({
    Name = "Minimum Strength Threshold",
    PlaceholderText = "Default: 100",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        minStrengthThreshold = parseStringToNumber(Text)
        print(string.format("[Config System] Filter minimum Strength metric updated: %d Strength", minStrengthThreshold))
    end,
})

MainTab:CreateInput({
    Name = "Universal Pre-Delay (Teleport Wait)",
    PlaceholderText = "Default: 0.1",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local val = tonumber(Text)
        if val then
            universalPreDelay = val
            print("[Config System] Universal pre-delay structural check timing adjusted: " .. tostring(val))
        end
    end,
})

MainTab:CreateInput({
    Name = "Universal Post-Delay (Next Target Wait)",
    PlaceholderText = "Default: 0.2",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local val = tonumber(Text)
        if val then
            universalPostDelay = val
            print("[Config System] Universal post-delay pacing evaluation interval modified: " .. tostring(val))
        end
    end,
})

MainTab:CreateSlider({
    Name = "Event Intercept Sync Delay",
    Range = {0, 2},
    Increment = 0.05,
    CurrentValue = interactionDelay,
    Flag = "EventInterceptSyncDelayFlag",
    Callback = function(Value)
        interactionDelay = Value
    end,
})

MainTab:CreateSlider({
    Name = "Max Capture Range (Teleport Threshold)",
    Range = {10, 65},
    Increment = 1,
    CurrentValue = maxCaptureDistance,
    Flag = "MaxCaptureRangeFlag",
    Callback = function(Value)
        maxCaptureDistance = Value
    end,
})

MainTab:CreateSlider({
    Name = "Max Capture Time Limit (Seconds)",
    Range = {2, 30},
    Increment = 1,
    CurrentValue = maxCaptureTimeLimit,
    Flag = "MaxCaptureTimeLimitFlag",
    Callback = function(Value)
        maxCaptureTimeLimit = Value
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
