# Metal Shader Implementation Notes

## Point Sprite Implementation

### Key Components

1. **Vertex Structure**
```metal
struct StarVertex {
    float2 position [[attribute(0)]];  // Normalized position (-1 to 1)
    float4 color [[attribute(1)]];     // RGBA color with alpha
    float size [[attribute(2)]];       // Size multiplier
    float age [[attribute(3)]];        // Age for fading (0 = new, 1 = old)
};
```

2. **Uniforms**
```metal
struct Uniforms {
    float4x4 projectionMatrix;  // View projection
    float time;                 // Current time for animations
    float fadeTime;            // Total fade duration
    float2 viewportSize;       // Screen dimensions
};
```

### Point Size Handling

1. **Vertex Shader Output**
```metal
struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 pointCoord;
    float pointSize [[point_size]];  // Required for point sprites
};
```

2. **Size Calculation**
```metal
float baseSize = 20.0;  // Base size in pixels
float sizeScale = min(viewportSize.x, viewportSize.y) / 1000.0;
float finalSize = baseSize * sizeScale * (0.5 + magnitude * 2.0);
```

### Star Shape Generation

1. **Ray Pattern**
```metal
float angle = atan2(coord.y, coord.x);
float numRays = 6.0;
float rayMask = 0.5 + 0.5 * cos(angle * numRays);
```

2. **Shape Components**
```metal
float star = smoothstep(1.0, 0.5, dist);           // Core
float rays = smoothstep(1.0, 0.2, dist * rayMask); // Ray pattern
float glow = exp(-dist * 3.0) * 0.3;               // Outer glow
```

## Common Issues

### 1. Point Sprite Setup
- Must enable point sprites in pipeline descriptor
- Vertex descriptor must match Swift structure exactly
- Point size must use [[point_size]] attribute

### 2. Coordinate Systems
- Vertex positions: Normalized (-1 to 1)
- Point coordinates: Normalized (0 to 1)
- Screen coordinates: Pixels (need viewport scaling)

### 3. Alpha Blending
```swift
pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
```

## Performance Considerations

1. **Vertex Buffer**
- Single buffer for all stars
- Update only changed vertices
- Use .storageModeShared for CPU/GPU sharing

2. **Uniform Updates**
- Single uniform buffer
- Update once per frame
- Include all required parameters

3. **Fragment Shader**
- Minimize texture lookups
- Use distance fields for shapes
- Optimize math operations

## Debugging Tips

1. **Vertex Issues**
- Check normalized coordinates (-1 to 1)
- Verify attribute offsets match Swift structure
- Ensure point size is being set correctly

2. **Fragment Issues**
- Use solid colors first
- Check point sprite coordinates
- Verify alpha blending setup

3. **Performance**
- Monitor draw call count
- Check vertex count
- Profile shader complexity 