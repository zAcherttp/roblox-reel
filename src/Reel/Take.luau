--!strict
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Letterbox = require(script.Parent.Letterbox)
local Panel = require(script.Parent.Panel)
local Shot = require(script.Parent.Shot)
local Stage = require(script.Parent.Stage)
local Timeline = require(script.Parent.Timeline)

export type Context = {
    name: string,
    variant: string?,
    seed: number,
    elapsed: () -> number,
    -- The reel's text panel (a feature showcase's), for its beats to fill; does nothing when the
    -- reel has none.
    panel: Panel.Api,
}

export type MarkKind = "start" | "cut" | "end" | "stop" | "fail"

export type Mark = {
    kind: MarkKind,
    name: string,
    variant: string?,
    shot: number?,
    elapsed: number,
    at: number,
    detail: string?,
}

export type Plan = {
    name: string,
    variant: string?,
    seed: number,
    shots: (Context) -> { Shot.Shot },
    beats: { Timeline.Beat<Context> }?,
    setup: ((Context) -> (() -> ())?)?,
    stage: Stage.Options?,
    camera: Camera?,
    onMark: ((Mark) -> ())?,
    -- Crop the picture to this aspect (width over height, 2.39 for cinema scope) with black bars.
    letterbox: number?,
    -- A text panel beside the picture, for the beats to fill (Panel).
    panel: Panel.Options?,
    -- false: the atmosphere's haze off for the take (it greys a Cyc's far wall into a horizon).
    haze: boolean?,
}

export type Status = {
    state: "preparing" | "rolling",
    -- In a live shot: the game's own camera frames the picture (Shot.live).
    live: boolean?,
    name: string,
    variant: string?,
    elapsed: number,
    duration: number?,
}

type SavedCamera = {
    cameraType: Enum.CameraType,
    cframe: CFrame,
    fov: number,
    subject: Instance?,
}

type Live = {
    plan: Plan,
    context: Context,
    state: "preparing" | "rolling",
    elapsed: number,
    fired: number,
    shot: number,
    timeline: Timeline.Timeline<Context>?,
    camera: Camera?,
    saved: SavedCamera?,
    restoreUi: (() -> ())?,
    cleanup: (() -> ())?,
    -- The lens effects a shot's look asks for, made on the camera the first time.
    focus: DepthOfFieldEffect?,
    blur: BlurEffect?,
    letterbox: Letterbox.Letterbox?,
    panel: Panel.Panel?,
    -- The atmospheres a take without haze cleared, and what they were.
    hazes: { Haze }?,
    -- The last two frames shown and when, for carrying a shot's motion across a cut.
    last: CFrame?,
    before: CFrame?,
    step: number,
    carry: Carry?,
    -- In a live shot: how to turn the game's picture, and the game's own frame before the turn,
    -- handed back to it before its camera runs again, so it never sees the turn.
    turn: { x: number, aspect: number? }?,
    base: CFrame?,
}

type Haze = { atmosphere: Atmosphere, density: number, haze: number, glare: number }

-- A shot's motion as it was cut away from: its last frame, moving at `move` studs a second and
-- turning `rate` radians a second about `axis` (in its own frame).
type Carry = { from: CFrame, move: Vector3, axis: Vector3, rate: number }

-- How long the letterbox's bars take to close in.
local LETTERBOX_IN = 0.5

local Take = {}

local BindName = "Reel_"
local LateName = "Reel_Live"

local current: Live? = nil
local bound = false

function Take.printMark(mark: Mark)
    local parts = { `[Reel] {mark.kind} {mark.name}` }
    if mark.variant then
        table.insert(parts, `variant={mark.variant}`)
    end
    if mark.shot then
        table.insert(parts, `shot={mark.shot}`)
    end
    table.insert(parts, string.format("elapsed=%.3f", mark.elapsed))
    table.insert(parts, `at={mark.at}`)
    if mark.detail then
        table.insert(parts, mark.detail)
    end
    print(table.concat(parts, " "))
end

local function mark(live: Live, kind: MarkKind, detail: string?)
    local entry: Mark = {
        kind = kind,
        name = live.plan.name,
        variant = live.plan.variant,
        shot = if kind == "cut" then live.shot else nil,
        elapsed = live.elapsed,
        at = DateTime.now().UnixTimestampMillis,
        detail = detail,
    }
    local onMark = live.plan.onMark or Take.printMark
    onMark(entry)
end

local function unbind()
    if bound then
        bound = false
        RunService:UnbindFromRenderStep(BindName)
        RunService:UnbindFromRenderStep(LateName)
    end
end

