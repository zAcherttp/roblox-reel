--!strict
local Shot = require(script.Parent.Shot)

export type Beat<Context> = { time: number, run: (Context) -> () }

export type Timeline<Context> = {
    shots: { Shot.Shot },
    starts: { number },
    duration: number,
    beats: { Beat<Context> },
}

local Timeline = {}

type Indexed<Context> = { beat: Beat<Context>, index: number }

local function ordered<Context>(beats: { Beat<Context> }): { Beat<Context> }
    local indexed: { Indexed<Context> } = {}
    for index, beat in beats do
        assert(beat.time >= 0, "a beat's time must not be negative")
        table.insert(indexed, { beat = beat, index = index })
    end
    table.sort(indexed, function(a: Indexed<Context>, b: Indexed<Context>)
        if a.beat.time ~= b.beat.time then
            return a.beat.time < b.beat.time
        end
        return a.index < b.index
    end)
    local out: { Beat<Context> } = {}
    for _, entry in indexed do
        table.insert(out, entry.beat)
    end
    return out
end

function Timeline.new<Context>(shots: { Shot.Shot }, beats: { Beat<Context> }?): Timeline<Context>
    assert(#shots > 0, "a reel needs at least one shot")
    local starts = {}
    local total = 0
    for _, shot in shots do
        assert(shot.duration >= 0, "a shot's duration must not be negative")
        table.insert(starts, total)
        total += shot.duration
    end
    return {
        shots = shots,
        starts = starts,
        duration = total,
        beats = ordered(beats or {}),
    }
end

function Timeline.shotAt<Context>(timeline: Timeline<Context>, t: number): (number, number)
    local at = math.clamp(t, 0, timeline.duration)
    for index = #timeline.shots, 1, -1 do
        local start = timeline.starts[index]
        if at >= start then
            return index, at - start
        end
    end
    return 1, 0
end

function Timeline.fired<Context>(timeline: Timeline<Context>, elapsed: number): number
    local count = 0
    for _, beat in timeline.beats do
        if beat.time > elapsed then
            break
        end
        count += 1
    end
    return count
end

return Timeline
