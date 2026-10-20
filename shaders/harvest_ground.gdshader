// Siege ground. South of the wall: a painterly summer meadow trampled by the army (grass in
// several greens and straw golds, churned earth along the road and the approaches, dark mud at
// the foot of the wall). North of the wall: the city's worn flagstones and the avenue.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"
uniform vec2 origin = vec2(0.0);
uniform float wall_y = 1810.0;
uniform float ground_y = 2070.0;
uniform float terrace_y = 820.0;
uniform float ave_x0 = 1060.0;
uniform float ave_x1 = 1140.0;
varying vec2 world;

void vertex() { world = VERTEX + origin; }

float fbm3(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.07 + 13.1) * 0.3 + vnoise(p * 4.31 + 7.7) * 0.15;
}

vec3 meadow(vec2 p) {
	vec2 warp = vec2(fbm3(p * 0.004), fbm3(p * 0.004 + 21.0)) * 140.0;
	float big = fbm3((p + warp) * 0.0032);
	float mid = fbm3((p + warp * 0.4) * 0.011);
	float fine = vnoise(p * 0.09);
	// painterly bands of colour (soft-edged posterisation)
	float g = big * 0.7 + mid * 0.3;
	float gq = floor(g * 6.0) / 6.0 + smoothstep(0.35, 0.65, fract(g * 6.0)) / 6.0;
	vec3 deep = vec3(0.18, 0.29, 0.25);
	vec3 lush = vec3(0.32, 0.43, 0.31);
	vec3 light = vec3(0.5, 0.57, 0.36);
	vec3 straw = vec3(0.72, 0.67, 0.45);
	vec3 col = gq < 0.4 ? mix(deep, lush, smoothstep(0.2, 0.4, gq)) : gq < 0.62 ? mix(lush, light, (gq - 0.4) / 0.22) : mix(light, straw, smoothstep(0.62, 0.85, gq));
	// grass strokes: short, slightly slanted dashes of light and shade
	vec2 sp = p * vec2(0.55, 0.22) + vec2(p.y * 0.12, 0.0);
	float stroke = vnoise(sp) * vnoise(sp * 1.9 + 3.0);
	col *= 0.9 + stroke * 0.22 + (fine - 0.5) * 0.06;
	// clover patches and darker damp hollows
	float hollow = smoothstep(0.62, 0.78, fbm3(p * 0.018 + 50.0));
	col = mix(col, deep * 0.85, hollow * 0.35);
	return col;
}

vec3 earth(vec2 p, float wet) {
	float n = fbm3(p * 0.03);
	float pebble = step(0.86, vnoise(p * 0.55)) * 0.06;
	vec3 dry = vec3(0.68, 0.59, 0.45);
	vec3 mud = vec3(0.34, 0.28, 0.22);
	vec3 c = mix(dry, mud, wet) * (0.88 + n * 0.22) + pebble;
	return c;
}

void fragment() {
	vec2 p = world;
	float grain = hash21(floor(p * 2.0));
	vec3 col;
	if (p.y >= ground_y) {
		col = meadow(p);
		// the road to the gate and the cross track, rutted by carts
		float n = fbm3(p * 0.02);
		float roadx = 1100.0 + sin(p.y * 0.007) * 32.0;
		float dx = abs(p.x - roadx);
		float road = 1.0 - smoothstep(38.0, 64.0, dx + (n - 0.5) * 34.0);
		float cross = 1.0 - smoothstep(16.0, 36.0, abs(p.y - 2310.0 - sin(p.x * 0.007) * 28.0) + (n - 0.5) * 24.0);
		road = max(road, cross * 0.9);
		// churned earth where the armies have marched and fought
		float churn = smoothstep(0.55, 0.75, fbm3(p * 0.006 + 77.0) + (1.0 - smoothstep(0.0, 260.0, abs(p.y - ground_y - 120.0))) * 0.25);
		float wall_mud = 1.0 - smoothstep(0.0, 70.0, p.y - ground_y - (n - 0.5) * 40.0);
		float dirt = clamp(max(road, max(churn * 0.75, wall_mud)), 0.0, 1.0);
		vec3 e = earth(p, clamp(wall_mud * 0.9 + churn * 0.3, 0.0, 1.0));
		col = mix(col, e, dirt);
		float rut = (1.0 - smoothstep(0.8, 2.6, abs(dx - 20.0))) * road * (0.6 + n * 0.4);
		col *= 1.0 - rut * 0.22;
		// grass edge fringe: darker band where grass meets earth
		float edge = smoothstep(0.35, 0.5, dirt) * (1.0 - smoothstep(0.5, 0.7, dirt));
		col *= 1.0 - edge * 0.12;
		// the wall's shadow and damp at its foot
		col *= mix(0.62, 1.0, smoothstep(ground_y, ground_y + 46.0, p.y));
	} else {
		vec2 q = p / vec2(19.0, 13.0);
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 f = fract(q);
		float seam = 1.0 - smoothstep(0.015, 0.07, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		float id = hash21(floor(q));
		vec3 stone = mix(vec3(0.66, 0.64, 0.56), vec3(0.74, 0.7, 0.6), id);
		col = mix(stone, vec3(0.36, 0.38, 0.32), seam * 0.55);
		col *= 0.93 + vnoise(p * 0.05) * 0.1;
		float avenue = 1.0 - smoothstep(48.0, 56.0, abs(p.x - 1100.0));
		col = mix(col, vec3(0.8, 0.74, 0.6) * (0.95 + id * 0.08), avenue * 0.7);
		float moss = smoothstep(0.66, 0.8, fbm3(p * 0.03)) * seam;
		col = mix(col, vec3(0.34, 0.46, 0.26), moss * 0.7);
		float wear = smoothstep(0.55, 0.8, fbm3(p * 0.008 + 5.0));
		col = mix(col, vec3(0.55, 0.5, 0.42), wear * 0.25);
	}
	col += (grain - 0.5) * 0.03;
	COLOR = vec4(col, 1.0);
}
