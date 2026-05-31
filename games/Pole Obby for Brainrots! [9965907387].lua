-- Set the script ID globally to stop previous execution instances
getgenv().ScriptID = os.clock()
local CurrentScriptId = getgenv().ScriptID

-- REMINDER FOR REFACTORING:
-- Rely completely on global environment mapping for variable injection.
-- Use 'ScriptID == CurrentScriptId' directly inside your loops.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the main window
local Window = Rayfield:CreateWindow({
   Name = "Mob Stealer & Farm",
   LoadingTitle = "Loading Script...",
   LoadingSubtitle = "by Gemini",
   ConfigurationSaving = {
      Enabled = false
   },
   Discord = {
      Enabled = false
   },
   KeySystem = false
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Mobs = workspace:WaitForChild("Mobs")
local Bases = workspace:WaitForChild("Bases")

-- Game Remotes, Data Modules, & Network Handlers
local Packages = ReplicatedStorage:WaitForChild("Packages")
local PlayerData = require(Packages:WaitForChild("PlayerData"))

local RedeemEvent = Packages.Net["RE/SafeZoneEvent"]
local RequestStatsUpgrade = Packages.Net["RE/RequestStatsUpgrade"]
local RequestRebirth = Packages.Net["RE/RequestRebirth"]
local UpgradeBrainrotEvent = Packages.Net["RE/UpgradeBrainrot"]

local BrainrotList = require(ReplicatedStorage.GameData.BrainrotList)

local ORIGIN_POINT = Vector3.new(-9, 127, -2)
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Cleanly handle character respawns
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    root = newCharacter:WaitForChild("HumanoidRootPart")
    humanoid = newCharacter:WaitForChild("Humanoid")
end)

-- Global setting configuration
local minDistanceConfig = 200

-- Dynamically find the player's base based on OwnerID attribute
local function getYourBase()
    for _, v in ipairs(Bases:GetChildren()) do
        local id = v:GetAttribute("OwnerID")
        if id and id == LocalPlayer.UserId then
            return v
        end
    end
    return nil
end

-- Find the furthest mob from the origin point (must be past minDistanceConfig)
local function getTarget()
    local mobChildren = Mobs:GetChildren()
    if #mobChildren == 0 then return nil, nil end

    local longestDistance = -1
    local chosenPrompt, chosenPart

    for _, mob in ipairs(mobChildren) do
        if ScriptID ~= CurrentScriptId then return nil, nil end
        
        local mobRoot = mob:FindFirstChild("RootPart")
        local prompt = mobRoot and mobRoot:FindFirstChildOfClass("ProximityPrompt")
        
        if prompt and prompt.Enabled then
            local distance = (ORIGIN_POINT - mobRoot.Position).Magnitude
            if distance >= minDistanceConfig and distance > longestDistance then
                longestDistance = distance
                chosenPrompt = prompt
                chosenPart = mobRoot
            end
        end
    end
    return chosenPrompt, chosenPart
end

-- Steal target action (used by both the toggle loop and one-time button)
local function stealTarget()
    if not root or not root:IsDescendantOf(workspace) then return end

    local targetPrompt, targetPart = getTarget()
    if targetPrompt and targetPart then
        local nextFireTime = 0
        local fireCooldown = 0.2

        while targetPrompt.Parent and targetPrompt.Enabled and root and root:IsDescendantOf(workspace) do
            if ScriptID ~= CurrentScriptId then break end
            
            root.CFrame = targetPart.CFrame + Vector3.new(0, 10, 0)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            
            local currentTime = os.clock()
            if currentTime >= nextFireTime then
                fireproximityprompt(targetPrompt)
                nextFireTime = currentTime + fireCooldown
            end
            
            RunService.Heartbeat:Wait()
        end
        task.wait(0.1)
    else
        task.wait(0.5)
    end
end

-- Find and equip the item with the highest Generation value (Scans character first)
local function equipBestBrainrot()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not character or not backpack or not humanoid then return end

    local bestTool = nil
    local highestValue = -1
    local currentlyEquippedBest = false

    -- 1. Scan Player's Character first (currently held tools)
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            local data = BrainrotList[tool.Name]
            if data and data.Generation then
                if data.Generation > highestValue then
                    highestValue = data.Generation
                    bestTool = tool
                    currentlyEquippedBest = true
                end
            end
        end
    end

    -- 2. Scan Backpack
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local data = BrainrotList[tool.Name]
            if data and data.Generation then
                if data.Generation > highestValue then
                    highestValue = data.Generation
                    bestTool = tool
                    currentlyEquippedBest = false
                end
            end
        end
    end

    -- 3. Equip only if the best tool is not already being held
    if bestTool and not currentlyEquippedBest then
        humanoid:EquipTool(bestTool)
    end
end

-- Simulates touch interest to instantly claim accrued income from base slots
local function collectBaseMoney()
    local myBase = getYourBase()
    if not myBase then return end

    local slotsFolder = myBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if ScriptID ~= CurrentScriptId then break end
        
        local hitbox = slot:FindFirstChild("Hitbox")
        if hitbox and hitbox:FindFirstChild("TouchInterest") and root and root:IsDescendantOf(workspace) then
            firetouchinterest(root, hitbox, 0) -- Touch start
            task.wait()
            firetouchinterest(root, hitbox, 1) -- Touch end
        end
    end
end

-- Loops through base slots and fires the upgrade remote with a protective yield
local function upgradeAllSlots()
    local myBase = getYourBase()
    if not myBase then return end

    local slotsFolder = myBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if ScriptID ~= CurrentScriptId then break end
        
        -- Pull out digits from slot names safely as numbers
        local slotString = string.match(slot.Name, "%d+")
        local slotNumber = slotString and tonumber(slotString)
        
        if slotNumber then
            UpgradeBrainrotEvent:FireServer(slotNumber)
            task.wait(0.05) -- Pacing delay between slots to protect network ping from climbing
        end
    end
end

-- Automatically cleans up visual and physics clutter on working slots
local function fixBaseProblems()
    local myBase = getYourBase()
    if not myBase then return end

    local slotsFolder = myBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        local active = slot:FindFirstChild("ActiveBrainrot")
        if active then
            -- Fix RootPart Transparency
            local rootPart = active:FindFirstChild("RootPart")
            if rootPart and rootPart:IsA("BasePart") then
                if rootPart.Transparency ~= 1 then rootPart.Transparency = 1 end
            end

            -- Fix VfxInstance properties
            local vfx = active:FindFirstChild("VfxInstance")
            if vfx then
                if vfx:IsA("BasePart") then
                    if vfx.CanCollide ~= false then vfx.CanCollide = false end
                    if vfx.Transparency ~= 1 then vfx.Transparency = 1 end
                end
                for _, desc in ipairs(vfx:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        if desc.CanCollide ~= false then desc.CanCollide = false end
                        if desc.Transparency ~= 1 then desc.Transparency = 1 end
                    end
                end
            end
        end
    end
end

-- Client patch to unlock and visually restore hidden base structures
local function unlockAllBaseSlots()
    local myBase = getYourBase()
    if not myBase then return end

    local slotsFolder = myBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        local targets = {"Base", "Rim", "Collect"}
        for _, name in ipairs(targets) do
            local part = slot:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                part.Transparency = 0
                part.CanCollide = true
            end
        end

        local basePart = slot:FindFirstChild("Base")
        local prompt = basePart and basePart:FindFirstChild("PlacePrompt")
        if prompt then
            prompt.Enabled = true
        end
    end
end

-- Process picking up items from occupied base slots (Fixed lag loop)
local function pickupAllFromBase()
    if not root or not root:IsDescendantOf(workspace) then return end
    
    local myBase = getYourBase()
    if not myBase then return end

    local slotsFolder = myBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if ScriptID ~= CurrentScriptId then break end
        
        if slot:FindFirstChild("ActiveBrainrot") then
            local part = slot:FindFirstChild("Base")
            local prompt = part and part:FindFirstChild("PlacePrompt")
            
            if prompt and root and root:IsDescendantOf(workspace) then
                root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0)) * root.CFrame.Rotation
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                
                -- Paced prompt activation loop to prevent frame dropping
                while slot:FindFirstChild("ActiveBrainrot") and root and root:IsDescendantOf(workspace) do
                    if ScriptID ~= CurrentScriptId then break end
                    fireproximityprompt(prompt)
                    task.wait(0.2)
                end
                task.wait(0.3)
            end
        end
    end
