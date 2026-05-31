-- Set the script ID globally to stop previous execution instances
getgenv().ScriptID = os.clock()
local CurrentScriptId = getgenv().ScriptID

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
local BrainrotShopAction = Packages.Net["RF/BrainrotShopAction"]

local BrainrotList = require(ReplicatedStorage.GameData.BrainrotList)
local MutationList = require(ReplicatedStorage.GameData.MutationList)

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
local minCashPerSecondConfig = 0
local autoSellThresholdConfig = 16666665

-- Suffix table designed to handle game shorthand alphanumeric text formats
local SuffixValues = {
    ["K"]   = 1e3,
    ["M"]   = 1e6,
    ["B"]   = 1e9,
    ["T"]   = 1e12,
    ["QA"]  = 1e15,
    ["QI"]  = 1e18,
    ["SX"]  = 1e21,
    ["SP"]  = 1e24,
    ["OC"]  = 1e27,
    ["NO"]  = 1e30,
    ["DC"]  = 1e33
}

-- Converts localized currency/stat strings into pure mathematical numbers
local function parseFormattedString(str)
    if not str or str == "" then return 0 end
    
    -- Normalize format: uppercase, strip dollar signs, strip /s notation, swap commas to decimals
    local normalized = string.upper(str)
    normalized = string.gsub(normalized, "%$", "")
    normalized = string.gsub(normalized, "/S", "")
    normalized = string.gsub(normalized, ",", ".")
    
    -- Extract number component and abbreviation component
    local numericPart = string.match(normalized, "[%d%.]+")
    local suffixPart  = string.match(normalized, "[A-Z]+")
    
    local baseValue = tonumber(numericPart) or 0
    if suffixPart and SuffixValues[suffixPart] then
        return baseValue * SuffixValues[suffixPart]
    end
    
    return baseValue
end

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

-- Scans all active mobs and selectively filters out the highest money-generating target
local function getTarget()
    local mobChildren = Mobs:GetChildren()
    if #mobChildren == 0 then return nil, nil end

    local highestCashPerSecond = -1
    local bestPrompt = nil
    local bestMobRoot = nil

    for _, mob in ipairs(mobChildren) do
        if ScriptID ~= CurrentScriptId then return nil, nil end
        
        local mobRoot = mob:FindFirstChild("RootPart")
        local prompt = mobRoot and mobRoot:FindFirstChildOfClass("ProximityPrompt")
        
        if prompt and prompt.Enabled then
            -- Navigate deep down into the requested structural hierarchy paths
            local overheadAttach = mobRoot:FindFirstChild("OverheadAttach")
            local animalOverhead = overheadAttach and overheadAttach:FindFirstChild("AnimalOverhead")
            local generation     = animalOverhead and animalOverhead:FindFirstChild("Generation")
            
            if generation and generation:IsA("TextLabel") then
                local mobCashPerSecond = parseFormattedString(generation.Text)
                
                -- Verify if the target meets the minimum condition and beats our current top choice
                if mobCashPerSecond >= minCashPerSecondConfig and mobCashPerSecond > highestCashPerSecond then
                    highestCashPerSecond = mobCashPerSecond
                    bestPrompt = prompt
                    bestMobRoot = mobRoot
                end
            end
        end
    end
    
    return bestPrompt, bestMobRoot
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
        task.wait(0.2) -- Quick cycle search check rate
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

-- Scans all valid base upgrades, detects pricing structures, and fires the upgrade remote on the cheapest choice
local function upgradeCheapestSlot()
    local myBase = getYourBase()
    if not myBase then return end

    local slotsFolder = myBase:FindFirstChild("Slots")
    if not slotsFolder then return end

    local lowestCost = math.huge
    local targetSlotNumber = nil

    for _, slot in ipairs(slotsFolder:GetChildren()) do
        if ScriptID ~= CurrentScriptId then return end
        
        local upgradeModel = slot:FindFirstChild("Upgrade")
        local surfaceGui  = upgradeModel and upgradeModel:FindFirstChild("SurfaceGui")
        local frame       = surfaceGui and surfaceGui:FindFirstChild("Frame")
        local costLabel   = frame and frame:FindFirstChild("Cost")

        if costLabel and costLabel:IsA("TextLabel") then
            local currentPrice = parseFormattedString(costLabel.Text)
            
            if currentPrice < lowestCost then
                local slotString = string.match(slot.Name, "%d+")
                local slotNumber = slotString and tonumber(slotString)
                
                if slotNumber then
                    lowestCost = currentPrice
                    targetSlotNumber = slotNumber
                end
            end
        end
    end

    if targetSlotNumber then
        UpgradeBrainrotEvent:FireServer(targetSlotNumber)
    end
