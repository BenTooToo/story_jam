shader_type canvas_item;
render_mode blend_add;

// 天光 / 丁达尔光束。
// 铺在房间最上层的一个全屏 ColorRect 上（Background/LightShafts）。
// blend_add = 只加亮、不压暗，所以压暗要靠下面那层黑色 ColorRect 滤镜。
//
// 坐标系：先把 UV 按 angle_deg 旋转，r.x 横切光束、r.y 沿光束方向。
//   angle_deg = 0    → 光从正上方打下来
//   angle_deg = 90   → 光从正左边打过来
//   angle_deg = -35  → 光从右上角斜着打下来

const int MAX_BEAMS = 8;

uniform float angle_deg = 0.0;

// 前两束位置写死（方便对准画面里的窗口/破口），多出来的用 seed 程序化铺开。
uniform int beam_count : hint_range(1, 8) = 3;
uniform float beam_pos_a = -0.20;
uniform float beam_pos_b = 0.12;
uniform float spread : hint_range(0.0, 2.0) = 1.1;
uniform float seed = 3.0;

uniform float shaft_w : hint_range(0.01, 0.60) = 0.09;
uniform float sway : hint_range(0.0, 0.20) = 0.020;
uniform float sway_speed : hint_range(0.0, 3.0) = 0.35;

// 沿光束方向的衰减：靠近光源最亮，往远处渐弱。
uniform float fade_start : hint_range(-0.5, 1.0) = 0.15;
uniform float fade_end : hint_range(0.0, 2.0) = 1.05;

uniform float dust_amount : hint_range(0.0, 1.0) = 0.45;
uniform float dust_scale : hint_range(1.0, 80.0) = 26.0;
uniform float dust_speed : hint_range(0.0, 1.0) = 0.12;

uniform float pulse_amount : hint_range(0.0, 1.0) = 0.12;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.60;

uniform vec4 light_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.55;

// 画面宽高比，用来防止光束被拉扁。
uniform vec2 aspect = vec2(1.7778, 1.0);

// 可选：按 split_clip.gdshader 的那条斜线裁掉一半（开场界面用）。
// 房间里保持 clip_enable = 0，行为和以前完全一样。
uniform float clip_enable : hint_range(0.0, 1.0) = 0.0;
uniform vec2 clip_aspect = vec2(1.7778, 1.0);
uniform float line_center = 0.0;
uniform float tilt = 0.0;
uniform float clip_side = 1.0;
uniform float clip_feather : hint_range(0.0, 0.05) = 0.003;


float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(i);
	float b = hash1(i + vec2(1.0, 0.0));
	float c = hash1(i + vec2(0.0, 1.0));
	float d = hash1(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


// 一束 = 一根高斯软柱，横向位置再叠一个 sin 做缓慢左右摆动。
float shaft(float across, float pos, float w, float phase, float t) {
	float x = across - pos + sin(t * sway_speed + phase) * sway;
	return exp(-(x * x) / max(w * w, 1e-5));
}


void fragment() {
	float t = TIME;

	vec2 p = (UV - vec2(0.5)) * aspect;
	float a = radians(angle_deg);
	float ca = cos(a);
	float sa = sin(a);
	vec2 r = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
	float along = r.y + 0.5;

	float v = 0.0;
	for (int i = 0; i < MAX_BEAMS; i++) {
		if (i >= beam_count) {
			break;
		}
		float pos;
		float w;
		float phase;
		float weight;
		if (i == 0) {
			pos = beam_pos_a;
			w = shaft_w;
			phase = 0.0;
			weight = 1.0;
		} else if (i == 1) {
			pos = beam_pos_b;
			w = shaft_w * 0.70;
			phase = 1.7;
			weight = 0.85;
		} else {
			float h = hash1(vec2(float(i), seed));
			pos = (h - 0.5) * spread;
			w = shaft_w * (0.30 + 0.55 * hash1(vec2(float(i) + 11.0, seed)));
			phase = h * 6.2831853;
			weight = 0.55;
		}
		v += shaft(r.x, pos, w, phase, t) * weight;
	}

	float fade = 1.0 - smoothstep(fade_start, fade_end, along);
	float dust = vnoise(vec2(r.x * dust_scale, (along - t * dust_speed) * dust_scale * 0.6));
	float dust_f = mix(1.0, 0.55 + 0.90 * dust, dust_amount);
	float pulse = 1.0 + pulse_amount * sin(t * pulse_speed);

	float amount = max(v * fade * dust_f * pulse * intensity, 0.0);

	if (clip_enable > 0.5) {
		vec2 cq = (SCREEN_UV - vec2(0.5)) * clip_aspect;
		float cd = (cq.x - line_center) * cos(tilt) - cq.y * sin(tilt);
		amount *= smoothstep(-clip_feather, clip_feather, cd * clip_side);
	}

	COLOR = vec4(light_color.rgb * amount * light_color.a, 1.0);
}
