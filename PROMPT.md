# Starter prompt for Claude Code

Copy the block below into Claude Code, opened at the root of your own Rojo project. Before you paste it, fill in the three `<...>` placeholders. If you leave one blank, Claude will ask you for it.

---

```text
I want to record showcase videos of my Roblox game with the Reel module
from https://github.com/zAcherttp/roblox-reel (MIT). It plays scripted
camera takes: a shot list, beats on a timeline, the UI hidden, and a
timestamped marker at every cut.

The feature I want to show: <one sentence, e.g. "the new dash ability">
Where it happens: <a place in my map, or "build a Cyc set for it">
How the feature is triggered from code: <e.g. "fire ReplicatedStorage.Remotes.Dash", or "find out">

Please:

1. Read the Reel README (README.md in that repo) end to end before writing
   any code. Then read my project's default.project.json (or whichever
   *.project.json I use) and how my client code is organised.
2. Add Reel to my project. Copy its src/Reel folder into the project (for
   example vendor/Reel) and map it to ReplicatedStorage.Reel in my project
   file. Don't add a package manager or change my existing folder layout.
   Reel has no dependencies.
3. Write my first reel as a ModuleScript ending in `.reel` (for example
   ReplicatedStorage/Reels/<Feature>.reel.luau), using --!strict:
   - a `setup` that puts the scene in place (spawn or find the subject) and
     returns a cleanup that undoes it;
   - a shot list of 3 to 4 shots, about 8 to 12 seconds in all: an
     establishing shot (Shot.frame or Shot.orbit), a closer shot of the
     action (Shot.follow or Shot.track, with a light Shot.shake), and a
     camera path through the scene with Shot.spline (pick 4 to 6 points
     that make sense for the scene; tell me how you chose them);
   - beats (`at`) that trigger the feature through my game's own code at
     the right moments;
   - if it's a feature showcase, a `panel` with a title card, one
     panel.show per shot, and an outro card.
   Use Shot.find(name) for anything that moves, so the camera follows it.
4. Add a small client-only LocalScript, usable only in Studio
   (RunService:IsStudio()), that calls Reel.collectAll() and plays the
   reel on a key (P). Keep it out of anything that ships to players, or
   gate it behind IsStudio.
5. Check it. If you have Roblox Studio MCP tools, start a playtest, play
   the reel, and confirm in the output that you see `[Reel] start`, one
   `[Reel] cut` per shot, and `[Reel] end` with no warnings. Take a
   screenshot at each cut to check the framing, and fix any shot that
   misses its subject. If you don't have those tools, tell me exactly
   what to run and what output to expect.
6. Tell me how to record it: press Ctrl+Shift+G in the playtest to hide
   Roblox's top bar, start a screen recorder, press P, and trim the
   video to the [Reel] start and end markers (the README's "Recording"
   section).

Rules: don't change gameplay code beyond what the beats need to trigger
the feature. Keep reels and the trigger script client-side. Ask me
before adding anything to the server. Don't publish anything.
```

---

## Tips

- **Before and after.** Add `variants = { "before", "after" }` and branch on `take.variant` in your beats. Both takes use the same seed, so random effects match.
- **Several reels.** `Reel.chain(Reel.expand("skills/*"))` plays every reel under `skills/`, one after another.
- **Clean background.** `Reel.Cyc.build(workspace, CFrame.new(0, 500, 0))` on the server gives you a studio plate in a flat void. Frame it with `Shot.frame` and set `haze = false`.
