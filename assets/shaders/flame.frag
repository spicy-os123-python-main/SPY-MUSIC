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
    mat2 rot = mat2(0.87, 0.5, -0.5, 0.87);
    for (int i = 0; i < 4; ++i) {
        v += a * noise(p);
        p = rot * p * 2.0 + vec2(10.0, 10.0);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;
    
    // yUp: 0.0 at bottom edge, 1.0 at top of flame area
    float yUp = 1.0 - uv.y;
    
    // Animate upward scrolling with organic sway
    float time = uTime * 1.6;
    vec2 coord = vec2(uv.x * 3.2 + sin(time * 0.4 + uv.y * 3.5) * 0.12, yUp * 2.0 - time);
    
    // Turbulent domain warping for dancing flame tongues
    float n1 = fbm(coord);
    float n2 = fbm(coord + n1 + vec2(0.0, -time * 0.35));
    float flameNoise = fbm(coord + vec2(n1, n2) * 0.7);
    
    // Smooth vertical envelope: tapers smoothly to 0 towards top
    float verticalFade = pow(clamp(1.0 - yUp * 1.25, 0.0, 1.0), 1.8);
    
    // Horizontal fade at screen borders
    float horizontalFade = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);
    
    // Dynamic flame pillars shaping across X
    float tongues = 0.5 + 0.5 * sin(uv.x * 10.0 + n1 * 2.5);
    
    // Intensity: organic and non-solid even at the bottom
    float intensity = (flameNoise * 0.75 + tongues * 0.25) * verticalFade * horizontalFade;
    intensity = clamp(intensity * 1.5, 0.0, 1.0);
    intensity = pow(intensity, 1.35);
    
    // Multi-tier color mapping
    vec4 col = vec4(0.0);
    if (intensity < 0.25) {
        float t = intensity / 0.25;
        col = mix(vec4(uColor1.rgb, 0.0), uColor1, t * t);
    } else if (intensity < 0.58) {
        float t = (intensity - 0.25) / 0.33;
        col = mix(uColor1, uColor2, smoothstep(0.0, 1.0, t));
    } else if (intensity < 0.84) {
        float t = (intensity - 0.58) / 0.26;
        col = mix(uColor2, uColor3, smoothstep(0.0, 1.0, t));
    } else {
        float t = (intensity - 0.84) / 0.16;
        col = mix(uColor3, uColor4, smoothstep(0.0, 1.0, t));
    }
    
    // Soft organic transparency (never solid, blends with dark background)
    float alpha = clamp(intensity * 1.0, 0.0, 0.72);
    fragColor = vec4(col.rgb * alpha, alpha);
}
