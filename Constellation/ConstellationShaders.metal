#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

/* Input vertex structure for star points */
struct StarVertex {
    packed_float2 position;    /* Position in normalized coordinates */
    packed_float4 color;       /* RGBA color (frequency-based) */
    float size;               /* Star size based on magnitude */
    float age;                /* Age of the peak (0.0 to 1.0) */
};

/* Uniform buffer for global parameters */
struct Uniforms {
    float4x4 projectionMatrix;  /* View-projection matrix */
    float time;                 /* Current time for animations */
    float fadeTime;            /* Total fade duration */
    float2 viewportSize;       /* Viewport dimensions */
};

/* Vertex shader output structure */
struct VertexOut {
    float4 position [[position]];  /* Clip space position */
    float4 color;                  /* Star color */
    float2 texCoord;              /* Texture coordinates for star shape */
    float alpha;                  /* Final alpha value */
    float age;                    /* Peak age for fade effects */
};

/* Vertex shader for star points */
vertex VertexOut star_vertex_shader(
    uint vertexID [[vertex_id]],
    constant StarVertex *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    StarVertex vert = vertices[vertexID];
    
    /* Apply projection matrix */
    out.position = uniforms.projectionMatrix * float4(vert.position, 0.0, 1.0);
    
    /* Calculate texture coordinates for star shape */
    out.texCoord = vert.position;
    
    /* Calculate age-based fade */
    float ageFade = 1.0 - (vert.age / uniforms.fadeTime);
    
    /* Add subtle pulsing effect based on time and age */
    float pulse = 0.8 + 0.2 * sin(uniforms.time * 3.0 + vert.position.x * 10.0);
    pulse *= ageFade;  /* Reduce pulse intensity as star ages */
    
    /* Set color and alpha */
    out.color = vert.color;
    out.alpha = vert.color.a * pulse * ageFade;
    out.age = vert.age;
    
    return out;
}

/* Fragment shader for star rendering */
fragment float4 star_fragment_shader(VertexOut in [[stage_in]]) {
    /* Create star-like shape using distance field */
    float2 pos = in.texCoord;
    float dist = length(pos);
    
    /* Create star shape with multiple rays */
    float angle = atan2(pos.y, pos.x);
    float rays = 6.0;  /* Number of star rays */
    float rayIntensity = 0.5 + 0.5 * cos(angle * rays);
    
    /* Combine circular and ray patterns */
    float starShape = smoothstep(0.02, 0.01, dist) + 
                     smoothstep(0.008, 0.003, dist * rayIntensity);
    
    /* Add glow effect that intensifies with age */
    float glowIntensity = 0.3 + 0.2 * (1.0 - in.age);  /* More glow for newer stars */
    float glow = exp(-dist * 40.0) * glowIntensity;
    
    /* Combine all effects */
    float totalIntensity = clamp(starShape + glow, 0.0, 1.0);
    
    /* Apply color and alpha */
    float4 color = in.color;
    color.a *= totalIntensity * in.alpha;
    
    return color;
} 