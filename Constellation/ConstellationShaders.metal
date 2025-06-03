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
};

// Vertex shader
vertex VertexOut star_vertex_shader(
    uint vertexID [[vertex_id]],
    constant StarVertex* vertices [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    StarVertex vert = vertices[vertexID];
    VertexOut out;
    
    // PROPER coordinate transformation from Swift coordinate space to NDC
    // Swift sends coordinates in range roughly -25 to +25 for X and Y
    // We need to map these to NDC space (-1 to +1)
    
    // Define the coordinate ranges that Swift is using
    float coordRangeX = 50.0;  // Swift uses frequencySpread = 50.0, so range is -25 to +25
    float coordRangeY = 40.0;  // Swift uses magnitudeSpread = 40.0, so range is -20 to +20
    
    // Convert from Swift coordinate space to NDC (-1 to +1)
    float ndcX = (vert.position.x / (coordRangeX * 0.5));  // Divide by half-range to get -1 to +1
    float ndcY = (vert.position.y / (coordRangeY * 0.5));  // Divide by half-range to get -1 to +1
    
    // Clamp to ensure we stay within valid NDC range
    ndcX = clamp(ndcX, -1.0, 1.0);
    ndcY = clamp(ndcY, -1.0, 1.0);
    
    // Flip Y coordinate for Metal's coordinate system (top-left origin)
    ndcY = -ndcY;
    
    out.position = float4(ndcX, ndcY, 0.0, 1.0);
    
    // Pass through color with age-based fade
    float ageFade = 1.0 - (vert.age / uniforms.fadeTime);
    float pulse = 0.8 + 0.2 * sin(uniforms.time * 3.0 + vert.position.x * 10.0);
    out.color = vert.color;
    out.color.a *= ageFade * pulse;
    
    // Calculate point size based on viewport and magnitude
    float baseSize = 20.0;  // Base size in pixels
    float sizeScale = min(uniforms.viewportSize.x, uniforms.viewportSize.y) / 1000.0;  // Scale based on viewport
    out.pointSize = baseSize * sizeScale * (0.5 + vert.size * 2.0);  // Adjust size based on magnitude
    
    // Pass through coordinates for fragment shader
    out.pointCoord = vert.position;
    
    return out;
}

// Fragment shader
fragment float4 star_fragment_shader(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Calculate distance from center of point sprite
    float2 coord = pointCoord * 2.0 - 1.0;
    float dist = length(coord);
    
    // Create star shape
    float angle = atan2(coord.y, coord.x);
    float numRays = 6.0;
    float rayMask = 0.5 + 0.5 * cos(angle * numRays);
    
    // Combine circular and ray patterns
    float star = smoothstep(1.0, 0.5, dist);
    float rayPattern = smoothstep(1.0, 0.2, dist * (1.0 - rayMask * 0.5));
    
    // Add glow
    float glow = exp(-dist * 3.0) * 0.3;
    
    // Combine all effects
    float brightness = star + rayPattern + glow;
    
    // Output final color
    float4 color = in.color;
    color.a *= brightness;
    return color;
} 