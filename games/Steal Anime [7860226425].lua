-- ==========================================
-- LOADING, SECURITY & INSTANCE LIFECYCLE CHECKS
-- ==========================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.GameId ~= 7860226425 then
    return
end

if getgenv().BaseScriptTrackerKey then
    getgenv().BaseScriptTrackerKey = os.time() + 1
    task.wait(1.1) 
end

local startTime = os.time()
getgenv().BaseScriptTrackerKey = startTime

-- ==========================================
-- PATHS & DEPENDENCY DECLARATIONS
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Root = Character:WaitForChild("HumanoidRootPart")
local Torso = Character:WaitForChild("Torso")
local Humanoid = Character:WaitForChild("Humanoid")
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local originalWalkSpeedValue = Humanoid and Humanoid.WalkSpeed or 16
local originalJumpPowerValue = Humanoid and Humanoid.JumpPower or 50
local originalJumpHeightValue = Humanoid and Humanoid.JumpHeight or 7.2

local Backpack = LocalPlayer:WaitForChild("Backpack")
local Abilities = Backpack:WaitForChild("Abilities")
local SubAbilities = Abilities:WaitForChild("Abilities")

local PunchEvent = SubAbilities:WaitForChild("Punch"):WaitForChild("Attack")
local HeavyEvent = SubAbilities:WaitForChild("HeavyAttack"):WaitForChild("RemoteEvent")
local BlackFlashEvent = SubAbilities:WaitForChild("BlackFlash"):WaitForChild("RemoteEvent")
local AbilityHandlerEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AbilityHandler")
local RasenganEvent = SubAbilities:WaitForChild("Rasengan"):WaitForChild("RemoteEvent")
local LeafDragonEvent = SubAbilities:WaitForChild("LeafDragon"):WaitForChild("RemoteEvent")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifsEvent = Remotes:WaitForChild("NotifsEvent2")
local SpinRequestEvent = Remotes:WaitForChild("SpinRequestEvent")
local SettingsEvent = Remotes:WaitForChild("SettingsEvent")
local CraftEvent = Remotes:WaitForChild("CraftEvent")

-- ==========================================
-- DYNAMIC OPTIMIZED METATABLE HOOKING
-- ==========================================
local scriptDisabledCache = {}
local mt = getrawmetatable(game)
local oldIndex = mt.__index
local oldNewIndex = mt.__newindex
setreadonly(mt, false)

mt.__index = newcclosure(function(self, key)
    if not checkcaller() then
        if self:IsA("Humanoid") then
            if key == "WalkSpeed" then return originalWalkSpeedValue
            elseif key == "JumpPower" then return originalJumpPowerValue
            elseif key == "JumpHeight" then return originalJumpHeightValue end
        elseif self:IsA("LocalScript") and key == "Disabled" then
            if scriptDisabledCache[self] ~= nil then
                return scriptDisabledCache[self]
            end
        end
    end
    return oldIndex(self, key)
end)

mt.__newindex = newcclosure(function(self, key, value)
    if not checkcaller() then
        if self:IsA("Humanoid") then
            if key == "WalkSpeed" then
                return oldNewIndex(self, key, getgenv().AntiCheatBypassToggled and getgenv().TargetSpeed or value)
            elseif key == "JumpPower" or key == "JumpHeight" then
                return oldNewIndex(self, key, getgenv().AntiCheatBypassToggled and getgenv().TargetJumpValue or value)
            end
        elseif self:IsA("LocalScript") and key == "Disabled" then
            scriptDisabledCache[self] = value
        end
    end
    return oldNewIndex(self, key, value)
end)
setreadonly(mt, true)

local function setScriptStateSecurely(scriptInstance, shouldDisable)
    if scriptInstance and scriptInstance:IsA("LocalScript") then
        if scriptDisabledCache[scriptInstance] == nil then
            scriptDisabledCache[scriptInstance] = scriptInstance.Disabled
        end
        scriptInstance.Disabled = shouldDisable
    end
end

-- Re-map character variables when the player respawns
local function handleDynamicStateConstraints(char)
    if not getgenv().AntiRagdollToggled then return end
    local pbstun = char:FindFirstChild("PBSTUN")
    if pbstun then pbstun:Destroy() end

    local valuesFolder = char:FindFirstChild("Values")
    if valuesFolder then
        local isAttacking = valuesFolder:FindFirstChild("IsAttacking")
        if isAttacking and isAttacking:IsA("BoolValue") then isAttacking.Value = false end
        local isJumping = valuesFolder:FindFirstChild("IsJumping")
        if isJumping and isJumping:IsA("BoolValue") then isJumping.Value = false end
    end
end

