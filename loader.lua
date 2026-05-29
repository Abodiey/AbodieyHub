-- AbodieyHub | Configurable Universal Match Loader & Manager Suite

local showGui = ...
if showGui == nil then showGui = false end

-- 1. Secure Wait-State Layer (Ensures valid engine identifiers before execution)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

while true do
    local valid, gid, pid = pcall(function()
        return game.GameId, game.PlaceId
    end)
    if valid and gid and pid and gid ~= 0 and pid ~= 0 then
        break
    end
    task.wait(0.5)
end

local currentId = tostring(game.GameId)
local fallbackId = tostring(game.PlaceId)
local http = cloneref(game:GetService("HttpService"))

local api = "https://api.github.com/repos/Abodiey/AbodieyHub/contents/games"
local raw = "https://raw.githubusercontent.com/Abodiey/AbodieyHub/main/games/"
local configFile = "AbodieyHub_Toggles.json"

-- Helper function to format massive metrics cleanly (e.g., 10,500 -> 10.5K)
local function formatMetric(value)
    local num = tonumber(value)
    if not num then return "0" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000):gsub("%.0M", "M")
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000):gsub("%.0K", "K")
    end
    return tostring(num)
end

-- Helper functions for local file-system persistence
local function loadSavedToggles()
    local t = {
        toggles = {},     -- Controls if a script runs at all
        askBefore = {}    -- Controls if it needs approval before firing
    }
    local readSuccess, content = pcall(function()
        return readfile(configFile)
    end)
    if readSuccess and content then
        pcall(function()
            local decoded = http:JSONDecode(content)
            if decoded.toggles then t.toggles = decoded.toggles end
            if decoded.askBefore then t.askBefore = decoded.askBefore end
        end)
    end
    return t
end

local function saveToggles(t)
    pcall(function()
        writefile(configFile, http:JSONEncode(t))
    end)
end

-- Helper function to fetch comprehensive game data (Details + Votes) from Roblox APIs
local function fetchGameDetails(universeId)
    local detailsUrl = "https://games.roblox.com/v1/games?universeIds=" .. tostring(universeId)
    local votesUrl = "https://games.roblox.com/v1/games/votes?universeIds=" .. tostring(universeId)
    
    local dataMap = {
        name = "Unknown Game",
        playing = "0",
        visits = "0",
        creator = "Unknown Creator",
        likes = "0",
        dislikes = "0"
    }
    
    local s1, r1 = pcall(function() return game:HttpGet(detailsUrl) end)
    if s1 and r1 then
        local d1 = http:JSONDecode(r1)
        if d1 and d1.data and d1.data[1] then
            local info = d1.data[1]
            dataMap.name = info.name or dataMap.name
            dataMap.playing = formatMetric(info.playing)
            dataMap.visits = formatMetric(info.visits)
            dataMap.creator = info.creator and info.creator.name or dataMap.creator
        end
    end
    
    local s2, r2 = pcall(function() return game:HttpGet(votesUrl) end)
    if s2 and r2 then
        local d2 = http:JSONDecode(r2)
        if d2 and d2.data and d2.data[1] then
            dataMap.likes = formatMetric(d2.data[1].upVotes)
            dataMap.dislikes = formatMetric(d2.data[1].downVotes)
        end
    end
    
    return dataMap
end

-- Create an isolated standalone prompt panel bypassing framework UI instances entirely
local function createVerificationPrompt(fileName)
    local coreGui = cloneref(game:GetService("CoreGui"))
    local signal = Instance.new("BindableEvent")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AbodieyPrompt_" .. fileName:gsub("%D", "")
    screenGui.ResetOnSpawn = false
    screenGui.Parent = coreGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 140)
    frame.Position = UDim2.new(0.5, -160, 0.4, -70)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Execution Authorization Required:\n" .. fileName
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.TextWrapped = true
    title.Parent = frame
    
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 25)
    desc.Position = UDim2.new(0, 10, 0, 55)
    desc.BackgroundTransparency = 1
    desc.Text = "This file is flagged to ask before running. Allow?"
    desc.TextColor3 = Color3.fromRGB(160, 160, 160)
    desc.Font = Enum.Font.SourceSans
    desc.TextSize = 13
    desc.Parent = frame

    local function createButton(name, xOffset, bg, textCol)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 130, 0, 35)
        btn.Position = UDim2.new(0, xOffset, 0, 90)
        btn.BackgroundColor3 = bg
        btn.Text = name
        btn.TextColor3 = textCol
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 14
        btn.Parent = frame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        return btn
    end
    
    local yesBtn = createButton("Yes, Execute", 20, Color3.fromRGB(40, 120, 70), Color3.fromRGB(255, 255, 255))
    local noBtn = createButton("No, Cancel", 170, Color3.fromRGB(140, 40, 40), Color3.fromRGB(255, 255, 255))
    
    yesBtn.MouseButton1Click:Connect(function()
        signal:Fire(true)
        screenGui:Destroy()
    end)
    
    noBtn.MouseButton1Click:Connect(function()
        signal:Fire(false)
        screenGui:Destroy()
    end)
    
    return signal.Event:Wait()
end

-- Initialize persistent state parameters
local configDb = loadSavedToggles()

-- Fetch Repository Inventory Data
local success, response = pcall(function()
    return game:HttpGet(api)
end)

