getgenv().ScriptID = os.time()
local CurrentScriptID = ScriptID

local players = game:GetService("Players")
local localPlayer = players.LocalPlayer

-- Wait for the character and root part to load
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Wait for the plots folder
local plotsFolder = workspace:WaitForChild("Plots")

-- Find our plot by matching the Owner attribute
local myPlot = nil
for _, plot in ipairs(plotsFolder:GetChildren()) do
    if plot:GetAttribute("Owner") == localPlayer.UserId then
        myPlot = plot
        break
    end
end

-- Wait for the required folders once at the start
local lockBaseZones = myPlot:WaitForChild("LockBaseZones")
local zone = lockBaseZones:WaitForChild("Zone")
local buttonsFolder = myPlot:WaitForChild("Buttons")

-- Remote event for Kill Aura
local validateHitEvent = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("ValidateHit")

-- Normal local variables for tracking toggle states
local AutoLockBase = true
local AutoCollectMoney = true
local KillAura = false

-- Helper function to find the closest player's character
local function getClosestPlayerCharacter()
    local maxDistance = 25 -- Adjust the aura range here
    local closestChar = nil
    
    local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
            local enemyHumanoid = player.Character:FindFirstChild("Humanoid")
            
            -- Ensure player is alive and has a root part
            if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
                local distance = (myRoot.Position - enemyRoot.Position).Magnitude
                if distance < maxDistance then
                    maxDistance = distance
                    closestChar = player.Character
                end
            end
        end
    end
    return closestChar
end

-- Helper function to manage weapon equipping
local function equipBestSword()
    local char = localPlayer.Character
    local backpack = localPlayer.Backpack
    if not char or not backpack then return end

    -- Check if a valid sword is already equipped in the character
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") and string.find(item.Name, "Sword") then
            return -- Already holding a sword, do nothing
        end
    end

    local woodenSword = nil
    local targetSword = nil

    -- Search backpack for the best option
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if tool.Name == "WoodenSword" then
                woodenSword = tool
            elseif string.find(tool.Name, "Sword") then
                targetSword = tool
                break -- Found a high-tier sword, stop searching
            end
        end
    end

    -- Determine which weapon to equip
    local swordToEquip = targetSword or woodenSword
    if swordToEquip then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:EquipTool(swordToEquip)
        end
    end
end

-- LOOP 1: Auto Lock Base (MAX SPEED)
task.spawn(function()
    while ScriptID == CurrentScriptID do
        task.wait() 
        if ScriptID ~= CurrentScriptID then break end
        
        if AutoLockBase then
            firetouchinterest(zone, rootPart, 0)
            firetouchinterest(zone, rootPart, 1)
        end
    end
end)

-- LOOP 2: Auto Collect Money (Buttons)
task.spawn(function()
    while ScriptID == CurrentScriptID do
        task.wait(0.5)
        if ScriptID ~= CurrentScriptID then break end
        
        if AutoCollectMoney then
            for _, button in ipairs(buttonsFolder:GetChildren()) do
                if ScriptID ~= CurrentScriptID or not AutoCollectMoney then break end
                
                local targetPart = button.Part
                local guiEnabled = targetPart.Attachment.BillboardGui.Enabled
                local stolenGuiEnabled = targetPart.StolenAttachment.BillboardGui.Enabled
                
                if guiEnabled or stolenGuiEnabled then
                    firetouchinterest(targetPart, rootPart, 0)
                    task.wait(0.05) 
                    firetouchinterest(targetPart, rootPart, 1)
                end
            end
        end
    end
end)

-- LOOP 3: Kill Aura
task.spawn(function()
    while ScriptID == CurrentScriptID do
        task.wait(0.1) -- Fast attack speed interval
        if ScriptID ~= CurrentScriptID then break end
        
        if KillAura then
            local targetCharacter = getClosestPlayerCharacter()
            if targetCharacter then
                equipBestSword() -- Attempt weapon handling right before validation attack
                validateHitEvent:FireServer(targetCharacter)
            end
        end
    end
end)

-- ==========================================
--               RAYFIELD GUI
-- ==========================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Tycoon Automation Suite",
    LoadingTitle = "Loading Automation...",
    LoadingSubtitle = "by AbodieyHub",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

local MainTab = Window:CreateTab("Automation", 4483362458)

MainTab:CreateToggle({
    Name = "Auto Lock Base",
    CurrentValue = AutoLockBase,
    Flag = "ToggleLockBase",
    Callback = function(Value)
        AutoLockBase = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Money",
    CurrentValue = AutoCollectMoney,
    Flag = "ToggleCollectMoney",
    Callback = function(Value)
        AutoCollectMoney = Value
    end,
})

MainTab:CreateToggle({
    Name = "Kill Aura",
    CurrentValue = KillAura,
    Flag = "ToggleKillAura",
    Callback = function(Value)
        KillAura = Value
    end,
})

Rayfield:Notify({
    Title = "Script Loaded Successfully",
    Content = "Toggles are ready to use in the GUI.",
    Duration = 5,
    Image = 4483362458,
})
