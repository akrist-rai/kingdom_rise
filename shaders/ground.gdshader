// Snow battlefield. Soft wind-sculpted drifts shaded from the slope of a height field (lit from
// the upper left, cool in the hollows), fine wind ripples, glinting crystals, a broad band of
// snow trampled grey and churned to slush where the armies have fought, frozen earth with dry
// grass showing through, iced-over ponds reflecting the sky, and rocky foothills at the top.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform float top_y = 80.0;
uniform float map_w = 3200.0;
uniform vec4 c0 : source_color = vec4(0.17, 0.27, 0.37, 1.0);   // deep drift shadow
uniform vec4 c1 : source_color = vec4(0.42, 0.53, 0.66, 1.0);   // shadow
uniform vec4 c2 : source_color = vec4(0.66, 0.75, 0.84, 1.0);   // half tone
uniform vec4 c3 : source_color = vec4(0.87, 0.9, 0.93, 1.0);    // lit snow
uniform vec4 c4 : source_color = vec4(0.98, 0.96, 0.93, 1.0);   // glare
uniform vec4 earth_col : source_color = vec4(0.27, 0.24, 0.22, 1.0);
uniform vec4 rock : source_color = vec4(0.16, 0.2, 0.26, 1.0);
uniform vec4 ink_col : source_color = vec4(0.03, 0.07, 0.1, 1.0);
uniform vec3 sky_a = vec3(0.6, 0.58, 0.78);
uniform vec3 sky_b = vec3(1.0, 0.82, 0.64);
uniform vec2 wind_dir = vec2(1.0, 0.26);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

float drift(vec2 p) {
	return fbm(p * vec2(0.0042, 0.0085)) + vnoise(p * vec2(0.014, 0.03)) * 0.18;
}

