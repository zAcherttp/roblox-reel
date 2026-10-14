# Reel

Scripted camera takes for recording Roblox showcase videos and trailers.

Showing off a feature usually means recording a video. Doing it by hand means flying the camera, hiding every overlay, and pressing the skill at just the right moment, then doing it all again the same way for a before-and-after comparison. Reel lets you write that take as code instead:

- **shots** say where the camera is over time;
- **beats** say what happens, and when.

When a reel plays, it takes over the camera and hides the UI. It runs the beats on time and prints a timestamped marker at every cut. When the take ends, it puts everything back. You record the screen with any recorder and trim the video to the markers.

- Pure Luau, `--!strict`, with no dependencies.
- Shots: still, dolly, orbit, follow, track, spline, whip pan, rack focus, shake, live game camera, and framing beside a text panel.
- A text panel and title cards for feature showcases, plus letterbox bars.
- A "cyc" set: a studio plate in a flat, horizonless void, with its own lighting.
- Variants (`before` / `after`) share a seed, so both takes roll the same random effects.
- Chains play several takes back to back.

## Install

**Rojo.** Copy `src/Reel` into your project and map it into `ReplicatedStorage`, for example:

```json
"ReplicatedStorage": {
  "Reel": { "$path": "vendor/Reel" }
}
```

**Studio only.** Drag `Reel.rbxm` into `ReplicatedStorage`. To rebuild it from source, run `rojo build -o Reel.rbxm`.

Reel runs on the **client**: require it from a LocalScript. The only exception is `Reel.Cyc`, which builds the set and can run on either side.

## Quick start

A reel is a ModuleScript whose name ends in `.reel`, anywhere under `ReplicatedStorage` or the player's `PlayerScripts`. It returns a function that registers one or more reels:

```lua
-- ReplicatedStorage/Reels/Fireball.reel.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Reel = require(ReplicatedStorage.Reel)
local Shot = Reel.Shot

return function(register)
    register({
        name = "skills/fireball",
        note = "fireball on the training dummy",
        variants = { "before", "after" },
        setup = function(take)
            -- spawn what the take needs; may yield
            local dummy = ReplicatedStorage.Dummy:Clone()
            dummy.Parent = workspace
            return function() -- cleanup, runs however the take ends
                dummy:Destroy()
            end
        end,
        shots = function(take)
            local dummy = Shot.find("Dummy")
            return {
                Shot.orbit({ target = dummy, radius = 12, height = 3, from = -30, to = 40, duration = 2.5 }),
                Shot.shake(
                    Shot.follow({ target = dummy, offset = Vector3.new(3, 2, 7), duration = 1.5, fov = 50 }),
                    { amplitude = 1.5, seed = take.seed }
                ),
            }
        end,
        at = {
            { time = 0.8, run = function(take)
                -- drive your game here: fire a remote, call your skill module, etc.
                print("cast fireball", take.variant)
            end },
        },
    })
end
```

Then play it from a LocalScript:

```lua
local Reel = require(game:GetService("ReplicatedStorage").Reel)

Reel.collectAll()                 -- requires every *.reel module and registers its reels
Reel.play("skills/fireball", { variant = "after" })
```

Output:

```
[Reel] start skills/fireball variant=after elapsed=0.000 at=1790551234567 seed=1234
[Reel] cut skills/fireball variant=after shot=1 elapsed=0.000 at=1790551234567
[Reel] cut skills/fireball variant=after shot=2 elapsed=2.504 at=1790551237071
[Reel] end skills/fireball variant=after elapsed=4.011 at=1790551238578
```

`at` is Unix milliseconds on this machine, the same clock a screen recorder on the same computer uses. Cut the video from `start` to `end` and you don't have to guess.

### Example place

`example.project.json` builds a small place with a cyc, a turning model and a demo reel that uses the text panel:

```bash
rojo build example.project.json -o ReelExample.rbxl
```

Open the place, press Play, then press **P** to start or stop the reel.

## API

### `Reel`

