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

-- Create custom rarity weights mapping from module order safely
local orderofpets = petsindex.RarityOrder
local rarityWeights = {}
if orderofpets then
    for index, rarityName in ipairs(orderofpets) do
        rarityWeights[rarityName] = index
    end
end
rarityWeights["Secret"] = #orderofpets + 1

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

-- Knit RF Services Path Correction
local KnitFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit")
local AFKServiceFolder = KnitFolder:WaitForChild("Services")

local StartAFK = AFKServiceFolder:WaitForChild("AFKService"):WaitForChild("RF"):WaitForChild("StartAFK")
local StopAFK = AFKServiceFolder:WaitForChild("AFKService"):WaitForChild("RF"):WaitForChild("StopAFK")

local PenServiceFolder = AFKServiceFolder:WaitForChild("PenService"):WaitForChild("RF")
local getMaxPetsForPlayer = PenServiceFolder:WaitForChild("getMaxPetsForPlayer")

-- State Toggles & Config Variables
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
local autoReplaceWorstWithBest = false
local autoLoopTeleport = false
local selectedIsland = nil

-- Filter Configs
local targetSelectionMode = "All" 
local ignoreNonMutated = false

local minRpsThreshold = 0
local minStrengthThreshold = 100
local loopCooldownCount = 5
local maxCaptureDistance = 45
local teleportWaitTime = 0.3
local maxCaptureTimeLimit = 10
local interactionDelay = 0.2 
local sellRpsThreshold = 50

-- Auto Loop Teleport Configurations
local loopTeleportInterval = 20
local noPetTimeoutLimit = 10

-- Universal Collect Dynamic Variables
local universalPreDelay = 0.1
local universalPostDelay = 0.2

-- Inventory Caching & Cycle Controls
local cachedInventoryData = nil
local lastDataFetchTime = 0
local cacheDurationLimit = 300 

local dataCycleDone = false
local placeCycleDone = false
local blockCycleDone = false
local replaceCycleDone = false

-- UPDATED: Integrated high-performance namecall interception with strict guard clauses
local function initiateNamecallInterception()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        -- 1. GUARD CLAUSE: Immediately exit if it's not a server invocation
        if method ~= "InvokeServer" then
            setnamecallmethod(method)
            return oldNamecall(self, ...)
        end
        
        -- 2. GUARD CLAUSE: Immediately exit if it's not our target script or remote
        if self ~= retrieveData or ScriptID ~= CurrentScriptID then
            setnamecallmethod(method)
            return oldNamecall(self, ...)
        end
        
        -- 3. INTERCEPTION: Handle the target remote safely
        setnamecallmethod(method)
        local data = oldNamecall(self, ...)
        
        if type(data) ~= "table" then 
            return data 
        end
        
        local inventory = data.inventory
        if inventory and inventory.pets then
            cachedInventoryData = inventory.pets
            lastDataFetchTime = os.clock()
            dataCycleDone = false   
            placeCycleDone = false  
            blockCycleDone = false
            replaceCycleDone = false
        end
        
        return data
    end)
end
initiateNamecallInterception()

-- Suffix Parsing Map
local suffixMultipliers = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
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

-- Tracking Cache Variables (Weak-keyed to prevent referencing dead GC instances)
local lastUsedPet = nil
local permanentIgnore = setmetatable({}, {__mode = "k"})
local dynamicBlacklist = setmetatable({}, {__mode = "k"})
local afkConnection = nil
local afkScreenConnection = nil

local function applyGearModifications()
    task.spawn(function()
        while ScriptID == CurrentScriptID and not getrenv()._G.Loaded do
            task.wait(1)
        end
        if ScriptID ~= CurrentScriptID then return end

        local oxygenKey1 = "Basic Tank"
        local suitKey = "Basic Lava Suit"
        local finsKey = "Yellow Fins"
        local jetpackKey = "Starter Jetpack"

        local costStr = string.char(67, 111, 115, 116)          
        local oxygenStr = string.char(79, 120, 121, 103, 101, 110) 
        local timeStr = string.char(84, 105, 109, 104)          
        local speedStr = string.char(83, 112, 101, 101, 100)    

        local maxDiscoveredFinSpeed = 50
        local maxDiscoveredJetpackSpeed = 70

        local gc = getgc(true)
        for i = 1, #gc do
            local v = gc[i]
            if type(v) == "table" then
                if rawget(v, oxygenKey1) then
                    for _, data in pairs(v) do
                        if type(data) == "table" then
                            if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                            if rawget(data, oxygenStr) ~= nil then rawset(data, oxygenStr, math.huge) end
                        end
                    end
                elseif rawget(v, suitKey) then
                    for _, data in pairs(v) do
                        if type(data) == "table" then
                            if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                            if rawget(data, timeStr) ~= nil then rawset(data, timeStr, math.huge) end
                        end
                    end
                elseif rawget(v, finsKey) then
                    for _, data in pairs(v) do
                        if type(data) == "table" then
                            if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                            if rawget(data, speedStr) ~= nil then rawset(data, speedStr, maxDiscoveredFinSpeed) end
                        end
                    end
                elseif rawget(v, jetpackKey) then
                    for _, data in pairs(v) do
                        if type(data) == "table" then
                            if rawget(data, costStr) ~= nil then rawset(data, costStr, 0) end
                            if rawget(data, speedStr) ~= nil then rawset(data, speedStr, maxDiscoveredJetpackSpeed) end
                        end
                    end
                end
            end
        end
        
        if LocalPlayer then
            pcall(function()
                LocalPlayer:SetAttribute("equippedTank", "Fusion Tank")
                LocalPlayer:SetAttribute("equippedSuit", "OP Lava Suit")
                LocalPlayer:SetAttribute("equippedFins", "Abyss Fins")
                LocalPlayer:SetAttribute("equippedJetpack", "OP Jetpack")
            end)
        end
        
        gc = nil
    end)
