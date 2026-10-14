--!strict
-- A demo reel: a title card, then three shots of the "Showcase" model on the Cyc, with a text
-- panel on the left that the beats fill, and an outro card.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reel = require(ReplicatedStorage:WaitForChild("Reel"))
local Shot, Curve = Reel.Shot, Reel.Curve

local panel: Reel.PanelOptions = { side = "left", share = 0.4 }

return function(register: (Reel.Spec) -> ())
    register({
        name = "demo/showcase",
        note = "a slow showcase of the Showcase model",
        panel = panel,
        haze = false,
        shots = function()
            local subject = Shot.find("Showcase")
            return {
                -- Framed beside the panel, looking down at it.
                Shot.frame({ subject = subject, size = 5, duration = 3, panel = panel }),
                -- Circling it while zooming in a little, kept beside the panel.
                Shot.offset(
                    Shot.orbit({
                        target = subject,
                        radius = 16,
                        height = 5,
                        from = -40,
                        to = 60,
                        aim = Vector3.new(0, 3, 0),
                        duration = 4,
                        fov = Curve.linear(55, 45),
                    }),
                    { x = 0.4 }
                ),
                -- A tripod off to the side that pans to keep it in view, with a little shake.
                Shot.offset(
                    Shot.shake(
                        Shot.track({
                            from = Vector3.new(26, 408, 20),
                            target = subject,
                            aim = Vector3.new(0, 3, 0),
                            duration = 3,
                            fov = 45,
                        }),
                        { amplitude = 0.6, seed = 7 }
                    ),
                    { x = 0.4 }
                ),
            }
        end,
        at = {
            {
                time = 0,
                run = function(take: Reel.Context)
                    take.panel.card({ title = "Reel", lines = { "a scripted camera take" } })
                end,
            },
            {
                time = 1.2,
                run = function(take: Reel.Context)
                    take.panel.show({
                        tag = "NEW",
                        title = "The showcase",
                        lines = { "Shots are pure functions of time", "Beats fire on cue" },
                        seeing = "a framed shot beside the panel",
                        counter = "1 / 3",
                    })
                end,
            },
            {
                time = 3,
                run = function(take: Reel.Context)
                    take.panel.show({
                        title = "Orbit",
                        lines = { "Circles the target, zooming in" },
                        seeing = "Shot.orbit, offset beside the panel",
                        counter = "2 / 3",
                    })
                end,
            },
            {
                time = 7,
                run = function(take: Reel.Context)
                    take.panel.show({
                        title = "Track",
                        lines = { "A tripod that pans to keep it in view" },
                        seeing = "Shot.track with a light shake",
                        counter = "3 / 3",
                    })
                end,
            },
            {
                time = 9.2,
                run = function(take: Reel.Context)
                    take.panel.card({ title = "Thanks for watching" })
                end,
            },
        },
    })
end