local function onCharacterReady(char)
    Character = char
    Root = char:WaitForChild("HumanoidRootPart")
    Torso = char:WaitForChild("Torso")
    Humanoid = char:WaitForChild("Humanoid")
    Backpack = LocalPlayer:WaitForChild("Backpack")
    
    local sub = Backpack:WaitForChild("Abilities"):WaitForChild("Abilities")
    PunchEvent = sub:WaitForChild("Punch"):WaitForChild("Attack")
    HeavyEvent = sub:WaitForChild("HeavyAttack"):WaitForChild("RemoteEvent")
    BlackFlashEvent = sub:WaitForChild("BlackFlash"):WaitForChild("RemoteEvent")
    RasenganEvent = sub:WaitForChild("Rasengan"):WaitForChild("RemoteEvent")
    LeafDragonEvent = sub:WaitForChild("LeafDragon"):WaitForChild("RemoteEvent")
    
    originalWalkSpeedValue = Humanoid.WalkSpeed
    originalJumpPowerValue = Humanoid.JumpPower
    originalJumpHeightValue = Humanoid.JumpHeight

    local ragdollTrigger = char:WaitForChild("RagdollTrigger", 5)
    if ragdollTrigger and ragdollTrigger:IsA("BoolValue") then
        ragdollTrigger.Value = false
        ragdollTrigger:GetPropertyChangedSignal("Value"):Connect(function()
            if getgenv().AntiRagdollToggled and ragdollTrigger.Value == true then
                ragdollTrigger.Value = false
            end
        end)
    end
    
    char.ChildAdded:Connect(function(child)
        if getgenv().AntiRagdollToggled then
            if child.Name == "Disabled" or child.Name == "PBSTUN" then
                task.defer(function() child:Destroy() end)
            end
            handleDynamicStateConstraints(char)
        end
    end)
    
    local valuesFolder = char:WaitForChild("Values", 5)
    if valuesFolder then
        valuesFolder.ChildAdded:Connect(function()
            handleDynamicStateConstraints(char)
        end)
    end

    local existingDisabled = char:FindFirstChild("Disabled")
    if existingDisabled and getgenv().AntiRagdollToggled then existingDisabled:Destroy() end
    handleDynamicStateConstraints(char)
end

if LocalPlayer.Character then onCharacterReady(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(onCharacterReady)

task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if getgenv().AntiRagdollToggled and Humanoid and Humanoid.Parent then
            if Humanoid.Health <= 0 then
                Humanoid.Health = 1
            end
        end
        task.wait()
    end
end)

-- ==========================================
-- EFFICIENT VARIABLE ATTRIBUTE TRACKING
-- ==========================================
local base = workspace.Bases:FindFirstChild(tostring(LocalPlayer:GetAttribute("Base")))
LocalPlayer:GetAttributeChangedSignal("Base"):Connect(function()
    base = workspace.Bases:FindFirstChild(tostring(LocalPlayer:GetAttribute("Base")))
end)

local BasesFolder = workspace:WaitForChild("Bases")

-- ==========================================
-- CONFIGURATION & DEFAULT TOGGLE STATES
-- ==========================================
local CombatToggled = false
local AutoLockToggled = true
local AutoCollectToggled = true
local AntiStealToggled = true
local StealGlitchToggled = false
local StealGlitchMode = "Remote Touch" 
local TouchOriginPart = "HumanoidRootPart"
local RainbowGlitchToggled = false
local RainbowGlitchMode = "Remote Touch" 
local DisableStealingToggled = false 
local AutoTpUnlockedToggled = false
local AntiAfkSystemToggled = false

local AutoCraftToggled = false
local ActiveCraftFolders = { ["Characters"] = true }

local TargetCharacterList = {}
local AutoTpWalkingCharToggled = false
local AutoTpBaseCharToggled = false
local AutoBuyOnTpEnabled = false
local AutoStealOnTpEnabled = false

-- Targeted Character Offset System Properties
local TargetYOffsetValue = 0
local TargetMinYFloorValue = -5
local AntiStealBehindOffset = 5

getgenv().AntiCheatBypassToggled = true
getgenv().AntiRagdollToggled = true
getgenv().TargetSpeed = originalWalkSpeedValue
getgenv().TargetJumpValue = originalJumpPowerValue
getgenv().BaseLockUnderOffset = 3

local originalFlyDetectSizes = {}
local originalStealSizes = {}
local originalStealTransparencies = {}
local originalRainbowSizes = {}
local originalRainbowTransparencies = {}
local stealCollisionConnections = {}
local rainbowCollisionConnections = {}

-- ==========================================
-- HELPER UTILITIES & CHARACTER PROPERTY PARSERS
-- ==========================================

local function parseCashValue(text)
    if not text then return 0 end
    local cleaned = string.gsub(text, "[%$,%s/s]", ""):lower()
    local multipliers = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
    local suffix = string.match(cleaned, "[a-z]")
    local number = tonumber(string.match(cleaned, "[%d%.]+"))
    
    if not number then return 0 end
    if suffix and multipliers[suffix] then
        return number * multipliers[suffix]
    end
    return number
end

local function getRaritySortWeight(name)
    local lowerName = string.lower(name)
    if string.find(lowerName, "cosmic") then
        return 3
    elseif string.find(lowerName, "rainbow") then
        return 2
    end
    return 1
end

local function getReplicatedCharactersList()
    local list = {}
    local charsFolder = ReplicatedStorage:FindFirstChild("Characters")
    if charsFolder then
        for _, child in ipairs(charsFolder:GetChildren()) do
            table.insert(list, child.Name)
        end
    end
    
    table.sort(list, function(a, b)
        local wA, wB = getRaritySortWeight(a), getRaritySortWeight(b)
        if wA ~= wB then
            return wA < wB
        end
        return a < b
    end)
    
    return list
end

local function getBaseOwnerAndName(targetBase)
    if not targetBase then return "Unknown Base", "Unknown" end
    local sign = targetBase:FindFirstChild("Sign")
    local signPart = sign and sign:FindFirstChild("SignPart")
    local surfaceGui = signPart and signPart:FindFirstChild("SurfaceGui")
    local textLabel = surfaceGui and surfaceGui:FindFirstChild("TextLabel")
    
    if textLabel and textLabel.Text ~= "" then
        local rawText = textLabel.Text
        local owner = string.match(rawText, "^(.-)'s Base") or string.match(rawText, "^(.-)s Base")
        if owner then
            return owner .. "'s Base (" .. targetBase.Name .. ")", owner
        end
    end
    return targetBase.Name, "Unowned"
end

local function findPlayerByNameOrDisplay(nameString)
    local target = Players:FindFirstChild(nameString)
    if target then return target end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == nameString then return p end
    end
    return nil
end

