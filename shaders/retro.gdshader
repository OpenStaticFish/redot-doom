shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform bool enabled = true;

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	if (enabled) {
		vec2 center = SCREEN_UV * 2.0 - 1.0;
		float vignette = 1.0 - dot(center, center) * 0.085;
		float scan = mod(floor(FRAGCOORD.y), 2.0) == 0.0 ? 1.0 : 0.94;
		scene = floor(scene * 31.0 + 0.5) / 31.0;
		scene *= vignette * scan;
	}
	COLOR = vec4(scene, 1.0);
}