| Function | Does |
|---|---|
| `Reel.register(spec)` | Registers a reel (normally done through a `.reel` module). |
| `Reel.collect(root)` / `Reel.collectAll()` | Requires every `*.reel` ModuleScript under `root` (or under `ReplicatedStorage` and `PlayerScripts`) and registers what each one returns. Returns `(loaded, failed)`. Calling it again registers the same reels again. |
| `Reel.play(name, options?)` | Starts a take and returns at once. Options: `variant`, `seed`, `camera`, `stage`, `onMark`, `letterbox`. |
| `Reel.stop()` | Ends the current take (or chain) early. |
| `Reel.status()` | Returns `nil` when idle; otherwise `{ state = "preparing" \| "rolling", name, variant, elapsed, duration, live }`. |
| `Reel.chain(entries, options?)` | Plays takes back to back. The next one starts `gap` seconds (default 1) after the previous one ends. |
| `Reel.expand(list)` | Turns `"a/b, a/c:after, x/*"` into chain entries. `name:*` means every variant; `prefix/*` means every reel under that prefix, sorted by `order`. |
| `Reel.chainStatus()` | Returns `{ index, count, entry }` while a chain runs. |
| `Reel.names(prefix?)`, `Reel.get(name)` | Look up what is registered. |
| `Reel.seedOf(name)` | The default seed: a hash of the name, the same for every variant. |

Only one take runs at a time. Playing a new one stops the current one.

### Spec

| Field | Meaning |
|---|---|
| `name` | A slash-separated name, so related reels sort together. |
| `note` | One line describing the reel. |
| `variants` | Names of the takes in a comparison (`before`, `after`). The first is the default. The reel reads `take.variant`. |
| `setup(take)` | Runs before the camera moves and may yield. It can return a cleanup function, which is called however the take ends. |
| `shots` | A list of shots, or `(take) -> shots`. The function form runs after `setup`, so shots can aim at what setup created. |
| `at` | Beats: `{ time, run(take) }`, with `time` in seconds from the first frame. Each beat runs in its own thread. Beats with the same time run in the order written. |
| `keep` | Names of your ScreenGuis to leave visible (captions, a comparison label). |
| `world` | Also hide BillboardGuis and SurfaceGuis in the workspace (nameplates, damage numbers). |
| `panel` | A text panel beside the picture: `{ side?, share?, font?, accent?, background?, text?, seeThrough? }`. |
| `haze` | `false` turns the atmosphere's haze off for the take. |
| `letterbox` | Crops the picture to this aspect ratio (2.39 for cinema scope) with black bars. |
| `order` | Sort order when a chain expands `prefix/*`. |

`take` is the context every callback receives: `name`, `variant`, `seed`, `elapsed()` and `panel`.

### Panel

When a reel has a `panel`, its beats fill it in:

- `take.panel.show({ tag?, title, lines?, seeing?, counter? })` slides new content into the side panel;
- `take.panel.card({ title, lines? })` covers the whole screen, for a title or an outro;
- `take.panel.clear()` hides both.

The panel stays visible while the rest of the UI is hidden. Without `panel`, these calls do nothing.

### Shots

A shot is `{ duration, pose(t) -> (CFrame?, fov, look?) }`. It is a pure function of time, so posing the same moment twice gives the same frame. If a shot's target is missing, the camera holds where it was.

