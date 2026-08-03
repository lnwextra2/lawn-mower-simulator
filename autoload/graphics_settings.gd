extends Node

## Player graphics settings: the values, saved to disk, applied live. The options
## UI edits these; the systems that render (lighting, bubbles) read them. Single
## source of truth - nothing else stores a graphics preference.
##
## `changed` fires whenever a value moves (from the UI or a load), so readers can
## re-apply. Every change also saves, so settings persist without a Save button.

signal changed

const PATH := "user://graphics.cfg"

# --- Bloom ---
var bloom_enabled: bool = true
var bloom_intensity: float = 0.4
# --- Clouds ---
var clouds_enabled: bool = true
var cloud_coverage: float = 0.5
var cloud_speed: float = 0.02
# --- Bubbles ---
var bubbles_enabled: bool = true
var bubble_amount: int = 40
var bubble_rim_glow: float = 2.5

## The keys that get saved/loaded and shown in the UI, in order.
const KEYS := [
	"bloom_enabled", "bloom_intensity",
	"clouds_enabled", "cloud_coverage", "cloud_speed",
	"bubbles_enabled", "bubble_amount", "bubble_rim_glow",
]

## UI metadata per setting: which section it sits in, its label, control type and
## range. The options menu builds itself from this - add a setting to KEYS and
## here and it appears in the menu with no UI code to touch.
const META := {
	"bloom_enabled": {"section": "Bloom", "label": "เปิด Bloom", "type": "bool"},
	"bloom_intensity": {"section": "Bloom", "label": "ความแรง", "type": "float", "min": 0.0, "max": 2.0, "step": 0.05},
	"clouds_enabled": {"section": "เมฆ", "label": "เปิดเมฆ", "type": "bool"},
	"cloud_coverage": {"section": "เมฆ", "label": "ปริมาณ", "type": "float", "min": 0.0, "max": 1.0, "step": 0.02},
	"cloud_speed": {"section": "เมฆ", "label": "ความเร็ว", "type": "float", "min": 0.0, "max": 0.2, "step": 0.005},
	"bubbles_enabled": {"section": "ฟองลอย", "label": "เปิดฟอง", "type": "bool"},
	"bubble_amount": {"section": "ฟองลอย", "label": "จำนวน", "type": "int", "min": 0, "max": 200, "step": 1},
	"bubble_rim_glow": {"section": "ฟองลอย", "label": "ความเรือง", "type": "float", "min": 1.0, "max": 6.0, "step": 0.1},
}

func _ready() -> void:
	load_settings()

## Set one value by name, then notify and persist. The UI calls this so it never
## has to know how each value is applied - it just moves the number.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	changed.emit()
	save_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("graphics", key, get(key))
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return   # no saved file yet - keep the defaults above
	for key in KEYS:
		if cfg.has_section_key("graphics", key):
			set(key, cfg.get_value("graphics", key))
	changed.emit()
