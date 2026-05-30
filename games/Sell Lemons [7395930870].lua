local Player = game.Players.LocalPlayer
local tycoon
for i,v in pairs(workspace:GetChildren()) do
    if not v:FindFirstChild("Owner") then continue end
    if v.Owner.Value ~= Player then continue end
    tycoon = v
end

_G.AutoClick = not _G.AutoClick
local Click = tycoon.Remotes.WakeIncomeStream
task.spawn(function()
    while _G.AutoClick and not tycoon.Purchases["Lemon Stand"].Other:FindFirstChild("Cash Register") do
        Click:InvokeServer("LemonStand")
        task.wait(.9)
    end
end)

_G.AutoUpgrade = not _G.AutoUpgrade
local Upgrade = tycoon.Purchases["Lemon Stand"]["Lemon Stand"]["Lemon Stand"].Upgrade
task.spawn(function()
    while _G.AutoUpgrade do
        Upgrade:InvokeServer(1)
        task.wait()
    end
end)
