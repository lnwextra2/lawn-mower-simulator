shader_type spatial;

// The lantern is one mesh with one texture - metal frame and lit flame/glass
// share it - so the glow can't be split by material. Instead it's split by
// BRIGHTNESS: the flame and glass are the bright pixels of the texture, the
// frame the dark ones, so only pixels above a threshold emit. The frame still
// lights normally from the scene (this shader is lit, not unshaded), so at night
// it goes dark while the flame keeps glowing - which is the whole point.

uniform sampler2D tex : source_color;
// Turned up by code when the lantern is lit, 0 when dark.
uniform float glow : hint_range(0.0, 5.0) = 0.0;
// Texture brightness a pixel needs before it emits. Raise it until the metal
// frame stops glowing and only the flame/glass remain.
uniform float threshold : hint_range(0.0, 1.0) = 0.6;
// Soft edge above the threshold, so the glowing part doesn't cut in hard.
uniform float softness : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	// Perceptual brightness of this texel.
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float mask = smoothstep(threshold, threshold + softness, lum);
	EMISSION = c.rgb * mask * glow;
}
