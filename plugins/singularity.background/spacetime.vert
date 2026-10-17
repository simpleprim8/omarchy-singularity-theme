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
const float PI=3.14159265359;
const float FUNNEL_DEPTH=34.0;
float ease(float a,float b,float x) {
    float t=clamp((x-a)/(b-a),0.0,1.0);
    // Evaluate from the nearer endpoint so float cancellation cannot make
    // the neck briefly acquire negative length as it finishes closing.
    float z=min(t,1.0-t);
    float q=z*z*z*(z*(z*6.0-15.0)+10.0);
    return t<=.5 ? q : 1.0-q;
}
vec3 control(int i) {
    const vec3 points[22]=vec3[22](
        vec3(80,22,.42),vec3(80,22,.42),vec3(80,22,.42),
        vec3(78,18,.39),vec3(74,10,.33),vec3(70,3,.26),
        vec3(67,-5,.16),vec3(64,-12,.04),vec3(63,-18,-.03),
        vec3(61,-20,-.05),vec3(57,-15,.02),vec3(50,-9,.12),
        vec3(38,-2,.36),vec3(24,2,.65),vec3(10,-3,1.05),
        vec3(.2,-12,1.5707963),vec3(.1,-19,1.5707963),
        vec3(12,-16,.95),vec3(40,-9,.55),
        vec3(80,22,.42),vec3(80,22,.42),vec3(80,22,.42)
    );
    return points[clamp(i,0,21)];
}
vec3 cameraPath(float u) {
    float t=min(u*19.0,18.999999);
    int i=int(floor(t));
    float f=fract(t),f2=f*f,f3=f2*f;
    return (control(i)*pow(1.0-f,3.0)
      +control(i+1)*(3.0*f3-6.0*f2+4.0)
      +control(i+2)*(-3.0*f3+3.0*f2+3.0*f+1.0)
      +control(i+3)*f3)/6.0;
}
void main() {
    float cycle=mod(max(phase,0.0),450.0)/90.0;
    float variant=floor(cycle),u=fract(cycle);
    float entry=ease(.035,.42,u),exit=ease(.88,1.0,u);
    float mass=entry*(1.0-exit);
    vec2 uv=qt_MultiTexCoord0;
    // One sheet, one descending funnel, one closed point. The mesh has no
    // lower branch, exit mouth, or second plane on the far side.
    float extent=110.0;
    float r=extent*uv.y*uv.y;
    float tail=8.0/(extent+8.0);
    float depression=(8.0/(r+8.0)-tail)/(1.0-tail);
    float spin=.55*PI*(ease(.50,.74,u)-ease(.84,1.0,u));
    // The same continuous wires stretch from the field to the singular point.
    float angle=2.0*PI*uv.x+spin*mass*exp(-r*r/180.0);
    vec3 world=vec3(cos(angle)*r,-FUNNEL_DEPTH*mass*depression,sin(angle)*r);
    vec3 pose=cameraPath(u);
    // Each route has its own direction, altitude, clearance, S-curve and
    // departure arc. All routes share a quiet flat-field loop boundary.
    const vec4 routes[5]=vec4[5](
        vec4(.60,-2.0,0.0,.00),
        vec4(-.70,8.0,8.0,.16),
        vec4(.20,0.0,-5.0,.48),
        vec4(-.85,-7.0,6.0,-.12),
        vec4(.85,5.0,-3.0,-.24)
    );
    vec4 route=routes[int(variant)];
    float survey=ease(.04,.15,u)*(1.0-ease(.53,.66,u));
    float departure=pow(sin(PI*ease(.77,1.0,u)),3.0);
    float arc=ease(.06,.70,u)-ease(.79,1.0,u);
    float orbit=route.x*arc+route.w*sin(2.0*PI*u)*pow(sin(PI*u),3.0);
    orbit-=.35*route.x*departure;
    float deltaY=route.y*(survey-.5*departure);
    float deltaR=route.z*(survey+.5*departure);
    float aimPitch=atan((pose.x*tan(min(pose.z,1.40))+deltaY)/max(pose.x+deltaR,1.0));
    pose.z+=(aimPitch-pose.z)*max(survey,departure);
    pose.y+=deltaY;
    pose.x+=deltaR;
    vec3 eye=vec3(sin(orbit)*pose.x,pose.y,cos(orbit)*pose.x);
    float yaw=-orbit+.055*sin(2.0*PI*u+variant*.9)*survey;
    vec3 forward=vec3(sin(yaw)*cos(pose.z),-sin(pose.z),-cos(yaw)*cos(pose.z));
    vec3 right=vec3(cos(yaw),0,sin(yaw));
    vec3 up=cross(right,forward);
    vec3 relative=world-eye;
    float depth=dot(relative,forward);
    float safeDepth=(depth<0.0 ? -1.0:1.0)*max(abs(depth),.0001);
    vec2 projected=vec2(dot(relative,right),dot(relative,up))*2.35/safeDepth;
    projected.x/=resolution.x/max(resolution.y,1.0);
    vec2 pixel=vec2(projected.x*.5+.5,.5-projected.y*.5)*resolution;
    // Homogeneous w preserves perspective-correct grid interpolation.
    gl_Position=(qt_Matrix*vec4(pixel,0,1))*depth;
    gridCoord=vec2(uv.x*24.0,uv.y*16.0);
    viewDistance=length(relative);
    edgeRadius=uv.y;
}
