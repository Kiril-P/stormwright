shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

instance uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float soft_edge = pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.1;
	ALPHA = COLOR.a * opacity * soft_edge;
}
