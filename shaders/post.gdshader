// Full-screen post-processing in the painted-poster style, in one pass:
//   lighting (scene x (ambient + light buffer), with the light pools posterised into flat
//   bands), bloom, flat light beams, hard-edged navy cloud shadows drifting over the field,
//   banded fog, a gradient map that pulls everything toward a limited per-battle palette
//   (while keeping saturated faction colours), the sumi-e ink-wash filter (used while
//   choosing a new body), manga impact frames, chromatic aberration, lightning flash,
//   letterbox, a brushed ink vignette and paper grain.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D light_tex : filter_linear;
uniform vec2 cam = vec2(0.0);
uniform vec2 view = vec2(640.0, 360.0);
uniform float zoom = 1.0;

uniform vec3 ambient = vec3(1.0);
uniform float light_gain = 1.5;
uniform float light_soft = 0.0;   // 0 = flat posterised light pools, 1 = smooth falloff
uniform float bloom = 0.5;
uniform float bloom_thresh = 0.84;
uniform vec3 ray_col = vec3(1.0, 0.8, 0.5);
uniform float ray_strength = 0.2;
uniform vec2 ray_dir = vec2(-0.8, 0.6);
uniform float cloud_shadow = 0.2;
uniform vec3 cloud_tint = vec3(0.55, 0.6, 1.0);
uniform vec2 wind = vec2(9.0, 2.0);
uniform vec3 fog_col = vec3(0.9, 0.88, 0.96);
uniform float fog_density = 0.15;
uniform float haze = 0.3;
uniform vec3 shadow_tint = vec3(0.85, 0.9, 1.08);
uniform vec3 high_tint = vec3(1.06, 1.0, 0.92);
uniform float saturation = 1.1;
uniform float contrast = 1.08;
uniform vec3 pal_dark = vec3(0.1, 0.09, 0.28);
uniform vec3 pal_mid = vec3(0.6, 0.44, 0.62);
uniform vec3 pal_light = vec3(1.0, 0.94, 0.78);
uniform float poster = 0.35;
uniform vec3 horizon = vec3(1.0, 0.72, 0.6);
uniform float horizon_k = 0.22;
uniform float paper = 1.0;
uniform float vignette = 0.5;
uniform float hurt = 0.0;
uniform float ink = 0.0;
uniform float impact = 0.0;
uniform float impact_invert = 0.0;
uniform float ca = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_col = vec3(1.0, 0.95, 0.9);
uniform float letterbox = 0.0;
uniform float blizzard = 0.0;
uniform float blur = 0.0;

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 soft_clip(vec3 c) {
	// Keeps colours below 0.8 untouched and rolls brighter values off smoothly,
	// so warm lights burn toward yellow-white instead of clipping flat.
	vec3 over = max(c - 0.8, 0.0);
	return min(c, vec3(0.8)) + (1.0 - exp(-over * 4.0)) * 0.2;
}

float red_mask(vec3 c) {
	return smoothstep(0.12, 0.32, c.r - max(c.g, c.b) * 1.05) * step(0.25, c.r);
}

// Quantises x into n flat steps with short soft transitions (screen-print bands).
float bands(float x, float n, float soft) {
	float y = x * n;
	float f = fract(y);
	return (floor(y) + smoothstep(0.5 - soft, 0.5 + soft, f)) / n;
}