local function processPassiveCombat()
    if not Root then return end

    local closestTarget = nil
    local shortestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local distance = (Root.Position - targetRoot.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestTarget = targetRoot
                end
            end
        end
    end

    if PunchEvent then PunchEvent:FireServer("Attack", false) end
    if BlackFlashEvent then BlackFlashEvent:FireServer() end
    if AbilityHandlerEvent then AbilityHandlerEvent:FireServer("NO3") end
    if RasenganEvent then RasenganEvent:FireServer() end

    if closestTarget then
        if HeavyEvent then 
            HeavyEvent:FireServer(closestTarget.CFrame, closestTarget.CFrame.Position) 
        end
        if LeafDragonEvent then 
            LeafDragonEvent:FireServer(closestTarget.CFrame, closestTarget.CFrame.Position, Root.Position) 
        end
    end
end

local function getPrioritizedTargets(searchFolderParent)
    if not searchFolderParent then return {} end
    local extractedList = {}
    
    for _, object in ipairs(searchFolderParent:GetChildren()) do
        if TargetCharacterList[object.Name] then
            local cashAmount = 0
            local infoGui = object:FindFirstChild("Head") and object.Head:FindFirstChild("InfoGui")
            local frame = infoGui and infoGui:FindFirstChild("Frame")
            local charCash = frame and frame:FindFirstChild("CharCash")
            
            if charCash and charCash:IsA("TextLabel") then
                cashAmount = parseCashValue(charCash.Text)
            end
            
            table.insert(extractedList, {
                Instance = object,
                CashVal = cashAmount,
                Weight = getRaritySortWeight(object.Name)
            })
        end
    end
    
    table.sort(extractedList, function(a, b)
        if a.Weight ~= b.Weight then
            return a.Weight < wB
        end
        return a.CashVal < b.CashVal
    end)
    
    return extractedList
end

local function fireSecureTouchInterest(targetPart)
    local sourcePart = (TouchOriginPart == "Torso" and Torso) or Root
    if sourcePart and targetPart and targetPart:FindFirstChildOfClass("TouchInterest") then
        firetouchinterest(sourcePart, targetPart, 0)
        task.wait()
        firetouchinterest(sourcePart, targetPart, 1)
    end
end

local function executeAdvancedPrompts(targetRoot)
    if not targetRoot then return end
    
    if AutoBuyOnTpEnabled then
        local buyPrompt = targetRoot:FindFirstChild("BuyPrompt")
        if buyPrompt and buyPrompt:IsA("ProximityPrompt") then
            local finalYCoordinate = targetRoot.Position.Y + TargetYOffsetValue
            if finalYCoordinate < TargetMinYFloorValue then
                finalYCoordinate = TargetMinYFloorValue
            end
            if Root then
                Root.CFrame = CFrame.new(targetRoot.Position.X, finalYCoordinate, targetRoot.Position.Z)
            end
            fireproximityprompt(buyPrompt)
        end
    end
    
    if AutoStealOnTpEnabled then
        local stealPrompt = targetRoot:FindFirstChild("StealPrompt")
        if stealPrompt and stealPrompt:IsA("ProximityPrompt") then 
            if Root then
                Root.CFrame = CFrame.new(targetRoot.Position.X, targetRoot.Position.Y, targetRoot.Position.Z)
            end
            
            local camera = workspace.CurrentCamera
            if camera then
                camera.CFrame = CFrame.new(camera.CFrame.Position, targetRoot.Position)
            end
            
            stealPrompt:InputHoldBegin()
            task.wait(stealPrompt.HoldDuration)
            stealPrompt:InputHoldEnd()
        end
    end
end

local function setupStealPartCollisionHook(stealPart)
    if not stealPart or not stealPart:IsA("BasePart") then return end
    if stealCollisionConnections[stealPart] then return end
    stealCollisionConnections[stealPart] = stealPart:GetPropertyChangedSignal("CanCollide"):Connect(function()
        if StealGlitchToggled and (StealGlitchMode == "Legacy Size" or StealGlitchMode == "Both") and stealPart.CanCollide == true then
            stealPart.CanCollide = false
        end
    end)
end

local function setupRainbowPartCollisionHook(rainbowPart)
    if not rainbowPart or not rainbowPart:IsA("BasePart") then return end
    if rainbowCollisionConnections[rainbowPart] then return end
    rainbowCollisionConnections[rainbowPart] = rainbowPart:GetPropertyChangedSignal("CanCollide"):Connect(function()
        if RainbowGlitchToggled and (RainbowGlitchMode == "Legacy Size" or RainbowGlitchMode == "Both") and rainbowPart.CanCollide == true then
            rainbowPart.CanCollide = false
        end
    end)
end

local function resetStealGlitchProperties()
    for part, originalSize in pairs(originalStealSizes) do
        if part and part.Parent then 
            part.Size = originalSize 
            part.CanCollide = false
            part.CastShadow = false 
            pcall(function() part.CanTouch = true end)
            if originalStealTransparencies[part] then part.Transparency = originalStealTransparencies[part] end
        end
    end
    table.clear(originalStealSizes)
    table.clear(originalStealTransparencies)
end

local function resetRainbowGlitchProperties()
    for part, originalSize in pairs(originalRainbowSizes) do
        if part and part.Parent then
            part.Size = originalSize
            part.CanCollide = false
            part.CastShadow = false 
            pcall(function() part.CanTouch = true end)
            if originalRainbowTransparencies[part] then part.Transparency = originalRainbowTransparencies[part] end
        end
    end
    table.clear(originalRainbowSizes)
    table.clear(originalRainbowTransparencies)
end

task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if Humanoid and Humanoid.Parent then
            if getgenv().AntiCheatBypassToggled then
                Humanoid.WalkSpeed = getgenv().TargetSpeed
                if Humanoid.UseJumpPower then Humanoid.JumpPower = getgenv().TargetJumpValue
                else Humanoid.JumpHeight = getgenv().TargetJumpValue end
            end
        end
        task.wait(0.1)
    end
end)

