#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec2 resolution;
  vec2 center;
  float phase;
  float seed;
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f*f*(3.0 - 2.0*f);
  return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
             mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i=0; i<4; i++) { v += a*noise(p); p = p*2.03 + 8.19; a *= 0.5; }
  return v;
}

void main() {
  vec2 p = vec2(qt_TexCoord0.x, 1.0-qt_TexCoord0.y)*resolution;
  vec2 q = p-center*resolution;
  float radius = length(q);
  float angle = atan(q.y,q.x);
  float diag = length(resolution);
  float normalized = radius/max(diag,1.0);
  float depth = 0.11/(normalized+0.035);
  float flow = phase*0.33;
  vec2 tunnel = vec2(angle*2.8 + depth*1.1 - flow*0.7,
                     depth*2.0 - flow + sin(angle*3.0+flow)*0.18);
  vec2 turbulence = vec2(fbm(tunnel*0.66+seed), fbm(tunnel*0.66+19.0+seed));
  float cloud = fbm(tunnel*1.5 + turbulence*1.8);
  float filaments = pow(max(0.0, sin(angle*13.0+depth*7.0-flow*2.2+cloud*5.0)), 8.0);
  float mist = smoothstep(0.30,0.76,cloud)*0.88 + filaments*0.28;
  float centerGlow = exp(-radius/max(22.0, diag*0.209+12.0));
  vec3 violet = vec3(0.28,0.20,0.63);
  vec3 teal = vec3(0.11,0.64,0.76);
  vec3 aether = mix(violet,teal,0.5+0.5*sin(depth*0.8+angle*2.0-flow*0.4));
  vec3 vortex = aether*(0.12+mist*1.8) + vec3(0.5,0.76,1.0)*filaments*0.42;
  vortex += vec3(1.0,0.96,0.88)*centerGlow*1.8;
  float starCell = 33.0;
  vec2 cell = floor((q+seed*91.0)/starCell);
  vec2 local = fract((q+seed*91.0)/starCell)-0.5;
  vec2 starPos = vec2(hash(cell),hash(cell+17.3))-0.5;
  float star = 1.0-smoothstep(0.015,0.09,length(local-starPos));
  star *= step(0.955,hash(cell+54.1));
  star *= 0.5+0.5*sin(phase*3.2+hash(cell)*6.28);
  vortex += vec3(0.83,0.91,1.0)*star*2.1;
  vortex = 1.0-exp(-max(vortex,0.0));
  fragColor = vec4(vortex,1.0);
}