end
applyGearModifications()

-- Island Data Setup
local islandConfigs = {
    ["Roaming"] = { Target = function() local floor = workspace:FindFirstChild("LOCKED_FLOOR") return floor and (floor:GetPivot().Position + Vector3.new(0, 15, 0)) end, Boxes = function() return workspace:FindFirstChild("RoamingPets") and workspace.RoamingPets:FindFirstChild("SpawnBoxes") end, Required = 1 },
    ["VolcanoIsland"] = { Target = function() local qt = workspace:FindFirstChild("QuickTravel") local volcano = qt and qt:FindFirstChild("VolcanoIsland") return volcano and volcano:FindFirstChild("Marker") end, Boxes = function() return workspace:FindFirstChild("VolcanoIslandPets") and workspace.VolcanoIslandPets:FindFirstChild("SpawnBoxes") end, Required = 13 },
    ["SkyIsland / DragonIsland"] = { Target = function() local qt = workspace:FindFirstChild("QuickTravel") local dragon = qt and qt:FindFirstChild("DragonIsland") return dragon and dragon:FindFirstChild("Marker") end, Boxes = function() return workspace:FindFirstChild("SkyIslandPets") and workspace.SkyIslandPets:FindFirstChild("SpawnBoxes") end, Required = 13 },
    ["WaterIsland"] = { Target = function() local qt = workspace:FindFirstChild("QuickTravel") local depths = qt and qt:FindFirstChild("ForgottenDepths") local marker = depths and depths:FindFirstChild("Marker") if marker then return marker end local cage = workspace:FindFirstChild("CAGE") return cage and cage:FindFirstChild("Part") end, Boxes = function() return workspace:FindFirstChild("WaterIslandPets") and workspace.WaterIslandPets:FindFirstChild("SpawnBoxes") end, Required = 9 },
    ["BeeIsland"] = { Target = function() local qt = workspace:FindFirstChild("QuickTravel") local bee = qt and qt:FindFirstChild("BeeIsland") return bee and bee:FindFirstChild("Marker") end, Boxes = function() return workspace:FindFirstChild("BeeIslandPets") and workspace.BeeIslandPets:FindFirstChild("SpawnBoxes") end, Required = 15 },
    ["LavaIsland"] = { Target = function() local zones = workspace:FindFirstChild("EnterZones") local volcanoZone = zones and zones:FindFirstChild("- Volcano Island -") if volcanoZone then return volcanoZone end local qt = workspace:FindFirstChild("QuickTravel") local volcano = qt and qt:FindFirstChild("VolcanoIsland") return volcano and volcano:FindFirstChild("Marker") end, Boxes = function() return workspace:FindFirstChild("LavaIslandPets") and workspace.LavaIslandPets:FindFirstChild("SpawnBoxes") end, Required = 2 },
    ["SafariIsland"] = { Target = function() local qt = workspace:FindFirstChild("QuickTravel") local safari = qt and qt:FindFirstChild("SafariIsland") return safari and safari:FindFirstChild("Marker") end, Boxes = function() return workspace:FindFirstChild("SafariIslandPets") and workspace.SafariIslandPets:FindFirstChild("SpawnBoxes") end, Required = 17 },
    ["CaveIsland"] = { Target = function() local qt = workspace:FindFirstChild("QuickTravel") local cave = qt and qt:FindFirstChild("CaveIsland") local marker = cave and cave:FindFirstChild("Marker") if marker then return marker end local topCave = workspace:FindFirstChild("TopCaveArea") return topCave and topCave:FindFirstChild("Tp") end, Boxes = function() return workspace:FindFirstChild("CaveIslandPets") and workspace.CaveIslandPets:FindFirstChild("SpawnBoxes") end, Required = 14 },
    ["DeepCave"] = { Target = function() local portal = workspace:FindFirstChild("Workspace") and workspace.Workspace:FindFirstChild("TeleportPortal") or workspace:FindFirstChild("TeleportPortal") return portal and portal:FindFirstChild("Tp") end, Boxes = function() return workspace:FindFirstChild("DeepCavePets") and workspace.DeepCavePets:FindFirstChild("SpawnBoxes") end, Required = 4 },
    ["AbyssIslandPets"] = { Target = function() local coral = workspace:FindFirstChild("Coral") if coral and coral.PrimaryPart then return coral.PrimaryPart end local crystal = workspace:FindFirstChild("AbyssCrystal") if crystal and crystal.PrimaryPart then return crystal.PrimaryPart end end, Boxes = function() return workspace:FindFirstChild("AbyssIslandPets") and workspace.AbyssIslandPets:FindFirstChild("SpawnBoxes") end, Required = 16 }
}

