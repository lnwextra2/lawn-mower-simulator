shader_type spatial;
render_mode cull_disabled;

// Recolours foliage: takes only the SHAPE of the leaves from the texture's alpha
// and paints them a flat colour of our choosing.
//
// StandardMaterial3D can't do this - its albedo_color multiplies the texture, so
// it can never turn red leaves green (multiplying can't add colour that isn't
// there). Here the texture's RGB is ignored entirely and only its alpha is read,
// which is what carries the leaf cut-outs.

uniform sampler2D shape_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.42, 0.60, 0.22, 1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	if (texture(shape_texture, UV).a < alpha_cutoff) {
		discard;   // outside a leaf - punch a hole so the flat quad isn't visible
	}
	ALBEDO = tint.rgb;
}
