#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 gridCoord;
layout(location = 1) out float viewDistance;
layout(location = 2) out float edgeRadius;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float phase;
};
void main() {
    vec2 uv = qt_MultiTexCoord0;
    float r = 110.0 * uv.y * uv.y;
    float spin = 2.4;
    float angle = 6.28318530718 * uv.x + spin * exp(-r / 22.0);
    float tail = 8.0 / 118.0;
    float depression = (8.0 / (r + 8.0) - tail) / (1.0 - tail);
    vec3 relative = vec3(cos(angle) * r, -34.0 * depression - 62.0, sin(angle) * r - 72.0);
    vec3 forward = normalize(vec3(0,-82,-72));
    vec3 up = vec3(0,-forward.z,forward.y);
    float depth = dot(relative,forward);
    vec2 projected = vec2(relative.x,dot(relative,up)) * 2.35 / depth;
    projected.x /= resolution.x / max(resolution.y,1.0);
    vec2 pixel = vec2(projected.x*.5+.5,.5-projected.y*.5)*resolution;
    gl_Position = (qt_Matrix * vec4(pixel,0,1)) * depth;
    gridCoord = vec2(uv.x*24.0,uv.y*16.0);
    viewDistance = length(relative);
    edgeRadius = uv.y;
}
