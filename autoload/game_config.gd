extends Node

# Player movement
const PLAYER_SPEED: float = 5.0
const PLAYER_JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.003
const PLAYER_SPRINT_SPEED: float = 8.0
# Units/sec^2. Walking is near-instant - having to wait to start moving at all
# just feels unresponsive. Only the stretch ABOVE walking speed ramps slowly, so
# sprinting stays a commitment you build up to (~0.75s from walk to full sprint).
const PLAYER_WALK_ACCELERATION: float = 60.0
const PLAYER_SPRINT_ACCELERATION: float = 4.0
# Stopping is quicker than starting - it keeps control tight and stops the player
# skating past where they meant to stop.
const PLAYER_DECELERATION: float = 20.0
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_RATE: float = 25.0
const STAMINA_REGEN_RATE: float = 15.0
const PLAYER_CARRY_CAPACITY: float = 100.0
const DROPOFF_RADIUS: float = 2.0
const SELL_RATE: float = 1.0

#GRASS
const GRASS_COUNT: int = 5000   # tufts are ~326 tris each, so ~1.6M tris total.
								# Dial down if the framerate suffers, up if the field
								# still looks thin. NOTE: this is also the total grass
								# (and so gold) available in the map.
const GRASS_FIELD_SIZE: float = 38.0
# In-game days for a blade to grow back from nothing to full height, carried over
# from the prototype's CONFIG.grass.regrowDays.
const GRASS_REGROW_DAYS: float = 3.0 #default 3.0 Day of Fully Growth

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
const DAY_NIGHT_CYCLE_DURATION: float = 480.0 #second / 1 Day
const DAY_NIGHT_START_TIME: float = 0.25
