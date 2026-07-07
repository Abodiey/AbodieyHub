getgenv().ScriptID = os.time()
local CurrentScriptID = getgenv().ScriptID

print("[+] Script initialized with ID: " .. tostring(CurrentScriptID))

-- Service Configuration
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))

local LocalPlayer = Players.LocalPlayer

-- Explicit Event Declaration
local LoadEvent = ReplicatedStorage:WaitForChild("Load")
local InsertElementEvent = ReplicatedStorage:WaitForChild("InsertElement")
local LoadEffectEvent = ReplicatedStorage:WaitForChild("LoadEffect")
local LoadEffect2Event = ReplicatedStorage:WaitForChild("LoadEffect2")
local SystemMessageEvent = ReplicatedStorage:WaitForChild("SystemMessage")

-- Custom Tool and Targeted Deletion Remotes
local CustomToolEvent = ReplicatedStorage:WaitForChild("^w^")
local MeowDeleteEvent = ReplicatedStorage:WaitForChild("meow")

-- Paths
local ItemsFolder = workspace:WaitForChild("_Items")

-- Global Script State Tracking
local ScriptEnabled = false
local BlockNotifications = true
local AntiAdminEnabled = true

-- Configuration States
local ManualModeEnabled = false
local ReverseManualMode = false
local TargetElementName = ""

-- Tunable Parameters
local PlacementCooldown = 0.5
local VerificationTimeout = 2.0
local PostFailureDelay = 3.0
local MinElementNameLength = 7
local MaxElementNameLength = 14

-- Session States
local StatusParagraph = nil
local consecutiveFailures = 0
local lastRandomElement = ""
local justWiped = false -- Anti-infinite loop flag after full board wipes

-- Signaling Variables for Network Listeners
local MergeStateReceived = false
local DiscoveredNewElement = false
local MergeFailedReceived = false

-- Forward Declarations
local GetPlaced
local DeletePlacedItem
local GetElements
local PlaceElement
local GetRandomShortElement

-- Anti Admin Logic
local function CheckForAdmin(player)
    if not AntiAdminEnabled or player == LocalPlayer then return end
    
    local success, rank = pcall(function()
        return player:GetRankInGroup(6804560)
    end)
    
    if success and rank and rank > 2 then
        LocalPlayer:Kick("Anti-Admin: Staff member detected (" .. player.Name .. ")")
    end
end

task.spawn(function()
    for _, player in ipairs(Players:GetPlayers()) do
        CheckForAdmin(player)
    end
    Players.PlayerAdded:Connect(CheckForAdmin)
end)

-- Background Memory Scan Task
task.spawn(function()
    if _G.Elements then return end

    local path = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ClientGui"):WaitForChild("SavedElementsFrame"):WaitForChild("ElementsScrollingFrame")
    local virtualScript = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ClientGui"):WaitForChild("Client"):WaitForChild("VirtualElements")

    local children = path:GetChildren()
    local targetName = ""

    for i = 1, #children do
        if children[i].Name ~= "" then
            targetName = children[i].Name
            break
        end
    end

    local targetCount = require(virtualScript).GetElementCount()
    local gc = getgc(true)

    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and type(rawget(v, targetName)) == "table" then
            local count = 0
            for _ in pairs(v) do count = count + 1 end
            
            if count >= targetCount then
                _G.Elements = v
                break
            end
        end
    end
end)

-- Wait for Elements
while not _G.Elements do task.wait(0.1) end

-- Signal Interceptor Hooks
local function InitializeSignals()
    LoadEffectEvent.OnClientEvent:Connect(function(actionType, ...)
        if getgenv().ScriptID ~= CurrentScriptID or not ScriptEnabled then return end
        
        if actionType == "MixStart" then
            MergeStateReceived = false
            DiscoveredNewElement = false
            MergeFailedReceived = false
        elseif actionType == "MixNormal" then
            DiscoveredNewElement = true
            MergeStateReceived = true
        end
    end)

    SystemMessageEvent.OnClientEvent:Connect(function(arg1, arg2)
        if getgenv().ScriptID ~= CurrentScriptID then return end
        
        local msg = tostring(arg2)
        if ScriptEnabled and string.find(msg, "Merge Failed") then
            MergeFailedReceived = true
            MergeStateReceived = true
        end
    end)
    
    if type(getconnections) == "function" then
        for _, connection in ipairs(getconnections(SystemMessageEvent.OnClientEvent)) do
            local oldFunction; oldFunction = hookfunction(connection.Function, function(...)
                if getgenv().ScriptID ~= CurrentScriptID then return oldFunction(...) end
                local args = {...}
                local message = args[2]
                if BlockNotifications and type(message) == "string" and string.find(message, "New Discovered Element") then
                    return 
                end
                return oldFunction(...)
            end)
        end

        for _, connection in ipairs(getconnections(LoadEffect2Event.OnClientEvent)) do
            local oldFunction; oldFunction = hookfunction(connection.Function, function(...)
                if getgenv().ScriptID ~= CurrentScriptID then return oldFunction(...) end
                
                local args = {...}
                local targetUser = args[1]
                
                if BlockNotifications then
                    if type(targetUser) ~= "string" or not string.find(targetUser, LocalPlayer.Name) then
                        return 
                    end
                end
                return oldFunction(...)
            end)
        end
    end
