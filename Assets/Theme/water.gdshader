shader_type canvas_item;

// Matte reflective floor for the bottom strip of the scene: a static, dark
// tinted stone base with a soft, blurred reflection of the scene above. The
// reflection is strongest at the contact line and dies off quickly with
// depth, so it reads as polished flooring rather than a mirror. Nothing here
// animates — stone, not water.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Static noise used only to mottle the base colour a little.
uniform sampler2D wave_noise : repeat_enable, filter_linear;

// Base colour of the floor itself.
uniform vec4 floor_tint : source_color = vec4(0.04, 0.08, 0.12, 1.0);
// Brightness of the base floor colour.
uniform float tint_amount : hint_range(0.0, 1.0) = 0.6;
// Darkening of the floor with depth (fake light falloff).
uniform float depth_dim : hint_range(0.0, 1.0) = 0.35;
// Fake floor perspective: how much wider the reflection spreads at the bottom
// edge (0 = straight mirror, 0.35 = bottom row is 35% wider than the top).
uniform float perspective : hint_range(0.0, 1.0) = 0.35;
// How visible the mirrored image is at the contact line.
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.45;
// How quickly the reflection dies off with depth.
uniform float reflection_falloff : hint_range(0.0, 8.0) = 2.5;
// Mip blur applied to the reflection toward the far edge (rough surface look).
uniform float blur_depth : hint_range(0.0, 4.0) = 2.0;
// Master opacity — driven by the intro script to fade the floor in.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// depth: 0 at the contact line (top), 1 at the far edge (bottom).
	float depth = UV.y;

	// Keystone warp: the top row samples 1:1, lower rows sample a slice
	// squeezed toward the screen centre so the reflection fans out wider
	// toward the bottom -> reads as floor perspective.
	float spread = 1.0 + perspective * depth;
	vec2 ruv = vec2(0.5 + (SCREEN_UV.x - 0.5) / spread, SCREEN_UV.y - UV.y);

	// The reflection blurs as it recedes — a rough surface, not a mirror.
	vec3 reflection = textureLod(screen_texture, ruv, blur_depth * depth).rgb;

	// Matte stone base with static large-scale mottling so it isn't flat.
	float mottle = texture(wave_noise, UV * vec2(0.35, 0.9)).r;
	vec3 col = floor_tint.rgb * tint_amount * (0.75 + 0.25 * mottle);
	col *= 1.0 - depth_dim * depth;

	// Blend the reflection on top: strong at the contact line, gone by the
	// bottom — this falloff is what makes it read as a floor.
	float refl_vis = reflection_strength * exp(-reflection_falloff * depth);
	col = mix(col, reflection, refl_vis);

	COLOR = vec4(col, fade);
}
