local Player = game.Players.LocalPlayer
local tycoon
for i,v in pairs(workspace:GetChildren()) do
    if not v:FindFirstChild("Owner") then continue end
    if v.Owner.Value ~= Player then continue end
    tycoon = v
end

_G.AutoClickLemonStand = not _G.AutoClickLemonStand
local ClickLemonStand = tycoon.Remotes.WakeIncomeStream
task.spawn(function()
    while _G.AutoClickLemonStand and not tycoon.Purchases["Lemon Stand"].Other:FindFirstChild("Cash Register") do
        ClickLemonStand:InvokeServer("LemonStand")
        task.wait(.9)
    end
end)

_G.AutoUpgradeLemonStand = not _G.AutoUpgradeLemonStand
local UpgradeLemonStand = tycoon.Purchases["Lemon Stand"]["Lemon Stand"]["Lemon Stand"].Upgrade
task.spawn(function()
    while _G.AutoUpgradeLemonStand do
        UpgradeLemonStand:InvokeServer(1)
        task.wait()
    end
end)

_G.AutoClickLemonDash = not _G.AutoClickLemonDash
local ClickLemonDash = tycoon.Remotes.WakeIncomeStream
task.spawn(function()
    while _G.AutoClickLemonDash do
        ClickLemonDash:InvokeServer("LemonDash")
        task.wait(15 - .1)
    end
end)

_G.AutoUpgradeLemonDash = not _G.AutoUpgradeLemonDash
local UpgradeLemonDash = tycoon.Purchases.LemonDash.LemonDash.LemonDash.Upgrade
task.spawn(function()
    while _G.AutoUpgradeLemonDash do
        UpgradeLemonDash:InvokeServer(1)
        task.wait()
    end
end)
