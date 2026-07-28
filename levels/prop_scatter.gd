@tool
extends Node3D
class_name PropScatter

## Seeds the CC0 nature props as scene dressing, then gets out of your way.
##
## This is a LAYOUT TOOL, not a runtime system. Press "Scatter (editable)" in the
## Inspector and it fills the scene with real, hand-editable prop nodes - a forest
## ring around the map edge, rocks and shrubs in the wilderness between the grass
## fields. From then on they're ordinary nodes: select, drag, rotate, delete or
## duplicate them in the 3D viewport by eye. Press again for a fresh random start,
## "Clear props" to empty it. The scatter just gives you a good first pass to
## art-direct from, instead of composing dozens of props from a blank floor.
##
## It instances the prop WRAPPER scenes in environment/props/, NOT the raw .glb.
## Each wrapper already carries the right collider (a trunk pillar for a tree, a
## footprint for a rock, none for a shrub you brush past) and has shadows off. So
## collision lives in ONE place per prop type - fix a collider in its .tscn and
## every scattered copy updates at once, instead of nudging each tree by hand.
##
## Placement rejects every grass field and the base yard, so nothing spawns
## through a building or buries a field edge. If the node is left in a scene with
## no baked children (e.g. a throwaway test), it still scatters once at runtime as
## a fallback, unowned.

# pine_b is intentionally absent: its glb import is stuck at valid=false, so there
# is no wrapper for it. Left for a separate fix rather than silently swapped in.
const TREES: Array[PackedScene] = [
	preload("res://environment/props/tree_twisted_a.tscn"),
	preload("res://environment/props/tree_twisted_b.tscn"),
	preload("res://environment/props/pine_a.tscn"),
]
const ROCKS: Array[PackedScene] = [
	preload("res://environment/props/rock_a.tscn"),
	preload("res://environment/props/rock_b.tscn"),
]
const PLANTS: Array[PackedScene] = [
	preload("res://environment/props/plant.tscn"),
	preload("res://environment/props/plant_big.tscn"),
]

## Inspector "buttons": tick either box to run it - it fires and unticks itself.
## A checkbox-as-button rather than @export_tool_button, whose Callable comes back
## Nil once the scene has been saved and reloaded.
@export var scatter_editable: bool = false:
	set(v):
		scatter_editable = false
		if v and Engine.is_editor_hint():
			_bake_layout()
@export var clear_props: bool = false:
	set(v):
		clear_props = false
		if v and Engine.is_editor_hint():
			_clear_layout()

@export var rng_seed: int = 1337
## Stay just inside the 160-wide floor so nothing hangs off the edge.
@export var map_half: float = 78.0
@export var tree_count: int = 44
@export var rock_count: int = 22
@export var plant_count: int = 30
## Breathing room added around each field and the yard. Also absorbs the models'
## off-centre pivots, so a canopy placed just outside a field can't poke into it.
@export var field_margin: float = 3.5
## The base and its scattered stands/cart/fuel/repair reach past the yard box,
## so clear a slightly larger rectangle around it (world x,z min/max). If the base
## is moved, update these or props will spawn on top of it.
@export var base_min := Vector2(2.0, -13.0)
@export var base_max := Vector2(27.0, 23.0)

## <1 pushes a coordinate toward the map edge; trees use it to read as a rim of
## forest, rocks/plants stay uniform (1.0) so they fill the interior evenly.
const TREE_EDGE_BIAS := 0.6
const SCALE_RANGE := Vector2(0.85, 1.25)
const MAX_TRIES := 24

var _fields: Array[Rect2] = []
## The scene the baked nodes are saved into (their `owner`). Null while scattering
## at runtime, where nodes are transient and want no owner.
var _bake_root: Node = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return   # in the editor, scattering happens only on the button, never on load
	if get_child_count() > 0:
		return   # a baked layout is already here; leave it alone
	_generate(null)

## Inspector button: replace whatever's here with a fresh, editable layout.
func _bake_layout() -> void:
	if not Engine.is_editor_hint():
		return
	var root := get_tree().edited_scene_root
	if root == null:
		push_warning("PropScatter: open the scene before scattering.")
		return
	_clear_layout()
	_generate(root)

## Inspector button: remove every prop this node holds.
func _clear_layout() -> void:
	for c in get_children():
		remove_child(c)
		c.free()

func _generate(owner_root: Node) -> void:
	_bake_root = owner_root
	_fields.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_collect_fields()
	_scatter(TREES, tree_count, rng, TREE_EDGE_BIAS, "Tree")
	_scatter(ROCKS, rock_count, rng, 1.0, "Rock")
	_scatter(PLANTS, plant_count, rng, 1.0, "Plant")

## Reads each placed field's footprint from the group, in world space, so this
## works no matter how the T-layout is arranged or resized.
func _collect_fields() -> void:
	for f in get_tree().get_nodes_in_group("grass_field"):
		var half: float = f.field_size * 0.5 + field_margin
		var c := Vector2(f.global_position.x, f.global_position.z)
		_fields.append(Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0))

func _scatter(models: Array[PackedScene], count: int, rng: RandomNumberGenerator, bias: float, prefix: String) -> void:
	for i in count:
		var p: Variant = _sample(rng, bias)
		if p == null:
			continue
		var pos: Vector2 = p
		# The wrapper brings its own collider and shadow settings; the scatter only
		# decides where each one stands, how it's turned, and how big it is.
		var inst := models[rng.randi() % models.size()].instantiate() as Node3D
		add_child(inst)
		inst.name = "%s_%02d" % [prefix, i]
		inst.position = Vector3(pos.x, 0.0, pos.y)
		inst.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(SCALE_RANGE.x, SCALE_RANGE.y)
		inst.scale = Vector3(s, s, s)
		_claim(inst)

## Marks a baked prop to be saved into the edited scene as an ordinary editable
## instance. Only the instance ROOT is owned - the wrapper's own children belong
## to that instanced scene and must not be re-owned. At runtime `_bake_root` is
## null and this does nothing.
func _claim(node: Node) -> void:
	if _bake_root != null:
		node.owner = _bake_root

## Rejection-samples a wilderness spot. Returns a Vector2, or null if every try
## landed on a field or the yard (rare; the wilderness dwarfs both).
func _sample(rng: RandomNumberGenerator, bias: float) -> Variant:
	for _t in MAX_TRIES:
		var p := Vector2(_biased(rng, bias), _biased(rng, bias))
		if _blocked(p):
			continue
		return p
	return null

## One coordinate in [-map_half, map_half]. bias<1 skews the magnitude outward.
func _biased(rng: RandomNumberGenerator, bias: float) -> float:
	var u := rng.randf_range(-1.0, 1.0)
	return signf(u) * pow(absf(u), bias) * map_half

func _blocked(p: Vector2) -> bool:
	if p.x >= base_min.x and p.x <= base_max.x and p.y >= base_min.y and p.y <= base_max.y:
		return true
	for r in _fields:
		if r.has_point(p):
			return true
	return false
