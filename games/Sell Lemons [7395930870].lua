-- Set the script ID globally to stop previous execution instances
getgenv().ScriptID = os.clock()
local CurrentScriptID = getgenv().ScriptID

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create the main window
local Window = Rayfield:CreateWindow({
   Name = "Tycoon Autofarm",
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

-- Find the player's tycoon
local Player = game.Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")
local tycoon = nil

for i, v in pairs(workspace:GetChildren()) do
    if getgenv().ScriptID ~= CurrentScriptID then return end
    if not v:FindFirstChild("Owner") then continue end
    if v.Owner.Value ~= Player then continue end
    tycoon = v
    break
end

-- Fallback in case tycoon isn't loaded yet
if not tycoon and getgenv().ScriptID == CurrentScriptID then
    Rayfield:Notify({
        Title = "Error",
        Content = "Could not find your Tycoon! Please make sure you own one.",
        Duration = 5,
        Image = 4483362458,
    })
    return
end

-- Create a Single Tab for everything
local MainTab = Window:CreateTab("Main Features", 4483362458)

-- State Variables for the toggles
local autoClickStand = false
local autoUpgradeStand = false
local autoClickDash = false
local autoUpgradeDash = false
local antiAfkEnabled = false

-- Anti AFK Setup (VirtualUser prevents IDLE kick)
Player.Idled:Connect(function()
    if antiAfkEnabled and getgenv().ScriptID == CurrentScriptID then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

---
-- LEMON STAND SECTION
---
MainTab:CreateSection("Lemon Stand")

MainTab:CreateToggle({
   Name = "Auto Click Lemon Stand",
   CurrentValue = false,
   Callback = function(Value)
      autoClickStand = Value
      if autoClickStand then
         task.spawn(function()
            local ClickLemonStand = tycoon.Remotes.WakeIncomeStream
            while autoClickStand and getgenv().ScriptID == CurrentScriptID do
               -- Only invoke if the NPC is missing from the Cash Register
               if not tycoon.Purchases["Lemon Stand"].Other["Cash Register"]:FindFirstChild("NPC") then
                  ClickLemonStand:InvokeServer("LemonStand")
               end
               task.wait(0.9)
            end
         end)
      end
   end,
})

MainTab:CreateToggle({
   Name = "Auto Upgrade Lemon Stand",
   CurrentValue = false,
   Callback = function(Value)
      autoUpgradeStand = Value
      if autoUpgradeStand then
         task.spawn(function()
            local UpgradeLemonStand = tycoon.Purchases["Lemon Stand"]["Lemon Stand"]["Lemon Stand"].Upgrade
            while autoUpgradeStand and getgenv().ScriptID == CurrentScriptID do
               UpgradeLemonStand:InvokeServer(1)
               task.wait()
            end
         end)
      end
   end,
})

---
-- LEMON DASH SECTION
---
MainTab:CreateSection("Lemon Dash")

MainTab:CreateToggle({
   Name = "Auto Click Lemon Dash",
   CurrentValue = false,
   Callback = function(Value)
      autoClickDash = Value
      if autoClickDash then
         task.spawn(function()
            local ClickLemonDash = tycoon.Remotes.WakeIncomeStream
            while autoClickDash and getgenv().ScriptID == CurrentScriptID do
               -- Only invoke if the NPC is missing from the Dash Manager
               if not tycoon.Purchases.LemonDash.Other["Dash Manager"]:FindFirstChild("NPC") then
                  ClickLemonDash:InvokeServer("LemonDash")
               end
               task.wait(15 - 0.1)
            end
         end)
      end
   end,
})

MainTab:CreateToggle({
   Name = "Auto Upgrade Lemon Dash",
   CurrentValue = false,
   Callback = function(Value)
      autoUpgradeDash = Value
      if autoUpgradeDash then
         task.spawn(function()
            local UpgradeLemonDash = tycoon.Purchases.LemonDash.LemonDash.LemonDash.Upgrade
            while autoUpgradeDash and getgenv().ScriptID == CurrentScriptID do
               UpgradeLemonDash:InvokeServer(1)
               task.wait()
            end
         end)
      end
   end,
})

---
-- UTILITIES SECTION
---
MainTab:CreateSection("Utilities")

MainTab:CreateToggle({
   Name = "Anti-AFK",
   CurrentValue = false,
   Callback = function(Value)
      antiAfkEnabled = Value
   end,
})

-- Initialize Rayfield
Rayfield:LoadConfiguration()
