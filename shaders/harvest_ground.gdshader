shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/common.gdshaderinc"
uniform vec2 origin = vec2(0.0);
uniform float wall_y = 1810.0;
uniform float ground_y = 2070.0;
uniform float terrace_y = 820.0;
uniform float ave_x0 = 1060.0;
uniform float ave_x1 = 1140.0;
varying vec2 world;
void vertex(){ world = VERTEX + origin; }
void fragment(){
 vec2 p = world;
 float brush = vnoise(p * 0.033);
 float grain = hash21(floor(p * 1.5));
 vec2 warp = vec2(vnoise(p*0.006),vnoise(p*0.005+39.0))*24.0;
 vec2 g = floor((p+warp)/vec2(210.0,130.0));
 float id = hash21(g);
 vec3 col = id < 0.23 ? vec3(0.57,0.61,0.34) : id < 0.55 ? vec3(0.77,0.67,0.37) : vec3(0.86,0.74,0.43);
 col *= 0.96+brush*0.08;
 float furrow = sin(p.y*0.71 + p.x*0.15 + id*19.0);
 col -= vec3(0.044,0.039,0.018)*step(0.82,furrow);
 float roadx = 1100.0 + sin(p.y*0.007)*32.0;
 float road = 1.0-smoothstep(44.0,62.0,abs(p.x-roadx)+brush*9.0);
 float cross = 1.0-smoothstep(19.0,32.0,abs(p.y-2310.0-sin(p.x*0.007)*28.0));
 road = max(road,cross*0.85);
 col = mix(col,vec3(0.87,0.78,0.57)*(0.97+brush*0.07),road);
 float track = (1.0-smoothstep(0.6,2.5,abs(abs(p.x-roadx)-22.0)))*road;
 col -= vec3(0.07,0.055,0.028)*track;
 if(p.y < ground_y){
   vec2 q=p/vec2(19.0,13.0); q.x += mod(floor(q.y),2.0)*0.5;
   vec2 f=fract(q);
   float seam=1.0-smoothstep(0.015,0.06,min(min(f.x,1.0-f.x),min(f.y,1.0-f.y)));
   col=mix(vec3(0.68,0.66,0.53),vec3(0.43,0.47,0.38),seam*0.45);
   col*=0.96+hash21(floor(q))*0.08;
   float avenue=1.0-smoothstep(48.0,55.0,abs(p.x-1100.0));
   col=mix(col,vec3(0.83,0.77,0.61),avenue*0.75);
   float moss=step(0.72,vnoise(p*0.043))*step(0.45,brush);
   col=mix(col,vec3(0.4,0.48,0.32),moss*0.25);
 }
 if(p.y>ground_y && p.y<ground_y+34.0) col*=mix(0.65,1.0,smoothstep(ground_y,ground_y+34.0,p.y));
 col+=(grain-0.5)*0.025;
 COLOR=vec4(col,1.0);
}
