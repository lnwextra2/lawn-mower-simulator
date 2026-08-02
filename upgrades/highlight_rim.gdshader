shader_type spatial;
// Added as a second pass over a target's own material to rim-light its edges
// while it's a throw target. Fresnel: a fragment glows by how side-on its surface
// is to the camera, so the silhouette edge lights up and the faces pointing at
// you stay untouched - the "only the outline, not the fill" look, and it sits ON
// the surface so there's no gap like a grown-shell outline has.
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 rim_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
// Higher = thinner, sharper rim hugging the very edge; lower = a wider, softer
// band creeping in from the edge.
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
// Overall brightness of the rim.
uniform float rim_strength : hint_range(0.0, 4.0) = 1.5;
// A gentle breathing pulse so the highlight reads as "active", not a paint job.
// amount 0 = steady; speed is roughly pulses per second.
uniform float pulse_speed : hint_range(0.0, 12.0) = 3.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	ALBEDO = rim_color.rgb;
	ALPHA = rim * rim_strength * pulse;
}
