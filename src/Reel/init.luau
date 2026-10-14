--!strict
-- Reel: scripted camera takes for recording showcase videos. A reel is a short storyboard written
-- as code: shots (where the camera is, over time) and beats (what happens, when). Playing one takes
-- over the camera, hides the UI, runs the beats on time, prints a marker at every cut, and gives
-- everything back at the end. Client side: require it from a LocalScript. See README.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shot = require(script.Shot)
local Stage = require(script.Stage)
local Panel = require(script.Panel)
local Take = require(script.Take)
local Timeline = require(script.Timeline)
local Curve = require(script.Curve)

export type Context = Take.Context
export type Beat = Timeline.Beat<Context>
export type Mark = Take.Mark
export type Look = Shot.Look
export type Status = Take.Status
export type Shot = Shot.Shot
export type PanelOptions = Panel.Options
export type Curve = Curve.Curve

export type Spec = {
    name: string,
    note: string?,
    variants: { string }?,
    keep: { string }?,
    world: boolean?,
    setup: ((Context) -> (() -> ())?)?,
    shots: { Shot.Shot } | (Context) -> { Shot.Shot },
    at: { Beat }?,
    letterbox: number?,
    panel: Panel.Options?,
    haze: boolean?,
    order: number?,
}

export type Entry = { name: string, variant: string? }

export type ChainOptions = {
    seed: number?,
    camera: Camera?,
    stage: Stage.Options?,
    onMark: ((Mark) -> ())?,
    letterbox: number?,
    gap: number?,
}

export type ChainStatus = { index: number, count: number, entry: Entry }

type Chain = { entries: { Entry }, index: number, options: ChainOptions }

export type PlayOptions = {
    variant: string?,
    seed: number?,
    camera: Camera?,
    stage: Stage.Options?,
    onMark: ((Mark) -> ())?,
    letterbox: number?,
}

local Reel = {}

Reel.Shot = Shot
Reel.Stage = Stage
Reel.Timeline = Timeline
Reel.Take = Take
Reel.Letterbox = require(script.Letterbox)
Reel.Panel = Panel
Reel.Cyc = require(script.Cyc)
Reel.Curve = Curve

local registry: { [string]: Spec } = {}

