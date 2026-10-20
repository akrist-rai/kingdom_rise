// Poster sky for the time of day: the gradient is cut into flat bands, swirling brush strokes
// follow the contours of a domain-warped noise field (in the manner of a painted sky),
// clouds are flat cut-out shapes with lit rims and ink edges, the sun is a flat disc with
// rings, and three mountain ranges are flat screen-print silhouettes with parallax.
// A storm mode is used for the general's last phase (Wrath).
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0, -700.0);
uniform vec2 cam = vec2(0.0);
uniform float bottom_y = 40.0;
uniform vec3 sky_top = vec3(0.24, 0.3, 0.58);
uniform vec3 sky_mid = vec3(0.6, 0.58, 0.78);
uniform vec3 sky_low = vec3(1.0, 0.82, 0.64);
uniform vec3 sun_col = vec3(1.0, 0.86, 0.6);
uniform float sun_y = -150.0;
uniform float stars = 0.0;
uniform float storm = 0.0;
uniform vec3 ink_col = vec3(0.07, 0.055, 0.14);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

float h1(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}
float n1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h1(i), h1(i + 1.0), f);
}
float ridge(float x, float seed) {
	float a = n1(x + seed);
	a = 1.0 - abs(a * 2.0 - 1.0);
	float v = a * 0.62;
	v += n1(x * 2.1 + seed * 1.7) * 0.22;
	v += n1(x * 4.3 + seed * 2.3) * 0.1;
	v += n1(x * 9.7 + seed * 3.1) * 0.04;
	return v;
}
float aedge(float v, float e, float w) {
	return smoothstep(e - w, e + w, v);
}
vec3 sky_grad(float g) {
	return g < 0.58 ? mix(sky_top, sky_mid, g / 0.58) : mix(sky_mid, sky_low, (g - 0.58) / 0.42);
}