if success and response then
    local decodeSuccess, fileArray
    decodeSuccess, fileArray = pcall(function()
        local decode = http.JSONDecode
        return decode(http, response)
    end)

    if decodeSuccess and type(fileArray) == "table" then
        local parsedInventory = {}
        local currentMatchedScripts = {}

        for _, file in ipairs(fileArray) do
            local name = file.name
            local matchedId = name:match("%d+")
            
            if matchedId then
                if not parsedInventory[matchedId] then
                    parsedInventory[matchedId] = {}
                end
                table.insert(parsedInventory[matchedId], name)
            end

            if name:find(currentId) or name:find(fallbackId) then
                table.insert(currentMatchedScripts, name)
            end

            -- Ensure core mapping fields are verified cleanly
            if configDb.toggles[name] == nil then configDb.toggles[name] = true end
            if configDb.askBefore[name] == nil then configDb.askBefore[name] = false end
        end
        saveToggles(configDb)

        -- ====================================================
        -- PATH A: GUI CONFIGURATION MODE (Pure Management)
        -- ====================================================
        if showGui then
            local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
            local Window = Rayfield:CreateWindow({
                Name = "AbodieyHub Engine Panel",
                LoadingTitle = "Syncing Local Hub Configs...",
                LoadingSubtitle = "by Abodiey",
                ConfigurationSaving = { Enabled = false }
            })

            -- Tab 1: Current Session Analytics
            local CurrentTab = Window:CreateTab("Current Game", 4483362458)
            CurrentTab:CreateSection("Target Environment Context")
            
            local activeDetails = fetchGameDetails(currentId)
            CurrentTab:CreateLabel("🎮 Title: " .. activeDetails.name)
            CurrentTab:CreateLabel("🆔 Universe ID: " .. currentId .. " | Place ID: " .. fallbackId)
            CurrentTab:CreateLabel("👤 Creator: " .. activeDetails.creator)
            CurrentTab:CreateLabel("🔥 Active: " .. activeDetails.playing .. " | 👍 Likes: " .. activeDetails.likes .. " | 👎 Dislikes: " .. activeDetails.dislikes)
            
            CurrentTab:CreateSection("Associated Script Profiles")
            if #currentMatchedScripts > 0 then
                for _, fileName in ipairs(currentMatchedScripts) do
                    CurrentTab:CreateToggle({
                        Name = "Enable Script: " .. fileName,
                        CurrentValue = configDb.toggles[fileName],
                        Callback = function(Value)
                            configDb.toggles[fileName] = Value
                            saveToggles(configDb)
                        end,
                    })
                    CurrentTab:CreateToggle({
                        Name = "└─ Ask Before Running",
                        CurrentValue = configDb.askBefore[fileName],
                        Callback = function(Value)
                            configDb.askBefore[fileName] = Value
                            saveToggles(configDb)
                        end,
                    })
                end
            else
                CurrentTab:CreateLabel("No assets found matching this game environment.")
            end

            -- Tab 2: Universal Database Explorer
            local InventoryTab = Window:CreateTab("All Supported Games", 4483362458)
            
            for targetId, files in pairs(parsedInventory) do
                local details = fetchGameDetails(targetId)
                local sectionTitle = "🎮 " .. details.name .. " (" .. details.playing .. " playing) [ID: " .. targetId .. "]"
                
                InventoryTab:CreateSection(sectionTitle)
                InventoryTab:CreateLabel("👍 Likes: " .. details.likes .. " | 👎 Dislikes: " .. details.dislikes .. " | 📊 Total Visits: " .. details.visits)
                
                for _, fileName in ipairs(files) do
                    InventoryTab:CreateToggle({
                        Name = "Enable: " .. fileName,
                        CurrentValue = configDb.toggles[fileName],
                        Callback = function(Value)
                            configDb.toggles[fileName] = Value
                            saveToggles(configDb)
                        end,
                    })
                    InventoryTab:CreateToggle({
                        Name = "   └─ Ask Before Running",
                        CurrentValue = configDb.askBefore[fileName],
                        Callback = function(Value)
                            configDb.askBefore[fileName] = Value
                            saveToggles(configDb)
                        end,
                    })
                end
            end

            -- Tab 3: Close Control Interface Panel
            local ActionTab = Window:CreateTab("Exit Panel", 4483362458)
            ActionTab:CreateSection("Unload Framework Interface")
            ActionTab:CreateButton({
                Name = "Completely Close & Destroy GUI",
                Callback = function()
                    Rayfield:Destroy()
                end,
            })

        -- ====================================================
        -- PATH B: SILENT EXECUTION MODE (Executes Target Modules)
        -- ====================================================
        else
            for _, fileName in ipairs(currentMatchedScripts) do
                if configDb.toggles[fileName] == true then
                    -- Verify if user triggered "Ask Before Running" requirement flag
                    local allowExecution = true
                    if configDb.askBefore[fileName] == true then
                        allowExecution = createVerificationPrompt(fileName)
                    end

                    if allowExecution then
                        local contentSuccess, content = pcall(function()
                            return game:HttpGet(raw .. fileName)
                        end)

                        if contentSuccess and content then
                            local execute, compileError = loadstring(content, "=" .. fileName)
                            if execute then
                                task.spawn(function()
                                    local runSuccess, runtimeError = pcall(execute)
                                    if not runSuccess then
                                        warn("[AbodieyHub Runtime Error] File: " .. fileName .. "\n" .. tostring(runtimeError))
                                    end
                                end)
                            else
                                warn("[AbodieyHub Syntax Error] File: " .. fileName .. "\n" .. tostring(compileError))
                            end
                        end
                    end
                end
            end
        end

    end
end
