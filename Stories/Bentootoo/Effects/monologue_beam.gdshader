shader_type canvas_item;
render_mode blend_add;

// Screen-space theatre spotlight. The target is the speaker's head in UV space.
uniform vec2 target_uv = vec2(0.5, 0.55);
uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform float top_width : hint_range(0.001, 0.2) = 0.012;
uniform float head_width : hint_range(0.01, 0.4) = 0.09;
uniform float edge_feather : hint_range(0.001, 0.1) = 0.025;
uniform float end_feather : hint_range(0.001, 0.1) = 0.035;
uniform float pulse_amount : hint_range(0.0, 0.2) = 0.025;
uniform float pulse_speed : hint_range(0.0, 4.0) = 0.9;
uniform vec4 light_color : source_color = vec4(1.0, 0.88, 0.62, 1.0);


void fragment() {
	float target_y = max(target_uv.y, 0.001);
	float progress = clamp(SCREEN_UV.y / target_y, 0.0, 1.0);
	float half_width = mix(top_width, head_width, progress);

	float horizontal = 1.0 - smoothstep(
		half_width,
		half_width + edge_feather,
		abs(SCREEN_UV.x - target_uv.x)
	);
	float below_top = smoothstep(-end_feather, 0.0, SCREEN_UV.y);
	float before_head = 1.0 - smoothstep(
		target_uv.y,
		target_uv.y + end_feather,
		SCREEN_UV.y
	);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	float amount = horizontal * below_top * before_head * intensity * pulse;

	COLOR = vec4(light_color.rgb * amount * light_color.a, 1.0);
}
