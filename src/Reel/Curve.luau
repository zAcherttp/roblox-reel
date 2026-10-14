--!strict
-- Curve: a number shaped over progress k, from 0 (start) to 1 (end). Reel takes one wherever
-- something changes over a shot: a field of view (`fov = Curve.linear(70, 40)` zooms in), an ease
-- over the shot's progress, a shake's envelope. Any `(k) -> number` works; these are the common
-- ones, and they combine.
--
--   Curve.linear(70, 40)                   -- from 70 at k 0 to 40 at k 1
--   Curve.rise(0, 1)                       -- eases in and out from 0 to 1 (the default ease)
--   Curve.window(0, 0.2, 0.8, 1)           -- in over 0 to 0.2, out over 0.8 to 1
--   Curve.ease(0.3, 1, 0.2)                -- from 0.3 to 1 by k 0.2, easing out, then held
--   Curve.sum(Curve.ease(0.3, 1, 0.2), Curve.linear(0, 0.3))
local Curve = {}

export type Curve = (k: number) -> number

local function smoothstep(a: number, b: number, x: number): number
    if b == a then
        return if x >= b then 1 else 0
    end
    local t = math.clamp((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
end

function Curve.constant(value: number): Curve
    return function()
        return value
    end
end

-- From `from` at k 0 to `to` at k 1.
function Curve.linear(from: number, to: number): Curve
    return function(k)
        return from + (to - from) * k
    end
end

-- 0 until k `a`, 1 from k `b`, smoothly between.
function Curve.rise(a: number, b: number): Curve
    return function(k)
        return smoothstep(a, b, k)
    end
end

-- 1 until k `a`, 0 from k `b`, smoothly between.
function Curve.fall(a: number, b: number): Curve
    return function(k)
        return 1 - smoothstep(a, b, k)
    end
end

-- In over `inFrom` to `inTo`, out over `outFrom` to `outTo`, `peak` (1) between.
function Curve.window(
    inFrom: number,
    inTo: number,
    outFrom: number,
    outTo: number,
    peak: number?
): Curve
    local top = peak or 1
    return function(k)
        return top * smoothstep(inFrom, inTo, k) * (1 - smoothstep(outFrom, outTo, k))
    end
end

-- From `from` to `to` by k `over`, fast then slow (cubic ease-out), then held at `to`.
function Curve.ease(from: number, to: number, over: number): Curve
    return function(k)
        local t = 1 - math.clamp(k / over, 0, 1)
        return from + (to - from) * (1 - t * t * t)
    end
end

-- The curves added.
function Curve.sum(...: Curve): Curve
    local curves = { ... }
    return function(k)
        local total = 0
        for _, c in curves do
            total += c(k)
        end
        return total
    end
end

-- The curves multiplied.
function Curve.product(...: Curve): Curve
    local curves = { ... }
    return function(k)
        local total = 1
        for _, c in curves do
            total *= c(k)
        end
        return total
    end
end

return Curve