local function release(live: Live)
    for _, effect in { live.focus, live.blur } :: { Instance? } do
        if effect then
            effect:Destroy()
        end
    end
    live.focus, live.blur = nil, nil
    if live.letterbox then
        live.letterbox.gui:Destroy()
        live.letterbox = nil
    end
    if live.panel then
        live.panel.gui:Destroy()
        live.panel = nil
    end
    local hazes: { Haze } = live.hazes or {}
    for _, was in hazes do
        was.atmosphere.Density = was.density
        was.atmosphere.Haze = was.haze
        was.atmosphere.Glare = was.glare
    end
    live.hazes = nil
    local camera, saved = live.camera, live.saved
    if camera and saved then
        camera.CameraType = saved.cameraType
        camera.CFrame = saved.cframe
        camera.FieldOfView = saved.fov
        camera.CameraSubject = saved.subject :: any
    end
    if live.restoreUi then
        live.restoreUi()
    end
end

local function clean(live: Live)
    local cleanup = live.cleanup
    if not cleanup then
        return
    end
    task.spawn(function()
        local ok, err = pcall(cleanup :: () -> ...any)
        if not ok then
            warn(`[Reel] {live.plan.name}: cleanup failed: {err}`)
        end
    end)
end

local function finish(live: Live, kind: "end" | "stop" | "fail", detail: string?)
    if current == live then
        current = nil
        unbind()
    end
    release(live)
    mark(live, kind, detail)
    clean(live)
end

local function runBeat(live: Live, beat: Timeline.Beat<Context>)
    task.spawn(function()
        local ok, err = pcall(beat.run :: (Context) -> ...any, live.context)
        if not ok then
            warn(`[Reel] {live.plan.name}: beat at {beat.time}s failed: {err}`)
        end
    end)
end

local function smooth(k: number): number
    return k * k * (3 - 2 * k)
end

-- The motion of the shot being cut away from, from the last two frames it showed.
local function carryOf(live: Live): Carry?
    local last, before, step = live.last, live.before, live.step
    if not (last and before) or step <= 0 then
        return nil
    end
    local turn = before:ToObjectSpace(last).Rotation
    local axis, angle = turn:ToAxisAngle()
    return {
        from = last,
        move = (last.Position - before.Position) / step,
        axis = axis,
        rate = angle / step,
    }
end

-- Where the cut-away shot's camera would be `t` seconds on, still moving as it was.
local function carried(carry: Carry, t: number): CFrame
    local turned = if carry.rate > 0
        then CFrame.fromAxisAngle(carry.axis, carry.rate * t)
        else CFrame.identity
    return (carry.from.Rotation * turned) + carry.from.Position + carry.move * t
end

-- Turn a shot's look into the camera's lens effects (made on the camera, removed with the take).
local function lens(live: Live, camera: Camera, look: Shot.Look?)
    local focus = look and look.focus
    if focus or live.focus then
        local dof = live.focus
        if not dof then
            local made = Instance.new("DepthOfFieldEffect")
            made.Name = "Reel_Focus"
            made.FarIntensity = 0.8
            made.NearIntensity = 0.8
            made.Parent = camera
            live.focus = made
            dof = made
        end
        assert(dof, "focus effect")
        dof.Enabled = focus ~= nil
        if focus then
            dof.FocusDistance = focus
            dof.InFocusRadius = (look :: Shot.Look).focusRadius or 4
        end
    end
    local blur = (look and look.blur) or 0
    if blur > 0 or live.blur then
        local b = live.blur
        if not b then
            local made = Instance.new("BlurEffect")
            made.Name = "Reel_Blur"
            made.Parent = camera
            live.blur = made
            b = made
        end
        assert(b, "blur effect")
        b.Size = blur
        b.Enabled = blur > 0
    end
end

local function advance(live: Live, delta: number)
    local timeline = live.timeline
    local camera = live.camera
    if not (timeline and camera) then
        return
    end
    live.elapsed += delta
    local fired = Timeline.fired(timeline, live.elapsed)
    for index = live.fired + 1, fired do
        runBeat(live, timeline.beats[index])
    end
    live.fired = fired
    if current ~= live then
        return
    end
    local index, t = Timeline.shotAt(timeline, live.elapsed)
    local shot = timeline.shots[index]
    if index ~= live.shot then
        live.shot = index
        live.carry = if (shot.blendIn or 0) > 0 then carryOf(live) else nil
        mark(live, "cut")
    end
    if shot.live then
        -- The game's camera frames it: its own frame back before it runs (Take.late turned it).
        if live.base then
            camera.CFrame = live.base
        end
        live.turn = shot.live
        live.before, live.last, live.carry = nil, nil, nil
        lens(live, camera, nil)
    else
        live.turn, live.base = nil, nil
        local frame, fov, look = shot.pose(t)
        local carry = live.carry
        if frame and carry and t < (shot.blendIn :: number) then
            frame = carried(carry, t):Lerp(frame, smooth(t / (shot.blendIn :: number)))
        end
        if frame then
            live.before, live.last, live.step = live.last, frame, delta
            camera.CFrame = frame
        end
        camera.FieldOfView = fov
        lens(live, camera, look)
    end
    if live.letterbox and live.plan.letterbox then
        local k = math.clamp(live.elapsed / LETTERBOX_IN, 0, 1)
        Letterbox.set(
            live.letterbox,
            Letterbox.share(camera.ViewportSize, live.plan.letterbox) * smooth(k)
        )
    end
    if live.elapsed >= timeline.duration then
        finish(live, "end")
    end
