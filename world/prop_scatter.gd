extends Node3D
class_name PropScatter

## Scatters the CC0 nature props as scene dressing: a forest ring that closes off
## the flat plane at the map edge, plus rocks and shrubs filling the wilderness
## between the grass fields. Procedural and seeded - the same choice GrassField
## already makes for its blades - so the test level stays readable instead of
## carrying dozens of hand-placed nodes with baked pivots, and the layout is
## reproducible and tunable from a handful of exports.
##
## Placement rejects every grass field and the base yard, so nothing sprouts up
## through a building or buries a field edge. Props are non-colliding for now,
## exactly like the grass: the models' pivots are off-centre (a trunk sits ~1m
## from its node origin), so a trunk-accurate collider is a follow-up, not a
## one-liner - flag it, don't fake it.

# pine_b.glb is intentionally absent: its import is stuck at valid=false, so it
# won't load. Left for a separate fix rather than silently swapped in broken.
const TREES: Array[PackedScene] = [
	preload("res://assets/models/nature/tree_twisted_a.glb"),
	preload("res://assets/models/nature/tree_twisted_b.glb"),
	preload("res://assets/models/nature/pine_a.glb"),
]
const ROCKS: Array[PackedScene] = [
	preload("res://assets/models/nature/rock_a.glb"),
	preload("res://assets/models/nature/rock_b.glb"),
]
const PLANTS: Array[PackedScene] = [
	preload("res://assets/models/nature/plant.glb"),
	preload("res://assets/models/nature/plant_big.glb"),
]

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
## so clear a slightly larger rectangle around it (world x,z min/max).
@export var base_min := Vector2(2.0, -13.0)
@export var base_max := Vector2(27.0, 23.0)

## <1 pushes a coordinate toward the map edge; trees use it to read as a rim of
## forest, rocks/plants stay uniform (1.0) so they fill the interior evenly.
const TREE_EDGE_BIAS := 0.6
const SCALE_RANGE := Vector2(0.85, 1.25)
const MAX_TRIES := 24

var _fields: Array[Rect2] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_collect_fields()
	_scatter(TREES, tree_count, rng, TREE_EDGE_BIAS)
	_scatter(ROCKS, rock_count, rng, 1.0)
	_scatter(PLANTS, plant_count, rng, 1.0)

## Reads each placed field's footprint from the group, in world space, so this
## works no matter how the T-layout is arranged or resized.
func _collect_fields() -> void:
	for f in get_tree().get_nodes_in_group("grass_field"):
		var half: float = f.field_size * 0.5 + field_margin
		var c := Vector2(f.global_position.x, f.global_position.z)
		_fields.append(Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0))

func _scatter(models: Array[PackedScene], count: int, rng: RandomNumberGenerator, bias: float) -> void:
	for _i in count:
		var p: Variant = _sample(rng, bias)
		if p == null:
			continue
		var pos: Vector2 = p
		var inst := models[rng.randi() % models.size()].instantiate() as Node3D
		add_child(inst)
		inst.position = Vector3(pos.x, 0.0, pos.y)
		inst.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(SCALE_RANGE.x, SCALE_RANGE.y)
		inst.scale = Vector3(s, s, s)
		_kill_shadows(inst)

## Dressing props don't cast shadows. These "low-poly" trees are ~10k tris each,
## and every one added is another caster the directional-light shadow map must
## redraw each frame - and since that map follows the camera, the cost lands on
## every turn. Dozens of scattered casters was what tanked the framerate on turn.
## Turning it off is nearly free visually (scattered background scenery reads fine
## without its own cast shadow) and is the difference between smooth and a slideshow.
func _kill_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_kill_shadows(c)

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
