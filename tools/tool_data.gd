extends Resource
class_name ToolData

## One held tool's data. Approach A (data-driven): tools differ only by
## these values, and the player reads them through this single interface.
## When a tool eventually needs behavior code of its own (scythe's arc cut,
## trimmer's held spin), add a method here - the player keeps calling the
## same interface, so it becomes an additive A->B step, not a rewrite.

@export var tool_name: String = "Knife"
@export var cut_radius: float = 1.0

## Needs both hands, so the lantern can't be held alongside it - it gets clipped
## to the hip while this tool is out. A one-handed tool (the sickle) leaves the
## off hand free to carry a light.
@export var two_handed: bool = false

## Wear added per unit of grass actually cut (1 unit = one fully-grown blade),
## NOT per swing: a blade dulls against what it cuts, so swinging at empty air
## costs nothing and clearing a thick patch costs a lot. This also makes upkeep
## scale with what you actually harvest rather than with how much you click.
## At 0.0005 a tool goes from sharp to fully blunt over ~2000 grass.
## Powered tools set this to 0: they never dull, they just run out of fuel.
##
## Wear itself is NOT stored here - this resource is shared by every copy of the
## tool, so per-item condition lives on whoever is holding it (see the player's
## held_wear and ToolPickup.tool_wear), exactly as lantern fuel does.
@export var wear_per_grass: float = 0.0005

## --- Powered tools ---
## A full tank, in seconds of running. 0 means this tool has no engine: it's
## hand-powered, dulls with use, and never runs out. Anything above 0 flips the
## tool to the other half of the rule - full power to the last drop, then it
## simply stops. Like wear, the actual fuel level is per-item and lives on the
## holder, not on this shared resource.
@export var fuel_capacity: float = 0.0
## Fuel burned per second while running. Kept separate from the tank size so a
## thirsty machine (the mower) and a frugal one can share a tank of the same
## fuel: running time is capacity / fuel_per_second.
@export var fuel_per_second: float = 1.0
## Cuts while the trigger is held instead of on a swing, so it eats whatever its
## head is touching rather than landing one blow at a time.
@export var continuous: bool = false
## How far in front of the player the cut lands. 0 cuts around the player (a
## swung blade); a long-handled tool reaches out ahead, which is the whole point
## of it - you clear ground before stepping into it.
@export var cut_offset: float = 0.0
## How many times a second a continuous tool bites. Cutting every frame would
## scan the whole field 60x a second for no visible gain.
@export var cuts_per_second: float = 10.0
## Pitch (degrees about X) the tool swings down to while running. At rest it sits
## in whatever pose its view model scene defines - shouldered, like every other
## tool - and only levels out at the grass when you pull the trigger, so idle and
## working read differently at a glance. Negative flips which way it tips.
@export var deploy_angle_deg: float = 0.0

## The posed first-person model shown in hand for this tool. Instanced under the
## player's SwingPivot when the tool becomes the held one. Leave empty for no
## view model (nothing shown).
@export var view_model_scene: PackedScene
## The model shown when this tool is lying in the world as a pickup, posed to
## rest on the ground (distinct from the in-hand pose). Leave empty to fall back
## to the pickup's placeholder box.
@export var world_model_scene: PackedScene
