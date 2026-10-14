--!strict
local Workspace = game:GetService("Workspace")

local Curve = require(script.Parent.Curve)

export type Target = () -> CFrame?
export type Fov = number | Curve.Curve

-- What a shot asks of the lens besides where it looks: the distance kept in focus (studs from
-- the camera; nil: everything sharp) and how far either side of it stays sharp, and a full-screen
-- blur (a whip pan's smear; 0 or nil: none). A take turns these into its camera's effects.
export type Look = {
    focus: number?,
    focusRadius: number?,
    blur: number?,
}

export type Shot = {
    duration: number,
    pose: (t: number) -> (CFrame?, number, Look?),
    -- Seconds at its start over which a take carries the last shot's motion on and eases into
    -- this one (a cut on motion); nil or 0: a hard cut. Set with `Shot.blendIn`.
    blendIn: number?,
    -- A live shot (`Shot.live`): the game's own camera, turned so its middle sits at `x` across the
    -- screen (-1 to 1). Its pose is not used.
    live: { x: number, aspect: number? }?,
}

-- A point to look at or focus on: fixed, or read each frame from a target.
export type Point = Vector3 | Target

export type StillOptions = { at: CFrame, duration: number, fov: Fov? }
export type DollyOptions = {
    from: CFrame,
    to: CFrame,
    duration: number,
    fov: Fov?,
    ease: Curve.Curve?,
}
export type OrbitOptions = {
    target: Target,
    radius: number,
    duration: number,
    height: number?,
    from: number?,
    to: number?,
    aim: Vector3?,
    fov: Fov?,
    ease: Curve.Curve?,
}
export type FollowOptions = {
    target: Target,
    offset: Vector3,
    duration: number,
    aim: Vector3?,
    fov: Fov?,
}
export type TrackOptions = {
    from: Vector3,
    target: Target,
    duration: number,
    aim: Vector3?,
    fov: Fov?,
}
export type SplineOptions = {
    points: { Vector3 },
    duration: number,
    target: Target?,
    aim: Vector3?,
    look: { Vector3 }?,
    fov: Fov?,
    ease: Curve.Curve?,
}
export type WhipOptions = {
    at: Vector3,
    from: Point,
    to: Point,
    duration: number,
    blur: number?,
    fov: Fov?,
}
export type FocusOptions = {
    from: number | Point,
    to: (number | Point)?,
    radius: number?,
    start: number?,
    finish: number?,
    ease: Curve.Curve?,
}
export type OffsetOptions = {
    x: number,
    y: number?,
    aspect: number?,
}
export type FrameOptions = {
    subject: Point,
    size: number,
    duration: number,
    from: Vector3?,
    elevation: number?,
    fill: number?,
    fov: number?,
    panel: { side: ("left" | "right")?, share: number? }?,
    aspect: number?,
}
export type LiveOptions = {
    duration: number,
    panel: { side: ("left" | "right")?, share: number? }?,
    aspect: number?,
}
export type ShakeOptions = {
    amplitude: number,
    frequency: number?,
    seed: number?,
    envelope: Curve.Curve?,
}

local Shot = {}

Shot.DefaultFov = 70

local smooth = Curve.rise(0, 1)

local function fraction(t: number, duration: number): number
    return if duration > 0 then math.clamp(t / duration, 0, 1) else 1
end

local function fovAt(fov: Fov?, k: number): number
    if fov == nil then
        return Shot.DefaultFov
    end
    if typeof(fov) == "number" then
        return fov
    end
    return (fov :: Curve.Curve)(k)
end

local function flatBasis(frame: CFrame): CFrame
    local look = frame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 1e-4 then
        flat = Vector3.new(0, 0, -1)
    end
    return CFrame.lookAt(frame.Position, frame.Position + flat)
end

function Shot.still(options: StillOptions): Shot
    return {
        duration = options.duration,
        pose = function(t)
            return options.at, fovAt(options.fov, fraction(t, options.duration)), nil
        end,
    }
end

function Shot.dolly(options: DollyOptions): Shot
    local ease = options.ease or smooth
    return {
        duration = options.duration,
        pose = function(t)
            local k = fraction(t, options.duration)
            return options.from:Lerp(options.to, ease(k)), fovAt(options.fov, k), nil
        end,
    }
end

function Shot.orbit(options: OrbitOptions): Shot
    local ease = options.ease or smooth
    local from = options.from or 0
    local to = options.to or 90
    local height = options.height or 0
    local aim = options.aim or Vector3.zero
    return {
        duration = options.duration,
        pose = function(t)
            local k = fraction(t, options.duration)
            local fov = fovAt(options.fov, k)
            local center = options.target()
            if not center then
                return nil, fov, nil
            end
            local basis = flatBasis(center)
            local angle = math.rad(from + (to - from) * ease(k))
            local offset = Vector3.new(
                math.sin(angle) * options.radius,
                height,
                -math.cos(angle) * options.radius
            )
            return CFrame.lookAt(basis * offset, basis * aim), fov, nil
        end,
    }
end

function Shot.follow(options: FollowOptions): Shot
    local aim = options.aim or Vector3.zero
    return {
        duration = options.duration,
        pose = function(t)
            local fov = fovAt(options.fov, fraction(t, options.duration))
            local center = options.target()
            if not center then
                return nil, fov, nil
            end
            local basis = flatBasis(center)
            return CFrame.lookAt(basis * options.offset, basis * aim), fov, nil
        end,
    }
end

function Shot.track(options: TrackOptions): Shot
    local aim = options.aim or Vector3.zero
    return {
        duration = options.duration,
        pose = function(t)
            local fov = fovAt(options.fov, fraction(t, options.duration))
            local center = options.target()
            if not center then
                return nil, fov, nil
            end
            return CFrame.lookAt(options.from, flatBasis(center) * aim), fov, nil
        end,
    }
end

function Shot.shake(shot: Shot, options: ShakeOptions): Shot
    local frequency = options.frequency or 12
    local seed = options.seed or 0
    local envelope = options.envelope
    return {
        duration = shot.duration,
        pose = function(t)
            local frame, fov, look = shot.pose(t)
            if not frame then
                return nil, fov, look
            end
            local strength = math.rad(options.amplitude)
            if envelope then
                strength *= envelope(fraction(t, shot.duration))
            end
            local x = t * frequency
            return frame * CFrame.Angles(
                math.noise(x, seed + 0.31, 0.17) * strength,
                math.noise(x, seed + 0.53, 0.71) * strength,
                math.noise(x, seed + 0.89, 0.37) * strength * 0.5
            ),
                fov,
                look
        end,
    }
end

-- Where a point is now (nil: its target is gone).
local function pointAt(point: Point): Vector3?
    if typeof(point) == "Vector3" then
        return point
    end
    local frame = (point :: Target)()
    return if frame then frame.Position else nil
end

-- A centripetal Catmull-Rom curve through `points` (knots spaced by the square root of the distance
-- between points, so it neither loops nor overshoots where the points are unevenly spaced: the
-- plain curve doubled back past a near point on its way to a far one), walked at an even speed:
-- each segment is sampled into a table of how far along it the path has come, so progress `k` (0
-- to 1) is a share of the whole length, not of the segments.
type Path = { at: (k: number) -> Vector3, points: { Vector3 } }

local SAMPLES = 24

local function knot(a: Vector3, b: Vector3): number
    return math.max((b - a).Magnitude ^ 0.5, 1e-4)
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: number): Vector3
    local t1 = knot(p0, p1)
    local t2 = t1 + knot(p1, p2)
    local t3 = t2 + knot(p2, p3)
    local t = t1 + (t2 - t1) * u
    local a1 = p0 * ((t1 - t) / t1) + p1 * (t / t1)
    local a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
    local a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
    local b1 = a1 * ((t2 - t) / t2) + a2 * (t / t2)
    local b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
    return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1))
