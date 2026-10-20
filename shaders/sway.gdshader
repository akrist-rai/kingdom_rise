// Sways a sprite's top edge in the wind (tall grass). The phase comes from the sprite's
// world position so neighbouring clumps move slightly out of step.
shader_type canvas_item;

uniform float amp = 1.6;
uniform float gust = 0.0;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float k = 1.0 - UV.y;
	float s = sin(TIME * 1.7 + wp.x * 0.045 + wp.y * 0.02) * 0.6 + sin(TIME * 3.1 + wp.x * 0.11) * 0.25 + 0.35;
	VERTEX.x += k * k * s * (amp + gust * 2.0);
}
