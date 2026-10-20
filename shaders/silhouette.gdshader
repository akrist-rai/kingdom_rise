// Draws a sprite as a solid white silhouette; the ShadowLayer tints and fades the result.
shader_type canvas_item;

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, step(0.5, texture(TEXTURE, UV).a));
}