-- ==========================================
-- MAIN AUTOMATION LOOPS
-- ==========================================

-- Auto Teleport to Walking Character Loop
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if AutoTpWalkingCharToggled and Root and ReplicatedStorage:FindFirstChild("Characters") then
            local targets = getPrioritizedTargets(ReplicatedStorage.Characters)
            for _, targetData in ipairs(targets) do
                if not AutoTpWalkingCharToggled or getgenv().BaseScriptTrackerKey ~= startTime then break end
                local targetModel = targetData.Instance
                local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
                if targetRoot and Root then
                    if not AutoBuyOnTpEnabled then
                        Root.CFrame = CFrame.new(targetRoot.Position)
                    end
                    executeAdvancedPrompts(targetRoot)
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Auto Teleport to Base Character Loop
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if AutoTpBaseCharToggled and Root then
            for _, individualBase in pairs(BasesFolder:GetChildren()) do
                if not AutoTpBaseCharToggled or getgenv().BaseScriptTrackerKey ~= startTime then break end
                for _, container in pairs(individualBase:GetChildren()) do
                    local targets = getPrioritizedTargets(container)
                    for _, targetData in ipairs(targets) do
                        local targetModel = targetData.Instance
                        local targetModelParentBase = targetModel:FindFirstAncestorOfClass("Folder")
                        if targetModelParentBase and targetModelParentBase.Parent == base then
                            continue
                        end
                        local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
                        if targetRoot and Root then
                            if not AutoBuyOnTpEnabled then
                                Root.CFrame = CFrame.new(targetRoot.Position)
                            end
                            executeAdvancedPrompts(targetRoot)
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Auto Crafting Execution Loop
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if AutoCraftToggled and base and CraftEvent then
            local targetFolders = {}
            if ActiveCraftFolders["Characters"] and base:FindFirstChild("Characters") then table.insert(targetFolders, base.Characters) end
            if ActiveCraftFolders["RainbowCharacters"] and base:FindFirstChild("RainbowCharacters") then table.insert(targetFolders, base.RainbowCharacters) end
            if ActiveCraftFolders["CosmicCharacters"] and base:FindFirstChild("CosmicCharacters") then table.insert(targetFolders, base.CosmicCharacters) end

            for _, folder in ipairs(targetFolders) do
                if not AutoCraftToggled or getgenv().BaseScriptTrackerKey ~= startTime then break end
                local firstItems = {}
                for _, object in ipairs(folder:GetChildren()) do
                    if not AutoCraftToggled or getgenv().BaseScriptTrackerKey ~= startTime then break end
                    local name = object.Name
                    if firstItems[name] then
                        local obj1 = firstItems[name]
                        local obj2 = object
                        if obj1:GetAttribute("SlotNumber") and obj2:GetAttribute("SlotNumber") then
                            CraftEvent:FireServer(obj1:GetAttribute("SlotNumber"), obj2:GetAttribute("SlotNumber"))
                            firstItems[name] = nil 
                            task.wait(0.1) 
                        end
                    else
                        firstItems[name] = object 
                    end
                end
            end
        end
        task.wait(1)
    end
end)

-- Dedicated RenderStepped Framework for Frame-Perfect Lock Teleportation
RunService.RenderStepped:Connect(function()
    if getgenv().BaseScriptTrackerKey == startTime and AutoLockToggled and Root and base then
        local lockButton = base:FindFirstChild("LockButton")
        local lockTime = LocalPlayer:GetAttribute("CurrentLockTime") or 0
        if lockButton and lockButton:FindFirstChild("TouchInterest") and lockTime <= 0 then
            if Root:IsA("BasePart") then
                Root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                Root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            Root.CFrame = CFrame.new(lockButton.Position - Vector3.new(0, getgenv().BaseLockUnderOffset, 0))
            firetouchinterest(Root, lockButton, 0)
            firetouchinterest(Root, lockButton, 1)
        end
    end
end)

