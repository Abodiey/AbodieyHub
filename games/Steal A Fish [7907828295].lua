getgenv().ScriptID = os.time()
local CurrentScriptID = ScriptID

local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CoreGui = cloneref(game:GetService("CoreGui"))

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local RootPart = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(NewChar)
    Character = NewChar
    RootPart = NewChar:WaitForChild("HumanoidRootPart")
end)

local MapFolder = workspace:WaitForChild("Map")
local TycoonsFolder = MapFolder:WaitForChild("Tycoons")

local Tycoon = nil
while ScriptID == CurrentScriptID and not Tycoon do
    for _, CurrentTycoon in ipairs(TycoonsFolder:GetChildren()) do
        if CurrentTycoon:GetAttribute("Owner") == LocalPlayer.Name then
            Tycoon = CurrentTycoon
            break
        end
    end
    if not Tycoon then
        task.wait()
    end
end

if ScriptID ~= CurrentScriptID then return end

local VoidSkyRemotes = ReplicatedStorage:WaitForChild("voidSky"):WaitForChild("Remotes")

local BuyButtonEvent = VoidSkyRemotes:WaitForChild("Server"):WaitForChild("Objects"):WaitForChild("BuyButton")
local CollectCashEvent = VoidSkyRemotes:WaitForChild("Server"):WaitForChild("Objects"):WaitForChild("Trash"):WaitForChild("Collect")
local NotifyClientEvent = VoidSkyRemotes:WaitForChild("Client"):WaitForChild("Visual"):WaitForChild("Notify")
local PlayEventTransition = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlayEventTransition")

local TycoonSubFolder = Tycoon:WaitForChild("Tycoon")
local ForcefieldFolder = TycoonSubFolder:WaitForChild("ForcefieldFolder")
local ButtonsFolder = ForcefieldFolder:WaitForChild("Buttons")
local ForceFieldBuyButton = ButtonsFolder:WaitForChild("ForceFieldBuy")

local ScreenObject = ForcefieldFolder:WaitForChild("Screen"):WaitForChild("Screen")
local SurfaceGui = ScreenObject:WaitForChild("SurfaceGui")
local TimeTextLabel = SurfaceGui:WaitForChild("Time")

local AutoLockBase = true
local AutoCollectCash = true
local BlockEmptyCashNotifications = true
local BlockWhiteScreenTransitions = true
local EnableBillboardTrackers = true

local ActiveBillboards = {}

local function ClearBillboards()
    for Target, Elements in pairs(ActiveBillboards) do
        if Elements.Gui then Elements.Gui:Destroy() end
        if Elements.Signal then Elements.Signal:Disconnect() end
    end
    table.clear(ActiveBillboards)
end

local function ConstructBillboard(TargetTycoon)
    if ActiveBillboards[TargetTycoon] then return end

    local Success, Screen = pcall(function()
        return TargetTycoon:WaitForChild("Tycoon", 2):WaitForChild("ForcefieldFolder", 2):WaitForChild("Screen", 2):WaitForChild("Screen", 2)
    end)
    
    if not Success or not Screen then return end
    
    local TimeLabelInstance = Screen:WaitForChild("SurfaceGui", 2):WaitForChild("Time", 2)
    if not TimeLabelInstance then return end

    local NewBillboard = Instance.new("BillboardGui")
    NewBillboard.Name = "TycoonTracker_" .. TargetTycoon.Name
    NewBillboard.Size = UDim2.new(0, 150, 0, 50)
    NewBillboard.AlwaysOnTop = true
    NewBillboard.MaxDistance = 500
    NewBillboard.ExtentsOffset = Vector3.new(0, 4, 0)
    NewBillboard.Adornee = Screen
    NewBillboard.Parent = CoreGui

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, 0, 1, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    TextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TextLabel.TextStrokeTransparency = 0
    TextLabel.Font = Enum.Font.RobotoMono
    TextLabel.TextSize = 22
    TextLabel.Text = TimeLabelInstance.Text
    TextLabel.Parent = NewBillboard

    local function RefreshText()
        if not EnableBillboardTrackers then
            TextLabel.Visible = false
            return
        end
        local CurrentText = TimeLabelInstance.Text
        TextLabel.Text = CurrentText
        
        if CurrentText == "0s" or CurrentText == "" or not string.match(CurrentText, "%d") then
            TextLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
        else
            TextLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
        end
        TextLabel.Visible = true
    end

    local ConnectionSignal = TimeLabelInstance:GetPropertyChangedSignal("Text"):Connect(RefreshText)
    RefreshText()

    ActiveBillboards[TargetTycoon] = {
        Gui = NewBillboard,
        Signal = ConnectionSignal
    }
end

