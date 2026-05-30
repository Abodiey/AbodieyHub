getgenv().AutoSell = not getgenv().AutoSell
getgenv().AutoHoneycomb = not getgenv().AutoHoneycomb
local Player = cloneref(game:GetService("Players")).Player
local character = Player.Character or Player.CharacterAdded:Wait()
local root = character:FindFirstChild("HumanoidRootPart")
local Honeycombs = workspace.InteractiveEvents.QueenBee.RuntimeHoneycombs
local Event = game:GetService("ReplicatedStorage").Remotes.SellCrates

Player.CharacterAdded:Connect(function(char)
    character = char
    root = char:WaitForChild("HumanoidRootPart")
end)

while getgenv().AutoSell do
	Event:FireServer()
	task.wait(1)
end

-- Main farm loop
while getgenv().AutoHoneycomb do
    if #Honeycombs:GetChildren() == 0 then
        Honeycombs.ChildAdded:Wait()
        task.wait(0.1)
    end

    if not root then 
        task.wait(0.5)
        continue 
    end

    -- Fast-scan descendants for actionable prompts
    for _, v in pairs(Honeycombs:GetDescendants()) do
        if not getgenv().AutoHoneycomb then break end
        if not root then break end -- Extra safety break mid-scan
        if not v:IsA("ProximityPrompt") then continue end
        
        local parent = v.Parent
        if parent and parent:IsA("BasePart") then
            root.CFrame = CFrame.new(parent.Position) * root.CFrame.Rotation
            task.wait(0.2)
            fireproximityprompt(v)
            task.wait(0.1)
        end
    end
    
    task.wait()
end