end

local function bind()
    if bound or not RunService:IsClient() then
        return
    end
    bound = true
    RunService:BindToRenderStep(BindName, Enum.RenderPriority.Camera.Value + 1, Take.step)
    RunService:BindToRenderStep(LateName, Enum.RenderPriority.Last.Value, Take.late)
end

local function roll(live: Live)
    local plan = live.plan
    if plan.setup then
        local ok, cleanup = pcall(plan.setup, live.context)
        if not ok then
            finish(live, "fail", `setup: {cleanup}`)
            return
        end
        live.cleanup = cleanup
    end
    if current ~= live then
        clean(live)
        return
    end
    local ok, built = pcall(function()
        return Timeline.new(plan.shots(live.context), plan.beats)
    end)
    if not ok then
        finish(live, "fail", `shots: {built}`)
        return
    end
    local camera = plan.camera or Workspace.CurrentCamera
    if not camera then
        finish(live, "fail", "no camera")
        return
    end
    live.timeline = built
    live.camera = camera
    live.saved = {
        cameraType = camera.CameraType,
        cframe = camera.CFrame,
        fov = camera.FieldOfView,
        subject = camera.CameraSubject,
    }
    if plan.haze == false then
        local hazes: { Haze } = {}
        for _, atmosphere in Lighting:GetChildren() do
            if atmosphere:IsA("Atmosphere") then
                table.insert(hazes, {
                    atmosphere = atmosphere,
                    density = atmosphere.Density,
                    haze = atmosphere.Haze,
                    glare = atmosphere.Glare,
                })
                atmosphere.Density, atmosphere.Haze, atmosphere.Glare = 0, 0, 0
            end
        end
        live.hazes = hazes
    end
    -- The take's own screens (the letterbox's bars, the text panel): kept, where the stage hides
    -- the rest.
    local stage: Stage.Options = if plan.stage then table.clone(plan.stage) else {}
    local keep = table.clone(stage.keep or {})
    if plan.letterbox then
        table.insert(keep, Letterbox.Name)
    end
    if plan.panel then
        table.insert(keep, Panel.Name)
    end
    stage.keep = keep
    if plan.letterbox or plan.panel then
        local player = Players.LocalPlayer
        local parent = stage.screens or (player and player:FindFirstChildOfClass("PlayerGui"))
        if parent then
            if plan.letterbox then
                live.letterbox = Letterbox.mount(parent)
            end
            if plan.panel then
                live.panel = Panel.mount(parent, plan.panel)
            end
        end
    end
    live.restoreUi = Stage.clear(stage)
    camera.CameraType = Enum.CameraType.Scriptable
    live.state = "rolling"
    mark(live, "start", `seed={plan.seed}`)
    bind()
    advance(live, 0)
end

local function newLive(plan: Plan): Live
    local owner: Live? = nil
    local function elapsed(): number
        return if owner then owner.elapsed else 0
    end
    local context: Context = {
        name = plan.name,
        variant = plan.variant,
        seed = plan.seed,
        elapsed = elapsed,
        panel = Panel.api(function()
            return if owner then owner.panel else nil
        end),
    }
    local live: Live = {
        plan = plan,
        context = context,
        state = "preparing",
        elapsed = 0,
        fired = 0,
        shot = 0,
        step = 0,
    }
    owner = live
    return live
end

function Take.start(plan: Plan)
    Take.stop()
    local live = newLive(plan)
    current = live
    task.spawn(roll, live)
end

function Take.step(delta: number)
    local live = current
    if live and live.state == "rolling" then
        advance(live, delta)
    end
end

-- In a live shot, after the game's camera has framed the picture: turn it beside the panel,
-- keeping the game's own frame to hand back (the render step's last; tests call it by hand).
function Take.late()
    local live = current
    local turn = live and live.turn
    local camera = live and live.camera
    if not (live and turn and camera and live.state == "rolling") then
        return
    end
    live.base = camera.CFrame
    camera.CFrame = Shot.turn(camera.CFrame, camera.FieldOfView, turn.x, 0, turn.aspect)
end

function Take.stop(): boolean
    local live = current
    if not live then
        return false
    end
    current = nil
    unbind()
    if live.state == "rolling" then
        finish(live, "stop")
    end
    return true
end

function Take.status(): Status?
    local live = current
    if not live then
        return nil
    end
    return {
        state = live.state,
        name = live.plan.name,
        variant = live.plan.variant,
        elapsed = live.elapsed,
        duration = if live.timeline then live.timeline.duration else nil,
        live = live.turn ~= nil,
    }
end

return Take