end
InitializeSignals()

local function UpdateDisplayUI(statusText)
    if getgenv().ScriptID ~= CurrentScriptID then return end
    if StatusParagraph then
        StatusParagraph:Set({ Title = "Logs", Content = statusText })
    end
end

local function Load()
    LoadEvent:FireServer()
end

function GetElements()
    if not _G.Elements then return {} end
    
    local names = {}
    for elementName, _ in pairs(_G.Elements) do
        if type(elementName) == "string" and elementName ~= "" then
            table.insert(names, elementName)
        end
    end
    return names
end

function GetRandomShortElement()
    local elements = GetElements()
    local filteredElements = {}
    local backupFiltered = {}
    
    for i = 1, #elements do
        local name = elements[i]
        if #name >= MinElementNameLength and #name <= MaxElementNameLength then 
            table.insert(backupFiltered, name)
            if name ~= lastRandomElement then
                table.insert(filteredElements, name) 
            end
        end
    end
    
    local chosen = nil
    if #filteredElements > 0 then
        chosen = filteredElements[math.random(1, #filteredElements)]
    elseif #backupFiltered > 0 then
        chosen = backupFiltered[math.random(1, #backupFiltered)]
    elseif #elements > 0 then
        local absoluteBackup = {}
        for i = 1, #elements do
            if elements[i] ~= lastRandomElement then table.insert(absoluteBackup, elements[i]) end
        end
        if #absoluteBackup > 0 then
            chosen = absoluteBackup[math.random(1, #absoluteBackup)]
        else
            chosen = elements[math.random(1, #elements)]
        end
    end
    
    if chosen then lastRandomElement = chosen end
    return chosen
end

function GetPlaced()
    local myItems = {}
    local children = ItemsFolder:GetChildren()
    for i = 1, #children do
        local item = children[i]
        if item:GetAttribute("Placer") == LocalPlayer.Name and item.Name and item.Name ~= "" then
            table.insert(myItems, item)
        end
    end
    return myItems
end

function PlaceElement(name)
    local activeCount = #GetPlaced()
    if activeCount >= 2 then 
        return false 
    end

    if not name or name == "" then return false end
    Load()
    InsertElementEvent:FireServer(name)
    task.wait(PlacementCooldown)
    return true
end

function DeletePlacedItem(targetItem)
    if not targetItem or not targetItem:IsDescendantOf(workspace) then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local toolsAttribute = LocalPlayer:GetAttribute("Tools")
    local unlocked = type(toolsAttribute) == "string" and string.find(toolsAttribute, "Delete")
    
    if not unlocked then
        CustomToolEvent:InvokeServer("et", "Delete")
        task.wait(0.1)
    end
    
    local currentlyEquipped = character:FindFirstChild("Delete")
    if not currentlyEquipped then
        CustomToolEvent:InvokeServer("t", "Delete")
    end
    
    if character:FindFirstChild("Delete") then
        MeowDeleteEvent:InvokeServer(targetItem)
    end
    
    CustomToolEvent:InvokeServer("t", "Delete")
end

function GetMergeSuggestion(availableElements)
    local filteredElements = {}
    local backupFiltered = {}
    
    for i = 1, #availableElements do
        local element = availableElements[i]
        if #element >= MinElementNameLength and #element <= MaxElementNameLength then
            table.insert(backupFiltered, element)
            if element ~= lastRandomElement then
                table.insert(filteredElements, element)
            end
        end
    end
    
    local chosen = nil
    if #filteredElements > 0 then 
        chosen = filteredElements[math.random(1, #filteredElements)]
    elseif #backupFiltered > 0 then
        chosen = backupFiltered[math.random(1, #backupFiltered)]
    elseif #availableElements > 0 then
        local absoluteBackup = {}
        for i = 1, #availableElements do
            if availableElements[i] ~= lastRandomElement then table.insert(absoluteBackup, availableElements[i]) end
        end
        if #absoluteBackup > 0 then
            chosen = absoluteBackup[math.random(1, #absoluteBackup)]
        else
            chosen = availableElements[math.random(1, #availableElements)]
        end
    end
    
    if chosen then lastRandomElement = chosen end
    return chosen
end

local function RunIteration()
    local initialAvailable = GetElements()
    local currentItems = GetPlaced()

    if #currentItems > 2 then
        UpdateDisplayUI("Overcrowded board. Purging extras...")
        for i = 2, #currentItems do
            local itemToClean = currentItems[i]
            if itemToClean then DeletePlacedItem(itemToClean) end
        end
        return
    end

    if ManualModeEnabled and TargetElementName == "" then
        UpdateDisplayUI("Error: Manual mode active but text box is empty!")
        return
    end

    -- Step 1: Handle board seeding when completely empty
    if #currentItems == 0 then
        local baseElement = nil
        
        -- Break loops by forcing a random rotation if we just completed a board wipe
        if justWiped then
            justWiped = false
            baseElement = GetRandomShortElement()
            UpdateDisplayUI("Board recovered from wipe. Seeding forced loop-breaker: " .. tostring(baseElement))
        elseif ManualModeEnabled then
            if ReverseManualMode then
                baseElement = GetRandomShortElement()
                UpdateDisplayUI("Reverse Mode: Seeding canvas with random element: " .. tostring(baseElement))
            else
                baseElement = TargetElementName
                UpdateDisplayUI("Board empty. Dropping targeted base: " .. baseElement)
            end
        else
            baseElement = GetRandomShortElement()
            UpdateDisplayUI("Board empty. Dropping random base: " .. tostring(baseElement))
        end

        if baseElement then
            PlaceElement(baseElement)
        end
        return
    end

    -- Step 2: Extract current structural asset on board
    local targetItem = currentItems[1]
    if not targetItem or not targetItem:IsA("BasePart") then return end
    
    if ManualModeEnabled and not justWiped then
        if not ReverseManualMode and targetItem.Name ~= TargetElementName then
            UpdateDisplayUI("Base mismatch. Resetting to target: " .. TargetElementName)
            DeletePlacedItem(targetItem)
            task.wait(0.1)
            PlaceElement(TargetElementName)
            return
        elseif ReverseManualMode and targetItem.Name == TargetElementName then
            UpdateDisplayUI("Target element stuck as base in Reverse. Purging canvas...")
            DeletePlacedItem(targetItem)
            return
        end
    end

    -- Step 3: Pick the catalyst depending on your operational parameters
    local mergeCandidate = nil
    if ManualModeEnabled and ReverseManualMode then
        mergeCandidate = TargetElementName
    else
        mergeCandidate = GetMergeSuggestion(initialAvailable)
    end

    if not mergeCandidate then return end
    
    MergeStateReceived = false
    DiscoveredNewElement = false
    MergeFailedReceived = false

    UpdateDisplayUI("Mixing: " .. targetItem.Name .. " + " .. mergeCandidate)
    local success = PlaceElement(mergeCandidate)
    if not success then return end
    
    local startWaitTime = os.clock()
    local initialCount = #GetPlaced()
    local unhookedHangDetected = false

    while not MergeStateReceived and (os.clock() - startWaitTime) < VerificationTimeout do
        if not ScriptEnabled or getgenv().ScriptID ~= CurrentScriptID then return end
        if (os.clock() - startWaitTime) >= 5.0 and #GetPlaced() == initialCount then
            unhookedHangDetected = true
            MergeStateReceived = true 
            break
        end
        task.wait()
    end

    if DiscoveredNewElement and not unhookedHangDetected then
        UpdateDisplayUI("New element tracked!")
        consecutiveFailures = 0 
        justWiped = false
    elseif MergeFailedReceived or not MergeStateReceived or unhookedHangDetected then
        consecutiveFailures = consecutiveFailures + 1
        
        if unhookedHangDetected then
            UpdateDisplayUI("Network hang. Failure cycle: " .. tostring(consecutiveFailures))
        elseif not MergeStateReceived then
            UpdateDisplayUI("Timeout. Syncing... Failure cycle: " .. tostring(consecutiveFailures))
        else
            UpdateDisplayUI("Failed combo. Failure cycle: " .. tostring(consecutiveFailures))
        end

        local checkItems = GetPlaced()
        
        -- Double failure protection rule condition trigger
        if consecutiveFailures >= 2 then
            UpdateDisplayUI("Double failure threshold reached! Wiping entire board...")
            for i = 1, #checkItems do
                if checkItems[i] then DeletePlacedItem(checkItems[i]) end
            end
            consecutiveFailures = 0 
            justWiped = true -- Flag that we just wiped the board to alter the next step's pick
        else
            -- Standard single failure removal mechanics
            if #checkItems >= 2 then
                local itemA = checkItems[1]
                local itemB = checkItems[2]
                
                if itemA and itemB then
                    local itemToDelete
                    if ManualModeEnabled then
                        if ReverseManualMode then
                            itemToDelete = (itemB.Name == TargetElementName) and itemB or itemA
                        else
                            itemToDelete = (itemA.Name == TargetElementName) and itemB or itemA
                        end
                    else
                        itemToDelete = (#itemA.Name >= #itemB.Name) and itemA or itemB
                    end
                    DeletePlacedItem(itemToDelete)
                end
            elseif #checkItems == 1 then
                if not ManualModeEnabled then
                    DeletePlacedItem(checkItems[1])
                end
            end
        end

        task.wait(PostFailureDelay)
    end
end

-- Rayfield GUI Interface Initialization
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "Craft Automation",
    LoadingTitle = "Loading Automation...",
    LoadingSubtitle = "by Abdullah Alhamidi",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Dashboard", nil)

MainTab:CreateSection("Main")

MainTab:CreateToggle({
    Name = "Enable Automation",
    CurrentValue = false,
    Callback = function(Value)
        ScriptEnabled = Value
        if ScriptEnabled then
            consecutiveFailures = 0
            justWiped = false
            UpdateDisplayUI("Running automation loop...")
            
            -- Automation Thread
            task.spawn(function()
                while ScriptEnabled and getgenv().ScriptID == CurrentScriptID do
                    local success, err = pcall(RunIteration)
                    if not success then 
                        warn("[-] Engine error: " .. tostring(err)) 
                    end
                    task.wait(0.1)
                end
            end)
            
            -- Coupled Anti-AFK Routine
            task.spawn(function()
                while ScriptEnabled and getgenv().ScriptID == CurrentScriptID do
                    pcall(function()
                        LocalPlayer.Idled:Connect(function()
                            if ScriptEnabled and getgenv().ScriptID == CurrentScriptID then
                                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                                task.wait(1)
                                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                            end
                        end)
                        -- Alternate programmatic ping fallback
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new(0,0))
                    end)
                    task.wait(120) -- Keep alive pulse every 2 minutes
                end
            end)
        else
            UpdateDisplayUI("Loop deactivated.")
        end
    end
})

MainTab:CreateToggle({
    Name = "Anti-Admin",
    CurrentValue = true,
    Callback = function(Value) AntiAdminEnabled = Value end
})

MainTab:CreateToggle({
    Name = "Mute Alerts",
    CurrentValue = true,
    Callback = function(Value) BlockNotifications = Value end
})

MainTab:CreateSection("Target Seeding Configuration")

MainTab:CreateToggle({
    Name = "Use Specific Base Element (Manual Mode)",
    CurrentValue = false,
    Callback = function(Value)
        ManualModeEnabled = Value
        if ManualModeEnabled then
            UpdateDisplayUI("Manual mode active. Target: " .. (TargetElementName ~= "" and TargetElementName or "[None]"))
        else
            UpdateDisplayUI("Random selection mode active.")
        end
    end
})

MainTab:CreateInput({
    Name = "Target Element Name",
    PlaceholderText = "Enter exact element name...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        TargetElementName = tostring(Text or "")
        if ManualModeEnabled then
            UpdateDisplayUI("Target updated to: " .. TargetElementName)
        end
    end
})

MainTab:CreateToggle({
    Name = "Reverse Manual Seeding Mode",
    CurrentValue = false,
    Callback = function(Value)
        ReverseManualMode = Value
        if ManualModeEnabled and ReverseManualMode then
            UpdateDisplayUI("Reverse mode engaged. Dropping random first, then dropping target: " .. TargetElementName)
        end
    end
})

MainTab:CreateSection("Delays")

MainTab:CreateSlider({
    Name = "Placement Cooldown",
    Range = {0.0, 2.0},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.5,
    Callback = function(Value) PlacementCooldown = Value end
})

MainTab:CreateSlider({
    Name = "Verification Timeout",
    Range = {0.5, 5.0},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 2.0,
    Callback = function(Value) VerificationTimeout = Value end
})

MainTab:CreateSlider({
    Name = "Failure Throttle Delay",
    Range = {0.0, 10.0},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 3.0,
    Callback = function(Value) PostFailureDelay = Value end
})

MainTab:CreateSection("Filters")

MainTab:CreateSlider({
    Name = "Min Name Length",
    Range = {1, 20},
    Increment = 1,
    Suffix = " chars",
    CurrentValue = 7,
    Callback = function(Value) MinElementNameLength = Value end
})

MainTab:CreateSlider({
    Name = "Max Name Length",
    Range = {5, 30},
    Increment = 1,
    Suffix = " chars",
    CurrentValue = 14,
    Callback = function(Value) MaxElementNameLength = Value end
})

MainTab:CreateSection("Diagnostics")
StatusParagraph = MainTab:CreateParagraph({Title = "Logs", Content = "System idling..."})
