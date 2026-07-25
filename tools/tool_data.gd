extends Resource
class_name ToolData

## One held tool's data. Approach A (data-driven): tools differ only by
## these values, and the player reads them through this single interface.
## When a tool eventually needs behavior code of its own (scythe's arc cut,
## trimmer's held spin), add a method here - the player keeps calling the
## same interface, so it becomes an additive A->B step, not a rewrite.

@export var tool_name: String = "Knife"
@export var cut_radius: float = 1.0
