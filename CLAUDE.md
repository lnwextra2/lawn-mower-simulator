# Lawn Mower Simulator — Project Context (Godot Edition)

## WHAT
First-person 3D survival horror disguised as a lawn-mowing simulator, built in
**Godot 4.x**. This is a fresh Godot project — no code ported from the earlier
prototype. A Three.js/HTML prototype of the early systems (day/night, grass
cutting/regrowth, cart, economy) lives right next to this project as
`lawn_mower_simulator.html` in the same repo root (context on its decisions:
`CLAUDE_html_prototype.md`) — **treat it as a design reference, not code to
port.**
It answers "what did we already decide about X" (exact formulas, tuning
numbers, edge cases already solved) faster than re-deriving from scratch, but
the Godot version should use idiomatic Godot patterns even where that means
solving something differently than the JS version did.

## WHY
Inspired by *Pumpkin Panic* (farming-sim-by-day, horror-by-night) — inspired-by,
not a clone. Core loop: mow grass by day → haul it in a cart → sell for gold →
buy upgrades/unlocks → survive the night → repeat.

## Game design spec (unchanged from the prototype — still the target)
- First-person, one held item at a time (knife = empty-hands default, belt-clips).
  Every held tool can also operate the grass cart.
- Sprint with limited stamina. Jump exists for realism, not central to gameplay.
- 3 hearts — deliberately more forgiving than Pumpkin Panic's harder curve.
- Day/night cycle. A bed exists but cannot be slept in.
- Night monsters are event-based, staged appearances, not roaming zombies —
  each with its own distinct mechanic. Avoid "keep your distance from a
  wandering enemy."
- Player can hide in the house, but the door can be broken down — deliberate
  pressure to go out and earn gold to repair it rather than camp until dawn.
- **No fighting back, ever.** At most, temporarily drive a monster off.
- Shop: 4 unlockable areas (higher-value grass) · tools (knife→trimmer→
  scythe→ride-on mower) · tool repair · expensive 1-HP heal · lantern fuel ·
  light posts (fixed unlockable spots) · upgrades (sale bonus, move speed,
  cart capacity, soil/regrowth speed, faster cart auto-collect).

### Decided 2026-07-27 (was open, now settled — don't reopen without the owner)
- **No tax system.** The gold sink is *tool repair + lantern fuel* instead:
  both scale with how much you actually play, and unlike a tax they're felt
  in the moment rather than deducted off-screen.
- **Tools dull, they never break.** Wear reduces cutting reach and raises the
  minimum grass height a tool can catch — a blunt blade can't bite short
  grass. Deliberately not a random "chance to fail": randomness in the action
  the player performs most reads as the game cheating. Never becomes
  unusable, so a worn tool is a decision (repair, or work around it) and
  never a dead stop in the field at night.
- **Tools have domains, split by grass height.** The scythe clears anything,
  tall growth included; the ride-on mower is fast and wide but can't drive
  into deep grass. So the mower comes *after* the scythe (order changed) and
  never obsoletes it: scythe knocks wild ground down, the mower then keeps
  that ground cropped, and ground left to regrow too long needs the scythe
  again.
- **The mower is the end-game rig, but only by towing the cart.** The mower
  cuts — fast and wide — and tows; it does *not* pick grass up. Collecting
  stays the cart's job, which it already had ("faster cart auto-collect" was
  always a listed upgrade). Mower alone leaves cut grass on the ground, so the
  cart is a further step to buy rather than something the mower obsoletes, and
  both cart upgrades keep their point. The mower is loud and noise draws
  monsters: late game buys speed and money at the cost of danger, rather than
  buying safety.
- **Refuelling happens at base.** A fuel tank there, hold-to-fill: fuel flows
  in while gold drains, and releasing stops it, so "fill as much as you can
  afford" is the player's call, not a calculation. Forcing the trip home
  keeps the walk back at night meaningful. A portable can is a later,
  expensive shop upgrade — convenience earned, not assumed.
- **Grass regrowth is real-time and phase-independent.** A blade grows 0→100%
  over GRASS_REGROW_DAYS in-game days, each blade at a slightly different
  rate so the field fills in patchily rather than stepping in lockstep (the
  prototype grew every blade together every 4 in-game hours). Grass is
  *measured, not counted*: cutting a half-grown blade yields half as much.

- **Open questions — do not invent answers, raise them:** win condition
  (leading idea: pay off a debt for freedom, not finalized), which monsters +
  their mechanics.

## Godot project conventions (establish these early, keep them consistent)
This is a from-scratch project, so there's no "current architecture" yet —
these are the patterns to set up deliberately in the first few sessions,
not retrofit later:

