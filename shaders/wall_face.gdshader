// The tall south face of a wall, seen from the front: courses of ashlar blocks of uneven
// length with a lit top bevel and dark mortar, pilasters every few hundred units, soot and
// rain streaks running down, a deep shadow under the parapet and a dark foot.
// marble = 1 turns it into the palace terrace: pale marble with a red lacquer band and gold rule.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform vec2 rsize = vec2(100.0);
uniform vec3 stone = vec3(0.64, 0.67, 0.57);
uniform vec3 mortar = vec3(0.27, 0.35, 0.31);
uniform float block_h = 14.0;
uniform float pilaster = 260.0;
uniform float marble = 0.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

void fragment() {
	vec2 p = wpos;
	float k = clamp((p.y - origin.y) / rsize.y, 0.0, 1.0);    // 0 at the top edge, 1 at the foot
	float bh = block_h * (marble > 0.5 ? 1.4 : 1.0);
	float row = floor(p.y / bh);
	float bw = (22.0 + hash21(vec2(row, 3.0)) * 18.0) * (marble > 0.5 ? 1.6 : 1.0);
	float off = hash21(vec2(row, 7.0)) * bw;
	float cx = floor((p.x + off) / bw);
	vec2 f = vec2(fract((p.x + off) / bw) * bw, fract(p.y / bh) * bh);
	float d = min(min(f.x, bw - f.x), min(f.y, bh - f.y));
	float tone = hash21(vec2(cx, row));
	vec3 base = marble > 0.5 ? vec3(0.82, 0.79, 0.65) : stone;
	vec3 c = base * (0.8 + tone * 0.3);
	c *= 0.9 + vnoise(p * 0.06) * 0.2;
	c *= mix(1.14, 0.86, f.y / bh);                     // bevel: lit top edge of each block
	float aa = fwidth(d) + 1e-4;
	c = mix(marble > 0.5 ? vec3(0.42, 0.38, 0.46) : mortar, c, smoothstep(0.7 - aa, 0.7 + aa, d));
	// pilasters: a slightly proud strip, lit on the left, shaded on the right
	float px = mod(p.x + 60.0, pilaster);
	float pil = step(px, 34.0);
	c *= mix(1.0, mix(1.16, 0.84, smoothstep(10.0, 30.0, px)), pil);
	c = mix(c, c * 0.6, (1.0 - smoothstep(0.0, 2.0, abs(px - 34.0))) * 0.8);
	// soot and rain streaks running down from the top
	float st = vnoise(vec2(p.x * 0.07, p.y * 0.0035));
	c *= 1.0 - smoothstep(0.55, 0.8, st) * 0.32 * (1.0 - k * 0.7);
	// cracks
	float cr = abs(vnoise(p * vec2(0.04, 0.012)) - 0.5);
	c *= 1.0 - (1.0 - smoothstep(0.0, 0.012, cr)) * 0.5 * step(0.6, vnoise(p * 0.01 + 3.0));
	if (marble > 0.5) {
		// red lacquer band with a gold rule below the balustrade
		float band = step(0.1, k) * step(k, 0.3);
		c = mix(c, vec3(0.6, 0.14, 0.12) * (0.9 + vnoise(p * 0.1) * 0.2), band);
		c = mix(c, vec3(0.9, 0.7, 0.32), (1.0 - smoothstep(0.0, 1.2, abs(p.y - (origin.y + rsize.y * 0.31)))) * 0.9);
	}
	// deep shadow under the parapet, a dark foot where the wall meets the ground
	c *= mix(0.5, 1.0, smoothstep(0.0, 0.16, k));
	c *= mix(1.0, 0.62, smoothstep(0.82, 1.0, k));
	COLOR = vec4(c, 1.0);
}
