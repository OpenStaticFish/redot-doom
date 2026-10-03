shader_type canvas_item;
// A tiny, isolated render target lets the HUD draw this below menu overlays.
// Store straight alpha; the HUD applies alpha blending exactly once.
render_mode unshaded, blend_disabled;

uniform float weights[8];

void fragment() {
	vec4 mixed = vec4(0.0);
	for (int frame = 0; frame < 8; frame++) {
		vec2 at = vec2((UV.x + float(frame)) / 8.0, UV.y);
		vec4 pose = texture(TEXTURE, at);
		mixed += vec4(pose.rgb * pose.a, pose.a) * weights[frame];
	}
	COLOR = vec4(mixed.rgb / max(mixed.a, 0.0001), mixed.a);
}