local orderedIslandKeys = { "Roaming", "VolcanoIsland", "SkyIsland / DragonIsland", "WaterIsland", "BeeIsland", "LavaIsland", "SafariIsland", "CaveIsland", "DeepCave", "AbyssIslandPets" }

local function updateTrackingClocks()
    for petInstance, loopsLeft in pairs(dynamicBlacklist) do
        if loopsLeft <= 1 then
            dynamicBlacklist[petInstance] = nil
        else
            dynamicBlacklist[petInstance] = loopsLeft - 1
        end
    end
end

local activelyFarmingPet = nil
local lastTimePetDiscovered = os.clock()

local function findBestValidPet()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil, nil, nil end
    
    local myPos = rootPart.Position
    local bestPet = nil
    
    local highestRps = -math.huge
    local highestRarityWeight = -math.huge
    local shortestDistance = math.huge
    local currentTime = os.time()
    local foundAnyValidWorkspacePet = false

    for i = 1, #activePetsFolders do
        local folder = activePetsFolders[i]
        if folder and folder.Parent then
            local children = folder:GetChildren()
            for j = 1, #children do
                local obj = children[j]
                if obj:IsA("Model") and obj.PrimaryPart and obj:GetAttribute("Captured") ~= true then
                    local lifetime = obj:GetAttribute("Lifetime")
                    if obj == activelyFarmingPet or (lifetime and lifetime >= currentTime) then
                        
                        foundAnyValidWorkspacePet = true

                        if permanentIgnore[obj] or obj == lastUsedPet or dynamicBlacklist[obj] then
                            continue
                        end

                        local isLuckyBlock = obj:HasTag("LuckyBlock")
                        local isBoss = (obj:GetAttribute("Rarity") == "Boss")
                        local isNonBossPet = (not isBoss and not isLuckyBlock)

                        if targetSelectionMode == "Bosses Only" and not isBoss then continue end
                        if targetSelectionMode == "Lucky Blocks Only" and not isLuckyBlock then continue end
                        if targetSelectionMode == "Non-Boss Pets Only" and not isNonBossPet then continue end

                        if ignoreNonMutated then
                            local mutation = obj:GetAttribute("Mutation")
                            if not mutation or mutation == "None" then continue end
                        end

                        local rpsValue = obj:GetAttribute("RPS") or 0
                        local strengthValue = obj:GetAttribute("Strength") or 0
                        if rpsValue < minRpsThreshold or strengthValue < minStrengthThreshold then
                            continue
                        end

                        local distance = (myPos - obj.PrimaryPart.Position).Magnitude

                        if isLuckyBlock then
                            local rarityAttr = obj:GetAttribute("Rarity") or "Common"
                            local rarityWeight = rarityWeights[rarityAttr] or 0
                            
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
                            if not bestPet then
                                highestRps = rpsValue
                                shortestDistance = distance
                                bestPet = obj
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
    
    if foundAnyValidWorkspacePet then
        lastTimePetDiscovered = os.clock()
    end

    return bestPet, (bestPet and (bestPet:GetAttribute("RPS") or bestPet:GetAttribute("Rarity")) or nil), shortestDistance
end

local function startBossTrackingTeleportLoop()
    task.spawn(function()
        while autoTeleportToBoss and ScriptID == CurrentScriptID do
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart then
                local myPos = rootPart.Position
                local closestBoss = nil
                local shortestDistance = math.huge

                for i = 1, #activePetsFolders do
                    local folder = activePetsFolders[i]
                    if folder and folder.Parent then
                        local children = folder:GetChildren()
                        for j = 1, #children do
                            local obj = children[j]
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
    end)
end

