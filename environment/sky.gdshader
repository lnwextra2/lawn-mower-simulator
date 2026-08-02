shader_type sky;

// The daytime sky, as a shader so it can carry clouds the ProceduralSky can't.
// Vertical gradient + a sun glow at the light's direction, with procedural clouds
// from 3D FBM noise sampled straight on the view direction - no flat projection to
// stretch, so no streaking at the horizon. Fractal noise over a few octaves reads
// as soft, random, smoke-like puffs, and it drifts with TIME. Gradient and sun
// colours are driven per-frame from lighting_controller.

uniform vec3 sky_top_color : source_color = vec3(0.25, 0.55, 0.95);
uniform vec3 sky_horizon_color : source_color = vec3(0.72, 0.88, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
// Tightness of the sun glow: higher = smaller, sharper.
uniform float sun_glow : hint_range(1.0, 400.0) = 90.0;

uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
// How much sky the clouds cover. 0 = clear, 1 = overcast.
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
// Soft edge of the puffs. Small = crisp cauliflower, large = wispy haze.
uniform float cloud_softness : hint_range(0.01, 0.6) = 0.25;
// Size of the puffs (higher = smaller, busier).
uniform float cloud_scale = 3.0;
uniform float cloud_speed = 0.02;
// How opaque clouds get at full density.
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.85;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	// Vertical gradient: horizon colour at the horizon, top colour overhead.
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon_color, sky_top_color, pow(h, 0.5));
	if (dir.y < 0.0) {
		col = sky_horizon_color;
	}
	// Sun glow at the directional light's direction.
	float sd = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	col += sun_color * pow(sd, sun_glow) * LIGHT0_ENERGY;
	// Clouds: 3D FBM sampled on the view direction itself, so they wrap the dome
	// evenly with no stretch. Drifting the sample point moves them across the sky.
	if (dir.y > 0.02) {
		vec3 p = dir * cloud_scale + vec3(TIME * cloud_speed, 0.0, 0.0);
		float n = fbm(p);
		float cloud = smoothstep(cloud_coverage, cloud_coverage + cloud_softness, n);
		// Fade clouds out before the horizon so they don't pile into a hard band.
		float horizon_fade = smoothstep(0.02, 0.4, dir.y);
		col = mix(col, cloud_color, cloud * cloud_opacity * horizon_fade);
	}
	COLOR = col;
}
