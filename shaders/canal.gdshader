// The canal through the city at night: dark blue water with drifting ripple lines and long
// broken streaks of firelight reflected from the burning houses, pale stone quays at the edges.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform vec2 rsize = vec2(100.0);
uniform vec3 fire = vec3(1.0, 0.55, 0.25);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

void fragment() {
	vec2 p = wpos;
	float k = (p.y - origin.y) / rsize.y;
	vec3 c = mix(vec3(0.08, 0.1, 0.22), vec3(0.14, 0.17, 0.32), vnoise(p * vec2(0.01, 0.05)));
	// ripples drifting east
	float r = sin(p.y * 0.9 + vnoise(vec2(p.x * 0.03 - TIME * 0.4, p.y * 0.2)) * 6.0);
	c += vec3(0.1, 0.12, 0.2) * smoothstep(0.85, 1.0, r);
	// reflections of the fires: vertical streaks broken by the ripples
	float col = vnoise(vec2(p.x * 0.012, 3.0));
	float streak = smoothstep(0.62, 0.8, col) * (0.5 + 0.5 * sin(p.y * 1.3 + TIME * 2.0 + p.x * 0.2));
	c = mix(c, fire * 0.9, streak * 0.55);
	// quay walls: lit stone lip on the north bank, dark shadowed lip on the south bank
	c = mix(c, vec3(0.5, 0.46, 0.56), 1.0 - smoothstep(0.0, 0.1, k));
	c = mix(c, vec3(0.05, 0.05, 0.12), smoothstep(0.86, 1.0, k));
	COLOR = vec4(c, 1.0);
}