| Shot | Camera |
|---|---|
| `Shot.still({ at, duration, fov? })` | Fixed. |
| `Shot.dolly({ from, to, duration, fov?, ease? })` | Slides between two CFrames. |
| `Shot.orbit({ target, radius, duration, height?, from?, to?, aim?, fov?, ease? })` | Circles the target while looking at it. Angles are in degrees; 0 is in front of the target. |
| `Shot.follow({ target, offset, duration, aim?, fov? })` | Rides at `offset` in the target's flattened frame (+Z is behind it). |
| `Shot.track({ from, target, duration, aim?, fov? })` | A tripod at `from` that pans to keep the target in view. |
| `Shot.spline({ points, duration, target?, aim?, look?, fov?, ease? })` | Glides through `points` at an even speed, on a centripetal Catmull-Rom curve. |
| `Shot.whip({ at, from, to, duration, blur?, fov? })` | A whip pan from one subject to another, smeared with blur. |
| `Shot.shake(shot, { amplitude, frequency?, seed?, envelope? })` | Adds rotational shake to any shot. The same seed gives the same shake. |
| `Shot.focus(shot, { from, to?, radius?, start?, finish?, ease? })` | Adds a rack focus to any shot, using depth of field. |
| `Shot.offset(shot, { x, y?, aspect? })` | Turns any shot so its subject sits at (`x`, `y`) on screen, each from -1 to 1. |
| `Shot.frame({ subject, size, duration, from?, elevation?, fill?, fov?, panel?, aspect? })` | Frames a subject of radius `size` beside a panel. It is recomputed every frame, so a moving subject stays framed. |
| `Shot.live({ duration, panel?, aspect? })` | Hands the camera back to your game's own camera, shifted beside the panel. While it runs, `Reel.status().live` is true. |
| `Shot.blendIn(shot, seconds)` | Enters the shot with a cut on motion instead of a hard cut. |
| `Shot.find(name, scope?)` | A target: finds a model or part by name under the workspace and keeps following it. |

A **target** is `() -> CFrame?`, read every frame. `fov` is a number or a curve over the shot. `ease` is a curve over the shot's progress.

### Curve

`Reel.Curve` contains small `(k) -> number` helpers over progress k from 0 to 1: `linear(a, b)`, `rise(a, b)`, `fall(a, b)`, `window(...)`, `ease(from, to, over)`, `constant(v)`, `sum(...)` and `product(...)`. For example, `fov = Reel.Curve.linear(70, 40)` zooms in.

### Cyc

`Reel.Cyc.build(parent, at, options?) -> { model, top, radius, destroy }` builds a photo studio set with the top middle of its plate at `at`. It has a round lit plate inside a closed, flat-coloured Neon void, so the picture shows only what stands on the plate. Build it on the server if anything stands on it.

Options: `void`, `plate`, `radius` (22), `thickness` (1), `sides` (64), `size` (130), `height` (90) and `brightness` (1).

Frame it with `Shot.frame({ subject = cyc.top.Position, size = cyc.radius, panel = spec.panel })`, and play the reel with `haze = false`.

### Stage

`Reel.Stage.clear(options?) -> restore` hides every ScreenGui under `PlayerGui` (except the `keep` names) and Roblox's CoreGui. Calling `restore()` puts back exactly what was there. A take calls this for you.

## Recording

A script can't record video in Studio, so record the window with an OS screen recorder (OBS, the macOS `screencapture -v`, or similar):

1. Start a playtest. Press **Ctrl+Shift+G** to hide Roblox's own top bar and Studio's stats bar; no script can hide those.
2. Note the time, start the recorder, and play the reel. Keep Studio in front for the whole take.
3. Trim the video using the `start` and `end` markers (`at` is Unix ms), or using `onMark`:

   ```lua
   Reel.play("skills/fireball", { onMark = function(mark) print(mark.kind, mark.at) end })
   ```

4. Crop to the viewport and encode, for example with ffmpeg: `crop`, `scale`, H.264, `yuv420p`, `+faststart`.

## Limits

- **Client only, and realtime.** A take runs in real time, so the recording shows exactly what the game did, at whatever frame rate the machine held. There is no stepped or slow-motion capture.
- **One take at a time.**
- **Roblox's new top bar can't be hidden by script.** Use Ctrl+Shift+G.
- **Roblox has no motion blur.** Whip pans fake it with a full-screen `BlurEffect`.
- **Some colours shift.** The cyc's void is Neon, which maps colours steeply. A `seeThrough` panel matches the void exactly; a background colour only comes close.
- Beats call your game directly. Reel has no input simulation and no networking of its own.

## Credits

Built by Phát ([@zAcherttp](https://github.com/zAcherttp)) as part of a Roblox game framework, and released on its own under the MIT licence. See [LICENSE](LICENSE).