-- Auto TP to Unlocked Base Loop
local autoTpSelectedBase = "All"
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if AutoTpUnlockedToggled and Root then
            local targetBases = {}
            if autoTpSelectedBase == "All" then
                for _, b in pairs(BasesFolder:GetChildren()) do
                    if b ~= base then table.insert(targetBases, b) end
                end
            else
                local matchedBase = BasesFolder:FindFirstChild(autoTpSelectedBase)
                if matchedBase and matchedBase ~= base then table.insert(targetBases, matchedBase) end
            end
            
            for _, b in ipairs(targetBases) do
                if not AutoTpUnlockedToggled or getgenv().BaseScriptTrackerKey ~= startTime then break end
                local lockButton = b:FindFirstChild("LockButton")
                if lockButton and lockButton:FindFirstChild("TouchInterest") then
                    local targetPlayerName = b.Name
                    local targetPlayer = Players:FindFirstChild(targetPlayerName)
                    local lockTime = targetPlayer and targetPlayer:GetAttribute("CurrentLockTime") or 0
                    
                    if lockTime <= 0 then
                        local originalCFrame = Root.CFrame
                        repeat
                            if Root:IsA("BasePart") then Root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
                            Root.CFrame = CFrame.new(lockButton.Position - Vector3.new(0, getgenv().BaseLockUnderOffset, 0))
                            firetouchinterest(Root, lockButton, 0)
                            task.wait()
                            firetouchinterest(Root, lockButton, 1)
                            task.wait(0.05)
                            lockTime = targetPlayer and targetPlayer:GetAttribute("CurrentLockTime") or 0
                        until lockTime > 0 or not AutoTpUnlockedToggled or getgenv().BaseScriptTrackerKey ~= startTime
                        
                        if Root and Root.Parent and getgenv().BaseScriptTrackerKey == startTime then Root.CFrame = originalCFrame end
                        task.wait(0.5)
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Steal Glitch Loop (Supports Remote Touch, Legacy Size, and Both)
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if StealGlitchToggled and Root and not DisableStealingToggled then
            for _, b in pairs(BasesFolder:GetChildren()) do
                if not StealGlitchToggled or getgenv().BaseScriptTrackerKey ~= startTime or DisableStealingToggled then break end
                
                local partsToProcess = {}
                local p1 = b:FindFirstChild("StealCollect")
                local p2 = b:FindFirstChild("StealCollect2")
                if p1 then table.insert(partsToProcess, p1) end
                if p2 then table.insert(partsToProcess, p2) end
                
                for _, stealPart in ipairs(partsToProcess) do
                    if stealPart and stealPart:IsA("BasePart") then
                        stealPart.CastShadow = false
                        if (StealGlitchMode == "Remote Touch" or StealGlitchMode == "Both") then
                            fireSecureTouchInterest(stealPart)
                        end
                        if (StealGlitchMode == "Legacy Size" or StealGlitchMode == "Both") then
                            if not originalStealSizes[stealPart] then
                                originalStealSizes[stealPart] = stealPart.Size
                                originalStealTransparencies[stealPart] = stealPart.Transparency
                            end
                            setupStealPartCollisionHook(stealPart)
                            stealPart.Size = Vector3.new(2048, 2048, 2048)
                            stealPart.Transparency = 1 
                            stealPart.CanCollide = false
                            pcall(function() stealPart.CanTouch = true end)
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Loop that resizes StealCollect parts to 0 to completely disable stealing
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if DisableStealingToggled and base then
            local partsToDisable = {}
            local p1 = base:FindFirstChild("StealCollect")
            local p2 = base:FindFirstChild("StealCollect2")
            if p1 then table.insert(partsToDisable, p1) end
            if p2 then table.insert(partsToDisable, p2) end
            
            for _, stealPart in ipairs(partsToDisable) do
                if stealPart and stealPart:IsA("BasePart") then
                    stealPart.CastShadow = false 
                    if not originalStealSizes[stealPart] then
                        originalStealSizes[stealPart] = stealPart.Size
                        originalStealTransparencies[stealPart] = stealPart.Transparency
                    end
                    stealPart.Size = Vector3.new(0, 0, 0)
                    stealPart.Transparency = 1 
                    stealPart.CanCollide = false
                    pcall(function() stealPart.CanTouch = false end)
                end
            end
        end
        task.wait(0.5)
    end
end)

-- Rainbow Steal Glitch Loop (Supports Remote Touch, Legacy Size, and Both)
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if RainbowGlitchToggled and Root then
            local rainbowPart = workspace:FindFirstChild("RainbowCollectPart")
            if rainbowPart and rainbowPart:IsA("BasePart") then
                rainbowPart.CastShadow = false 
                if (RainbowGlitchMode == "Remote Touch" or RainbowGlitchMode == "Both") then
                    fireSecureTouchInterest(rainbowPart)
                end
                if (RainbowGlitchMode == "Legacy Size" or RainbowGlitchMode == "Both") then
                    if not originalRainbowSizes[rainbowPart] then
                        originalRainbowSizes[rainbowPart] = rainbowPart.Size
                        originalRainbowTransparencies[rainbowPart] = rainbowPart.Transparency
                    end
                    setupRainbowPartCollisionHook(rainbowPart)
                    rainbowPart.Size = Vector3.new(2048, 2048, 2048)
                    rainbowPart.Transparency = 1 
                    rainbowPart.CanCollide = false
                    pcall(function() rainbowPart.CanTouch = true end)
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Anti Steal with position recall
NotifsEvent.OnClientEvent:Connect(function(message)
    if not AntiStealToggled or getgenv().BaseScriptTrackerKey ~= startTime then return end
    if type(message) ~= "string" or not string.find(message, "is stealing") then return end
    
    local thiefName = string.match(message, "^(%S+) is stealing")
    local thief = thiefName and findPlayerByNameOrDisplay(thiefName)
    
    if thief and thief ~= LocalPlayer then
        task.spawn(function()
            local antiStealReturnCFrame = Root and Root.CFrame
            local startTimeL = tick()
            local hadWeld = false
            
            while AntiStealToggled and getgenv().BaseScriptTrackerKey == startTime and thief.Parent do
                local thiefChar = thief.Character
                local thiefRoot = thiefChar and thiefChar:FindFirstChild("HumanoidRootPart")
                if not Root or not thiefRoot or not PunchEvent then task.wait(0.1) continue end
                
                local carryWeld = thiefRoot:FindFirstChild("CarryWeld")
                if carryWeld then hadWeld = true
                elseif not carryWeld and hadWeld then break
                elseif not carryWeld and (tick() - startTimeL) > 5 then break end
                
                if Root:IsA("BasePart") then
                    Root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
                Root.CFrame = thiefRoot.CFrame * CFrame.new(0, 0, AntiStealBehindOffset)
                if PunchEvent then PunchEvent:FireServer("Attack", false) end
                task.wait(0.1)
            end
            if AntiStealToggled and antiStealReturnCFrame and Root and Root.Parent and getgenv().BaseScriptTrackerKey == startTime then
                Root.CFrame = antiStealReturnCFrame
            end
        end)
    end
end)

