shader_type canvas_item;

// Polished reflective marble-floor shader for a canvas strip placed at the
// bottom of the scene. It mirrors the whole scene above it into the floor and
// blends seamlessly at the top edge (no visible seam), then tints and dims the
// reflection with depth for a high-end glossy stone look.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D wave_noise : repeat_enable, filter_linear;

// Colour the reflection fades toward as it recedes into the floor.
uniform vec4 floor_tint : source_color = vec4(0.04, 0.08, 0.12, 1.0);
// How strongly the far part of the floor takes the tint (0 = pure mirror).
uniform float tint_amount : hint_range(0.0, 1.0) = 0.6;
// Overall dimming of the reflection with depth (fake light falloff).
uniform float depth_dim : hint_range(0.0, 1.0) = 0.35;
// Ripple strength. Kept small on purpose — this is stone, not water.
uniform float distortion : hint_range(0.0, 0.03) = 0.007;
// Slow moving specular streaks that read as a wet/polished sheen.
uniform float gloss : hint_range(0.0, 1.0) = 0.18;
uniform float wave_speed = 0.02;
// Fake floor perspective: how much wider the reflection spreads at the bottom
// edge (0 = straight mirror, 0.35 = bottom row is 35% wider than the top).
uniform float perspective : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	// depth: 0 at the seam (top), 1 at the far edge (bottom).
	float depth = UV.y;

	// Ripple fades to zero at the seam so the top row stays pixel-perfectly
	// continuous with the geometry above it -> this is what kills the seam.
	float ripple_mask = smoothstep(0.0, 0.18, depth);
	vec2 wobble = (texture(wave_noise, UV * vec2(1.0, 3.0) + TIME * wave_speed).rg - 0.5)
				  * distortion * ripple_mask;

	// Mirror the whole scene above into the floor. Keystone warp: the top row
	// samples 1:1 (keeps the seam), lower rows sample a slice squeezed toward
	// the screen centre so the reflection fans out wider toward the bottom.
	float spread = 1.0 + perspective * depth;
	vec2 ruv = vec2(0.5 + (SCREEN_UV.x - 0.5) / spread, SCREEN_UV.y - UV.y) + wobble;
	vec3 reflection = texture(screen_texture, ruv).rgb;

	// Tint ramps in with depth; at depth 0 there is no tint, so the seam matches
	// the un-tinted geometry directly above it.
	float tint = tint_amount * smoothstep(0.0, 1.0, depth);
	vec3 col = mix(reflection, floor_tint.rgb, tint);

	// Gentle darkening into the distance.
	col *= 1.0 - depth_dim * depth;

	// Soft polished sheen: a couple of slow bright streaks near the front edge.
	float streak = texture(wave_noise, UV * vec2(1.5, 0.4) - TIME * wave_speed * 0.6).r;
	col += gloss * smoothstep(0.65, 1.0, streak) * (1.0 - depth);

	COLOR = vec4(col, 1.0);
}
