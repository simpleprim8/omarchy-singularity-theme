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
layout(binding = 1) uniform sampler2D desktopSource;

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
mat2 rotate2(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
float ease(float x) { x = clamp(x, 0.0, 1.0); return x*x*(3.0-2.0*x); }

void main() {
  vec2 p = qt_TexCoord0 * resolution;
  vec2 origin = center * resolution;
  vec2 d = p - origin;
  float radius = length(d);
  float angle = atan(d.y, d.x);
  float farthest = max(max(length(origin), length(resolution-origin)),
                       max(length(vec2(resolution.x-origin.x, origin.y)),
                           length(vec2(origin.x, resolution.y-origin.y))));
  float progress = ease(phase / 24.0);
  float front = mix(4.0, farthest + 40.0, pow(progress, 1.65));
  front += farthest*0.11*sin(3.14159*progress)*sin(angle*7.0 + phase*0.21 + noise(d*0.004+seed)*2.0);
  float edge = max(radius-front, 0.0);

  // Inverse mapping pulls source pixels inward. The narrowing angular bands
  // retain sampled desktop colour so the image appears to unravel into threads.
  float pull = pow(progress, 1.45) * farthest * 0.42 * exp(-edge / (farthest*0.38+1.0));
  float twist = (0.1 + progress*3.5) * exp(-edge / (farthest*0.56+1.0));
  twist += phase*0.032 * exp(-edge / (farthest*0.24+1.0));
  twist += sin(angle*9.0 + radius*0.012 - phase*0.6) * 0.06 * progress;
  vec2 samplePoint = origin + rotate2(twist) * d * ((radius+pull) / max(radius,1.0));
  vec3 desktop = texture(desktopSource, clamp(samplePoint/resolution, vec2(0.0), vec2(1.0))).rgb;
  float strands = pow(0.5+0.5*sin(angle*115.0 + radius*0.018 - phase*0.8 + noise(d*0.008+seed)*3.0), 18.0);
  float threadZone = progress * exp(-edge / (farthest*0.27+1.0));
  vec3 thread = desktop * (0.15 + strands*2.6) + vec3(0.19,0.39,0.72)*strands*0.24;
  vec3 color = mix(desktop, thread, clamp(threadZone*1.2,0.0,1.0));
  float rim = exp(-pow(edge/max(3.0, front*0.018), 2.0));
  color += vec3(0.23,0.43,0.87) * rim * strands * (1.0-progress) * 0.9;
  float trailingThread = strands * exp(-max(front-radius,0.0)/(farthest*0.13+1.0)) * (1.0-progress);
  color *= max(smoothstep(front-3.0, front+8.0, radius), trailingThread);

  if (phase >= 24.0) {
    float t = phase-24.0;
    float reveal = mix(5.0, farthest+50.0, ease(t/9.0));
    float mask = 1.0-smoothstep(reveal*0.86, reveal*1.04+2.0, radius);
    float normalized = radius/max(length(resolution),1.0);
    float depth = 0.11/(normalized+0.035);
    float flow = t*0.34;
    vec2 tunnel = vec2(angle*2.8 + depth*1.1 - flow*0.7,
                       depth*2.0 - flow + sin(angle*3.0+flow)*0.18);
    vec2 turbulence = vec2(fbm(tunnel*0.66+seed), fbm(tunnel*0.66+19.0+seed));
    float cloud = fbm(tunnel*1.5 + turbulence*1.8);
    float filaments = pow(max(0.0, sin(angle*13.0+depth*7.0-flow*2.2+cloud*5.0)), 8.0);
    float mist = smoothstep(0.30,0.76,cloud)*0.88 + filaments*0.28;
    float centerGlow = exp(-radius/max(22.0, reveal*0.19+12.0));
    vec3 violet = vec3(0.28,0.20,0.63);
    vec3 teal = vec3(0.11,0.64,0.76);
    vec3 aether = mix(violet,teal,0.5+0.5*sin(depth*0.8+angle*2.0-flow*0.4));
    vec3 wormhole = aether*(0.12+mist*1.8) + vec3(0.5,0.76,1.0)*filaments*0.42;
    wormhole += vec3(1.0,0.96,0.88)*centerGlow*1.8;
    vec2 cell = floor((d+seed*91.0)/33.0);
    vec2 local = fract((d+seed*91.0)/33.0)-0.5;
    vec2 starPos = vec2(hash(cell),hash(cell+17.3))-0.5;
    float star = (1.0-smoothstep(0.015,0.09,length(local-starPos))) * step(0.955,hash(cell+54.1));
    wormhole += vec3(0.83,0.91,1.0)*star*(0.5+0.5*sin(t*3.2+hash(cell)*6.28))*2.1;
    float splashRadius = t * min(resolution.x,resolution.y) * 0.13;
    float splash = exp(-pow((radius-splashRadius)/max(4.0,splashRadius*0.12),2.0))*exp(-t*0.22);
    wormhole += vec3(0.70,0.88,1.0)*splash*2.5;
    wormhole += vec3(1.0,0.98,0.90)*exp(-radius/24.0)*exp(-t*0.32)*3.0;
    color = mix(color, wormhole, mask);
  }

  color = 1.0-exp(-max(color,0.0));
  fragColor = vec4(color,1.0);
}
