shader_type spatial;
// A soft glowing orb for the moon, to match the ProceduralSky sun's glow instead
// of reading as a hard disc. On a sphere, the surface facing the camera is
// brightest and it fades to nothing at the silhouette - so it looks like light,
// not a solid ball. Additive, so it glows against the night sky.
render_mode blend_add, unshaded, cull_back, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
// Higher = tighter bright core with a wider soft falloff; lower = broad even glow.
uniform float core_power : hint_range(0.3, 6.0) = 1.6;
uniform float strength : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = glow_color.rgb;
	ALPHA = pow(facing, core_power) * strength;
}