end

local function path(points: { Vector3 }): Path
    assert(#points >= 2, "a spline needs at least two points")
    local count = #points
    -- Past either end, a point mirrored through the end one, so the path leaves and arrives
    -- heading along its first and last segments.
    local function segmentAt(i: number, u: number): Vector3
        local p1, p2 = points[i], points[i + 1]
        local p0 = if i > 1 then points[i - 1] else 2 * p1 - p2
        local p3 = if i + 2 <= count then points[i + 2] else 2 * p2 - p1
        return catmull(p0, p1, p2, p3, u)
    end
    -- lengths[n]: how far the path has come at sample n (n = 0 is its start).
    local lengths: { number } = { [0] = 0 }
    local last = points[1]
    local total = 0
    for i = 1, count - 1 do
        for j = 1, SAMPLES do
            local here = segmentAt(i, j / SAMPLES)
            total += (here - last).Magnitude
            last = here
            lengths[(i - 1) * SAMPLES + j] = total
        end
    end
    local samples = (count - 1) * SAMPLES
    return {
        points = points,
        at = function(k: number): Vector3
            local want = math.clamp(k, 0, 1) * total
            local low, high = 0, samples
            while high - low > 1 do
                local mid = (low + high) // 2
                if lengths[mid] < want then
                    low = mid
                else
                    high = mid
                end
            end
            local span = lengths[high] - lengths[low]
            local within = if span > 0 then (want - lengths[low]) / span else 0
            local sample = low + within
            local i = math.clamp(math.floor(sample / SAMPLES) + 1, 1, count - 1)
            return segmentAt(i, sample / SAMPLES - (i - 1))
        end,
    }
end

-- A camera gliding through `points` at an even speed, easing in and out. It looks at `target`
-- (plus `aim` in its flattened frame) if given, else along its own `look` points (a second
-- spline, walked in step), else ahead along the path.
function Shot.spline(options: SplineOptions): Shot
    local ease = options.ease or smooth
    local route = path(options.points)
    local sights = if options.look then path(options.look) else nil
    local aim = options.aim or Vector3.zero
    return {
        duration = options.duration,
        pose = function(t)
            local k = fraction(t, options.duration)
            local fov = fovAt(options.fov, k)
            local e = ease(k)
            local here = route.at(e)
            local sight: Vector3
            if options.target then
                local center = options.target()
                if not center then
                    return nil, fov, nil
                end
                sight = flatBasis(center) * aim
            elseif sights then
                sight = sights.at(e)
            else
                local ahead = route.at(math.min(e + 0.02, 1))
                local behind = route.at(math.max(e - 0.02, 0))
                sight = here + (ahead - behind)
            end
            if (sight - here).Magnitude < 1e-4 then
                sight = here + Vector3.new(0, 0, -1)
            end
            return CFrame.lookAt(here, sight), fov, nil
        end,
    }
end

-- The whip's ease: slow off the first subject, a smear across, settling on the second.
local function whipEase(k: number): number
    return if k < 0.5 then 16 * k ^ 5 else 1 - (-2 * k + 2) ^ 5 / 2
end

-- A whip pan: the camera stays at `at` and swings from looking at `from` to looking at `to`, fast
-- in the middle, the frame smeared by a blur that peaks mid-swing (`blur`, default 14: Roblox has
-- no motion blur, so a full-screen blur stands in for it).
function Shot.whip(options: WhipOptions): Shot
    local most = options.blur or 14
    return {
        duration = options.duration,
        pose = function(t)
            local k = fraction(t, options.duration)
            local fov = fovAt(options.fov, k)
            local a, b = pointAt(options.from), pointAt(options.to)
            if not (a and b) then
                return nil, fov, nil
            end
            local start = CFrame.lookAt(options.at, a)
            local finish = CFrame.lookAt(options.at, b)
            return start:Lerp(finish, whipEase(k)), fov, { blur = most * math.sin(math.pi * k) ^ 2 }
        end,
    }
end

-- A rack focus on any shot: the distance in focus goes from `from` to `to` (a distance in studs
-- from the camera, or a point, measured each frame), between `start` and `finish` (shares of the
-- shot, default the whole of it), eased; `radius` studs either side stay sharp (default 4).
-- Without `to` it holds focus on `from` (a subject kept sharp, the rest soft).
function Shot.focus(shot: Shot, options: FocusOptions): Shot
    local ease = options.ease or smooth
    local first, last = options.start or 0, options.finish or 1
    local radius = options.radius or 4
    local function distance(frame: CFrame, point: number | Point): number?
        if typeof(point) == "number" then
            return point
        end
        local where = pointAt(point :: Point)
        return if where then (where - frame.Position).Magnitude else nil
    end
    return {
        duration = shot.duration,
        pose = function(t)
            local frame, fov, look = shot.pose(t)
            if not frame then
                return nil, fov, look
            end
            local near = distance(frame, options.from)
            local far = if options.to ~= nil
                then distance(frame, options.to :: number | Point)
                else near
            if not (near and far) then
                return frame, fov, look
            end
            local k = fraction(t - first * shot.duration, (last - first) * shot.duration)
            local out: Look = if look then table.clone(look) else {}
            out.focus = near + (far - near) * ease(k)
            out.focusRadius = radius
            return frame, fov, out
        end,
    }
end

-- The picture's aspect (width over height): the current camera's, unless given.
local function aspectOf(given: number?): number
    if given then
        return given
    end
    local camera = Workspace.CurrentCamera
    local size = if camera then camera.ViewportSize else Vector2.new(16, 9)
    return if size.Y > 0 then size.X / size.Y else 16 / 9
end

-- `frame` turned so what it looks at sits at (`x`, `y`) on the screen.
local function turned(frame: CFrame, fov: number, x: number, y: number, aspect: number): CFrame
    local tall = math.tan(math.rad(fov) / 2)
    local wide = tall * aspect
    local yaw = math.atan(x * wide)
    local pitch = math.atan(y * tall)
    return frame * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0)