vec3 grad_map(float g) {
	return g < 0.5 ? mix(pal_dark, pal_mid, g * 2.0) : mix(pal_mid, pal_light, (g - 0.5) * 2.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 sp = uv * view;
	vec2 w = (sp - view * 0.5) / zoom + cam;
	vec2 fc = FRAGCOORD.xy;
	float t = TIME;

	// --- scene (with optional chromatic aberration)
	vec3 scene;
	if (ca > 0.01) {
		vec2 dir = (uv - 0.5) * ca / view;
		scene.r = textureLod(screen_tex, uv + dir, 0.0).r;
		scene.g = textureLod(screen_tex, uv, 0.0).g;
		scene.b = textureLod(screen_tex, uv - dir, 0.0).b;
	} else {
		scene = textureLod(screen_tex, uv, 0.0).rgb;
	}
	if (blur > 0.001) {
		scene = mix(scene, textureLod(screen_tex, uv, 2.2).rgb, blur);
	}
	vec3 raw = scene;

	// --- light buffer, softened, then posterised into flat pools (hue kept)
	vec2 lp = 1.0 / (view * 0.5);
	vec3 L = texture(light_tex, uv).rgb * 0.4;
	L += texture(light_tex, uv + vec2(lp.x * 1.5, 0.0)).rgb * 0.15;
	L += texture(light_tex, uv - vec2(lp.x * 1.5, 0.0)).rgb * 0.15;
	L += texture(light_tex, uv + vec2(0.0, lp.y * 1.5)).rgb * 0.15;
	L += texture(light_tex, uv - vec2(0.0, lp.y * 1.5)).rgb * 0.15;
	float lm = max(L.r, max(L.g, L.b));
	float lwob = (vnoise(w * 0.09) - 0.5) * 0.05;
	float lq = bands(lm + lwob, 4.0, 0.06);
	L *= mix(lq / max(lm, 0.001), 1.0, light_soft);

	// --- cloud shadows: flat navy shapes with brush-wobbled edges
	float cl = fbm(w * 0.0021 + wind * t * 0.0011) + (vnoise(w * vec2(0.03, 0.09) + t * 0.05) - 0.5) * 0.035;
	float cfw = fwidth(cl) * 0.9 + 1e-4;
	float cloud = smoothstep(0.56 - cfw, 0.56 + cfw, cl);
	vec3 amb = ambient * mix(vec3(1.0), cloud_tint, cloud * clamp(cloud_shadow * 2.6, 0.0, 1.0));

	// --- flat light beams where the sky opens
	vec2 rd = normalize(ray_dir);
	float proj = dot(w, vec2(-rd.y, rd.x));
	float along = dot(w, rd);
	float band = vnoise(vec2(proj * 0.012 + t * 0.03, 0.0)) * 0.7 + vnoise(vec2(proj * 0.04 - t * 0.05, 3.0)) * 0.3;
	float bfw = fwidth(band) + 1e-4;
	float rays = smoothstep(0.7 - bfw, 0.7 + bfw, band) * (0.6 + 0.4 * step(0.5, vnoise(vec2(along * 0.004 + t * 0.02, proj * 0.003))));
	rays *= (1.0 - cloud) * ray_strength * 0.6;

	// --- lighting
	vec3 col = scene * (amb + L * light_gain);
	col += ray_col * rays * (0.3 + lum(scene) * 0.5);
	col += L * L * 0.3 * light_gain;

	// --- bloom from bright parts of the scene (screen mipmaps) and from lights
	vec3 b1 = textureLod(screen_tex, uv, 2.0).rgb;
	vec3 b2 = textureLod(screen_tex, uv, 3.5).rgb;
	vec3 bl = max(b1 - bloom_thresh, 0.0) * 0.5 + max(b2 - bloom_thresh, 0.0) * 0.8;
	col += bl * bloom * (amb + L);
	col += L * bloom * 0.14;

	// --- fog: flat drifting banks in two tones + banded haze toward the top
	float f1 = fbm(w * 0.004 + vec2(t * 0.025, t * 0.006));
	float f2 = vnoise(w * 0.011 + vec2(-t * 0.045, t * 0.012) + 31.0);
	float fv = f1 * 0.65 + f2 * 0.35;
	float ffw = fwidth(fv) + 1e-4;
	float fog = (smoothstep(0.6 - ffw, 0.6 + ffw, fv) * 0.6 + smoothstep(0.7 - ffw, 0.7 + ffw, fv) * 0.4) * fog_density;
	fog += blizzard * 0.28 * (0.5 + 0.5 * f2);
	fog += bands(smoothstep(0.55, 0.0, uv.y), 3.0, 0.04) * haze * 0.35;
	fog = clamp(fog, 0.0, 0.85);
	vec3 fogc = fog_col * (amb * 0.6 + 0.4) + L * 0.3;
	col = mix(col, fogc, fog);

	// --- peach light from the low sun beyond the armies, washing down from the top
	float hz = smoothstep(0.75, 0.0, uv.y) * (1.0 - cloud * 0.6);
	col = mix(col, col * horizon * 1.25 + horizon * 0.06, hz * horizon_k);

	// --- colour grading: split tone, contrast, saturation
	col = soft_clip(col);
	float l = lum(col);
	col *= mix(shadow_tint, high_tint, smoothstep(0.05, 0.85, l));
	col = (col - 0.5) * contrast + 0.5;
	l = lum(col);
	col = mix(vec3(l), col, saturation);

	// --- limited palette: gradient-map the image, but keep strongly coloured things
	//     (faction cloth, fire, blood) closer to their own hue
	float chroma = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	float keep = smoothstep(0.2, 0.5, chroma);
	vec3 gm = grad_map(clamp(lum(col), 0.0, 1.0));
	col = mix(col, gm, poster * (1.0 - keep * 0.75));

	// --- brushed ink vignette and hurt
	vec2 cuv = uv - 0.5;
	float vs = length(cuv * vec2(1.0, 1.3)) + (vnoise(fc * 0.012) - 0.5) * 0.05 + (vnoise(fc * vec2(0.004, 0.05)) - 0.5) * 0.03;
	float vfw = fwidth(vs) * 1.2 + 1e-4;
	float va = (smoothstep(0.3, 0.75, vs) * 0.5 + smoothstep(0.66 - vfw, 0.66 + vfw, vs) * 0.5) * (vignette + hurt * 0.6);
	vec3 dark = mix(pal_dark * 0.45, vec3(0.45, 0.02, 0.06), hurt);
	col = mix(col, dark, clamp(va, 0.0, 0.92));

	// --- sumi-e ink wash
	if (ink > 0.001) {
		float px = 1.0 / view.x;
		float py = 1.0 / view.y;
		float lx = lum(textureLod(screen_tex, uv + vec2(px, 0.0), 0.0).rgb) - lum(textureLod(screen_tex, uv - vec2(px, 0.0), 0.0).rgb);
		float ly = lum(textureLod(screen_tex, uv + vec2(0.0, py), 0.0).rgb) - lum(textureLod(screen_tex, uv - vec2(0.0, py), 0.0).rgb);
		float edge = length(vec2(lx, ly));
		float il = lum(raw);
		float tone = bands(il + (vnoise(w * 0.05) - 0.5) * 0.08, 4.0, 0.08);
		float grain = hash21(floor(fc)) * 0.05 + vnoise(fc * 0.04) * 0.05;
		vec3 paperc = vec3(0.94, 0.9, 0.82) - grain;
		vec3 inkc = vec3(0.07, 0.06, 0.09);
		vec3 ic = mix(inkc, paperc, pow(clamp(tone, 0.0, 1.0), 0.8));
		ic = mix(ic, inkc, smoothstep(0.06, 0.2, edge));
		ic = mix(ic, vec3(0.8, 0.12, 0.1), red_mask(raw) * 0.9);
		// ink seeps in from the edges of the screen
		float seep = smoothstep(ink * 1.6 - 0.6, ink * 1.6, 1.0 - length(cuv) * 1.2 + vnoise(sp * 0.05) * 0.2);
		col = mix(col, ic, clamp(ink * 1.2, 0.0, 1.0) * (1.0 - seep * (1.0 - ink)));
	}

	// --- manga impact frame: two-tone ink with red accents
	if (impact > 0.001) {
		float il = lum(raw * (ambient + L));
		float th = step(0.48, il);
		if (impact_invert > 0.5) {
			th = 1.0 - th;
		}
		vec3 ic = mix(vec3(0.03, 0.02, 0.04), vec3(0.98, 0.95, 0.88), th);
		ic = mix(ic, vec3(0.9, 0.08, 0.08), red_mask(raw));
		col = mix(col, ic, impact);
	}

	col = mix(col, flash_col, flash);

	// --- letterbox
	float bar = letterbox * 0.13;
	if (uv.y < bar || uv.y > 1.0 - bar) {
		col = vec3(0.02, 0.015, 0.03);
	}

	// --- paper: fine tooth, fibres and slow mottling, fixed to the screen like a print
	float tooth = hash21(floor(fc)) - 0.5;
	float fibre = vnoise(fc * vec2(0.5, 0.045)) - 0.5;
	float mottle = vnoise(fc * 0.006) - 0.5;
	col *= 1.0 + (tooth * 0.045 + fibre * 0.03 + mottle * 0.05) * paper;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