end

-- Scans the Workspace and permanently deletes replication instances of harmful touch scripts
local function disableKillParts()
    for _, v in ipairs(workspace:GetDescendants()) do
        if ScriptID ~= CurrentScriptId then break end
        if v:IsA("BasePart") and string.find(v.Name, "Kill") then
            local touchInterest = v:FindFirstChild("TouchInterest")
            if touchInterest then
                touchInterest:Destroy()
            end
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
            local rootPart = active:FindFirstChild("RootPart")
            if rootPart and rootPart:IsA("BasePart") then
                if rootPart.Transparency ~= 1 then rootPart.Transparency = 1 end
            end

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

    while Boost < MaxBoostCapacity do
        if ScriptID ~= CurrentScriptId then return end
        
        local UpgradeAmount = (MaxBoostCapacity - Boost >= 5) and 5 or 1
        RequestStatsUpgrade:FireServer("Boost", UpgradeAmount)
        
        local changedSignal = LocalPlayer:GetAttributeChangedSignal("Boost")
        local updated = false
        local connection
        
        connection = changedSignal:Connect(function()
            updated = true
            connection:Disconnect()
        end)
        
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

    if Boost >= MaxBoostCapacity then
        RequestRebirth:FireServer()
        task.wait(0.5)
    end
end

-- Create a Single Tab for features
local MainTab = Window:CreateTab("Main Features", 4483362458)

-- Default State Values (Configured to be ON by default per instructions)
local autoCollectEnabled = true
local autoFixEnabled = true
local antiKillEnabled = true

-- Remaining State Variables
local autoStealEnabled = false
local autoEquipEnabled = false
local autoSellCheapEnabled = false
local autoPickupEnabled = false
local autoPlaceEnabled = false
local autoUpgradeEnabled = false
local autoRebirthEnabled = false
local autoRedeemEnabled = false

-- UI Toggle Elements stored as variables to allow for dynamic state changes
local AutoEquipToggle = nil
local AutoSellToggle = nil