end

-- The same shot, turned so what it looks at sits at (`x`, `y`) on the screen instead of its middle:
-- each from -1 to 1 across the picture (x 0.5 is the middle of the right half, beside a panel on
-- the left; y up). The picture's `aspect` (width over height) is the current camera's unless given.
function Shot.offset(shot: Shot, options: OffsetOptions): Shot
    return {
        duration = shot.duration,
        blendIn = shot.blendIn,
        pose = function(t)
            local frame, fov, look = shot.pose(t)
            if not frame then
                return nil, fov, look
            end
            local aspect = aspectOf(options.aspect)
            return turned(frame, fov, options.x, options.y or 0, aspect), fov, look
        end,
    }
end

-- `frame` turned so what it looks at sits at (`x`, `y`) on the screen (each -1 to 1), for a
-- picture of `aspect` (the current camera's unless given).
function Shot.turn(frame: CFrame, fov: number, x: number, y: number?, aspect: number?): CFrame
    return turned(frame, fov, x, y or 0, aspectOf(aspect))
end

-- The game's own camera, live, for `duration`: the take leaves the camera to the game (a game
-- camera that stands aside for a take runs through a live shot: `Reel.status().live`) and turns
-- the picture it frames so the game's middle sits in the middle of the picture beside the reel's
-- `panel`, not of the screen. For a feature that is the camera (an aim mode's shoulder view).
function Shot.live(options: LiveOptions): Shot
    local panel = options.panel
    local share = if panel then panel.share or 0.5 else 0
    return {
        duration = options.duration,
        live = {
            x = if not panel then 0 elseif panel.side == "right" then -share else share,
            aspect = options.aspect,
        },
        pose = function()
            return nil, Shot.DefaultFov, nil
        end,
    }
end

-- A subject framed in the picture beside a reel's panel: the camera looks down at it at
-- `elevation` degrees (32 by default) from the `from` side (flattened; default +Z), back just far
-- enough that a ball of radius `size` round the subject spans `fill` (0.65 by default) of the
-- picture's width or height, whichever is tighter, and turned so the subject sits in the middle of
-- the picture rather than of the screen. The picture is the screen less the `panel`'s share (the
-- reel's own `panel` options). Reckoned each frame, so it keeps a moving subject framed.
function Shot.frame(options: FrameOptions): Shot
    local elevation = math.rad(options.elevation or 32)
    local fill = options.fill or 0.65
    local fov = options.fov or 40
    local panel = options.panel
    local share = if panel then panel.share or 0.5 else 0
    local x = if not panel then 0 elseif panel.side == "right" then -share else share
    local from = options.from or Vector3.new(0, 0, 1)
    local flat = Vector3.new(from.X, 0, from.Z)
    flat = if flat.Magnitude > 1e-4 then flat.Unit else Vector3.new(0, 0, 1)
    local toCamera = flat * math.cos(elevation) + Vector3.yAxis * math.sin(elevation)
    return {
        duration = options.duration,
        pose = function()
            local subject = pointAt(options.subject)
            if not subject then
                return nil, fov, nil
            end
            local aspect = aspectOf(options.aspect)
            local tall = math.tan(math.rad(fov) / 2)
            local wide = tall * aspect * (1 - share)
            local distance = options.size / (fill * math.min(tall, wide))
            local frame = CFrame.lookAt(subject + toCamera * distance, subject)
            return turned(frame, fov, x, 0, aspect), fov, nil
        end,
    }
end

-- The same shot, entered by a cut on motion: over its first `seconds` the camera keeps going the
-- way the shot before it was moving, and eases into this one (Take does the blending).
function Shot.blendIn(shot: Shot, seconds: number): Shot
    local out = table.clone(shot)
    out.blendIn = seconds
    return out
end

function Shot.find(name: string, scope: Instance?): Target
    local root = scope or Workspace
    local found: PVInstance? = nil
    return function()
        local current = found
        if not (current and current:IsDescendantOf(root)) then
            local match = root:FindFirstChild(name, true)
            current = if match and match:IsA("PVInstance") then match else nil
            found = current
        end
        return if current then current:GetPivot() else nil
    end
end

return Shot
