local Player = game.Players.LocalPlayer
local tycoon
for i,v in pairs(workspace:GetChildren()) do
    if not v:FindFirstChild("Owner") then continue end
    if v.Owner.Value ~= Player then continue end
    tycoon = v
end

_G.AutoClick = not _G.AutoClick
local Click = tycoon.Remotes.WakeIncomeStream
while _G.AutoClick do
    Click:InvokeServer("LemonStand")
    task.wait(.9)
end