- **Autoload singletons** for the global managers the prototype had as plain
  JS objects/classes (`Input` config, `Economy`, `DayNight`, `GrassSys`,
  `Cart`). Godot's Autoload is the direct equivalent — a script that's always
  loaded and globally accessible by name. Don't reinvent a service-locator
  pattern on top of this; Autoload already is one.
- **Scenes over factory functions.** The prototype manually built THREE.js
  meshes in JS constructors (`buildTools()`, `buildWorld()`, etc.) because it
  had no editor. Godot's native equivalent is a `.tscn` scene you build once
  in the editor and `instantiate()` at runtime (monsters, tools, cart, grass
  blade if not using a MultiMesh) — prefer this over hand-building node trees
  in code, since it's what the engine is actually good at.
- **MultiMeshInstance3D for the grass field**, not 10,000 individual nodes —
  this is the direct Godot equivalent of the prototype's `InstancedMesh` +
  Float32Array approach. The same per-cell spatial bucketing idea (for
  "what's near point P" queries) still applies, but check whether Godot's
  own spatial query tools (`Area3D` overlap queries, `PhysicsServer3D`
  shape queries) already cover the need before hand-rolling a grid — Godot
  has built-in spatial partitioning the browser/Three.js prototype didn't.
- **Input Map (Project Settings → Input Map)** instead of a hand-rolled
  `Input` object with raw keycodes. Define actions (`move_forward`,
  `interact`, `drop`, `attack`) there once; read them via `Input.is_action_pressed()` /
  `Input.is_action_just_pressed()` (the latter is the built-in equivalent of
  the prototype's manual edge-trigger `consumeX()` pattern — use it directly
  instead of reimplementing edge-triggering by hand).
- **Signals for decoupling**, direct Autoload calls where a signal would be
  overkill. E.g. `GrassSys` emitting a `grass_cut(amount)` signal that
  `Economy`/UI can listen to is more idiomatic than every system reaching
  into every other system directly — but don't force a signal where a plain
  function call on an Autoload is simpler and the coupling is already
  intentional (e.g. `Cart` calling `GrassSys.collect_near()` directly is
  fine, that's a real dependency, not an event).
- **A Resource (`.tres`) or an Autoload `GameConfig` script** for the tuning
  constants that lived in the JS `CONFIG` object (cart capacity, sell rate,
  regrow days, cycle duration, etc.) — single source of truth, same
  principle as before, different mechanism.

## How this project likes to be worked on (carried over, Godot-adapted)
1. **Never trust a commit message's description of what changed — read the
   actual diff.** This bit the JS prototype for real more than once. Same
   discipline applies here: `git diff` before trusting a summary, whether the
   summary is Claude's own or a person's.
2. **Incremental, targeted patches over rewrites.** A full-scene rewrite is
   the one move most likely to introduce a regression that goes undetected,
   because nothing gets checked against prior behavior. If a rewrite is
   truly necessary, write the "must-preserve" behavior list first, verify
   against it after.
3. **Keep gameplay logic testable without running the game.** GDScript
   functions that take plain values/Vectors and return a result (no node
   tree mutation inside) can be run headless via `godot --headless --script
   res://some_test.gd` or a proper test framework (GUT - Godot Unit Test - is
   the closest equivalent to the ad hoc `node --check` + standalone `.mjs`
   scripts the prototype used for pure-logic verification). Prefer this over
   "looks right when I press play" for anything with real math in it
   (economy, regrowth timing, collision).
4. **Scope discipline.** Implement only what's asked. Flag out-of-scope
   issues found along the way instead of silently fixing them, unless the
   fix is a genuine prerequisite. For ambiguous requests: large/hard-to-
   reverse interpretations → ask first; small/reversible → pick the sensible
   option and say so, in the same reply.
5. **Single source of truth.** Tuning numbers live in `GameConfig`, not
   scattered magic numbers in scripts. Shared math/logic gets a named
   function, not copy-pasted between scripts.
6. **Commit often, in `git`.** This replaces the prototype's in-file comment
   commit log — same spirit (what changed, why, what was verified), just
   living in `git log` instead of a comment block. Don't let commit messages
   undersell the actual diff (see rule 1).

## Priority when things conflict
Gameplay → Behavior → Readability → Architecture → Performance → Code
Shortness. In a horror game, *feel* is the product — a technically clean
system that feels wrong has failed regardless of how idiomatic the Godot
code is.

## Communication preference
Explanations in Thai, technical terms/code/node names in English. Keep code
explanations short with the reasoning, not long prose. Reference scene/script
names when pointing at something. Say directly when unsure rather than
guessing confidently. One short piece of feedback per round beats a big pile
of spec changes at once.
