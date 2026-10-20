// A worn practice floor: pale sand inside a mossy flagstone court. Low-frequency
// colour variation carries the scene; fine detail stays quieter than weapons.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"
uniform vec2 origin=vec2(0.0);
varying vec2 world;
void vertex(){world=VERTEX+origin;}
void fragment(){
	vec2 p=world;
	vec2 q=p/vec2(14.0,10.0);
	q.x+=mod(floor(q.y),2.0)*0.5;
	vec2 f=fract(q);
	float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	float seam=1.0-smoothstep(0.015,0.055,edge);
	float id=hash21(floor(q));
	vec3 stone=mix(vec3(0.42,0.47,0.43),vec3(0.61,0.61,0.5),id);
	stone=mix(stone,vec3(0.23,0.31,0.27),seam*0.38);
	float moss=smoothstep(0.58,0.77,vnoise(p*0.026))*seam;
	stone=mix(stone,vec3(0.27,0.38,0.25),moss*0.7);
	vec2 d=abs((p-vec2(600,470))/vec2(340,245));
	float margin=max(d.x,d.y)+(vnoise(p*0.025)-0.5)*0.14;
	float sand=1.0-smoothstep(0.8,1.0,margin);
	float grain=vnoise(p*0.34);
	vec3 earth=mix(vec3(0.54,0.48,0.36),vec3(0.7,0.63,0.46),vnoise(p*0.006));
	earth*=0.96+grain*0.065;
	float scuff=smoothstep(0.65,0.82,vnoise(p*vec2(0.045,0.11)));
	earth*=1.0-scuff*0.035;
	vec3 col=mix(stone,earth,sand);
	col*=0.96+vnoise(p*0.04)*0.06;
	COLOR=vec4(col,1.0);
}
