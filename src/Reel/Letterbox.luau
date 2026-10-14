--!strict
-- Letterbox: black bars above and below the picture, cropping it to a wider aspect (2.39 is
-- cinema scope), for a take that wants to look like film. A ScreenGui of two bars, drawn over
-- everything and past the topbar inset.
local Letterbox = {}

Letterbox.Name = "Reel_Letterbox"

export type Letterbox = { gui: ScreenGui, top: Frame, bottom: Frame }

-- The share of the screen's height each bar covers to crop a `size` viewport to `aspect` (width
-- over height): none when the screen is already that wide or wider.
function Letterbox.share(size: Vector2, aspect: number): number
    if size.Y <= 0 or aspect <= 0 then
        return 0
    end
    return math.max(0, (1 - size.X / aspect / size.Y) / 2)
end

local function bar(gui: ScreenGui, name: string, anchor: number): Frame
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BorderSizePixel = 0
    frame.AnchorPoint = Vector2.new(0, anchor)
    frame.Position = UDim2.fromScale(0, anchor)
    frame.Size = UDim2.fromScale(1, 0)
    frame.Parent = gui
    return frame
end

function Letterbox.mount(parent: Instance): Letterbox
    local gui = Instance.new("ScreenGui")
    gui.Name = Letterbox.Name
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    gui.ResetOnSpawn = false
    local box = { gui = gui, top = bar(gui, "Top", 0), bottom = bar(gui, "Bottom", 1) }
    gui.Parent = parent
    return box
end

-- Each bar `share` of the screen's height.
function Letterbox.set(box: Letterbox, share: number)
    box.top.Size = UDim2.fromScale(1, share)
    box.bottom.Size = UDim2.fromScale(1, share)
end

return Letterbox
