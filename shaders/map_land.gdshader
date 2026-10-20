// The painted countryside of the campaign map, seen from high above: a patchwork of fields
// (gold wheat, sage, olive, rust, fallow lavender) with furrows and hedgerows, cut into
// districts that each run their own way; dark forests of round tree crowns; the north under
// snow; drifting violet cloud shadows and a warm light from the upper left.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 size = vec2(612.0, 332.0);
uniform vec2 origin = vec2(14.0, 14.0);
uniform float time = 0.0;

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + 19.19));
}

// Rectangular-ish Voronoi (Chebyshev distance). x: distance to the cell border (in cell units),
// y: cell id hash, zw: position relative to the cell centre.
vec4 cells(vec2 q) {
	vec2 g = floor(q);
	vec2 f = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	vec2 rel = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + 0.5 + (hash22(g + o) - 0.5) * 0.75 - f;
			float d = max(abs(c.x), abs(c.y));
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = g + o;
				rel = c;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(d2 - d1, hash21(id), rel);
}

vec3 crop(float h) {
	if (h < 0.18) return vec3(0.88, 0.72, 0.36);   // ripe wheat
	if (h < 0.32) return vec3(0.93, 0.83, 0.52);   // pale barley
	if (h < 0.46) return vec3(0.58, 0.64, 0.38);   // sage
	if (h < 0.58) return vec3(0.44, 0.53, 0.32);   // olive
	if (h < 0.7) return vec3(0.76, 0.48, 0.3);     // rust, ploughed
	if (h < 0.82) return vec3(0.64, 0.54, 0.56);   // fallow, lavender-brown
	if (h < 0.92) return vec3(0.68, 0.72, 0.42);   // young millet
	return vec3(0.33, 0.45, 0.33);                 // pasture
}

void fragment() {
	vec2 p = UV * size + origin;
	// districts: big patches of fields that share an orientation, edged by hedges
	vec4 dist = cells(p / vec2(92.0, 70.0));
	float ang = (dist.y - 0.5) * 1.3;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = rot * p;
	vec4 fc = cells(q / vec2(15.0, 9.0) + dist.y * 13.0);
	vec3 col = crop(fc.y);
	// furrows, along or across each field
	float dir = step(0.5, fract(fc.y * 7.3));
	float fu = sin((dir > 0.5 ? fc.z * 15.0 : fc.w * 9.0) * 6.2831 * 1.4);
	col *= 0.93 + 0.07 * smoothstep(-0.2, 0.2, fu);
	col *= 0.94 + hash21(vec2(fc.y, 3.0)) * 0.1;
	// hedgerows between fields, darker ones between districts
	float hedge = 1.0 - smoothstep(0.03, 0.07, fc.x);
	col = mix(col, vec3(0.24, 0.34, 0.24), hedge * 0.8);
	float dh = 1.0 - smoothstep(0.004, 0.012, dist.x);
	col = mix(col, vec3(0.18, 0.27, 0.2), dh);
	// forests: dense round crowns, lit from the upper left
	float fm = fbm(p * 0.018 + 5.0) + (vnoise(p * 0.12) - 0.5) * 0.08;
	float forest = smoothstep(0.6, 0.615, fm);
	float md = 9.0;
	vec2 trel = vec2(0.0);
	if (forest > 0.0) {
		vec2 tq = p / 3.2;
		vec2 tg = floor(tq);
		vec2 tf = fract(tq);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 o = vec2(float(x), float(y));
				vec2 c = o + hash22(tg + o) * 0.8 + 0.1 - tf;
				float d = length(c);
				if (d < md) {
					md = d;
					trel = c;
				}
			}
		}
		vec3 tc = mix(vec3(0.16, 0.3, 0.26), vec3(0.34, 0.48, 0.3), smoothstep(0.2, -0.4, trel.x + trel.y));
		tc = mix(tc, vec3(0.08, 0.16, 0.18), smoothstep(0.42, 0.62, md));
		col = mix(col, tc, forest);
	}
	// the north lies under snow; along its edge some fields are white and some still bare
	float sn = smoothstep(165.0, 90.0, p.y + (fbm(p * 0.012) - 0.5) * 110.0) * smoothstep(430.0, 320.0, p.x + (fbm(p * 0.02 + 3.0) - 0.5) * 60.0);
	sn = max(sn, smoothstep(70.0, 40.0, p.y));
	sn += (fc.y - 0.5) * 0.5;
	vec3 snow = mix(vec3(0.9, 0.9, 0.97), vec3(0.74, 0.76, 0.9), hedge * 0.8 + dh);
	snow = mix(snow, vec3(0.82, 0.83, 0.94), 0.5 + 0.5 * smoothstep(-0.2, 0.2, fu) * 0.3);
	if (forest > 0.0) {
		// snowy pines: dark blue-green crowns with snow on their lit side
		vec3 pine = mix(vec3(0.16, 0.26, 0.32), vec3(0.86, 0.88, 0.96), smoothstep(0.0, -0.45, trel.x + trel.y));
		pine = mix(pine, vec3(0.1, 0.16, 0.24), smoothstep(0.42, 0.62, md));
		snow = mix(snow, pine, forest);
	}
	col = mix(col, snow, smoothstep(0.42, 0.58, sn));
	// broad light: warm from the upper left, cooler toward the lower right
	vec2 uv = p / size;
	col *= mix(vec3(1.08, 1.0, 0.9), vec3(0.86, 0.86, 1.02), clamp(uv.x * 0.5 + uv.y * 0.6, 0.0, 1.0));
	col *= 0.94 + fbm(p * 0.01) * 0.12;
	// drifting cloud shadows: flat violet shapes
	float cl = fbm(p * 0.006 + vec2(time * 0.004, time * 0.0015)) + (vnoise(p * 0.05) - 0.5) * 0.03;
	float cfw = fwidth(cl) + 1e-4;
	float cloud = smoothstep(0.58 - cfw, 0.58 + cfw, cl);
	col = mix(col, col * vec3(0.56, 0.52, 0.82), cloud * 0.6);
	COLOR = vec4(col, 1.0);
}
