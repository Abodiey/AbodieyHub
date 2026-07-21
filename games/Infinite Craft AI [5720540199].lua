-- 1. Get Players & Wait for Character before doing ANYTHING else
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- 2. Strictly use cloneref for all other services
local CoreGui = cloneref(game:GetService("CoreGui"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserService = cloneref(game:GetService("UserService"))

-- Network Services & Targets
local Event = ReplicatedStorage:WaitForChild("InformBuyableElement")
local SaveEvent = ReplicatedStorage:WaitForChild("SaveElement")
local RemoteFunc = ReplicatedStorage:WaitForChild("^w^")
local SystemMessageEvent = ReplicatedStorage:WaitForChild("SystemMessage")

local UI_NAME = "TopNotificationGui_Unique"

-- 3. Grab targets using upvalue shortcuts directly
local f41, listingsIndex
for _, conn in pairs(getconnections(SaveEvent.OnClientEvent)) do
    local func = conn.Function
    if func and type(func) == "function" and not iscclosure(func) then
        f41 = getupvalues(func)[1]
        listingsIndex = 1
        break
    end
end

if not f41 then 
    warn("Failed to locate targets! Element scan loop will not function.") 
end

local function getLatestListings()
    if not f41 then return nil end
    local val1, val2 = getupvalue(f41, listingsIndex)
    if type(val1) == "string" then
        return val2
    end
    return val1
end

-- 4. Intercept SystemMessage.OnClientEvent directly
for _, connection in pairs(getconnections(SystemMessageEvent.OnClientEvent)) do
    local oldConnFunc
    oldConnFunc = hookfunction(connection.Function, function(...)
        if select(2, ...) == "Successfully added/updated the element sale to the marketplace." then
            return
        end
        return oldConnFunc(...)
    end)
end

-- 5. Clean up old UI GUI (disconnects old script listeners automatically)
local existingGui = CoreGui:FindFirstChild(UI_NAME)
if existingGui then existingGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = UI_NAME
screenGui.Parent = CoreGui

-- Stacking configurations
local activeNotifications = {}
local NOTIF_WIDTH = 320
local NOTIF_HEIGHT = 52
local NOTIF_SPACING = 8
local START_Y = 24

-- State trackers for spam deduplication
local lastElementName = ""
local lastState = nil
local lastFireTime = 0
local DEBOUNCE_DELAY = 0.25

-- Resolves names asynchronously in the background
local function resolveSellerNamesAsync(userId, callback)
    if not userId or userId <= 0 then
        callback("Unknown", "Unknown")
        return
    end

    local player = Players:GetPlayerByUserId(userId)
    if player then
        callback(player.DisplayName, player.Name)
        return
    end

    task.spawn(function()
        local username = "Unknown"
        local displayName = nil

        local successUsername, resultUsername = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)
        if successUsername then
            username = resultUsername
        end

        local successDisplay, resultDisplay = pcall(function()
            return UserService:GetUserInfosByUserIdsAsync({userId})
        end)
        
        if successDisplay and resultDisplay and resultDisplay[1] then
            displayName = resultDisplay[1].DisplayName
        end

        if not displayName or displayName == "" then
            displayName = username
        end

        callback(displayName, username)
    end)
end

-- Re-calculates and smoothly transitions notifications to their stacked positions
local function repositionStack()
    for index, frame in ipairs(activeNotifications) do
        local targetY = START_Y + (index - 1) * (NOTIF_HEIGHT + NOTIF_SPACING)
        TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -NOTIF_WIDTH/2, 0, targetY)
        }):Play()
    end
end

local function dismissNotification(frame)
    local index = table.find(activeNotifications, frame)
    if index then
        table.remove(activeNotifications, index)
        repositionStack()
    end

    -- Smooth slide-out and fade-out transition
    local hideTween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -NOTIF_WIDTH/2, 0, -NOTIF_HEIGHT - 20),
        BackgroundTransparency = 1
    })
    
    local stroke = frame:FindFirstChildOfClass("UIStroke")
    if stroke then
        TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Transparency = 1}):Play()
    end
    local label = frame:FindFirstChildOfClass("TextLabel")
    if label then
        TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {TextTransparency = 1}):Play()
    end
    
    hideTween:Play()
    hideTween.Completed:Connect(function()
        frame:Destroy()
    end)
end

