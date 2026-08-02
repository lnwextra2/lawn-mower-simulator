extends Resource
class_name UpgradeData

## One upgrade, as data (same Approach-A shape as ToolData). An upgrade is a thing
## you pick up and hold; how you spend it depends on its mode:
##   SELF   - press the use key while holding it, and it applies to you/the world
##            at once (move speed, sale bonus, regrow).
##   TARGET - throw it at the matching object to apply it there (cart upgrades at
##            the cart, a light post at its slot). While you hold a TARGET
##            upgrade, valid targets glow faintly so you can see what it's for.
## Either way it's consumed on use - one upgrade, one effect, then it's gone.

enum Mode { SELF, TARGET }
enum Effect { MOVE_SPEED, CART_CAPACITY, CART_MAGNET, SALE_BONUS, REGROW_SPEED, LIGHT_POST }

@export var upgrade_name: String = "Upgrade"
@export var mode: Mode = Mode.SELF
@export var effect: Effect = Effect.MOVE_SPEED
## Size of the effect where one applies (e.g. +0.2 to move_speed_mult). Effects
## that are just on/off (magnet) ignore it.
@export var value: float = 0.2

## TARGET only: the group the thrown upgrade must land near to take. Empty for
## SELF upgrades.
@export var target_group: String = ""

## Model shown in hand while held. Leave empty for the pickup's placeholder.
@export var view_model_scene: PackedScene
## Model shown lying in the world as a pickup.
@export var world_model_scene: PackedScene