end

-- Process placing items into empty base slots (Fixed lag loop)
local function placeAllIntoBase()
    if not root or not root:IsDescendantOf(workspace) then return end
    
    local myBase = getYourBase()
    if not myBase then return end

    local slotsFolder = myBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if ScriptID ~= CurrentScriptId then break end
        
        if not slot:FindFirstChild("ActiveBrainrot") then
            local part = slot:FindFirstChild("Base")
            local prompt = part and part:FindFirstChild("PlacePrompt")
            
            if prompt and root and root:IsDescendantOf(workspace) then
                root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0)) * root.CFrame.Rotation
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                
                -- Paced prompt activation loop to prevent frame dropping
                while not slot:FindFirstChild("ActiveBrainrot") and root and root:IsDescendantOf(workspace) do
                    if ScriptID ~= CurrentScriptId then break end
                    fireproximityprompt(prompt)
                    task.wait(0.2)
                end
                task.wait(0.3)
            end
        end
    end
end

-- Logic processor for running the rebirth operations
local function executeRebirthProcess()
    local Data = PlayerData.GetData()
    if not Data then return end

    local Boost = LocalPlayer:GetAttribute("Boost")
    if typeof(Boost) ~= "number" then
        Boost = typeof(Data.Boost) == "number" and Data.Boost or 1
    end

    local MaxBoostCapacity = 40 + (Data.Rebirth or 0) * 10

    -- Perform the stats upgrading sequence
    while Boost < MaxBoostCapacity do
        if ScriptID ~= CurrentScriptId then return end
        
        local UpgradeAmount = (MaxBoostCapacity - Boost >= 5) and 5 or 1
        RequestStatsUpgrade:FireServer("Boost", UpgradeAmount)
        
        -- Safely wait for attribute response with a lifecycle script check backup
        local changedSignal = LocalPlayer:GetAttributeChangedSignal("Boost")
        local updated = false
        local connection
        
        connection = changedSignal:Connect(function()
            updated = true
            connection:Disconnect()
        end)
        
        -- Yield processing slightly to let backend respond or break if script refreshed
        while not updated do
            if ScriptID ~= CurrentScriptId then
                if connection then connection:Disconnect() end
                return
            end
            RunService.Heartbeat:Wait()
        end
        
        local CurrentAttribute = LocalPlayer:GetAttribute("Boost")
        if typeof(CurrentAttribute) == "number" then
            Boost = CurrentAttribute
        else
            break
        end
    end

    -- Run rebirth remote call once target requirements are filled
    if Boost >= MaxBoostCapacity then
        RequestRebirth:FireServer()
        task.wait(0.5) -- Cool down allowance for data state updating
    end