void fragment() {
	vec2 p = wpos;
	float t = TIME;
	float px = p.x - cam.x * 0.92;

	// --- swirling field: domain-warped noise whose contour lines become brush strokes
	vec2 q = vec2(px * 0.0042, p.y * 0.011);
	vec2 wq = vec2(fbm(q + vec2(0.0, t * 0.012)), fbm(q + vec2(5.2, 1.3) - t * 0.01));
	vec2 r = q + (wq - 0.5) * 2.6;
	float field = fbm(r);

	// --- flat gradient bands, their edges bent by the swirl
	float sy = clamp((p.y + 320.0) / 320.0, 0.0, 1.0);
	float g = clamp(sy + (field - 0.5) * 0.16, 0.0, 1.0);
	float gb = floor(g * 6.0) / 6.0;
	float gf = fract(g * 6.0);
	float gfw = fwidth(g * 6.0) + 1e-4;
	g = gb + aedge(gf, 1.0 - gfw, gfw) / 6.0;
	vec3 col = sky_grad(g);
	float contour = fract(field * 11.0 + t * 0.015);
	float cfw = fwidth(field * 11.0) + 1e-4;
	float stroke = aedge(contour, 0.5, cfw) * (1.0 - aedge(contour, 0.62, cfw));
	col = mix(col, col * 1.08 + vec3(0.02), stroke * 0.55);
	col = mix(col, col * 0.93, (1.0 - aedge(contour, 0.12, cfw)) * 0.4);

	// --- sun: a flat disc with two flat halo rings, nearly fixed on screen
	vec2 sun = vec2(cam.x + 170.0 + (cam.x - 1600.0) * 0.04, sun_y);
	float sd = length((p - sun) * vec2(1.0, 1.15)) + (field - 0.5) * 6.0;
	float sfw = fwidth(sd) + 1e-4;
	col = mix(col, mix(col, sun_col, 0.35), 1.0 - aedge(sd, 70.0, sfw));
	col = mix(col, mix(col, sun_col * 1.1, 0.6), 1.0 - aedge(sd, 36.0, sfw));
	col = mix(col, vec3(1.0, 0.97, 0.86), 1.0 - aedge(sd, 16.0, sfw));

	// --- stars: tiny crisp dots
	if (stars > 0.01 && sy < 0.55) {
		vec2 cell = floor(p / 7.0);
		float h = hash21(cell);
		if (h > 0.93) {
			vec2 c = (cell + 0.5 + (vec2(hash21(cell + 3.1), hash21(cell + 7.7)) - 0.5) * 0.6) * 7.0;
			float dd = length(p - c);
			float tw = 0.6 + 0.4 * sin(t * 2.0 + h * 80.0);
			col = mix(col, vec3(0.95, 0.95, 1.0), (1.0 - aedge(dd, 0.6 + tw * 0.3, 0.35)) * stars * (0.55 - sy) * 2.0);
		}
	}

	// --- cut-out clouds: flat body, lit rim from below and the sun side, ink edge
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		vec2 cq = vec2(px * (0.0045 - fi * 0.0012) + t * (0.004 + fi * 0.003), p.y * (0.02 + fi * 0.008) + fi * 7.0);
		cq += (wq - 0.5) * 0.9;
		float c = fbm(cq);
		float cover = 0.58 - storm * 0.18 - fi * 0.03;
		float bandm = smoothstep(-300.0, -200.0, p.y) * smoothstep(-20.0, -120.0 + fi * 40.0, p.y);
		float cc_fw = fwidth(c) * 0.9 + 1e-4;
		float inside = aedge(c, cover + (1.0 - bandm) * 0.25, cc_fw);
		if (inside > 0.0) {
			float below = fbm(cq + vec2(0.0, 0.07));
			float rim = clamp((c - below) * 10.0, 0.0, 1.0);
			vec3 dark = mix(mix(sky_mid, sky_top, 0.5), vec3(0.14, 0.03, 0.06), storm * 0.8);
			vec3 mid = mix(sky_mid, sky_low, 0.5);
			vec3 lit = mix(sky_low, sun_col, 0.6) * 1.08;
			lit = mix(lit, vec3(1.0, 0.5, 0.22), storm * 0.6);
			float tone = 1.0 - rim;
			float rfw = fwidth(tone) + 1e-4;
			vec3 cc = dark;
			cc = mix(cc, mid, aedge(tone, 0.35, rfw));
			cc = mix(cc, lit, aedge(tone, 0.7, rfw));
			// ink edge on the cloud outline
			float edge_line = 1.0 - aedge(c, cover + (1.0 - bandm) * 0.25 + cc_fw * 3.0, cc_fw);
			cc = mix(cc, ink_col, edge_line * 0.55);
			col = mix(col, cc, inside * (0.95 - fi * 0.15));
		}
	}
	vec3 sky_col = col;

	// --- three mountain ranges, far to near: flat lit and shadow faces, snow caps, ink ridges
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float par = 0.85 - fi * 0.3;
		float x = p.x - cam.x * par;
		float scale = 1.0 / (230.0 - fi * 55.0);
		float seed = fi * 13.7 + 3.0;
		float rr = ridge(x * scale, seed);
		float top = (-30.0 + fi * 30.0) - rr * (170.0 - fi * 45.0);
		float depth = p.y - top;
		float dfw = fwidth(depth) + 1e-4;
		float m = aedge(depth, 0.0, dfw);
		if (m > 0.0) {
			float slope = ridge((x + 2.0) * scale, seed) - ridge((x - 2.0) * scale, seed);
			bool lit = slope < 0.0;
			vec3 rock_lit = mix(vec3(0.58, 0.5, 0.7), vec3(0.38, 0.33, 0.5), fi / 2.0) * mix(vec3(1.0), sky_low, 0.3);
			vec3 rock_sh = mix(vec3(0.34, 0.35, 0.62), vec3(0.18, 0.18, 0.38), fi / 2.0) * mix(vec3(1.0), sky_mid, 0.3);
			vec3 snow_lit = mix(vec3(1.0, 0.95, 0.88), sun_col, 0.35);
			vec3 snow_sh = mix(vec3(0.6, 0.62, 0.88), sky_mid, 0.35);
			float sn = vnoise(vec2(x * 0.05, fi * 5.0));
			float snow_depth = 10.0 + sn * 34.0 + (lit ? 10.0 : 0.0);
			float patchy = vnoise(vec2(x * 0.045, p.y * 0.07 + fi * 9.0));
			vec3 c = lit ? rock_lit : rock_sh;
			float snow_m = max(1.0 - aedge(depth, snow_depth, 0.6), aedge(patchy, 0.72, fwidth(patchy) + 1e-4) * (1.0 - aedge(depth, 90.0, 0.6)));
			c = mix(c, lit ? snow_lit : snow_sh, snow_m);
			// ink line along the ridge
			c = mix(c, ink_col, (1.0 - aedge(depth, 1.1, dfw)) * (0.75 - fi * 0.15));
			float hz = 0.62 - fi * 0.26;
			col = mix(col, mix(c, sky_col, hz), m);
		}
	}
	// --- flat mist bands at the foot of the mountains
	float mist = smoothstep(-10.0, bottom_y, p.y);
	float mb = floor(mist * 4.0) / 4.0 + aedge(fract(mist * 4.0), 0.98, fwidth(mist * 4.0) + 1e-4) / 4.0;
	col = mix(col, mix(vec3(0.86, 0.85, 0.95), sky_low, 0.25), mb * 0.9);
	COLOR = vec4(col, 1.0);
}
