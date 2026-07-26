extends Node

# Player movement
const PLAYER_SPEED: float = 5.0
const PLAYER_JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.003
const PLAYER_SPRINT_SPEED: float = 8.0
const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN_RATE: float = 25.0
const STAMINA_REGEN_RATE: float = 15.0
const PLAYER_CARRY_CAPACITY: float = 100.0
const DROPOFF_RADIUS: float = 2.0
const SELL_RATE: float = 1.0

#GRASS
const GRASS_COUNT: int = 10000
const GRASS_FIELD_SIZE: float = 38.0

#GRASS THINGS
const HAND_CUT_RADIUS: float = 1.0
const COLLECT_RADIUS: float = 1.5   # reach for scooping cut grass off the ground
const GRASS_THROW_FORCE: float = 6.0  # forward speed of a thrown armful
const GRASS_THROW_LIFT: float = 3.5   # upward speed, i.e. how high the arc goes
 
#Time
const DAY_NIGHT_CYCLE_DURATION: float = 480.0 #second / 1 Day
const DAY_NIGHT_START_TIME: float = 0.25
