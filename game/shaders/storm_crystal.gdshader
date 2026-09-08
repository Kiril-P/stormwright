shader_type spatial;
render_mode cull_disabled;

uniform bool hostile = false;

void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	vec3 body = hostile ? vec3(COLOR.b, COLOR.g * 0.22 + 0.025, COLOR.r * 0.10 + 0.02) : COLOR.rgb;
	vec3 rim_tint = hostile ? vec3(0.8, 0.18, 0.06) : vec3(0.03, 0.5, 0.7);
	ALBEDO = body;
	METALLIC = 0.36;
	ROUGHNESS = 0.17;
	EMISSION = body * 0.55 + rim_tint * rim * 0.32;
}
