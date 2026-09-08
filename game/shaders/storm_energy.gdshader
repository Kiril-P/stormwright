shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float radiance : hint_range(0.0, 8.0) = 1.8;

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * radiance;
	ALPHA = COLOR.a * opacity;
}