local function startAutoFarmLoop()
    task.spawn(function()
        while ScriptID == CurrentScriptID and autoFarmActive do
            updateTrackingClocks()
            local pet, statValue, distance = findBestValidPet()
            
            if not pet then
                repeat
                    task.wait(0.2)
                    if not autoFarmActive or ScriptID ~= CurrentScriptID then return end
                    pet, statValue, distance = findBestValidPet()
                until pet ~= nil
            end
            
            activelyFarmingPet = pet
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if rootPart and pet.PrimaryPart then
                if distance > maxCaptureDistance and not autoTeleportToBoss then
                    rootPart.CFrame = CFrame.new(pet.PrimaryPart.Position)
                    task.wait(teleportWaitTime)
                end
            else
                activelyFarmingPet = nil
                task.wait(0.1)
                continue
            end
            
            if ScriptID ~= CurrentScriptID or not autoFarmActive then 
                activelyFarmingPet = nil
                break 
            end
            
            local pivot = pet:GetPivot()
            local success, canStart = pcall(function()
                return minigameRequest:InvokeServer(pet, pivot)
            end)
            
            if success and canStart == true then
                local stickyConnection = nil
                local captureStartTime = os.clock()
                local sequenceTimedOut = false
                local isBossPet = (pet:GetAttribute("Rarity") == "Boss")
                
                stickyConnection = RunService.RenderStepped:Connect(function()
                    if ScriptID ~= CurrentScriptID or not pet or not pet.PrimaryPart or not autoFarmActive then
                        if stickyConnection then stickyConnection:Disconnect() stickyConnection = nil end
                        return
                    end
                    if autoTeleportToBoss then return end
                    
                    local currentCharacter = LocalPlayer.Character
                    local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
                    if currentRoot and pet.PrimaryPart then
                        currentRoot.CFrame = CFrame.new(pet.PrimaryPart.Position)
                    end
                end)
                
                if isBossPet then
                    while pet.Parent and pet:GetAttribute("Captured") ~= true and ScriptID == CurrentScriptID and autoFarmActive do
                        UpdateProgress:FireServer(1)
                        task.wait()
                    end
                else
                    local lasso = LocalPlayer:GetAttribute("equippedLasso")
                    local petStrength = pet:GetAttribute("Strength") or 1
                    local difficulty = petStrength <= 14 and 1 or strengthConfig(lasso, petStrength)
                    local configSettings = DifficultyConfig.Settings[difficulty]
                    local ppp = 100 / (configSettings and configSettings.clicksRequired.min or 20)
                    
                    local currentPercent = 0
                    while pet.Parent and pet:GetAttribute("Captured") ~= true and ScriptID == CurrentScriptID and autoFarmActive do
                        if (os.clock() - captureStartTime) >= maxCaptureTimeLimit then
                            sequenceTimedOut = true
                            pcall(function() CancelMinigame:FireServer() end)
                            break
                        end
                        
                        UpdateProgress:FireServer(currentPercent)
                        if currentPercent < 100 then
                            currentPercent = math.min(currentPercent + ppp, 100)
                        end
                        task.wait()
                    end
                end
                
                if not sequenceTimedOut then
                    lastUsedPet = pet
                else
                    dynamicBlacklist[pet] = loopCooldownCount
                end
                
                if stickyConnection then
                    stickyConnection:Disconnect()
                    stickyConnection = nil
                end
            else
                local errorReason = tostring(canStart)
                if errorReason == "pet_already_captured" or errorReason == "pet_destroyed" then
                    permanentIgnore[pet] = true
                else
                    lastUsedPet = pet
                end
                task.wait(0.2)
            end
            
            activelyFarmingPet = nil
            task.wait()
        end
    end)
end

local function executeAreaTeleport(islandName)
    local config = islandConfigs[islandName]
    if not config then return end
    
    local isFirstTeleportPass = true
    while ScriptID == CurrentScriptID do
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then 
            task.wait(0.5)
            continue 
        end
        
        local boxesObj = config.Boxes()
        local currentCount = boxesObj and #boxesObj:GetChildren() or 0
        
        if not isFirstTeleportPass and currentCount >= config.Required then break end
        
        local targetSource = config.Target()
        if targetSource then
            local targetCFrame
            if typeof(targetSource) == "Vector3" then
                targetCFrame = CFrame.new(targetSource)
            elseif targetSource:IsA("Model") then
                targetCFrame = targetSource:GetPivot()
            elseif targetSource:IsA("BasePart") then
                targetCFrame = targetSource.CFrame
            end
            
            if targetCFrame then
                if islandName == "WaterIsland" then
                    targetCFrame = targetCFrame * CFrame.new(0, -150, 0)
                end
                rootPart.CFrame = targetCFrame
            end
        end
        
        isFirstTeleportPass = false
        task.wait(0.5)
        if not autoLoopTeleport then break end
    end
end

local function startAutoLoopTeleportWorker()
    task.spawn(function()
        local currentIndex = 1
        lastTimePetDiscovered = os.clock() 
        
        while autoLoopTeleport and ScriptID == CurrentScriptID do
            local currentTargetIsland = orderedIslandKeys[currentIndex]
            if currentTargetIsland then
                executeAreaTeleport(currentTargetIsland)
                local islandArrivalTimestamp = os.clock()
                
                while autoLoopTeleport and ScriptID == CurrentScriptID do
                    task.wait(0.5)
                    if activelyFarmingPet ~= nil then
                        islandArrivalTimestamp = os.clock()
                        lastTimePetDiscovered = os.clock()
                        continue
                    end
                    
                    if (os.clock() - lastTimePetDiscovered) >= noPetTimeoutLimit then break end
                    if (os.clock() - islandArrivalTimestamp) >= loopTeleportInterval then break end
                end
            end
            
            currentIndex = currentIndex + 1
            if currentIndex > #orderedIslandKeys then currentIndex = 1 end
            task.wait(0.5)
        end
    end)
end

local function startAutoCollectMoney()
    task.spawn(function()
        while autoCollectMoney and ScriptID == CurrentScriptID do
            pcall(function() collectAllPetCash:FireServer() end)
            task.wait(0.9)
        end
    end)
end