-- Dedicated VirtualUser Loop for Anti-AFK Engine Continuity
task.spawn(function()
    while getgenv().BaseScriptTrackerKey == startTime do
        if AntiAfkSystemToggled then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(0.3)
                VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        end
        task.wait(15)
    end
end)

-- Automated Initialization Processing for Default States
task.spawn(function()
    local t1 = PlayerScripts:FindFirstChild("Testing1")
    local t2 = PlayerScripts:FindFirstChild("Testing2")
    setScriptStateSecurely(t1, true)
    setScriptStateSecurely(t2, true)
    
    task.spawn(function()
        while getgenv().AntiCheatBypassToggled and getgenv().BaseScriptTrackerKey == startTime do
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "FlyDetect" then
                    if not originalFlyDetectSizes[obj] then originalFlyDetectSizes[obj] = obj.Size end
                    obj.Size = Vector3.new(0.001, 0.001, 0.001)
                end
            end
            task.wait(1)
        end
    end)
    
    task.spawn(function()
        while AutoCollectToggled and getgenv().BaseScriptTrackerKey == startTime do
            if Root and base then
                local collectionPaths = {}
                local c1 = base:FindFirstChild("CollectParts")
                local f2 = base:FindFirstChild("Floor2")
                local c2 = f2 and f2:FindFirstChild("CollectParts")
                local f3 = base:FindFirstChild("Floor3")
                local c3 = f3 and f3:FindFirstChild("CollectParts")
                
                if c1 then table.insert(collectionPaths, c1) end
                if c2 then table.insert(collectionPaths, c2) end
                if c3 then table.insert(collectionPaths, c3) end
                
                for _, parentFolder in ipairs(collectionPaths) do
                    if not AutoCollectToggled or getgenv().BaseScriptTrackerKey ~= startTime then break end
                    for _, child in pairs(parentFolder:GetChildren()) do
                        local gui = child:FindFirstChild("CollectGui")
                        local touchInterest = child:FindFirstChild("TouchInterest") or (child:IsA("BasePart") and child:FindFirstChildOfClass("TouchInterest"))
                        if gui and gui.Enabled and touchInterest then
                            firetouchinterest(Root, child, 0)
                            task.wait()
                            firetouchinterest(Root, child, 1)
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end)

-- ==========================================
-- GUI SETUP (RAYFIELD COMPACT ONE-TAB DESIGN)
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Base & Combat Automation Suite",
    LoadingTitle = "Assembling Components...",
    LoadingSubtitle = "CATSTAR Unified Engine",
    ConfigurationSaving = { Enabled = false }
})

local UnifiedTab = Window:CreateTab("All Functions", nil)

-- ==========================================
-- SECTION: COMBAT & INTERACTIVE DEFENSE
-- ==========================================
UnifiedTab:CreateSection("Combat & Defense Controls")

UnifiedTab:CreateToggle({
    Name = "Extended Multi-M1 Combat",
    CurrentValue = false,
    Flag = "PassiveCombat",
    Callback = function(Value)
        CombatToggled = Value
        task.spawn(function()
            while CombatToggled and getgenv().BaseScriptTrackerKey == startTime do
                processPassiveCombat()
                task.wait(0.2)
            end
        end)
    end,
})

UnifiedTab:CreateToggle({
    Name = "Anti Steal Defense Loop",
    CurrentValue = true,
    Flag = "AntiSteal",
    Callback = function(Value) AntiStealToggled = Value end,
})

UnifiedTab:CreateSlider({
    Name = "Thief Recall TP Offset Behind",
    Range = {1, 30},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = 5,
    Flag = "ThiefBehindOffsetSlider",
    Callback = function(Value) AntiStealBehindOffset = Value end,
})

UnifiedTab:CreateToggle({
    Name = "Lock Base (RenderStepped Force)",
    CurrentValue = true,
    Flag = "AutoLockBase",
    Callback = function(Value) AutoLockToggled = Value end,
})

UnifiedTab:CreateSlider({
    Name = "Base Lock Under-Offset Axis",
    Range = {0, 25},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = 3,
    Flag = "LockUnderSlider",
    Callback = function(Value) getgenv().BaseLockUnderOffset = Value end,
})

-- ==========================================
-- SECTION: TYCOON EXPLOITATIONS & ECONOMY
-- ==========================================
UnifiedTab:CreateSection("Tycoon & Economy Automation")

UnifiedTab:CreateToggle({
    Name = "Auto Collect Money Floors",
    CurrentValue = true,
    Flag = "AutoCollect",
    Callback = function(Value)
        AutoCollectToggled = Value
    end,
})

UnifiedTab:CreateToggle({
    Name = "Block Base Thievery Entirely",
    CurrentValue = false,
    Flag = "DisableStealing",
    Callback = function(Value)
        DisableStealingToggled = Value
        if not Value then resetStealGlitchProperties() end
    end,
})

UnifiedTab:CreateDropdown({
    Name = "Remote Touch Tracking Part Source",
    Options = {"HumanoidRootPart", "Torso"},
    CurrentOption = {"HumanoidRootPart"},
    MultipleOptions = false,
    Flag = "TouchPartDropdown",
    Callback = function(Option) TouchOriginPart = Option[1] end,
})

UnifiedTab:CreateDropdown({
    Name = "Steal Glitch System Execution Mode",
    Options = {"Remote Touch", "Legacy Size", "Both"},
    CurrentOption = {"Remote Touch"},
    MultipleOptions = false,
    Flag = "StealModeDropdown",
    Callback = function(Option)
        StealGlitchMode = Option[1]
        resetStealGlitchProperties()
    end,
})

