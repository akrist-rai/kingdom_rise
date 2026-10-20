// Old printed campaign map paper: warm cream stock with slow tonal variation, foxing
// stains, fine fibres and tooth, two fold creases (light ridge + shadow), and darker,
// worn edges.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"

uniform vec2 size = vec2(640.0, 360.0);
uniform vec3 paper = vec3(0.925, 0.9, 0.82);

float crease(float d) {
	// d: signed distance to the fold. A thin dark valley with a light ridge on one side.
	return -exp(-d * d * 1.6) * 0.09 + exp(-(d - 2.2) * (d - 2.2) * 0.25) * 0.03 - exp(-(d + 3.0) * (d + 3.0) * 0.08) * 0.025;
}

void fragment() {
	vec2 p = UV * size;
	vec2 fc = FRAGCOORD.xy;
	vec3 c = paper;
	c *= 0.965 + fbm(p * 0.008) * 0.07;
	// foxing: scattered brown age spots and a couple of larger water stains
	float fx = fbm(p * 0.035 + 7.0);
	c = mix(c, vec3(0.78, 0.66, 0.47), smoothstep(0.7, 0.78, fx) * 0.22);
	float ws = fbm(p * 0.006 + 31.0);
	float ring = smoothstep(0.66, 0.67, ws) * (1.0 - smoothstep(0.672, 0.69, ws));
	c = mix(c, vec3(0.8, 0.7, 0.52), smoothstep(0.66, 0.75, ws) * 0.08 + ring * 0.12);
	// fibres and tooth, fixed to the screen pixels
	c *= 1.0 + (vnoise(fc * vec2(0.55, 0.045)) - 0.5) * 0.035 + (hash21(floor(fc)) - 0.5) * 0.035;
	// fold creases
	c *= 1.0 + crease(p.x - size.x * 0.5) + crease(p.y - size.y * 0.5) * 0.8;
	// worn, darkened edges
	vec2 e = min(p, size - p);
	float edge = min(e.x, e.y) + (vnoise(p * 0.07) - 0.5) * 10.0;
	c *= mix(0.72, 1.0, smoothstep(0.0, 30.0, edge));
	COLOR = vec4(c, 1.0);
}
