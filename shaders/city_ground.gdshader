// Ground of the Siege of Handan, by zone from south (bottom) to north (top): the frozen,
// churned field before the walls (wheel ruts of the ram and siege towers, trampled snow), the
// cobbled city streets with the paved avenue running north from the gate, and the great square
// flagstones of the palace platform with its carved central way. The walls, the terrace face
// and the canal are drawn over this by their own nodes.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform float wall_y = 1762.0;      // city side of the wall
uniform float ground_y = 1990.0;    // foot of the wall's outer face
uniform float terrace_y = 810.0;    // south edge of the palace platform
uniform float ave_x0 = 1040.0;
uniform float ave_x1 = 1160.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

float edge(float v, float e, float w) {
	return smoothstep(e - w, e + w, v);
}

// distance to the nearest mortar line of a running-bond flagstone pattern
float bond(vec2 p, vec2 size) {
	float row = floor(p.y / size.y);
	vec2 q = vec2(p.x + mod(row, 2.0) * size.x * 0.5, p.y);
	vec2 f = fract(q / size) * size;
	return min(min(f.x, size.x - f.x), min(f.y, size.y - f.y));
}

vec3 flagstones(vec2 p, vec2 size, vec3 base, vec3 mortar) {
	float d = bond(p, size);
	float tone = hash21(floor(vec2(p.x + mod(floor(p.y / size.y), 2.0) * size.x * 0.5, p.y) / size));
	vec3 c = base * (0.88 + tone * 0.2);
	return mix(mortar, c, edge(d, 1.0, fwidth(d) + 1e-4));
}

vec3 field(vec2 p) {
	// frozen, trampled ground: soft patches of mud and old snow, finely mottled
	float n = fbm(p * 0.006);
	float v = n + (vnoise(p * 0.05) - 0.5) * 0.06;
	float fw = fwidth(v) * 0.9 + 1e-4;
	vec3 c = vec3(0.17, 0.14, 0.22);
	c = mix(c, vec3(0.22, 0.18, 0.27), edge(v, 0.47, fw));
	c = mix(c, vec3(0.27, 0.23, 0.32), edge(v, 0.57, fw));
	float s = fbm(p * 0.012 + 7.0) + (vnoise(p * 0.08) - 0.5) * 0.05;
	float sfw = fwidth(s) + 1e-4;
	c = mix(c, vec3(0.4, 0.39, 0.52), edge(s, 0.62, sfw));
	c = mix(c, vec3(0.55, 0.54, 0.68), edge(s, 0.7, sfw));
	c *= 0.95 + vnoise(p * vec2(0.2, 0.05)) * 0.08;
	// ruts of the ram and the siege towers, running north to the wall
	for (int i = 0; i < 3; i++) {
		float lx = i == 0 ? 1100.0 : (i == 1 ? 620.0 : 1580.0);
		float d = abs(abs(p.x - lx) - 13.0 - vnoise(vec2(p.y * 0.02, float(i))) * 2.0);
		float rut = 1.0 - edge(d, 2.4, fwidth(d) + 1e-4);
		c = mix(c, vec3(0.06, 0.05, 0.1), rut * 0.85 * step(ground_y, p.y));
	}
	return c;
}

vec3 cobbles(vec2 p) {
	vec2 g = floor(p / 6.5);
	vec2 f = fract(p / 6.5);
	float md = 9.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + vec2(hash21(g + o), hash21(g + o + 17.3)) * 0.8 + 0.1 - f;
			float d = length(r);
			if (d < md) {
				md = d;
				id = hash21(g + o + 3.1);
			}
		}
	}
	vec3 c = mix(vec3(0.32, 0.29, 0.37), vec3(0.4, 0.36, 0.43), id);
	return mix(c, vec3(0.19, 0.17, 0.23), edge(md, 0.6, fwidth(md) + 1e-4));
}

void fragment() {
	vec2 p = wpos;
	vec3 col;
	bool ave = p.x > ave_x0 && p.x < ave_x1;
	if (p.y > ground_y - 4.0) {
		col = field(p);
		// the foot of the wall lies in its deep shadow
		col *= mix(0.5, 1.0, smoothstep(ground_y, ground_y + 110.0, p.y));
	} else if (p.y > wall_y - 10.0) {
		// the wall-walk: big worn flagstones
		col = flagstones(p, vec2(26.0, 14.0), vec3(0.46, 0.42, 0.52), vec3(0.2, 0.18, 0.25));
	} else if (p.y > terrace_y) {
		col = cobbles(p);
		if (ave) {
			col = flagstones(p, vec2(16.0, 30.0), vec3(0.42, 0.38, 0.46), vec3(0.18, 0.16, 0.22));
		}
		// darker just inside the wall, in its shadow
		col *= mix(1.0, 0.7, smoothstep(wall_y - 80.0, wall_y, p.y));
	} else {
		col = flagstones(p, vec2(30.0, 30.0), vec3(0.5, 0.47, 0.54), vec3(0.24, 0.21, 0.28));
		if (ave) {
			// the carved imperial way: pale stone with a cloud-scroll band
			col = flagstones(p, vec2(13.0, 26.0), vec3(0.72, 0.66, 0.66), vec3(0.32, 0.27, 0.32));
			float band = abs(p.x - (ave_x0 + ave_x1) * 0.5);
			float sc = sin(p.y * 0.18 + sin(p.y * 0.05) * 2.0) * 6.0;
			float scroll = 1.0 - edge(abs(band - abs(sc)), 1.0, fwidth(band) + 1e-4);
			col = mix(col, vec3(0.86, 0.5, 0.32), scroll * step(band, 9.0) * 0.7);
		}
	}
	COLOR = vec4(col, 1.0);
}