UnifiedTab:CreateToggle({
    Name = "Auto Steal Glitch Engine",
    CurrentValue = false,
    Flag = "StealGlitch",
    Callback = function(Value)
        StealGlitchToggled = Value
        if not Value then resetStealGlitchProperties() end
    end,
})

UnifiedTab:CreateDropdown({
    Name = "Rainbow Glitch System Execution Mode",
    Options = {"Remote Touch", "Legacy Size", "Both"},
    CurrentOption = {"Remote Touch"},
    MultipleOptions = false,
    Flag = "RainbowModeDropdown",
    Callback = function(Option)
        RainbowGlitchMode = Option[1]
        resetRainbowGlitchProperties()
    end,
})

UnifiedTab:CreateToggle({
    Name = "Auto Rainbow Steal Engine",
    CurrentValue = false,
    Flag = "RainbowGlitch",
    Callback = function(Value)
        RainbowGlitchToggled = Value
        if not Value then resetRainbowGlitchProperties() end
    end,
})

UnifiedTab:CreateDropdown({
    Name = "Auto Craft Structural Category Filter",
    Options = {"Characters", "RainbowCharacters", "CosmicCharacters"},
    CurrentOption = {"Characters"},
    MultipleOptions = true,
    Flag = "CraftFoldersDropdown",
    Callback = function(Options)
        table.clear(ActiveCraftFolders)
        for _, selectedOption in ipairs(Options) do ActiveCraftFolders[selectedOption] = true end
    end,
})

UnifiedTab:CreateToggle({
    Name = "Enable Tycoon Auto Craft Loop",
    CurrentValue = false,
    Flag = "AutoCraftToggle",
    Callback = function(Value) AutoCraftToggled = Value end,
})

-- ==========================================
-- SECTION: CLIENT MODIFIERS & ENVIRONMENT
-- ==========================================
UnifiedTab:CreateSection("Client Modifiers & Bypass Engine")

UnifiedTab:CreateToggle({
    Name = "Anti Ragdoll + State Restoration",
    CurrentValue = true,
    Flag = "AntiRagdoll",
    Callback = function(Value)
        getgenv().AntiRagdollToggled = Value
        if Value and Character then
            local ragdollTrigger = Character:FindFirstChild("RagdollTrigger")
            if ragdollTrigger and ragdollTrigger:IsA("BoolValue") then ragdollTrigger.Value = false end
            local existingDisabled = Character:FindFirstChild("Disabled")
            if existingDisabled then existingDisabled:Destroy() end
            handleDynamicStateConstraints(Character)
        end
    end,
})

UnifiedTab:CreateToggle({
    Name = "Security AntiCheat Internal Bypass",
    CurrentValue = true,
    Flag = "AntiCheatBypassToggle",
    Callback = function(Value)
        getgenv().AntiCheatBypassToggled = Value
        local t1 = PlayerScripts:FindFirstChild("Testing1")
        local t2 = PlayerScripts:FindFirstChild("Testing2")
        setScriptStateSecurely(t1, Value)
        setScriptStateSecurely(t2, Value)
        
        if not Value and Humanoid then
            Humanoid.WalkSpeed = originalWalkSpeedValue
            if Humanoid.UseJumpPower then Humanoid.JumpPower = originalJumpPowerValue
            else Humanoid.JumpHeight = originalJumpHeightValue end
        end
    end,
})

UnifiedTab:CreateSlider({
    Name = "Custom WalkSpeed Target Value",
    Range = {16, 250},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = originalWalkSpeedValue,
    Flag = "SpeedSlider",
    Callback = function(Value)
        getgenv().TargetSpeed = Value
        if getgenv().AntiCheatBypassToggled and Humanoid then Humanoid.WalkSpeed = Value end
    end,
})

UnifiedTab:CreateSlider({
    Name = "Custom Jump Power/Height Value",
    Range = {0, 500},
    Increment = 1,
    Suffix = "Jump",
    CurrentValue = originalJumpPowerValue,
    Flag = "JumpSlider",
    Callback = function(Value)
        getgenv().TargetJumpValue = Value
        if getgenv().AntiCheatBypassToggled and Humanoid then
            if Humanoid.UseJumpPower then Humanoid.JumpPower = Value
            else Humanoid.JumpHeight = Value end
        end
    end,
})

UnifiedTab:CreateToggle({
    Name = "Anti AFK Connectivity Keep-Alive",
    CurrentValue = false,
    Flag = "AntiAfkLogicToggle",
    Callback = function(Value)
        AntiAfkSystemToggled = Value
        local afkScript = PlayerScripts:FindFirstChild("AFK")
        if afkScript then
            setScriptStateSecurely(afkScript, Value)
        end
    end,
})

UnifiedTab:CreateToggle({
    Name = "Game Core Remote AutoSpin Trigger",
    CurrentValue = false,
    Flag = "GameSettingsAutoSpin",
    Callback = function(Value) if SettingsEvent then SettingsEvent:FireServer("AutoSpin", Value) end end,
})

UnifiedTab:CreateButton({
    Name = "Request Instant Single Spin Remotely",
    Callback = function() if SpinRequestEvent then SpinRequestEvent:FireServer() end end,
})

-- ==========================================
-- SECTION: NAVIGATION & INSTANT TELEPORTATION
-- ==========================================
UnifiedTab:CreateSection("Navigation & Teleport Hub")

UnifiedTab:CreateButton({
    Name = "Return to Self Base Lock Button",
    Callback = function()
        if Root and base then
            local lockButton = base:FindFirstChild("LockButton")
            if lockButton then Root.CFrame = CFrame.new(lockButton.Position + Vector3.new(0, 3, 0)) end
        end
    end,
})

