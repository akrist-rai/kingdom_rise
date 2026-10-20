// Dash after-images and other glowing silhouettes: the sprite's shape, filled with the
// modulate colour and added to the scene.
shader_type canvas_item;
render_mode blend_add;

varying vec4 mod;

void vertex() {
	mod = COLOR;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(mod.rgb * a * mod.a, a * mod.a);
}
