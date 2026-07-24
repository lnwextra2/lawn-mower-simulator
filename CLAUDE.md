# Lawn Mower Simulator — Project Context

## WHAT
First-person 3D survival horror disguised as a lawn-mowing simulator. Single
self-contained HTML file (`lawn_mower_simulator.html`), Three.js r160 via
ES modules/importmap, no build step, no dependencies to install. Open the file
directly in a browser to run it.

## WHY
Inspired by *Pumpkin Panic* (farming-sim-by-day, horror-by-night) — inspired-by,
not a clone. Core loop: mow grass by day → haul it in a cart → sell for gold →
buy upgrades/unlocks → survive the night → repeat.

## Game design spec
- First-person, one held item at a time (knife = empty-hands default, belt-clips).
  Every held tool can also operate the grass cart.
- Sprint with limited stamina (not yet built). Jump exists for realism, not central.
- 3 hearts (not yet built) — deliberately more forgiving than Pumpkin Panic.
- Day/night cycle exists. A bed exists but cannot be slept in (not yet built).
- Night monsters (not yet built) are event-based staged appearances, each with
  its own distinct mechanic — NOT a "keep your distance from a wandering enemy"
  pattern.
- Player can hide in the house; the door can be broken down (not yet built) —
  deliberate pressure to go out and earn gold rather than camp until dawn.
- **No fighting back, ever.** At most, temporarily drive a monster off.
- Shop (not yet built): 4 unlockable areas · tools (knife→trimmer→ride-on
  mower→scythe) · 1-HP heal · lantern fuel · light posts · upgrades (sale
  bonus, move speed, cart capacity, soil/regrowth speed).
- **Open questions — do not invent answers, raise them if asked to touch these:**
  win condition (leading idea: pay off a debt for freedom, not finalized), tax
  system specifics (the gold-sink equivalent to Pumpkin Panic's seed-buying,
  not designed), which monsters + their mechanics, exactly how grass regrowth
  interacts with day/night (currently a flat real-time timer, phase-independent
  — that's a placeholder, not a decision).

## Current architecture (read the file before assuming — this drifts)
Class-based, one instance each: `EnvironmentBuilder` (env/collision),
`GrassManager` (grass/cutting/piles/regrowth), `ToolManager` (equip/drop/swing),
`Vehicle` (ride-on mower, cuts only — no cargo of its own), `CartManager`
(pushable cart, driven like `Vehicle`, the only thing that collects grass),
`DayNightManager`, `Economy`, `PlayerController` (camera-as-player + input
dispatch), plus static `Utils`/`Input` objects and a module-level `CONFIG`.

`Input` is one object: held-state booleans for movement, plus edge-triggered
one-shot flags (`interact`, `drop`, `attack`) each with `consumeX()`. **This is
the established convention for "on the frame this was pressed," not "while
held."** Follow it for any new one-shot action.

Known design tension: camera *is* the player (no separate entity). Fine today,
but hearts/damage/knockback, monster collision, hiding indoors, and cart-pushing
all eventually want a real player entity. Treat introducing one as its own
deliberate step, not folded into an unrelated feature.

## How this codebase likes to be worked on
1. **Never trust a commit-log description of what changed — read the actual
   diff.** A log claiming "fixed X" has, in this project's own history, turned
   out to only change a related-but-different mechanism. Grep for the specific
   claim; read the exact lines.
2. **Incremental, targeted patches over rewrites.** The one full rewrite this
   project saw introduced regressions that went undetected because nothing was
   diffed against prior behavior. A rewrite needs an explicit "must-preserve"
   checklist verified after.
3. **Pure math where it's gameplay logic.** `GrassManager.cutGrass()`/
   `collectNear()` etc. do their distance/angle math in plain numbers (no
   `THREE.Vector3` methods) even though `THREE.Vector3` is sitting right there
   in the caller — this is what makes them headlessly testable with `node`.
   Keep extending new gameplay logic the same way. Rendering-adjacent code
   (mesh/material updates) is fine to mix in the same function, following the
   existing precedent, rather than forcing an artificial split.
4. **Share the spatial grid.** `GrassManager` already has a uniform grid for
   "what's near point P" queries. New systems needing proximity queries
   (monster line-of-sight, light posts) should consider reusing it before
   inventing a new O(n) scan.
5. **Single source of truth.** Consolidate repeated constants into `CONFIG`.
   Extract shared math into a named helper instead of duplicating it (e.g.
   `cellIndexFor()`, `Economy.isNearDropOff()`).
6. **Scope discipline.** Implement only what's asked. Flag out-of-scope issues
   found along the way instead of silently fixing them, unless the fix is a
   genuine prerequisite. For ambiguous requests: large/hard-to-reverse
   interpretations → ask first; small/reversible → pick the sensible option
   and say so, in the same reply.
7. **Test what you can headlessly.** Extract the `<script type="module">` body
   (strip the `import` lines) and run `node --check` for syntax. For pure
   logic (grid math, state machines), write a small standalone `.mjs` that
   reimplements just that logic with stubbed side effects and assert against
   it — this project's history has caught real bugs this way (see e.g. the
   collect/deposit/regrowth timer interactions).
8. **Keep an in-file commit log** at the top of the HTML (what changed, why,
   what was verified) and bump the `Version:` line in that same header block.
   This has been the single most useful thing for resuming context across
   sessions — keep it honest and complete (see rule 1: don't let it undersell
   the actual diff).
9. **Versioning lives in git, not in the filename.** The filename stays
   `lawn_mower_simulator.html` forever — renaming per version breaks
   `git diff` across versions, which rule 1 depends on. One logical change =
   one commit; tag only real milestones (`git tag -a v0.13 -m "…"`). Remote is
   `origin` → `github.com/lnwextra2/lawn-mower-simulator`.

## Priority when things conflict
Gameplay → Behavior → Readability → Architecture → Performance → Code Shortness.
In a horror game, *feel* is the product — a technically clean system that
feels wrong has failed regardless of how elegant the code is.

## Communication preference
Explanations in Thai, technical terms/code/variable names in English. Keep
code explanations short with the reasoning, not long prose. Reference line
numbers/function names when pointing at something in the code. Say directly
when unsure rather than guessing confidently. One short piece of feedback per
round beats a big pile of spec changes at once.