void fragment() {
	vec2 p = wpos;
	vec2 wd = normalize(wind_dir);
	vec2 q = vec2(dot(p, wd), dot(p, vec2(-wd.y, wd.x)));

	// --- drifts: shade a height field by its slope against a light from the upper left
	float h = drift(p);
	float hx = drift(p + vec2(5.0, 0.0));
	float hy = drift(p + vec2(0.0, 5.0));
	vec2 grad = vec2(h - hx, h - hy) * 60.0;
	float sl = clamp(dot(grad, normalize(vec2(-0.62, -0.72))) * 2.2, -1.0, 1.0);   // -1 lee side, +1 facing the sun
	float hl = smoothstep(-0.2, 0.8, sl);
	vec3 col = c3.rgb;
	col = mix(col, c2.rgb, smoothstep(0.1, -0.7, sl) * 0.85);
	col = mix(col, c1.rgb, smoothstep(-0.5, -1.0, sl) * 0.35);
	col = mix(col, c4.rgb, smoothstep(0.3, 1.0, sl) * 0.55);
	// cooler, bluer snow lying in the broad hollows
	col = mix(col, c2.rgb, smoothstep(0.48, 0.3, h) * 0.3);

	// --- wind ripples, faint and only on some drifts
	float rmask = smoothstep(0.5, 0.72, vnoise(p * 0.004 + 9.0));
	float rip = sin(q.y * 0.5 + vnoise(q * vec2(0.01, 0.03)) * 8.0 + q.x * 0.01);
	col *= 1.0 + rip * 0.035 * rmask;
	// powder grain
	col *= 0.985 + vnoise(p * 0.7) * 0.03;

	// --- trampled: grey compacted snow, slush and mud where the armies have fought
	float field = smoothstep(top_y + 20.0, top_y + 140.0, p.y) * smoothstep(map_w + 40.0, map_w - 200.0, p.x) * smoothstep(-40.0, 200.0, p.x);
	float tn = fbm(p * 0.0035 + 31.0) + (vnoise(p * 0.03) - 0.5) * 0.12;
	float tramp = smoothstep(0.42, 0.58, tn) * field;
	vec3 packed = mix(c2.rgb, vec3(0.6, 0.62, 0.66), 0.55) * (0.92 + vnoise(p * 0.09) * 0.12);
	col = mix(col, packed, tramp * 0.75);
	float slush = smoothstep(0.66, 0.78, tn + (vnoise(p * 0.02 + 4.0) - 0.5) * 0.2) * field;
	vec3 slc = mix(vec3(0.56, 0.55, 0.56), vec3(0.44, 0.4, 0.37), smoothstep(0.4, 0.7, vnoise(p * 0.05)));
	col = mix(col, slc, slush * 0.55);

	// --- frozen earth and dry grass where the snow has blown thin
	float m = fbm(p * 0.009 + 20.0) * 0.8 + vnoise(q * vec2(0.03, 0.1)) * 0.2;
	float earth = smoothstep(0.68, 0.76, m) * (1.0 - slush);
	vec3 ec = mix(vec3(0.42, 0.38, 0.33), vec3(0.66, 0.6, 0.47), smoothstep(0.4, 0.62, vnoise(q * vec2(0.08, 0.5))));
	ec *= 0.85 + vnoise(p * 0.2) * 0.25;
	// half buried: snow still lies between the tussocks
	col = mix(col, ec, earth * (0.45 + 0.3 * smoothstep(0.4, 0.7, vnoise(p * 0.12))));
	// snow lying in the lee of each patch
	col = mix(col, c3.rgb, smoothstep(0.66, 0.7, m) * (1.0 - smoothstep(0.7, 0.74, m)) * 0.35);

	// --- iced ponds: pale reflection of the sky, white cracks, a soft snow rim
	float pond = vnoise(p * 0.0028 + 50.0) * 0.75 + vnoise(p * 0.013 + 9.0) * 0.25;
	float ice = smoothstep(0.79, 0.81, pond) * (1.0 - earth) * (1.0 - slush);
	if (ice > 0.0) {
		float refl = smoothstep(0.3, 0.9, fract(p.y * 0.004 + vnoise(vec2(p.x * 0.004, p.y * 0.01))));
		vec3 ic = mix(vec3(0.62, 0.74, 0.88), mix(sky_b, sky_a, refl), 0.3);
		ic *= 0.92 + vnoise(q * vec2(0.02, 0.2)) * 0.12;
		float crack = abs(vnoise(p * 0.06) - 0.5);
		ic = mix(ic, vec3(0.96, 0.98, 1.0), (1.0 - smoothstep(0.0, 0.018, crack)) * 0.8);
		float rim = 1.0 - smoothstep(0.81, 0.83, pond);
		ic = mix(ic, c3.rgb, rim * 0.7);
		col = mix(col, ic, ice);
	}

	// --- crystals glinting in the lit snow
	vec2 gc = floor(p * 0.9);
	float gl = step(0.996, hash21(gc)) * hl * (1.0 - tramp) * (1.0 - earth);
	col = mix(col, vec3(1.0), gl * 0.7);

	// --- foothills at the top: rock with snow lying on the ledges
	if (p.y < top_y + 10.0) {
		float k = clamp((top_y - p.y) / 70.0, 0.0, 1.0);
		float rn = fbm(p * vec2(0.022, 0.05));
		float rv = rn * 0.8 + (1.0 - k) * 0.55;
		float rk = 1.0 - smoothstep(0.47, 0.53, rv);
		float ledge = smoothstep(0.45, 0.6, vnoise(p * vec2(0.05, 0.12)));
		vec3 rc = mix(rock.rgb, rock.rgb * 1.5, smoothstep(0.4, 0.6, vnoise(p * vec2(0.05, 0.02))));
		rc = mix(rc, c2.rgb, ledge * 0.55);
		col = mix(col, rc, rk);
		// a soft dark seam where the rock meets the snow
		col *= 1.0 - (smoothstep(0.44, 0.5, rv) - smoothstep(0.5, 0.56, rv)) * 0.3;
	}
	COLOR = vec4(col, 1.0);
}
