#version 440
layout(location = 0) in vec2 gridCoord;
layout(location = 1) in float viewDistance;
layout(location = 2) in float edgeRadius;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float phase;
};
void main() {
    // A single continuous quadrilateral grid, with no second grid, alternate
    // coordinate chart, tunnel overlay or crossfade between renderers.
    vec2 aa=max(fwidth(gridCoord),vec2(.0001));
    vec2 distanceToWire=abs(fract(gridCoord-.5)-.5)/aa;
    vec2 wire=(1.0-smoothstep(vec2(0),vec2(1.12),distanceToWire));
    wire*=1.0-smoothstep(vec2(.35),vec2(1.25),aa);
    float line=max(wire.x,wire.y);
    float depthCue=.33+.67*exp(-viewDistance/100.0);
    float edge=1.0-smoothstep(.90,1.0,edgeRadius);
    float nearClip=smoothstep(1.5,4.0,viewDistance);
    float alpha=line*depthCue*edge*nearClip*.64;
    if(alpha<.002) discard;
    // Empty cells are transparent. Rear wires remain visible through the
    // actual front mesh, while distance naturally makes the far side dimmer.
    fragColor=vec4(vec3(.09,.90,.24)*alpha,alpha)*qt_Opacity;
}
