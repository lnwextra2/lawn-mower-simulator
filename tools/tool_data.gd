extends Resource
class_name ToolData

## One held tool's data. Approach A (data-driven): tools differ only by
## these values, and the player reads them through this single interface.
## When a tool eventually needs behavior code of its own (scythe's arc cut,
## trimmer's held spin), add a method here - the player keeps calling the
## same interface, so it becomes an additive A->B step, not a rewrite.

@export var tool_name: String = "Knife"
@export var cut_radius: float = 1.0
## The posed first-person model shown in hand for this tool. Instanced under the
## player's SwingPivot when the tool becomes the held one. Leave empty for no
## view model (nothing shown).
@export var view_model_scene: PackedScene
## The model shown when this tool is lying in the world as a pickup, posed to
## rest on the ground (distinct from the in-hand pose). Leave empty to fall back
## to the pickup's placeholder box.
@export var world_model_scene: PackedScene
