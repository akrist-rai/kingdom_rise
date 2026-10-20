// Trees, bushes and tall grass sway in the wind; the base stays planted. The phase comes from
// the world position, so neighbouring plants move slightly out of step.
shader_type canvas_item;

uniform float amp = 4.0;     // sway at the top, in sprite pixels
uniform float base = 0.3;    // part of the height (from the bottom) that stays still
uniform float gust = 0.0;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float h = clamp((1.0 - UV.y - base) / (1.0 - base), 0.0, 1.0);
	float s = sin(TIME * 1.25 + wp.x * 0.031 + wp.y * 0.017) * 0.6
		+ sin(TIME * 2.4 + wp.x * 0.071) * 0.25 + 0.2;
	VERTEX.x += h * h * s * (amp + gust * amp);
	VERTEX.y += h * h * abs(s) * amp * 0.12;
}

// Winter: with snow > 0 the summer bake cools and loses its green, and snow settles on the
// lit, upward-facing surfaces (the bright side of every crown, rock and roof).
uniform float snow = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (snow > 0.0) {
		float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		c.rgb = mix(c.rgb, vec3(l) * vec3(0.76, 0.88, 1.0), 0.55 * snow);
		// frost lifts the darkest needles a little, snow lies on everything the sun reaches
		c.rgb = mix(c.rgb, vec3(0.5, 0.58, 0.68), 0.12 * snow);
		float s = smoothstep(0.1, 0.3, l) * snow;
		c.rgb = mix(c.rgb, vec3(0.9, 0.94, 1.0), s * 0.85);
	}
	COLOR = c;
}
