// Finishing pass for the cinematic title: soft bloom from the screen mipmaps, a cool
// vignette, slight lift in the shadows and fine print grain.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fade = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 b = textureLod(screen_tex, uv, 3.0).rgb;
	c += max(b - 0.55, 0.0) * 0.6;
	vec2 q = uv - 0.5;
	float v = smoothstep(0.35, 0.85, length(q * vec2(1.0, 1.25)));
	c = mix(c, vec3(0.02, 0.05, 0.08), v * 0.6);
	c = c * 0.96 + vec3(0.012, 0.02, 0.03);
	vec2 fc = FRAGCOORD.xy;
	c *= 1.0 + (hash21(floor(fc)) - 0.5) * 0.05 + (vnoise(fc * vec2(0.5, 0.045)) - 0.5) * 0.03;
	COLOR = vec4(c * fade, 1.0);
}