for _, Connection in ipairs(getconnections(NotifyClientEvent.OnClientEvent)) do
    local OldConnectionFunc; OldConnectionFunc = hookfunction(Connection.Function, function(...)
        if ScriptID ~= CurrentScriptID then
            return OldConnectionFunc(...)
        end
        
        local Args = {...}
        if BlockEmptyCashNotifications and Args[1] == "+ 0$" then
            return
        end
        
        return OldConnectionFunc(...)
    end)
end

for _, Connection in ipairs(getconnections(PlayEventTransition.OnClientEvent)) do
    local OldTransitionFunc; OldTransitionFunc = hookfunction(Connection.Function, function(...)
        if ScriptID ~= CurrentScriptID then
            return OldTransitionFunc(...)
        end
        
        if BlockWhiteScreenTransitions then
            return
        end
        
        return OldTransitionFunc(...)
    end)
end

task.spawn(function()
    while ScriptID == CurrentScriptID do
        task.wait()
        if ScriptID ~= CurrentScriptID then break end

        if AutoLockBase and RootPart then
            local Text = TimeTextLabel.Text
            
            if Text == "3s" or Text == "2s" or Text == "1s" or Text == "0s" then
                local OldCFrame = RootPart.CFrame
                
                local TargetPart = ForceFieldBuyButton:WaitForChild("Forcefield")
                local CleanTargetPosition = TargetPart.Position + Vector3.new(0, 3, 0)
                
                RootPart.CFrame = CFrame.new(CleanTargetPosition)
                task.wait(0.05)
                
                BuyButtonEvent:FireServer(ForceFieldBuyButton)
                
                while ScriptID == CurrentScriptID and AutoLockBase do
                    local CurrentText = TimeTextLabel.Text
                    if CurrentText ~= "3s" and CurrentText ~= "2s" and CurrentText ~= "1s" and CurrentText ~= "0s" then
                        break
                    end
                    
                    BuyButtonEvent:FireServer(ForceFieldBuyButton)
                    task.wait(0.1)
                end
                
                if RootPart then
                    RootPart.CFrame = OldCFrame
                end
                
                task.wait(0.5)
            end
        end
    end
end)

task.spawn(function()
    while ScriptID == CurrentScriptID do
        task.wait(0.15)
        if ScriptID ~= CurrentScriptID then break end
        
        if AutoCollectCash then
            for SlotNumber = 1, 10 do
                if ScriptID ~= CurrentScriptID or not AutoCollectCash then break end
                
                CollectCashEvent:FireServer(SlotNumber)
                task.wait(0.2)
            end
        end
    end
end)

task.spawn(function()
    while ScriptID == CurrentScriptID do
        if EnableBillboardTrackers then
            for _, CurrentTycoon in ipairs(TycoonsFolder:GetChildren()) do
                if ScriptID ~= CurrentScriptID then break end
                ConstructBillboard(CurrentTycoon)
            end
        else
            ClearBillboards()
        end
        task.wait(2)
    end
    ClearBillboards()
end)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Void Sky Automation Suite",
    LoadingTitle = "Loading Automation...",
    LoadingSubtitle = "by AbodieyHub",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

local MainTab = Window:CreateTab("Automation", 4483362458)

MainTab:CreateToggle({
    Name = "Auto Lock Base (Timed Filter)",
    CurrentValue = AutoLockBase,
    Flag = "ToggleLockBase",
    Callback = function(Value)
        AutoLockBase = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Collect Cash (Max Speed)",
    CurrentValue = AutoCollectCash,
    Flag = "ToggleCollectCash",
    Callback = function(Value)
        AutoCollectCash = Value
    end,
})

MainTab:CreateToggle({
    Name = "Block Empty Cash Popups",
    CurrentValue = BlockEmptyCashNotifications,
    Flag = "ToggleBlockEmptyCash",
    Callback = function(Value)
        BlockEmptyCashNotifications = Value
    end,
})

MainTab:CreateToggle({
    Name = "Anti White Screen Transition",
    CurrentValue = BlockWhiteScreenTransitions,
    Flag = "ToggleWhiteScreen",
    Callback = function(Value)
        BlockWhiteScreenTransitions = Value
    end,
})

MainTab:CreateToggle({
    Name = "Show Base Unlock Timers (Always On Top)",
    CurrentValue = EnableBillboardTrackers,
    Flag = "ToggleBillboardTrackers",
    Callback = function(Value)
        EnableBillboardTrackers = Value
        if not Value then
            ClearBillboards()
        end
    end,
})

Rayfield:Notify({
    Title = "Script Loaded Successfully",
    Content = "CoreGui visual elements tracking structure initialized.",
    Duration = 5,
    Image = 4483362458,
})