local function showNotification(isOnSale, elementName, color, details)
    -- Robust Boolean Verification (safeguard against game script inconsistencies)
    local isReallyOnSale = false
    if isOnSale == true then
        isReallyOnSale = true
    elseif type(details) == "table" and details.onsale == true then
        isReallyOnSale = true
    elseif type(color) == "table" and color.onsale == true then
        isReallyOnSale = true
        details = color
        color = nil
    end

    -- 1. Construct Premium Container Frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, NOTIF_WIDTH, 0, NOTIF_HEIGHT)
    frame.Position = UDim2.new(0.5, -NOTIF_WIDTH/2, 0, -NOTIF_HEIGHT - 20) -- Start hidden above screen
    frame.BackgroundColor3 = Color3.fromRGB(15, 16, 18)
    frame.BackgroundTransparency = 0.25 -- Smooth glass transparency
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    -- Add to the top of our stack
    table.insert(activeNotifications, 1, frame)
    repositionStack()

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = frame

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.fromRGB(255, 255, 255)
    uiStroke.Transparency = 0.88
    uiStroke.Thickness = 1
    uiStroke.Parent = frame

    -- 2. Status Accent Bar
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 4, 1, -16)
    accentBar.Position = UDim2.new(0, 8, 0, 8)
    accentBar.BorderSizePixel = 0
    accentBar.BackgroundColor3 = isReallyOnSale and (color or Color3.fromRGB(0, 220, 110)) or Color3.fromRGB(255, 75, 75)
    accentBar.Parent = frame
    
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 2)
    accentCorner.Parent = accentBar

    -- 3. Core Text Box
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -32, 1, -12)
    label.Position = UDim2.new(0, 20, 0.5, 0)
    label.AnchorPoint = Vector2.new(0, 0.5)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextColor3 = Color3.fromRGB(245, 245, 245)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.RichText = true
    label.TextScaled = true
    label.Parent = frame

    local sizeConstraint = Instance.new("UITextSizeConstraint")
    sizeConstraint.MinTextSize = 10
    sizeConstraint.MaxTextSize = 13
    sizeConstraint.Parent = label

    -- Populate layout instantly
    if isReallyOnSale then
        local price = (details and details.price) or 0
        local sType = (details and details.saletype) or "Item"
        
        label.Text = string.format(
            "🟢 <b>%s</b> is on sale!\n<font color=\"#D0D0D0\">Price: %s (%s) • By: Loading...</font>", 
            elementName, tostring(price), sType
        )

        resolveSellerNamesAsync(details and details.owner, function(displayName, username)
            if label and label.Parent then
                local sellerText = (displayName == username) and ("@" .. username) or string.format("%s (@%s)", displayName, username)
                label.Text = string.format(
                    "🟢 <b>%s</b> is on sale!\n<font color=\"#D0D0D0\">Price: %s (%s) • By: %s</font>", 
                    elementName, tostring(price), sType, sellerText
                )
            end
        end)
    else
        label.Text = string.format("🔴 <b>%s</b> is now off sale.", elementName)
    end

    -- 4. Interactive Dismiss button (Click to slide away)
    local clickButton = Instance.new("TextButton")
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.BackgroundTransparency = 1
    clickButton.Text = ""
    clickButton.Parent = frame

    local autoDismissThread
    clickButton.MouseButton1Click:Connect(function()
        if autoDismissThread then task.cancel(autoDismissThread) end
        dismissNotification(frame)
    end)

    -- 5. Auto dismiss timer
    autoDismissThread = task.delay(7, function()
        dismissNotification(frame)
    end)
end

-- Connection with auto-cleanup & duplicate check
local connection
connection = Event.OnClientEvent:Connect(function(isOnSale, elementName, color, details)
    if not screenGui or not screenGui.Parent then
        if connection then connection:Disconnect() end
        return
    end

    -- Find actual details table if args shifted
    local actualDetails = details
    if type(color) == "table" then
        actualDetails = color
    end

    -- IGNORE local player events completely
    if actualDetails and type(actualDetails) == "table" and actualDetails.owner == LocalPlayer.UserId then
        return
    end

    local now = os.clock()
    if elementName == lastElementName and isOnSale == lastState and (now - lastFireTime) < DEBOUNCE_DELAY then
        return
    end
    lastElementName = elementName
    lastState = isOnSale
    lastFireTime = now

    showNotification(isOnSale, elementName, color, details)
end)

-- 6. Main Loop Thread (Spawns safely so it doesn't block the GUI thread)
task.spawn(function()
    while true do
        local currentListings = getLatestListings()
        if currentListings and next(currentListings) then
            for element in pairs(currentListings) do
                print(tostring(element), typeof(element))
                pcall(function()
                    RemoteFunc:InvokeServer("mds", element, "am")
                end)
                task.wait(5)
            end
        else
            task.wait(5)
        end
    end
end)
