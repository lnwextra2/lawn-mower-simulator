shader_type canvas_item;

// A red vignette that eats in from the screen edges. The player reads their
// health from how much red is standing there, not from any counter - so this
// is the whole health UI. intensity is driven from code (hud.gd) off the
// current hearts; everything else is a look knob you can tune by eye in the
// material inspector.

// 0 = clean screen, 1 = full blood. Set by hud.gd, don't hand-edit.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// The red itself. Darker/less saturated reads as "grimmer", brighter as "alarm".
uniform vec4 blood_color : source_color = vec4(0.55, 0.02, 0.02, 1.0);
// How far from the centre the red starts, as a fraction of the way to the
// corner. Higher = the clear middle is bigger and the red hugs the very edge.
uniform float edge_start : hint_range(0.0, 1.0) = 0.35;
// How soft the fade from clear to red is. Small = a hard ring, large = a gentle
// wash creeping inward.
uniform float softness : hint_range(0.01, 1.0) = 0.55;

void fragment() {
	// Distance from screen centre, normalised so a corner is ~1.0.
	vec2 d = UV - vec2(0.5);
	float dist = length(d) * 1.41421356;
	float edge = smoothstep(edge_start, edge_start + softness, dist);
	COLOR = vec4(blood_color.rgb, edge * intensity);
}