function Reel.register(spec: Spec)
    assert(spec.name ~= "", "a reel needs a name")
    if spec.variants then
        assert(#spec.variants > 0, `reel {spec.name}: variants must not be empty`)
    end
    registry[spec.name] = spec
end

function Reel.get(name: string): Spec?
    return registry[name]
end

function Reel.names(prefix: string?): { string }
    local out = {}
    for name in registry do
        if not prefix or string.sub(name, 1, #prefix) == prefix then
            table.insert(out, name)
        end
    end
    table.sort(out)
    return out
end

local function ordered(prefix: string): { string }
    local out = Reel.names(prefix)
    table.sort(out, function(a: string, b: string)
        local first = registry[a].order or math.huge
        local second = registry[b].order or math.huge
        if first ~= second then
            return first < second
        end
        return a < b
    end)
    return out
end

function Reel.expand(list: string): { Entry }
    local entries: { Entry } = {}
    for token in string.gmatch(list, "[^,%s]+") do
        local name, variant = string.match(token, "^(.-):(.*)$")
        local pattern = name or token
        local every = string.sub(pattern, -1) == "*"
        local names: { string } = if every then ordered(string.sub(pattern, 1, -2)) else { pattern }
        assert(#names > 0, `no reels match "{pattern}"`)
        for _, found in names do
            local spec = registry[found]
            assert(spec, `no reel named "{found}"`)
            local all = variant == "*" or (every and variant == nil)
            if all and spec.variants then
                for _, each in spec.variants do
                    table.insert(entries, { name = found, variant = each })
                end
            else
                local chosen = if all or variant == "" then nil else variant
                table.insert(entries, { name = found, variant = Reel.variantOf(spec, chosen) })
            end
        end
    end
    return entries
end

function Reel.clearRegistry()
    registry = {}
end

function Reel.collect(root: Instance): (number, number)
    local loaded, failed = 0, 0
    for _, module in root:GetDescendants() do
        if not (module:IsA("ModuleScript") and string.match(module.Name, "%.reel$")) then
            continue
        end
        local ok, result = pcall(require, module)
        if ok and typeof(result) == "function" then
            ok, result = pcall(result, Reel.register)
        elseif ok then
            ok, result = false, "must return a function that registers reels"
        end
        if ok then
            loaded += 1
        else
            failed += 1
            warn(`[Reel] {module:GetFullName()}: {result}`)
        end
    end
    return loaded, failed
end

function Reel.collectAll(): (number, number)
    local loaded, failed = Reel.collect(ReplicatedStorage)
    local player = Players.LocalPlayer
    local scripts = player and player:FindFirstChild("PlayerScripts")
    if scripts then
        local more, broken = Reel.collect(scripts)
        loaded += more
        failed += broken
    end
    return loaded, failed
end

function Reel.seedOf(name: string): number
    local hash = 5381
    for index = 1, #name do
        hash = (hash * 33 + string.byte(name, index)) % 2147483647
    end
    return hash
end

function Reel.variantOf(spec: Spec, requested: string?): string?
    local variants = spec.variants
    if not variants then
        assert(requested == nil, `reel {spec.name} has no variants`)
        return nil
    end
    if requested == nil then
        return variants[1]
    end
    assert(
        table.find(variants, requested),
        `reel {spec.name} has no variant "{requested}" ({table.concat(variants, ", ")})`
    )
    return requested
end

local chain: Chain? = nil

local function start(name: string, options: PlayOptions?)
    local spec = registry[name]
    assert(spec, `no reel named "{name}"`)
    local given: PlayOptions = options or {}
    local shots = spec.shots
    local stage: Stage.Options = given.stage or { keep = spec.keep }
    if spec.world and stage.world == nil then
        stage = table.clone(stage)
        stage.world = workspace
    end
    Take.start({
        name = spec.name,
        variant = Reel.variantOf(spec, given.variant),
        seed = given.seed or Reel.seedOf(spec.name),
        shots = if typeof(shots) == "function"
            then shots
            else function()
                return shots :: { Shot.Shot }
            end,
        beats = spec.at,
        setup = spec.setup,
        stage = stage,
        camera = given.camera,
        onMark = given.onMark,
        letterbox = if given.letterbox ~= nil then given.letterbox else spec.letterbox,
        panel = spec.panel,
        haze = spec.haze,
    })
end

function Reel.play(name: string, options: PlayOptions?)
    chain = nil
    start(name, options)
end

local function advance(run: Chain)
    if chain ~= run then
        return
    end
    run.index += 1
    local entry = run.entries[run.index]
    if not entry then
        chain = nil
        return
    end
    local options = run.options
    local forward = options.onMark or Take.printMark
    start(entry.name, {
        variant = entry.variant,
        seed = options.seed,
        camera = options.camera,
        stage = options.stage,
        letterbox = options.letterbox,
        onMark = function(mark: Mark)
            forward(mark)
            if chain ~= run then
                return
            end
            if mark.kind == "stop" then
                chain = nil
            elseif mark.kind == "end" or mark.kind == "fail" then
                task.delay(options.gap or 1, advance, run)
            end
        end,
    })
end

function Reel.chain(entries: { Entry }, options: ChainOptions?)
    assert(#entries > 0, "a chain needs at least one reel")
    for _, entry in entries do
        assert(registry[entry.name], `no reel named "{entry.name}"`)
    end
    Take.stop()
    local run: Chain = { entries = entries, index = 0, options = options or {} }
    chain = run
    advance(run)
end

function Reel.chainStatus(): ChainStatus?
    local run = chain
    if not run then
        return nil
    end
    return { index = run.index, count = #run.entries, entry = run.entries[run.index] }
end

function Reel.stop(): boolean
    local chained = chain ~= nil
    chain = nil
    return Take.stop() or chained
end

function Reel.status(): Status?
    return Take.status()
end

return Reel
