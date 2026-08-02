extends Node

# Player movement
const PLAYER_SPEED: float = 5.0
const PLAYER_JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.003
const PLAYER_SPRINT_SPEED: float = 8.0
# Acceleration as a FRACTION of current top speed per second, not an absolute
# units/sec^2. Multiplied by top speed at runtime, so it scales WITH speed: a
# move-speed upgrade raises the cap and how fast you reach and turn at it in step,
# so handling stays as responsive as at base speed instead of getting sluggish as
# the cap climbs. Walking is near-instant; only the stretch above walking ramps
# slowly, so sprinting stays a commitment you build up to.
const PLAYER_WALK_ACCEL_FRACTION: float = 12.0
const PLAYER_SPRINT_ACCEL_FRACTION: float = 0.7
# Stopping (and turning, which decelerates the old heading) is quicker than
# starting - it keeps control tight and lets you change direction at speed
# without waiting to coast down first.
const PLAYER_DECEL_FRACTION: float = 4.0
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_RATE: float = 25.0
const STAMINA_REGEN_RATE: float = 15.0
const PLAYER_CARRY_CAPACITY: float = 100.0
const DROPOFF_RADIUS: float = 2.0
const SELL_RATE: float = 1.0

#GRASS
# Field size and blade count are per-field now (GrassField.field_size /
# blade_count), so the map can hold several fields of different sizes.
# The yard: a rectangle (in X/Z) kept clear of grass, where the base buildings
# stand. Without it the shop and the repair bay sit in the middle of the meadow
# with grass growing up through the floor. Given as opposite corners.
const YARD_MIN := Vector2(4.0, 4.0)
const YARD_MAX := Vector2(20.0, 20.0)
# In-game days for a blade to grow back from nothing to full height, carried over
# from the prototype's CONFIG.grass.regrowDays.
const GRASS_REGROW_DAYS: float = 3.0 #default 3.0 Day of Fully Growth

# How a fully blunt hand tool performs. It never stops working - a worn tool is
# a decision (repair, or work around it), never a dead stop in the field.
const TOOL_WORN_RADIUS_FACTOR: float = 0.55   # reach at full wear, vs sharp
const TOOL_WORN_MIN_GROWTH: float = 0.55      # at full wear, only grass at least
											  # this grown can be caught at all -
											  # a blunt blade can't bite short grass
# Below this fraction of a full tank an engine starts to stutter, so running dry
# is something you can see coming and decide about, not an ambush.
const TOOL_LOW_FUEL_FRACTION: float = 0.15
# End-over-end tumble given to a thrown tool. Very sensitive: a long item has
# little inertia about its short axes, so small changes here read as a big
# difference between "turns over once" and "whirls like a propeller".
const TOOL_THROW_SPIN: float = 0.06
# Refuelling: fuel flows while you hold the key, and gold drains with it, so the
# player decides how much to afford instead of the game calculating it.
const FUEL_FILL_RATE: float = 25.0        # fuel units per second
const FUEL_PRICE_PER_UNIT: float = 0.5    # gold per fuel unit
# The cart sweeps a wider path than you can reach by hand - it's doing the job
# for you, which is what it's for.
const CART_COLLECT_RADIUS: float = 2.2

# Collision layers. Layer 1 is the solid world; things on LAYER_LOOK_ONLY can be
# aimed at by the interact ray but are walked and driven straight through - for
# flat markers like the sale pad, which you're meant to stand and park on.
const LAYER_WORLD: int = 1
const LAYER_LOOK_ONLY: int = 1 << 2
# Loose items lying about - dropped tools. They fall and rest on the world, and
# can be aimed at, but they are not walls: the cart drives over them rather than
# being stopped dead by a scythe in the grass. (Shoving them aside with physics
# was tried first and fought the movement code, since a CharacterBody is stopped
# by the collision before any push it applies can take effect.)
const LAYER_LOOSE_ITEM: int = 1 << 3
const INTERACT_RAY_MASK: int = LAYER_WORLD | LAYER_LOOK_ONLY | LAYER_LOOSE_ITEM

#GRASS THINGS
const HAND_CUT_RADIUS: float = 1.0
const COLLECT_RADIUS: float = 1.5   # reach for scooping cut grass off the ground
const GRASS_THROW_FORCE: float = 6.0  # forward speed of a thrown armful
const GRASS_THROW_LIFT: float = 3.5   # upward speed, i.e. how high the arc goes
const GRASS_THROW_MOMENTUM: float = 0.8  # how much of the player's own speed the
										 # throw inherits (1.0 = all of it)

# Colours of grass by state. Cut grass is still fresh - a lighter, yellower
# green - not dried hay; it was standing a moment ago. Lives here because both
# the field's cut blades and the heaps the player drops must match.
const COLOR_GRASS_STANDING := Color(0.13, 0.55, 0.13)
const COLOR_GRASS_CUT := Color(0.42, 0.60, 0.22)
 
#Time
const DAY_NIGHT_CYCLE_DURATION: float = 60.0 #second / 1 Day
const DAY_NIGHT_START_TIME: float = 0.25