local function startAutoCollectFruits()
    task.spawn(function()
        while autoCollectFruits and ScriptID == CurrentScriptID do
            for i = 1, #activeFruitsFolders do
                local folder = activeFruitsFolders[i]
                if folder and folder.Parent and autoCollectFruits then
                    local children = folder:GetChildren()
                    for j = 1, #children do
                        local handle = children[j]:FindFirstChild("Handle")
                        local prompt = handle and handle:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then pcall(function() fireproximityprompt(prompt) end) end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

local function startAutoCollectFoodRain()
    task.spawn(function()
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
                        local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        
                        if parentPart and rootPart then
                            rootPart.CFrame = parentPart.CFrame
                            task.wait(interactionDelay)
                            if prompt.Parent and prompt.Enabled then pcall(function() fireproximityprompt(prompt) end) end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

local function startAutoCollectEasterEggs()
    task.spawn(function()
        while autoCollectEasterEggs and ScriptID == CurrentScriptID do
            local easterEggsFolder = workspace:FindFirstChild("EasterEggs")
            if easterEggsFolder then
                local descendants = easterEggsFolder:GetDescendants()
                for i = 1, #descendants do
                    if not autoCollectEasterEggs or ScriptID ~= CurrentScriptID then break end
                    
                    local prompt = descendants[i]
                    if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Enabled then
                        local parentPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
                        local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        
                        if parentPart and rootPart then
                            rootPart.CFrame = parentPart.CFrame
                            task.wait(interactionDelay)
                            if prompt.Parent and prompt.Enabled then pcall(function() fireproximityprompt(prompt) end) end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

local function startAutoUniversalCollect()
    task.spawn(function()
        local beeHives = workspace:FindFirstChild("BeeHives")
        local foodRain = workspace:FindFirstChild("FoodRainEvent")
        local easterEggs = workspace:FindFirstChild("EasterEggs")
        
        while autoUniversalCollect and ScriptID == CurrentScriptID do
            local descendants = workspace:GetDescendants()
            for i = 1, #descendants do
                if not autoUniversalCollect or ScriptID ~= CurrentScriptID then break end
                
                local prompt = descendants[i]
                if prompt:IsA("ProximityPrompt") and prompt.ActionText == "Collect" and prompt.Enabled then
                    if beeHives and prompt:IsDescendantOf(beeHives) then continue end
                    if foodRain and prompt:IsDescendantOf(foodRain) then continue end
                    if easterEggs and prompt:IsDescendantOf(easterEggs) then continue end
                    
                    local targetPosition = nil
                    local firstPartAncestor = prompt:FindFirstAncestorWhichIsA("BasePart")
                    if firstPartAncestor then
                        targetPosition = firstPartAncestor.CFrame
                    else
                        local firstModelAncestor = prompt:FindFirstAncestorWhichIsA("Model")
                        if firstModelAncestor then targetPosition = firstModelAncestor:GetPivot() end
                    end
                    
                    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if targetPosition and rootPart then
                        rootPart.CFrame = targetPosition
                        task.wait(universalPreDelay)
                        if prompt.Parent and prompt.Enabled then pcall(function() fireproximityprompt(prompt) end) end
                        task.wait(universalPostDelay)
                    end
                end
            end
            task.wait(1)
        end
    end)
end

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
            replaceCycleDone = false
            return true
        end
        return false
    end
    return true
end

local function sellWorstPetAction(isAutomatedCall)
    if dataCycleDone and isAutomatedCall then return false end
    if not updateInventoryCache(false) or not cachedInventoryData then return false end
    
    local pets = cachedInventoryData
    local lowestRPS = math.huge
    local lowestPetUUID = nil
    local lowestPetData = nil
    
    for uuid, pet in pairs(pets) do
        if not string.find(pet.name, "Lucky Block") then
            if pet.revPerSec < lowestRPS then
                lowestRPS = pet.revPerSec
                lowestPetUUID = uuid
                lowestPetData = pet
            end
        end
    end
    
    if lowestPetUUID and lowestPetData then
        if lowestPetData.revPerSec < sellRpsThreshold then
            local sellSuccess = sellPet:InvokeServer(lowestPetUUID, false)
            if sellSuccess then
                removeTool:InvokeServer(lowestPetUUID)
                pets[lowestPetUUID] = nil
                return true
            end
        else
            if isAutomatedCall then dataCycleDone = true end
        end
    else
        if isAutomatedCall then dataCycleDone = true end
    end
    return false
end

local function startAutoSellWorstPetLoop()
    task.spawn(function()
        while autoSellWorstPet and ScriptID == CurrentScriptID do
            local executedSale = sellWorstPetAction(true)
            if dataCycleDone then
                task.wait(5)
            elseif not executedSale then
                task.wait(2)
            else
                task.wait(0.3)
            end
        end
    end)
end

local function placeBestPetAction(isAutomatedCall)
    if placeCycleDone and isAutomatedCall then return false end
    
    local canPlaceSuccess, canPlace = pcall(function() return getMaxPetsForPlayer:InvokeServer() end)
    if not canPlaceSuccess or not canPlace then
        if isAutomatedCall then placeCycleDone = true end
        return false
    end

    if not updateInventoryCache(false) or not cachedInventoryData then return false end

    local pets = cachedInventoryData
    local highestRPS = -math.huge
    local highestPetUUID = nil
    local highestPetData = nil
    
    for uuid, pet in pairs(pets) do
        if not string.find(pet.name, "Lucky Block") then
            if pet.revPerSec > highestRPS then
                highestRPS = pet.revPerSec
                highestPetUUID = uuid
                highestPetData = pet
            end
        end
    end

    if highestPetUUID and highestPetData then
        local success = pcall(function() RequestPlacePet:FireServer(highestPetUUID, Vector3.zero, CFrame.new()) end)
        if success then
            pets[highestPetUUID] = nil
            return true
        end
    else
        if isAutomatedCall then placeCycleDone = true end
    end
    return false
end

local function startAutoPlaceBestPetsLoop()
    task.spawn(function()
        while autoPlaceBestPets and ScriptID == CurrentScriptID do
            local executedPlacement = placeBestPetAction(true)
            if placeCycleDone then
                task.wait(5)
            elseif not executedPlacement then
                task.wait(2)
            else
                task.wait(0.3)
            end
        end
    end)
end

local function placeLuckyBlockAction(isAutomatedCall)
    if blockCycleDone and isAutomatedCall then return false end

    local canPlaceSuccess, canPlace = pcall(function() return getMaxPetsForPlayer:InvokeServer() end)
    if not canPlaceSuccess or not canPlace then
        if isAutomatedCall then blockCycleDone = true end
        return false
    end

    if not updateInventoryCache(false) or not cachedInventoryData then return false end

    local pets = cachedInventoryData
    local highestWeight = -math.huge
    local bestBlockUUID = nil
    
    for uuid, pet in pairs(pets) do
        if string.find(pet.name, "Lucky Block") then
            local currentWeight = rarityWeights[pet.Rarity or "Common"] or 0
            if currentWeight > highestWeight then
                highestWeight = currentWeight
                bestBlockUUID = uuid
            end
        end
    end

    if bestBlockUUID then
        local success = pcall(function() RequestPlacePet:FireServer(bestBlockUUID, Vector3.zero, CFrame.new()) end)
        if success then
            pets[bestBlockUUID] = nil
            return true
        end
    else
        if isAutomatedCall then blockCycleDone = true end
    end
    return false
end

local function startAutoPlaceLuckyBlocksLoop()
    task.spawn(function()
        while autoPlaceLuckyBlocks and ScriptID == CurrentScriptID do
            local executedPlacement = placeLuckyBlockAction(true)
            if blockCycleDone then
                task.wait(5)
            elseif not executedPlacement then
                task.wait(2)
            else
                task.wait(0.3)
            end
        end
    end)
end

local function replaceWorstPetWithBestAction(isAutomatedCall)
    if replaceCycleDone and isAutomatedCall then return false end
    if not updateInventoryCache(false) or not cachedInventoryData then return false end

    local petsInInventory = cachedInventoryData
    local highestInventoryRPS = -math.huge
    local bestUnplacedUUID = nil
    
    for uuid, pet in pairs(petsInInventory) do
        if not string.find(pet.name, "Lucky Block") then
            if pet.revPerSec > highestInventoryRPS then
                highestInventoryRPS = pet.revPerSec
                bestUnplacedUUID = uuid
            end
        end
    end

    if not bestUnplacedUUID then
        if isAutomatedCall then replaceCycleDone = true end
        return false
    end

    local pensFolder = workspace:FindFirstChild("PlayerPens")
    if not pensFolder then return false end
    
    local targetPen = nil
    local pens = pensFolder:GetChildren()
    for i = 1, #pens do
        if pens[i]:GetAttribute("Owner") == LocalPlayer.Name then
            targetPen = pens[i]
            break
        end
    end
    
    if targetPen and targetPen:FindFirstChild("Pets") then
        local petsPlaced = targetPen.Pets:GetChildren()
        if #petsPlaced == 0 then
            if isAutomatedCall then replaceCycleDone = true end
            return false
        end
        
        local lowestPlacedRPS = math.huge
        local worstPlacedPetModel = nil
        
        for i = 1, #petsPlaced do
            local pModel = petsPlaced[i]
            local rpsAttr = pModel:GetAttribute("RPS") or 0
            if rpsAttr < lowestPlacedRPS then
                lowestPlacedRPS = rpsAttr
                worstPlacedPetModel = pModel
            end
        end
        
        if worstPlacedPetModel and highestInventoryRPS > lowestPlacedRPS then
            local pickupSuccess = pcall(function()
                pickupRequest:InvokeServer("Pet", worstPlacedPetModel.Name, worstPlacedPetModel)
            end)
            
            if pickupSuccess then
                task.wait(0.1) 
                pcall(function() RequestPlacePet:FireServer(bestUnplacedUUID, Vector3.zero, CFrame.new()) end)
                petsInInventory[bestUnplacedUUID] = nil
                return true
            end
        else
            if isAutomatedCall then replaceCycleDone = true end
        end
    end
    return false
end

local function startAutoReplaceWorstWithBestLoop()
    task.spawn(function()
        while autoReplaceWorstWithBest and ScriptID == CurrentScriptID do
            local executedReplacement = replaceWorstPetWithBestAction(true)
            if replaceCycleDone then
                task.wait(5)
            elseif not executedReplacement then
                task.wait(2)
            else
                task.wait(0.4)
            end
        end
    end)
end

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
        for i = 1, #petsToCollect do
            local petObj = petsToCollect[i]
            pcall(function() pickupRequest:InvokeServer("Pet", petObj.Name, petObj) end)
        end
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
        if #petsPlaced == 0 then return end
        
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
            pcall(function() pickupRequest:InvokeServer("Pet", targetPetModel.Name, targetPetModel) end)
        end
    end
end

local function handleAFKScreenState()
    local afkGui = PlayerGui:FindFirstChild("AFK")
    if not afkGui then return end
    if antiAfkActive and afkGui.Enabled == true then
        afkGui.Enabled = false
    end
end

local function startAntiAFK()
    local function handleAFKState()
        if ScriptID ~= CurrentScriptID or not antiAfkActive then 
            if afkConnection then afkConnection:Disconnect() afkConnection = nil end 
            if afkScreenConnection then afkScreenConnection:Disconnect() afkScreenConnection = nil end
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

if LocalPlayer:GetAttribute("AFK_NextRewardTime") == nil then
    pcall(function() StartAFK:InvokeServer() end)
end
startAntiAFK()

-- UI Setup
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
        if Value then startAutoFarmLoop() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Loop Teleport Areas",
    CurrentValue = autoLoopTeleport,
    Flag = "AutoLoopTeleportToggleFlag",
    Callback = function(Value)
        autoLoopTeleport = Value
        if Value then startAutoLoopTeleportWorker() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Universal Collect ('Collect')",
    CurrentValue = autoUniversalCollect,
    Flag = "AutoUniversalCollectToggle",
    Callback = function(Value)
        autoUniversalCollect = Value
        if Value then startAutoUniversalCollect() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Fruits",
    CurrentValue = autoCollectFruits,
    Flag = "AutoCollectFruitsToggle",
    Callback = function(Value)
        autoCollectFruits = Value
        if Value then startAutoCollectFruits() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Food Rain Event",
    CurrentValue = autoCollectFoodRain,
    Flag = "AutoCollectFoodRainToggle",
    Callback = function(Value)
        autoCollectFoodRain = Value
        if Value then startAutoCollectFoodRain() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Easter Eggs",
    CurrentValue = autoCollectEasterEggs,
    Flag = "AutoCollectEasterEggsToggle",
    Callback = function(Value)
        autoCollectEasterEggs = Value
        if Value then startAutoCollectEasterEggs() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Pet Cash",
    CurrentValue = autoCollectMoney,
    Flag = "AutoCollectMoneyToggle",
    Callback = function(Value)
        autoCollectMoney = Value
        if Value then startAutoCollectMoney() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Teleport to Closest Boss",
    CurrentValue = autoTeleportToBoss,
    Flag = "AutoTeleportToBossToggle",
    Callback = function(Value)
        autoTeleportToBoss = Value
        if Value then startBossTrackingTeleportLoop() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Sell Worst Pet",
    CurrentValue = autoSellWorstPet,
    Flag = "AutoSellWorstPetToggleFlag",
    Callback = function(Value)
        autoSellWorstPet = Value
        if Value then dataCycleDone = false startAutoSellWorstPetLoop() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Place Best Pets",
    CurrentValue = autoPlaceBestPets,
    Flag = "AutoPlaceBestPetsToggleFlag",
    Callback = function(Value)
        autoPlaceBestPets = Value
        if Value then placeCycleDone = false startAutoPlaceBestPetsLoop() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Replace Worst Equipped",
    CurrentValue = autoReplaceWorstWithBest,
    Flag = "AutoReplaceWorstWithBestToggleFlag",
    Callback = function(Value)
        autoReplaceWorstWithBest = Value
        if Value then replaceCycleDone = false startAutoReplaceWorstWithBestLoop() end
    end,
})

MainTab:CreateToggle({
    Name = "Auto Place Lucky Blocks",
    CurrentValue = autoPlaceLuckyBlocks,
    Flag = "AutoPlaceLuckyBlocksToggleFlag",
    Callback = function(Value)
        autoPlaceLuckyBlocks = Value
        if Value then blockCycleDone = false startAutoPlaceLuckyBlocksLoop() end
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
            if nextRewardTime == nil then pcall(function() StartAFK:InvokeServer() end) end
        else
            if nextRewardTime ~= nil then pcall(function() StopAFK:InvokeServer() end) end
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
MainTab:CreateButton({ Name = "Sell Worst Pet", Callback = function() sellWorstPetAction(false) end })
MainTab:CreateButton({ Name = "Place Best Pet", Callback = function() placeBestPetAction(false) end })
MainTab:CreateButton({ Name = "Replace Worst Equipped", Callback = function() replaceWorstPetWithBestAction(false) end })
MainTab:CreateButton({ Name = "Pickup Lowest Placed Pet", Callback = function() pickupLowestRpsPlacedPetAction() end })
MainTab:CreateButton({ Name = "Pickup All Pen Pets", Callback = function() pickupAllMapPetsAction() end })
MainTab:CreateButton({ Name = "Collect Pet Cash", Callback = function() pcall(function() collectAllPetCash:FireServer() end) end })
MainTab:CreateButton({ Name = "Force Cancel Minigame", Callback = function() pcall(function() CancelMinigame:FireServer() end) end })

MainTab:CreateSection("--- Navigation ---")
MainTab:CreateDropdown({
    Name = "Select Teleport Island",
    Options = {"Roaming", "VolcanoIsland", "SkyIsland / DragonIsland", "WaterIsland", "BeeIsland", "LavaIsland", "SafariIsland", "CaveIsland", "DeepCave", "AbyssIslandPets"},
    CurrentOption = "",
    Flag = "IslandSelectionDropdown",
    Callback = function(Value) selectedIsland = type(Value) == "table" and Value[1] or Value end,
})

MainTab:CreateButton({
    Name = "Teleport to Selected Area",
    Callback = function()
        if selectedIsland and selectedIsland ~= "" then executeAreaTeleport(selectedIsland) end
    end,
})

MainTab:CreateSection("--- Targeting Filters & Modes ---")
MainTab:CreateDropdown({
    Name = "Farming Mode Filter Target",
    Options = {"All", "Bosses Only", "Lucky Blocks Only", "Non-Boss Pets Only"},
    CurrentOption = targetSelectionMode,
    Flag = "FarmingModeFilterDropdown",
    Callback = function(Value) targetSelectionMode = type(Value) == "table" and Value[1] or Value end
})

MainTab:CreateToggle({
    Name = "Ignore All Non-Mutated Pets",
    CurrentValue = ignoreNonMutated,
    Flag = "IgnoreNonMutatedToggleFlag",
    Callback = function(Value) ignoreNonMutated = Value end
})

MainTab:CreateSection("--- Tuning Configurations ---")
MainTab:CreateSlider({ Name = "Loop Teleport Interval (Seconds)", Range = {5, 120}, Increment = 1, CurrentValue = loopTeleportInterval, Flag = "LoopTeleportIntervalSliderFlag", Callback = function(Value) loopTeleportInterval = Value end })
MainTab:CreateSlider({ Name = "No Pet Found Timeout (Seconds)", Range = {2, 60}, Increment = 1, CurrentValue = noPetTimeoutLimit, Flag = "NoPetTimeoutLimitSliderFlag", Callback = function(Value) noPetTimeoutLimit = Value end })

MainTab:CreateInput({
    Name = "Sell Pet Minimum RPS Threshold",
    PlaceholderText = "Default: 50",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local val = tonumber(Text)
        if val then sellRpsThreshold = val dataCycleDone = false end
    end,
})

MainTab:CreateInput({
    Name = "Minimum RPS Threshold",
    PlaceholderText = "Ex: 1.5k, 50M, 2B...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) minRpsThreshold = parseStringToNumber(Text) end,
})

MainTab:CreateInput({
    Name = "Minimum Strength Threshold",
    PlaceholderText = "Default: 100",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) minStrengthThreshold = parseStringToNumber(Text) end,
})

MainTab:CreateInput({
    Name = "Universal Pre-Delay (Teleport Wait)",
    PlaceholderText = "Default: 0.1",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) local val = tonumber(Text) if val then universalPreDelay = val end end,
})

MainTab:CreateInput({
    Name = "Universal Post-Delay (Next Target Wait)",
    PlaceholderText = "Default: 0.2",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text) local val = tonumber(Text) if val then universalPostDelay = val end end,
})

