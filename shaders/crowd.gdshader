// Brings the static reserve armies to life: each figure carries a random phase in its
// vertex colour (blue channel) and shuffles/bobs by a pixel now and then. `excite` makes
// the duel ring cheer.
shader_type canvas_item;

uniform float excite = 0.0;

varying float phase;

void vertex() {
	phase = COLOR.b * 97.0;
	float s = sin(TIME * (2.0 + excite * 6.0) + phase * 6.2831);
	float bob = step(0.86 - excite * 0.5, s);
	VERTEX.y -= bob * (1.0 + excite);
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
