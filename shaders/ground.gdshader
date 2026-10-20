// Snow battlefield in the painted-poster style (blue-hour palette): a few flat tones separated by crisp,
// brush-wobbled edges, long brush strokes running with the wind, engraved ripple lines,
// plum earth patches with ink rims, flat ice ponds that reflect the sky in bands, and the
// rocky foothills at the top edge as flat silhouettes. No dithering: edges are
// anti-aliased with fwidth so they stay sharp at any resolution.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform float top_y = 80.0;
uniform float map_w = 3200.0;
uniform vec4 c0 : source_color = vec4(0.17, 0.27, 0.37, 1.0);   // deep drift shadow (ultramarine)
uniform vec4 c1 : source_color = vec4(0.38, 0.5, 0.61, 1.0);   // shadow (periwinkle)
uniform vec4 c2 : source_color = vec4(0.62, 0.72, 0.8, 1.0);   // half tone (lilac)
uniform vec4 c3 : source_color = vec4(0.84, 0.87, 0.88, 1.0);   // lit snow (cream)
uniform vec4 c4 : source_color = vec4(0.97, 0.95, 0.92, 1.0);    // glare
uniform vec4 earth_col : source_color = vec4(0.16, 0.19, 0.23, 1.0);
uniform vec4 rock : source_color = vec4(0.1, 0.16, 0.22, 1.0);
uniform vec4 ink_col : source_color = vec4(0.03, 0.07, 0.1, 1.0);
uniform vec3 sky_a = vec3(0.6, 0.58, 0.78);
uniform vec3 sky_b = vec3(1.0, 0.82, 0.64);
uniform vec2 wind_dir = vec2(1.0, 0.26);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

float edge(float v, float e, float w) {
	return smoothstep(e - w, e + w, v);
}

void fragment() {
	vec2 p = wpos;
	vec2 wd = normalize(wind_dir);
	// q: coordinates along / across the wind, used to stretch noise into brush strokes
	vec2 q = vec2(dot(p, wd), dot(p, vec2(-wd.y, wd.x)));

	// --- big drift shapes, quantised into flat tones with wobbly brush edges
	float n = fbm(p * vec2(0.0032, 0.0065));
	float wob = (vnoise(q * vec2(0.035, 0.18)) - 0.5) * 0.07 + (vnoise(q * vec2(0.12, 0.6)) - 0.5) * 0.02;
	float v = n + wob;
	float fw = fwidth(v) * 0.9 + 1e-4;
	vec3 col = c0.rgb;
	col = mix(col, c1.rgb, edge(v, 0.36, fw));
	col = mix(col, c2.rgb, edge(v, 0.47, fw));
	col = mix(col, c3.rgb, edge(v, 0.56, fw));
	col = mix(col, c4.rgb, edge(v, 0.71, fw));

	// --- brush strokes: long, thin value variations running with the wind
	float st = vnoise(q * vec2(0.010, 0.28)) * 0.6 + vnoise(q * vec2(0.03, 0.9)) * 0.4;
	col *= 1.0 + (st - 0.5) * 0.07;

	// --- engraved wind ripples (sastrugi): thin ink-blue hatch lines in some areas
	float rmask = smoothstep(0.55, 0.7, vnoise(p * 0.0045 + 9.0));
	float rip = sin(q.y * 0.55 + vnoise(q * vec2(0.01, 0.03)) * 9.0 + q.x * 0.012);
	float rfw = fwidth(rip) + 1e-4;
	float line = edge(rip, 0.93, rfw) * rmask * edge(vnoise(q * vec2(0.03, 0.2)), 0.45, 0.02);
	col = mix(col, c1.rgb * 0.9, line * 0.65);

	// --- frozen earth: flat plum shapes with a dark ink rim
	float m = fbm(p * 0.011 + 20.0) * 0.82 + vnoise(q * vec2(0.04, 0.12)) * 0.18;
	float mfw = fwidth(m) * 0.9 + 1e-4;
	float earth = edge(m, 0.705, mfw);
	if (earth > 0.0) {
		vec3 ec = mix(earth_col.rgb, earth_col.rgb * 1.25, edge(vnoise(q * vec2(0.05, 0.3)), 0.55, 0.03));
		float rim = earth * (1.0 - edge(m, 0.716, mfw));
		col = mix(col, ec, earth);
		col = mix(col, ink_col.rgb, rim * 0.85);
	}

	// --- ice ponds: flat pale blue, banded sky reflection, white cracks, snow lip
	float pond = vnoise(p * 0.0028 + 50.0) * 0.75 + vnoise(p * 0.013 + 9.0) * 0.25;
	float pfw = fwidth(pond) * 0.9 + 1e-4;
	float ice = edge(pond, 0.8, pfw) * (1.0 - earth);
	if (ice > 0.0) {
		float band = floor(fract(p.y * 0.035 + vnoise(vec2(p.x * 0.006, p.y * 0.02)) * 1.2) * 3.0) / 2.0;
		vec3 ic = mix(vec3(0.7, 0.8, 0.95), mix(sky_b, sky_a, band), 0.32);
		float crack = abs(vnoise(p * 0.06) - 0.5);
		ic = mix(ic, vec3(0.97, 0.98, 1.0), 1.0 - edge(crack, 0.016, fwidth(crack) + 1e-4));
		float lip = 1.0 - edge(pond, 0.808, pfw);
		ic = mix(ic, c4.rgb, lip);
		col = mix(col, ic, ice);
		col = mix(col, ink_col.rgb, ice * (1.0 - edge(pond, 0.8 + pfw * 3.0, pfw)) * 0.6);
	}

	// --- foothills at the top: flat rock silhouettes with snow and an ink edge
	if (p.y < top_y + 10.0) {
		float k = clamp((top_y - p.y) / 70.0, 0.0, 1.0);
		float rn = fbm(p * vec2(0.022, 0.05));
		float rv = rn * 0.8 + (1.0 - k) * 0.55;
		float rfw2 = fwidth(rv) * 0.9 + 1e-4;
		float rk = 1.0 - edge(rv, 0.5, rfw2);
		vec3 rc = mix(rock.rgb, rock.rgb * 1.45, edge(vnoise(p * vec2(0.05, 0.02)), 0.5, 0.04));
		col = mix(col, rc, rk);
		col = mix(col, ink_col.rgb, rk * edge(rv, 0.5 - rfw2 * 3.5, rfw2) * 0.9);
	}
	COLOR = vec4(col, 1.0);
}
