// Aerial perspective for distant scenery: blends the sprite toward the haze colour.
shader_type canvas_item;

uniform vec3 haze_col : source_color = vec3(0.8, 0.86, 0.9);
uniform float amount = 0.4;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = mix(c.rgb, haze_col, amount);
	COLOR = c;
}