-- Background worker thread handling the selective evaluation and execution of the item liquidation cycle
local function runAutoSellProcess()
    while autoSellCheapEnabled and ScriptID == CurrentScriptId do
        local currentCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local currentHumanoid = currentCharacter:WaitForChild("Humanoid", 5)
        
        if currentHumanoid then
            local validTools = {}
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            
            if backpack then
                for _, t in ipairs(backpack:GetChildren()) do
                    if t:IsA("Tool") and t:GetAttribute("Level") ~= nil then 
                        table.insert(validTools, t)
                    end
                end
            end
            
            if #validTools > 0 then 
                local randomTool = validTools[math.random(1, #validTools)]
                currentHumanoid:EquipTool(randomTool) 
            end

            local brainrotName, mutationName
            local childConnection
            
            childConnection = currentCharacter.ChildAdded:Connect(function(child)
                if child:IsA("Model") and child:GetAttribute("BrainrotLvl") then
                    if string.find(child.Name, "_") then
                        local segments = string.split(child.Name, "_")
                        brainrotName = segments[1]
                        mutationName = child:GetAttribute("Mutation")
                    end
                end
            end)

            while autoSellCheapEnabled and ScriptID == CurrentScriptId and not brainrotName do
                task.wait()
            end
            
            if childConnection then 
                childConnection:Disconnect() 
            end

            if brainrotName and autoSellCheapEnabled and ScriptID == CurrentScriptId then
                local brainrotData = BrainrotList[brainrotName]
                local mutationData = mutationName and MutationList[mutationName] or nil

                if brainrotData then
                    local baseGen = brainrotData.Generation or 0
                    local multiplier = mutationData and mutationData.Multiplier or 1
                    local total = baseGen * multiplier

                    task.defer(function()
                        print(string.format("[CATSTAR] Name: %s | Mutation: %s | Total: %s", brainrotName, mutationName or "None", total))
                    end)

                    if total < autoSellThresholdConfig then
                        BrainrotShopAction:InvokeServer(1)
                        task.wait(0.2) 
                    else
                        currentHumanoid:UnequipTools()
                    end
                end
            end

            while autoSellCheapEnabled and ScriptID == CurrentScriptId and currentCharacter:FindFirstChildOfClass("Model") do
                task.wait()
            end
        end
        task.wait(0.1)
    end
end

---
-- CONFIGURATION SECTION
---
MainTab:CreateSection("Configurations")

MainTab:CreateInput({
   Name = "Minimum Cash Per Second",
   PlaceholderText = "Ex: 1.5B, 20.1B, 500K...",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      minCashPerSecondConfig = parseFormattedString(Text)
   end,
})

MainTab:CreateInput({
   Name = "Auto Sell Threshold",
   PlaceholderText = "Default: 16.66M (16666665)",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      autoSellThresholdConfig = parseFormattedString(Text)
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
   Name = "Steal Next Valid Mob (One-Time)",
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

local CollectToggle = MainTab:CreateToggle({
   Name = "Loop Auto Collect Money",
   CurrentValue = true,
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
   Name = "Loop Auto Upgrade Cheapest Slot",
   CurrentValue = false,
   Callback = function(Value)
      autoUpgradeEnabled = Value
      if autoUpgradeEnabled then
         task.spawn(function()
            while autoUpgradeEnabled and ScriptID == CurrentScriptId do
                upgradeCheapestSlot()
                RunService.Heartbeat:Wait()
            end
         end)
      end
   end,
})

MainTab:CreateButton({
   Name = "Upgrade Cheapest Slot Once (One-Time)",
   Callback = function()
      task.spawn(upgradeCheapestSlot)
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
      pickupAllFromBase()
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
      placeAllIntoBase()
   end,
})

local FixToggle = MainTab:CreateToggle({
   Name = "Auto Fix Clutter / Problems",
   CurrentValue = true,
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
-- GEAR & DEFENSE SECTION
---
MainTab:CreateSection("Combat & Defense")

local AntiKillToggle = MainTab:CreateToggle({
   Name = "Anti-Kill (Strip Touch Hazards)",
   CurrentValue = true,
   Callback = function(Value)
      antiKillEnabled = Value
      if antiKillEnabled then
         task.spawn(function()
            while antiKillEnabled and ScriptID == CurrentScriptId do
                disableKillParts()
                task.wait(1)
            end
         end)
      end
   end,
})

AutoEquipToggle = MainTab:CreateToggle({
   Name = "Loop Auto Equip Best Brainrot",
   CurrentValue = false,
   Callback = function(Value)
      autoEquipEnabled = Value
      if autoEquipEnabled then
         -- Force-disable conflicting automation loop safely
         if autoSellCheapEnabled then
            autoSellCheapEnabled = false
            AutoSellToggle:Set(false)
         end
         
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

AutoSellToggle = MainTab:CreateToggle({
   Name = "Auto Equip & Auto Sell Cheap Brainrots",
   CurrentValue = false,
   Callback = function(Value)
      autoSellCheapEnabled = Value
      if autoSellCheapEnabled then
         -- Force-disable conflicting automation loop safely
         if autoEquipEnabled then
            autoEquipEnabled = false
            AutoEquipToggle:Set(false)
         end
         
         task.spawn(runAutoSellProcess)
      end
   end,
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

-- Handle initial execution triggers for defaults
task.spawn(function()
    while autoCollectEnabled and ScriptID == CurrentScriptId do
        collectBaseMoney()
        task.wait(0.5)
    end
end)

task.spawn(function()
    while autoFixEnabled and ScriptID == CurrentScriptId do
        fixBaseProblems()
        task.wait(0.5)
    end
end)

task.spawn(function()
    while antiKillEnabled and ScriptID == CurrentScriptId do
        disableKillParts()
        task.wait(1)
    end
end)

-- Initialize Rayfield (Load the UI fully)
Rayfield:LoadConfiguration()
