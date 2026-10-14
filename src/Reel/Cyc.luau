--!strict
-- Cyc: a cyclorama for a feature showcase, the photo studio's set: a round plate, lit and shadowed,
-- in a void of one flat colour with no horizon, so what stands on the plate is all the picture
-- shows. Built where a game says, on the server when players or models stand on it (the plate is
-- solid; the void is a closed box: a floor, four walls and a ceiling, so a camera tilted up sees
-- the void, not the sky).
--
-- The void is Neon: opaque, and drawn unlit, so it has no shading and no seams. (It was SurfaceGuis
-- with LightInfluence 0 at first, but a SurfaceGui is sorted with the transparent things, and the
-- floor's, one huge sheet, was drawn over particles in front of it: an effect seen low against
-- the floor lost its particles to a dark band.) Neon maps its colour steeply: 20 to 44 grey came out
-- black and 60, 66, 84 a bright blue; the default `Cyc.Void` (52, 54, 58) renders like Panel's
-- default background (18, 20, 26). A panel drawn without a background (`seeThrough`) shows the
-- void itself, one colour exactly. Closed, the box keeps the sun out, and the set is lit by its own
-- lights instead, the same at any time of day: four soft lights spread round the plate, as in a
-- studio, each on an attachment, with no lamp to see. The atmosphere's haze greys a far wall into a
-- horizon; a take turns it off with `haze = false`.
--
-- The plate is a regular polygon of `sides` sides (64 by default; Roblox's cylinder showed its
-- facets from 90 studs), laid as `sides / 2` boxes across it, each spanning two opposite sides:
-- together they cover it exactly, with flat tops at one height. They are only seen: a vehicle stood on
-- the middle, where every box overlaps, slid off it a stud or more (its shape casts caught the
-- boxes' edges there), so what is stood on is one invisible cylinder, the `Solid`, of the plate's
-- colour (so anything that reads the colour of what it hits reads the plate's).
local Cyc = {}

Cyc.Name = "Reel_Cyc"

Cyc.Void = Color3.fromRGB(52, 54, 58)
Cyc.Plate = Color3.fromRGB(196, 198, 204)

export type Options = {
    -- The void's colour.
    void: Color3?,
    -- The plate's colour, radius (studs), thickness, and number of sides (even).
    plate: Color3?,
    radius: number?,
    thickness: number?,
    sides: number?,
    -- The void's half-width and height, studs: far enough that a camera framing the plate stays
    -- inside it.
    size: number?,
    height: number?,
    -- How bright the set's lights are, all together (1: as tuned).
    brightness: number?,
}

export type Cyc = {
    model: Model,
    -- The plate's top, at its middle: where things stand.
    top: CFrame,
    radius: number,
    destroy: () -> (),
}

local function block(model: Model, name: string, size: Vector3, frame: CFrame, color: Color3): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = size
    part.CFrame = frame
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = model
    return part
end

-- Build the set with the plate's top middle at `at` (its up is the set's up), under `parent`.
function Cyc.build(parent: Instance, at: CFrame, options: Options?): Cyc
    local given: Options = options or {}
    local void = given.void or Cyc.Void
    local radius = given.radius or 22
    local thickness = given.thickness or 1
    local sides = given.sides or 64
    assert(sides >= 4 and sides % 2 == 0, "a plate's sides must be even, at least 4")
    local size = given.size or 130
    local height = given.height or 90

    local model = Instance.new("Model")
    model.Name = Cyc.Name

    local floor = at * CFrame.new(0, -thickness, 0)
    type Wall = { name: string, size: Vector3, frame: CFrame }
    local walls: { Wall } = {
        {
            name = "Floor",
            size = Vector3.new(2 * size, 1, 2 * size),
            frame = floor * CFrame.new(0, -0.5, 0),
        },
        {
            name = "Back",
            size = Vector3.new(2 * size, height, 1),
            frame = floor * CFrame.new(0, height / 2, -size),
        },
        {
            name = "Front",
            size = Vector3.new(2 * size, height, 1),
            frame = floor * CFrame.new(0, height / 2, size),
        },
        {
            name = "Right",
            size = Vector3.new(1, height, 2 * size),
            frame = floor * CFrame.new(size, height / 2, 0),
        },
        {
            name = "Left",
            size = Vector3.new(1, height, 2 * size),
            frame = floor * CFrame.new(-size, height / 2, 0),
        },
        {
            name = "Ceiling",
            size = Vector3.new(2 * size, 1, 2 * size),
            frame = floor * CFrame.new(0, height + 0.5, 0),
        },
    }
    local parts: { [string]: Part } = {}
    for _, wall in walls do
        local part = block(model, wall.name, wall.size, wall.frame, void)
        part.Material = Enum.Material.Neon
        parts[wall.name] = part
    end

    -- The lights hang on attachments to the floor, placed in the world, all aimed at the plate's
    -- middle: a studio's soft, spread lighting, not one hard key. Four gentle
    -- lights from round the plate, only the one overhead casting shadows (soft ones, straight
    -- down, that sit things on the plate).
    local brightness = given.brightness or 1
    type Lamp = {
        name: string,
        offset: Vector3,
        kind: "point" | "spot",
        power: number,
        shadows: boolean,
    }
    local lamps: { Lamp } = {
        {
            name = "Top",
            offset = Vector3.new(0, 34, 4),
            kind = "point",
            power = 0.5,
            shadows = true,
        },
        {
            name = "Key",
            offset = Vector3.new(-22, 24, 24),
            kind = "spot",
            power = 0.45,
            shadows = false,
        },
        {
            name = "Fill",
            offset = Vector3.new(24, 18, 20),
            kind = "spot",
            power = 0.25,
            shadows = false,
        },
        {
            name = "Back",
            offset = Vector3.new(4, 22, -28),
            kind = "spot",
            power = 0.3,
            shadows = false,
        },
    }
    for _, lamp in lamps do
        local attachment = Instance.new("Attachment")
        attachment.Name = lamp.name
        attachment.Parent = parts.Floor
        local from = at * lamp.offset
        attachment.WorldCFrame = CFrame.lookAt(from, at.Position)
        local source: Light
        if lamp.kind == "spot" then
            local spot = Instance.new("SpotLight")
            spot.Face = Enum.NormalId.Front
            spot.Angle = 100
            spot.Range = 60
            source = spot
        else
            local point = Instance.new("PointLight")
            point.Range = 60
            source = point
        end
        source.Brightness = lamp.power * brightness
        source.Shadows = lamp.shadows
        source.Parent = attachment
    end

    local plate = Instance.new("Model")
    plate.Name = "Plate"
    local across = 2 * radius * math.cos(math.pi / sides)
    local side = 2 * radius * math.sin(math.pi / sides)
    local middle = at * CFrame.new(0, -thickness / 2, 0)
    local color = given.plate or Cyc.Plate
    for i = 0, sides / 2 - 1 do
        local slat = block(
            plate,
            `Slat{i + 1}`,
            Vector3.new(side, thickness, across),
            middle * CFrame.Angles(0, (i + 0.5) * 2 * math.pi / sides, 0),
            color
        )
        slat.CanCollide = false
        slat.CanTouch = false
    end
    local solid = block(
        plate,
        "Solid",
        Vector3.new(thickness, 2 * radius, 2 * radius),
        middle * CFrame.Angles(0, 0, math.pi / 2),
        color
    )
    solid.Shape = Enum.PartType.Cylinder
    solid.Transparency = 1
    solid.CastShadow = false
    plate.Parent = model

    model.Parent = parent
    return {
        model = model,
        top = at,
        radius = radius,
        destroy = function()
            model:Destroy()
        end,
    }
end

return Cyc
