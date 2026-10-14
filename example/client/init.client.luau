--!strict
-- Press P to play the demo reel (example/reels/Showcase.reel.luau); press P again to stop it.
-- Every cut prints a marker line ([Reel] start / cut / end ...) to the output.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reel = require(ReplicatedStorage:WaitForChild("Reel"))

ReplicatedStorage:WaitForChild("Reels")
local loaded, failed = Reel.collectAll()
print(`[ReelExample] {loaded} reel module(s) loaded, {failed} failed. Press P to play.`)

ContextActionService:BindAction("PlayReel", function(_, state)
    if state ~= Enum.UserInputState.Begin then
        return Enum.ContextActionResult.Pass
    end
    if Reel.status() then
        Reel.stop()
    else
        Reel.play("demo/showcase")
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.P)
