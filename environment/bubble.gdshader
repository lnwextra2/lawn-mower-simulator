shader_type spatial;
// A clear water bubble: mostly transparent, with a thin cool-white rim at the
// edge and a small sharp glint where light catches it. No rainbow film - that
// iridescence reads as an oily/chemical soap bubble; plain water is just clear
// glass with highlights. Unshaded and see-through, so it stays subtle, including
// at night (no hard bright disc against a dark sky).
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

// Tightness of the bright edge rim: higher = thinner rim hugging the silhouette.
uniform float rim_power : hint_range(0.5, 12.0) = 4.0;
// Opacity of the edge rim.
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.4;
// Faint body across the whole bubble so it isn't invisible head-on. Keep low -
// water is clear.
uniform float film_alpha : hint_range(0.0, 1.0) = 0.06;
// The water's tint - a touch of cool blue-white, like clean water.
uniform vec3 water_tint : source_color = vec3(0.85, 0.93, 1.0);
// The glint. spec_power: higher = smaller, sharper. spec_strength: how bright.
uniform float spec_power : hint_range(2.0, 300.0) = 90.0;
uniform float spec_strength : hint_range(0.0, 3.0) = 1.0;
// Direction the glint comes from (a stand-in for the sun).
uniform vec3 spec_dir = vec3(0.4, 0.8, 0.3);

void fragment() {
	vec3 n = normalize(NORMAL);
	float facing = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	// Bright at glancing angles (the edge), clear head-on.
	float rim = pow(1.0 - facing, rim_power);
	// A tight white highlight where the surface faces the "sun".
	float spec = pow(max(dot(n, normalize(spec_dir)), 0.0), spec_power) * spec_strength;
	// Clear water: cool-white tint plus the white glint, no rainbow.
	ALBEDO = water_tint + vec3(spec);
	ALPHA = clamp(film_alpha + rim * rim_alpha + spec, 0.0, 1.0);
}
