// The tall south face of a wall, seen from the front: courses of weathered ashlar of uneven
// length, each block pillowed (lit from the upper left like the baked props, its lower right
// edge in shade) and pitted, set in recessed mortar. Pilasters every few hundred units, soot and
// rain streaks running down, moss and splashed mud creeping up from the foot, a deep shadow under
// the parapet. marble = 1 turns it into the palace terrace: pale marble with a red lacquer band
// and gold rule.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform vec2 rsize = vec2(100.0);
uniform vec3 stone = vec3(0.66, 0.64, 0.55);
uniform vec3 mortar = vec3(0.22, 0.24, 0.22);
uniform float block_h = 16.0;
uniform float pilaster = 260.0;
uniform float marble = 0.0;
uniform float kofs = 0.0;      // the top edge relative to origin, for faces that are not rects

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

void fragment() {
	vec2 p = wpos;
	bool mb = marble > 0.5;
	float k = clamp((p.y - origin.y - kofs) / rsize.y, 0.0, 1.0);    // 0 at the top edge, 1 at the foot
	float bh = block_h * (mb ? 1.3 : 1.0);
	float row = floor(p.y / bh);
	float bw = (26.0 + hash21(vec2(row, 3.0)) * 22.0) * (mb ? 1.5 : 1.0);
	float off = hash21(vec2(row, 7.0)) * bw;
	float cx = floor((p.x + off) / bw);
	// a few blocks per course are half-width, so the joints never line up into a grid
	float split = step(0.72, hash21(vec2(cx, row + 11.0)));
	float lx = fract((p.x + off) / bw) * bw;
	float bww = bw;
	if (split > 0.5) {
		bww = bw * 0.5;
		cx += step(bww, lx) * 0.5;
		lx = mod(lx, bww);
	}
	vec2 f = vec2(lx, fract(p.y / bh) * bh);
	vec2 sz = vec2(bww, bh);
	vec2 id = vec2(cx, row);
	float tone = hash21(id);
	float warm = hash21(id + 5.3);
	// colour: weathered sandstone drifting between warm and cool per block
	vec3 base = mb ? vec3(0.86, 0.83, 0.72) : stone;
	vec3 c = base * (0.78 + tone * 0.3);
	c *= mix(vec3(0.94, 0.98, 1.04), vec3(1.06, 1.0, 0.9), warm);
	// pillowed face: each block reads as a slightly domed lump lit from the upper left
	vec2 q = (f / sz) * 2.0 - 1.0;                         // -1..1 across the block
	float edge_x = smoothstep(0.55, 1.0, abs(q.x));
	float edge_y = smoothstep(0.45, 1.0, abs(q.y));
	float lit = (q.x < 0.0 ? edge_x * 0.10 : -edge_x * 0.16) + (q.y < 0.0 ? edge_y * 0.16 : -edge_y * 0.24);
	c *= 1.0 + lit;
	// pitting and grain, stronger on the older, darker blocks
	float grain = fbm(p * 0.22 + id * 7.0);
	c *= 0.91 + grain * 0.17;
	float pit = smoothstep(0.62, 0.7, vnoise(p * 0.35 + id * 3.1));
	c *= 1.0 - pit * 0.12 * (1.2 - tone);
	// a chipped corner on some blocks
	vec2 corner = sign(vec2(hash21(id + 3.0) - 0.5, hash21(id + 4.0) - 0.5));
	float chip = step(0.78, hash21(id + 2.2)) * (1.0 - smoothstep(0.35, 0.5, length(q - corner)));
	c *= 1.0 - chip * 0.3;
	// recessed mortar: the joint under a block is in its shadow, the joint above it catches light
	float d = min(min(f.x, sz.x - f.x), min(f.y, sz.y - f.y));
	float aa = fwidth(d) + 1e-4;
	float jw = mb ? 0.6 : 1.0;
	vec3 mc = mb ? vec3(0.5, 0.46, 0.52) : mortar;
	mc *= 0.8 + vnoise(p * 0.5) * 0.4;
	float in_joint = 1.0 - smoothstep(jw - aa, jw + aa, d);
	c = mix(c, mc, in_joint);
	// a thin dark line just inside the bottom and right edges (the block's own cast shadow)
	float sh_b = (1.0 - smoothstep(jw, jw + 1.6, sz.y - f.y)) * (1.0 - in_joint);
	float sh_r = (1.0 - smoothstep(jw, jw + 1.4, sz.x - f.x)) * (1.0 - in_joint);
	c *= 1.0 - max(sh_b, sh_r) * 0.28;
	// a bright rim along the top edge of every block
	c *= 1.0 + (1.0 - smoothstep(jw, jw + 1.2, f.y)) * (1.0 - in_joint) * 0.14;
	// pilasters: a proud strip, lit on the left, shaded on the right, with a cast shadow
	float px = mod(p.x + 60.0, pilaster);
	float pil = step(px, 38.0);
	c *= mix(1.0, mix(1.14, 0.88, smoothstep(8.0, 34.0, px)), pil);
	c = mix(c, c * 0.55, (1.0 - smoothstep(0.0, 1.5, abs(px - 38.0))) * 0.85);
	c *= mix(1.0, mix(0.72, 1.0, smoothstep(38.0, 58.0, px)), step(38.0, px) * step(px, 58.0));
	// soot and rain streaks running down from the top, broken by the courses
	float st = vnoise(vec2(p.x * 0.06, p.y * 0.003));
	float st2 = vnoise(vec2(p.x * 0.21, p.y * 0.008 + 9.0));
	c *= 1.0 - smoothstep(0.55, 0.82, st) * 0.34 * (1.0 - k * 0.6);
	c *= 1.0 - smoothstep(0.7, 0.9, st2) * 0.16;
	// lighter lime wash bleeding out of the joints near the top
	c = mix(c, vec3(0.86, 0.84, 0.76), smoothstep(0.6, 0.9, vnoise(p * vec2(0.05, 0.02) + 17.0)) * 0.12 * (1.0 - k));
	// cracks that follow the joints for a while
	float cr = abs(vnoise(p * vec2(0.035, 0.011)) - 0.5);
	c *= 1.0 - (1.0 - smoothstep(0.0, 0.01, cr)) * 0.55 * step(0.62, vnoise(p * 0.009 + 3.0));
	if (mb) {
		// red lacquer band with a gold rule below the balustrade
		float band = step(0.1, k) * step(k, 0.3);
		c = mix(c, vec3(0.6, 0.14, 0.12) * (0.9 + vnoise(p * 0.1) * 0.2), band);
		c = mix(c, vec3(0.9, 0.7, 0.32), (1.0 - smoothstep(0.0, 1.2, abs(p.y - (origin.y + rsize.y * 0.31)))) * 0.9);
	} else {
		// moss and lichen climbing from the foot and gathering in the joints
		float mn = fbm(p * vec2(0.03, 0.05) + 40.0);
		float moss = smoothstep(0.2, 0.0, (1.0 - k) - mn * 0.36) * (0.45 + in_joint * 0.6);
		moss = max(moss, in_joint * smoothstep(0.7, 0.82, mn) * 0.6);
		vec3 mcol = mix(vec3(0.27, 0.36, 0.16), vec3(0.42, 0.48, 0.2), vnoise(p * 0.3));
		c = mix(c, mcol * (0.8 + grain * 0.4), clamp(moss, 0.0, 0.85));
		// mud splashed up the bottom few feet
		float splash = smoothstep(0.78, 1.0, k + (vnoise(p * vec2(0.12, 0.06)) - 0.5) * 0.12);
		c = mix(c, vec3(0.28, 0.22, 0.15), splash * 0.6);
	}
	// deep shadow under the parapet, a dark foot where the wall meets the ground
	c *= mix(0.42, 1.0, smoothstep(0.0, 0.18, k));
	c *= mix(1.0, 0.55, smoothstep(0.86, 1.0, k));
	COLOR = vec4(c, 1.0);
}
