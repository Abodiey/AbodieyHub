_G.AutoRedeem = not _G.AutoRedeem
local Redeem = game:GetService("ReplicatedStorage").Packages.Net["RE/SafeZoneEvent"]
while _G.AutoRedeem do
    Redeem:FireServer()
    task.wait()
en
