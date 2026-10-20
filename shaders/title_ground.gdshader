// The title diorama's ground: a summer meadow in the golden hour (bands of green and straw,
// short grass strokes, damp hollows), the dusty road winding from the foreground up to the
// city gate, and a haze that thickens toward the horizon.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform vec2 road_a = vec2(470.0, 900.0);   // quadratic road: foreground end
uniform vec2 road_b = vec2(900.0, 720.0);   // control point
uniform vec2 road_c = vec2(1010.0, 540.0);  // at the gate
uniform float horizon = 300.0;
uniform vec3 haze_col = vec3(0.86, 0.82, 0.7);

varying vec2 world;

void vertex() { world = VERTEX + origin; }

float fbm3(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.07 + 13.1) * 0.3 + vnoise(p * 4.31 + 7.7) * 0.15;
}

// distance to the road curve, sampled (cheap enough for one full-screen pass)
float road_dist(vec2 p) {
	float d = 1e9;
	for (int i = 0; i <= 24; i++) {
		float s = float(i) / 24.0;
		vec2 q = mix(mix(road_a, road_b, s), mix(road_b, road_c, s), s);
		d = min(d, distance(p, q));
	}
	return d;
}

void fragment() {
	vec2 p = world;
	vec2 warp = vec2(fbm3(p * 0.004), fbm3(p * 0.004 + 21.0)) * 140.0;
	float big = fbm3((p + warp) * 0.0035);
	float mid = fbm3((p + warp * 0.4) * 0.012);
	float g = big * 0.7 + mid * 0.3;
	vec3 deep = vec3(0.27, 0.4, 0.2);
	vec3 lush = vec3(0.43, 0.56, 0.25);
	vec3 light = vec3(0.62, 0.66, 0.31);
	vec3 straw = vec3(0.8, 0.7, 0.4);
	vec3 col = g < 0.42 ? mix(deep, lush, smoothstep(0.22, 0.42, g)) : g < 0.6 ? mix(lush, light, (g - 0.42) / 0.18) : mix(light, straw, smoothstep(0.6, 0.8, g));
	vec2 sp = p * vec2(0.55, 0.22) + vec2(p.y * 0.12, 0.0);
	float stroke = vnoise(sp) * vnoise(sp * 1.9 + 3.0);
	col *= 0.9 + stroke * 0.22 + (vnoise(p * 0.09) - 0.5) * 0.06;
	col = mix(col, deep * 0.85, smoothstep(0.62, 0.78, fbm3(p * 0.018 + 50.0)) * 0.3);
	// the road: pale packed dust with darker ruts and soft grassy verges
	float n = fbm3(p * 0.02);
	float rd = road_dist(p);
	float w = mix(34.0, 16.0, smoothstep(900.0, 540.0, p.y));
	float road = 1.0 - smoothstep(w, w + 16.0, rd + (n - 0.5) * 18.0);
	vec3 dust = vec3(0.78, 0.68, 0.5) * (0.9 + n * 0.2);
	float rut = (1.0 - smoothstep(0.0, 2.5, abs(rd - w * 0.45))) * 0.12;
	dust *= 1.0 - rut;
	col = mix(col, dust, road);
	// haze toward the horizon
	float hz = 1.0 - smoothstep(horizon, horizon + 300.0, p.y);
	col = mix(col, haze_col, hz * 0.55);
	// the far edge dissolves into the haze over the ranges
	COLOR = vec4(col, smoothstep(origin.y + 10.0, origin.y + 150.0, p.y));
}