MainTab:CreateSlider({ Name = "Event Intercept Sync Delay", Range = {0, 2}, Increment = 0.05, CurrentValue = interactionDelay, Flag = "EventInterceptSyncDelayFlag", Callback = function(Value) interactionDelay = Value end })
MainTab:CreateSlider({ Name = "Max Capture Range (Teleport Threshold)", Range = {10, 65}, Increment = 1, CurrentValue = maxCaptureDistance, Flag = "MaxCaptureRangeFlag", Callback = function(Value) maxCaptureDistance = Value end })
MainTab:CreateSlider({ Name = "Max Capture Time Limit (Seconds)", Range = {2, 30}, Increment = 1, CurrentValue = maxCaptureTimeLimit, Flag = "MaxCaptureTimeLimitFlag", Callback = function(Value) maxCaptureTimeLimit = Value end })
MainTab:CreateSlider({ Name = "Loop Cooldown Count", Range = {1, 20}, Increment = 1, CurrentValue = loopCooldownCount, Flag = "LoopCooldownCountFlag", Callback = function(Value) loopCooldownCount = Value end })
MainTab:CreateSlider({ Name = "Teleport Sync Delay", Range = {0, 2}, Increment = 0.1, CurrentValue = teleportWaitTime, Flag = "TeleportSyncDelayFlag", Callback = function(Value) teleportWaitTime = Value end })