end

-- Create a Single Tab for features
local MainTab = Window:CreateTab("Main Features", 4483362458)

-- State Variables for the toggles
local autoStealEnabled = false
local autoEquipEnabled = false
local autoPickupEnabled = false
local autoPlaceEnabled = false
local autoFixEnabled = false
local autoCollectEnabled = false
local autoUpgradeEnabled = false
local autoRebirthEnabled = false
local autoRedeemEnabled = false

---
-- CONFIGURATION SECTION
---
MainTab:CreateSection("Configurations")

MainTab:CreateSlider({
   Name = "Minimum Distance From Origin",
   Info = "Mobs closer than this distance will be ignored.",
   Range = {0, 2000},
   Increment = 10,
   Suffix = "Studs",
   CurrentValue = 200,
   Flag = "MinDistanceSlider",
   Callback = function(Value)
      minDistanceConfig = Value
   end,
})

---
-- AUTOFARM SECTION
---
MainTab:CreateSection("Autofarm Mobs")

MainTab:CreateToggle({
   Name = "Loop Auto Steal Mobs",
   CurrentValue = false,
   Callback = function(Value)
      autoStealEnabled = Value
      if autoStealEnabled then
         task.spawn(function()
            -- Continuous background thread to force kill velocity while farming is active
            task.spawn(function()
                while autoStealEnabled and ScriptID == CurrentScriptId do
                    if root and root:IsDescendantOf(workspace) then
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                    RunService.Heartbeat:Wait()
                end
            end)

            while autoStealEnabled and ScriptID == CurrentScriptId do
                stealTarget()
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Steal Next Mob (One-Time)",
   Callback = function()
      task.spawn(stealTarget)
   end,
})

---
-- REBIRTH SYSTEM SECTION
---
MainTab:CreateSection("Progression & Rebirth")

MainTab:CreateToggle({
   Name = "Loop Auto Upgrade & Rebirth",
   CurrentValue = false,
   Callback = function(Value)
      autoRebirthEnabled = Value
      if autoRebirthEnabled then
         task.spawn(function()
            while autoRebirthEnabled and ScriptID == CurrentScriptId do
                executeRebirthProcess()
                task.wait(1)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Rebirth Once (One-Time Run)",
   Callback = function()
      task.spawn(executeRebirthProcess)
   end,
})

---
-- BASE MANAGEMENT SECTION
---
MainTab:CreateSection("Base Management")

MainTab:CreateToggle({
   Name = "Loop Auto Collect Money",
   CurrentValue = false,
   Callback = function(Value)
      autoCollectEnabled = Value
      if autoCollectEnabled then
         task.spawn(function()
            while autoCollectEnabled and ScriptID == CurrentScriptId do
                collectBaseMoney()
                task.wait(0.5)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Collect Money Once (One-Time)",
   Callback = function()
      collectBaseMoney()
   end,
})

MainTab:CreateToggle({
   Name = "Loop Auto Upgrade Slots",
   CurrentValue = false,
   Callback = function(Value)
      autoUpgradeEnabled = Value
      if autoUpgradeEnabled then
         task.spawn(function()
            while autoUpgradeEnabled and ScriptID == CurrentScriptId do
                upgradeAllSlots()
                task.wait(1.5) -- Rest between complete cycles to prevent long-term ping accumulation
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Upgrade Slots Once (One-Time)",
   Callback = function()
      upgradeAllSlots()
   end,
})

MainTab:CreateToggle({
   Name = "Loop Pickup All Slots",
   CurrentValue = false,
   Callback = function(Value)
      autoPickupEnabled = Value
      if autoPickupEnabled then
         task.spawn(function()
            while autoPickupEnabled and ScriptID == CurrentScriptId do
                pickupAllFromBase()
                task.wait(0.5)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Pickup All Slots Once (One-Time)",
   Callback = function()
      task.spawn(pickupAllFromBase)
   end,
})

MainTab:CreateToggle({
   Name = "Loop Place Brainrot (Empty Slots)",
   CurrentValue = false,
   Callback = function(Value)
      autoPlaceEnabled = Value
      if autoPlaceEnabled then
         task.spawn(function()
            while autoPlaceEnabled and ScriptID == CurrentScriptId do
                placeAllIntoBase()
                task.wait(0.5)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Place Brainrot Once (One-Time)",
   Callback = function()
      task.spawn(placeAllIntoBase)
   end,
})

MainTab:CreateToggle({
   Name = "Auto Fix Clutter / Problems",
   CurrentValue = false,
   Callback = function(Value)
      autoFixEnabled = Value
      if autoFixEnabled then
         task.spawn(function()
            while autoFixEnabled and ScriptID == CurrentScriptId do
                fixBaseProblems()
                task.wait(0.5)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Unlock All Base Slots (Client Path)",
   Callback = function()
      unlockAllBaseSlots()
   end,
})

---
-- GEAR SECTION
---
MainTab:CreateSection("Brainrot Weapons")

MainTab:CreateToggle({
   Name = "Loop Auto Equip Best Brainrot",
   CurrentValue = false,
   Callback = function(Value)
      autoEquipEnabled = Value
      if autoEquipEnabled then
         task.spawn(function()
            while autoEquipEnabled and ScriptID == CurrentScriptId do
                equipBestBrainrot()
                task.wait(1)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Equip Best Brainrot (One-Time)",
   Callback = function()
      equipBestBrainrot()
   end
})

---
-- UTILITIES SECTION
---
MainTab:CreateSection("Safe Zone Utilities")

MainTab:CreateToggle({
   Name = "Loop Auto Redeem (Safe Zone)",
   CurrentValue = false,
   Callback = function(Value)
      autoRedeemEnabled = Value
      if autoRedeemEnabled then
         task.spawn(function()
            while autoRedeemEnabled and ScriptID == CurrentScriptId do
                RedeemEvent:FireServer()
                task.wait(0.1)
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Redeem Once (One-Time)",
   Callback = function()
      RedeemEvent:FireServer()
   end,
})

-- Initialize Rayfield (Load the UI fully)
Rayfield:LoadConfiguration()