UnifiedTab:CreateButton({
    Name = "Return to Self Base Unlock Gate",
    Callback = function()
        if Root and base then
            local unlockBase = base:FindFirstChild("UnlockBase")
            if unlockBase then Root.CFrame = CFrame.new(unlockBase.Position + Vector3.new(0, 3, 0)) end
        end
    end
})

local baseMapping = {}
local baseOptions = {"All"}

local function rebuildBaseOptions()
    table.clear(baseOptions)
    table.clear(baseMapping)
    table.insert(baseOptions, "All")
    for _, b in pairs(BasesFolder:GetChildren()) do
        local displayName, ownerName = getBaseOwnerAndName(b)
        baseMapping[displayName] = b.Name
        table.insert(baseOptions, displayName)
    end
end

rebuildBaseOptions()
local initialCurrentSelectBaseDisplay = "All"
local selfBaseFolder = BasesFolder:FindFirstChild(tostring(LocalPlayer:GetAttribute("Base")))
if selfBaseFolder then
    initialCurrentSelectBaseDisplay = getBaseOwnerAndName(selfBaseFolder)
end

local BaseDropdown = UnifiedTab:CreateDropdown({
    Name = "Select Base Target Coordinate Location",
    Options = baseOptions,
    CurrentOption = {initialCurrentSelectBaseDisplay},
    MultipleOptions = false,
    Flag = "BaseDropdown",
    Callback = function(Option) selectedBaseTargetDisplay = Option[1] end,
})

local function refreshUIFriendlyDropdown()
    rebuildBaseOptions()
    BaseDropdown:Refresh(baseOptions)
end

BasesFolder.ChildAdded:Connect(refreshUIFriendlyDropdown)
BasesFolder.ChildRemoved:Connect(refreshUIFriendlyDropdown)

UnifiedTab:CreateButton({
    Name = "Teleport to Selected Base Lock Button",
    Callback = function()
        if not Root then return end
        local targetRealName = baseMapping[selectedBaseTargetDisplay]
        local target = targetRealName and BasesFolder:FindFirstChild(targetRealName)
        if target then
            local lockButton = target:FindFirstChild("LockButton")
            if lockButton then Root.CFrame = CFrame.new(lockButton.Position + Vector3.new(0, 3, 0)) end
        end
    end,
})

UnifiedTab:CreateButton({
    Name = "Teleport to Selected Base Front Gate",
    Callback = function()
        if not Root then return end
        local targetRealName = baseMapping[selectedBaseTargetDisplay]
        local target = targetRealName and BasesFolder:FindFirstChild(targetRealName)
        if target then
            local unlockBase = target:FindFirstChild("UnlockBase")
            if unlockBase then Root.CFrame = CFrame.new(unlockBase.Position + Vector3.new(0, 3, 0)) end
        end
    end,
})

UnifiedTab:CreateDropdown({
    Name = "Auto Unlocked Teleport Filtering Array",
    Options = baseOptions,
    CurrentOption = {"All"},
    MultipleOptions = false,
    Flag = "AutoTpTargetDropdown",
    Callback = function(Option)
        local mapped = baseMapping[Option[1]]
        autoTpSelectedBase = mapped or "All"
    end,
})

UnifiedTab:CreateToggle({
    Name = "Loop Teleport Unlocked Competitor Bases",
    CurrentValue = false,
    Flag = "AutoTpUnlocked",
    Callback = function(Value) autoTpUnlockedToggled = Value end,
})

UnifiedTab:CreateButton({
    Name = "Force Instant Protocol Server Rejoin",
    Callback = function()
        if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
    end,
})

-- ==========================================
-- SECTION: ENTITY TRACKING & AUTOMATED ASSIGNMENT
-- ==========================================
UnifiedTab:CreateSection("Target Character Tracking Loops")

UnifiedTab:CreateDropdown({
    Name = "Multi-Select Target Validation Registry",
    Options = getReplicatedCharactersList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "TargetCharsDropdown",
    Callback = function(Options)
        table.clear(TargetCharacterList)
        for _, selectedChar in ipairs(Options) do TargetCharacterList[selectedChar] = true end
    end,
})

UnifiedTab:CreateSlider({
    Name = "Auto Buy Target Y-Offset Shift",
    Range = {-10, 50},
    Increment = 1,
    Suffix = "Studs",
    CurrentValue = 0,
    Flag = "TargetYOffsetSlider",
    Callback = function(Value)
        TargetYOffsetValue = Value
    end,
})

UnifiedTab:CreateSlider({
    Name = "Minimum Allowed Ground Safety Height Floor",
    Range = {-100, 20},
    Increment = 1,
    Suffix = "Y-Height",
    CurrentValue = -5,
    Flag = "TargetMinYFloorSlider",
    Callback = function(Value)
        TargetMinYFloorValue = Value
    end,
})

UnifiedTab:CreateToggle({
    Name = "Auto TP Loop: Map Spawned Models",
    CurrentValue = false,
    Flag = "AutoTpWalkingChar",
    Callback = function(Value) AutoTpWalkingCharToggled = Value end,
})

UnifiedTab:CreateToggle({
    Name = "Auto TP Loop: Base Placed Models",
    CurrentValue = false,
    Flag = "AutoTpBaseChar",
    Callback = function(Value) AutoTpBaseCharToggled = Value end,
})

UnifiedTab:CreateToggle({
    Name = "Action Mapping: Auto Interact BuyPrompt",
    CurrentValue = false,
    Flag = "AutoBuyPromptToggle",
    Callback = function(Value) AutoBuyOnTpEnabled = Value end,
})

UnifiedTab:CreateToggle({
    Name = "Action Mapping: Auto Interact StealPrompt",
    CurrentValue = false,
    Flag = "AutoStealPromptToggle",
    Callback = function(Value) AutoStealOnTpEnabled = Value end,
})
