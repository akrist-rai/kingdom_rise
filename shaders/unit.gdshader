// Soldier sprites (baked from the KayKit CC0 characters). One bake serves every army:
//  - team cloth was baked as a pure green key; it is re-coloured here with the faction ramp
//  - neutral greys (steel) take a faction tint (warm for the March, cold for the Crown)
//  - modulate above 1.0 is a hit flash (Unit sets e.g. Color(2, 2, 2)), below 1.0 tints / fades
shader_type canvas_item;

uniform vec3 team_hi : source_color = vec3(0.98, 0.5, 0.38);
uniform vec3 team_mid : source_color = vec3(0.76, 0.16, 0.14);
uniform vec3 team_lo : source_color = vec3(0.26, 0.04, 0.08);
uniform vec3 steel_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 flash_col : source_color = vec3(1.0, 0.96, 0.9);

varying vec4 mod;

void vertex() {
	mod = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float key = smoothstep(0.04, 0.14, c.g - max(c.r, c.b));
	float s = pow(clamp(c.g * 1.08, 0.0, 1.0), 1.3);
	vec3 tc = s < 0.5 ? mix(team_lo, team_mid, s * 2.0) : mix(team_mid, team_hi, (s - 0.5) * 2.0);
	c.rgb = mix(c.rgb, tc, key);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float grey = (1.0 - smoothstep(0.04, 0.16, mx - mn)) * (1.0 - key);
	c.rgb *= mix(vec3(1.0), steel_tint, grey);
	float flash = clamp(max(mod.r, max(mod.g, mod.b)) - 1.0, 0.0, 1.0);
	c.rgb = mix(c.rgb * min(mod.rgb, vec3(1.0)), flash_col, flash);
	c.a *= mod.a;
	COLOR = c;
}
