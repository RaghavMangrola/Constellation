#include <metal_stdlib>
using namespace metal;

// Vertex structure matching Swift StarVertex
struct StarVertex {
    float2 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float size [[attribute(2)]];
    float age [[attribute(3)]];
};

// Uniforms matching Swift structure
struct Uniforms {
    float4x4 projectionMatrix;
    float time;
    float fadeTime;
    float2 viewportSize;
};

// Vertex shader output
struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 pointCoord;
    float pointSize [[point_size]];
    float brightness;
    float starType;
};

// Noise function for nebula effects
float noise(float2 uv) {
    return fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise for nebula
float smoothNoise(float2 uv) {
    float2 i = floor(uv);
    float2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = noise(i);
    float b = noise(i + float2(1.0, 0.0));
    float c = noise(i + float2(0.0, 1.0));
    float d = noise(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractional Brownian Motion for complex nebula patterns
float fbm(float2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 5; i++) {
        value += amplitude * smoothNoise(uv * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

// Vertex shader
vertex VertexOut star_vertex_shader(
    uint vertexID [[vertex_id]],
    constant StarVertex* vertices [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    StarVertex vert = vertices[vertexID];
    VertexOut out;
    
    // TRANSFORM EXTREME coordinates directly to viewport pixel space
    // Input coordinates are now roughly -25 to +25 (X) and -20 to +20 (Y)
    
    // Map X: -25 to +25 → 0 to viewportWidth (ensure full coverage)
    float pixelX = (vert.position.x + 25.0) * (uniforms.viewportSize.x / 50.0);
    // Map Y: -20 to +20 → 0 to viewportHeight (ensure full coverage)
    float pixelY = (vert.position.y + 20.0) * (uniforms.viewportSize.y / 40.0);
    
    // Convert pixel coordinates to NDC for Metal rendering
    // NDC: (0,0) to (width,height) → (-1,-1) to (+1,+1)
    float ndcX = (pixelX / uniforms.viewportSize.x) * 2.0 - 1.0;
    float ndcY = (pixelY / uniforms.viewportSize.y) * 2.0 - 1.0;
    
    // Metal's Y axis is flipped, so invert Y
    ndcY = -ndcY;
    
    // Clamp to ensure we stay within valid NDC range
    ndcX = clamp(ndcX, -1.0, 1.0);
    ndcY = clamp(ndcY, -1.0, 1.0);
    
    out.position = float4(ndcX, ndcY, 0.0, 1.0);
    
    // Enhanced color and brightness calculation
    float ageFade = max(0.1, 1.0 - (vert.age * 1.5));
    float twinkle = 0.8 + 0.2 * sin(uniforms.time * 4.0 + vert.position.x * 15.0 + vert.position.y * 10.0);
    
    out.color = vert.color;
    out.brightness = vert.size * ageFade * twinkle;
    
    // Star type based on size (larger stars get diffraction spikes)
    out.starType = vert.size > 0.025 ? 1.0 : 0.0;
    
    // Viewport-aware point sizing - make them HUGE for debugging
    float aspectRatio = uniforms.viewportSize.x / uniforms.viewportSize.y;
    float baseSize = out.starType > 0.5 ? 150.0 : 120.0;  // Even larger
    
    // Scale based on smallest viewport dimension to ensure visibility
    float minDimension = min(uniforms.viewportSize.x, uniforms.viewportSize.y);
    float sizeScale = minDimension / 600.0;  // More aggressive scaling
    
    out.pointSize = max(baseSize * sizeScale, 80.0);  // Large minimum size
    
    // Pass through the NDC position for fragment calculations
    out.pointCoord = float2(ndcX, ndcY);
    
    return out;
}

// Fragment shader - ultra-simple debugging
fragment float4 star_fragment_shader(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Convert point coord to centered coordinates
    float2 coord = pointCoord * 2.0 - 1.0;
    float dist = length(coord);
    
    // SUPER SIMPLE debugging colors - position based
    float3 debugColor = float3(0.0);
    
    // Map NDC position (-1 to +1) to color (0 to 1)
    debugColor.r = (in.pointCoord.x + 1.0) * 0.5;  // Red = X position
    debugColor.g = (in.pointCoord.y + 1.0) * 0.5;  // Green = Y position  
    debugColor.b = 0.8;  // High blue for visibility
    
    // Ultra-simple star shape - just a circle with strong visibility
    float starAlpha = 1.0 - smoothstep(0.0, 1.0, dist);
    starAlpha = max(starAlpha, 0.5);  // Ensure high minimum visibility
    
    // Force bright, visible colors
    float3 finalColor = debugColor;
    finalColor = max(finalColor, float3(0.3, 0.3, 0.3));  // Minimum brightness
    
    return float4(finalColor, starAlpha);
} 