#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uSize;
uniform vec4 uColor1; // outer
uniform vec4 uColor2; // mid
uniform vec4 uColor3; // core
uniform vec4 uColor4; // hot

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;
    
    float yFromBottom = 1.0 - uv.y;
    vec2 p = vec2(uv.x * 4.0, (1.0 - uv.y) * 2.0 - uTime * 1.5);
    
    float q = fbm(p);
    vec2 r = vec2(fbm(p + q + uTime * 0.7 - p.x - p.y), fbm(p + q - uTime * 0.4));
    float f = fbm(p + r);
    
    float shape = pow(max(0.0, 1.0 - yFromBottom * 1.6), 1.2);
    float intensity = clamp((f * 1.4 + (1.0 - yFromBottom * 1.2)) * shape, 0.0, 1.0);
    
    float sideFade = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);
    intensity *= sideFade;
    
    vec4 col = vec4(0.0);
    if (intensity < 0.25) {
        float t = intensity / 0.25;
        col = mix(vec4(uColor1.rgb, 0.0), uColor1, t);
    } else if (intensity < 0.55) {
        float t = (intensity - 0.25) / 0.3;
        col = mix(uColor1, uColor2, t);
    } else if (intensity < 0.82) {
        float t = (intensity - 0.55) / 0.27;
        col = mix(uColor2, uColor3, t);
    } else {
        float t = (intensity - 0.82) / 0.18;
        col = mix(uColor3, uColor4, clamp(t, 0.0, 1.0));
    }
    
    col.a *= clamp(intensity * 1.5, 0.0, 1.0);
    fragColor = col;
}
