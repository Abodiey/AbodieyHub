-- Set the script ID globally to stop previous execution instances
getgenv().ScriptID = os.clock()
local CurrentScriptID = getgenv().ScriptID

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

-- Game Remotes & Data
local RedeemEvent = ReplicatedStorage.Packages.Net["RE/SafeZoneEvent"]
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

-- Find the furthest mob from the origin point (must be past minDistanceConfig)
local function getTarget()
    local mobChildren = Mobs:GetChildren()
    if #mobChildren == 0 then return nil, nil end -- Quick escape if no mobs exist

    local longestDistance = -1
    local chosenPrompt, chosenPart

    for _, mob in ipairs(mobChildren) do
        if getgenv().ScriptID ~= CurrentScriptID then return nil, nil end
        
        local mobRoot = mob:FindFirstChild("RootPart")
        local prompt = mobRoot and mobRoot:FindFirstChildOfClass("ProximityPrompt")
        
        if prompt and prompt.Enabled then
            local distance = (ORIGIN_POINT - mobRoot.Position).Magnitude
            -- Only consider targets that are further away than our slider setting
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
            if getgenv().ScriptID ~= CurrentScriptID then break end
            
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

-- Create a Single Tab for features
local MainTab = Window:CreateTab("Main Features", 4483362458)

-- State Variables for the toggles
local autoStealEnabled = false
local autoEquipEnabled = false
local autoRedeemEnabled = false

---
-- CONFIGURATION SECTION
---
MainTab:CreateSection("Configurations")

MainTab:CreateSlider({
   Name = "Minimum Distance From Origin",
   Info = "Mobs closer than this distance will be ignored.",
   Min = 0,
   Max = 2000,
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
            -- Parallel background thread running continuously to completely kill velocity while farming
            task.spawn(function()
                while autoStealEnabled and getgenv().ScriptID == CurrentScriptID do
                    if root and root:IsDescendantOf(workspace) then
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                    RunService.Heartbeat:Wait()
                end
            end)

            while autoStealEnabled and getgenv().ScriptID == CurrentScriptID do
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
            while autoEquipEnabled and getgenv().ScriptID == CurrentScriptID do
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
            while autoRedeemEnabled and getgenv().ScriptID == CurrentScriptID do
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
