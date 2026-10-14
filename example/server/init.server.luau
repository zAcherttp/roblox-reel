--!strict
-- The example's set: a Cyc (a studio plate in a flat void) high above the baseplate, and a
-- "Showcase" model on it that turns slowly, for the demo reel to film.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reel = require(ReplicatedStorage:WaitForChild("Reel"))

local cyc = Reel.Cyc.build(workspace, CFrame.new(0, 400, 0))

local showcase = Instance.new("Model")
showcase.Name = "Showcase"

local base = Instance.new("Part")
base.Name = "Base"
base.Anchored = true
base.Size = Vector3.new(6, 1, 6)
base.Color = Color3.fromRGB(40, 44, 52)
base.Material = Enum.Material.SmoothPlastic
base.Parent = showcase

local gem = Instance.new("Part")
gem.Name = "Gem"
gem.Anchored = true
gem.Shape = Enum.PartType.Ball
gem.Size = Vector3.new(4, 4, 4)
gem.Color = Color3.fromRGB(255, 140, 64)
gem.Material = Enum.Material.Neon
gem.Parent = showcase

showcase.PrimaryPart = base
showcase.Parent = workspace

local spin = 0
RunService.Heartbeat:Connect(function(delta: number)
    spin += delta * 0.6
    local at = cyc.top * CFrame.Angles(0, spin, 0)
    base.CFrame = at * CFrame.new(0, 0.5, 0)
    gem.CFrame = at * CFrame.new(0, 3.5 + math.sin(spin * 2) * 0.5, 0)
end)
