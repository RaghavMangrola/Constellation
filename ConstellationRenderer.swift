private func updateVertexBuffer(with peaks: [(peak: Peak, fade: Float)]) {
    let vertexBufferPointer = vertexBuffer.contents().bindMemory(to: StarVertex.self, capacity: maxStars)
    
    self.currentVertexCount = min(peaks.count, maxStars)
    
    // Statistics for distribution analysis
    var xMin: Float = Float.infinity
    var xMax: Float = -Float.infinity
    var yMin: Float = Float.infinity
    var yMax: Float = -Float.infinity
    var quadrantCounts = [0, 0, 0, 0] // [Q1, Q2, Q3, Q4]
    
    for (index, peakWithFade) in peaks.enumerated() {
        guard index < maxStars else { break }
        
        let peak = peakWithFade.peak
        let fade = peakWithFade.fade
        
        // Convert from normalized 0-1 coordinates to NDC space (-1 to 1)
        let aspectRatio = Float(view.drawableSize.width) / Float(view.drawableSize.height)
        let ndcX = (peak.normalizedFrequency * 2.0 - 1.0) * aspectRatio
        let ndcY = peak.normalizedMagnitude * 2.0 - 1.0
        
        // Track distribution statistics
        xMin = min(xMin, ndcX)
        xMax = max(xMax, ndcX)
        yMin = min(yMin, ndcY)
        yMax = max(yMax, ndcY)
        
        // Count stars in each quadrant
        if ndcX >= 0 && ndcY >= 0 { quadrantCounts[0] += 1 }      // Q1
        else if ndcX < 0 && ndcY >= 0 { quadrantCounts[1] += 1 }  // Q2
        else if ndcX < 0 && ndcY < 0 { quadrantCounts[2] += 1 }   // Q3
        else { quadrantCounts[3] += 1 }                     // Q4
        
        // Choose color based on frequency
        let colorIndex = Int(peak.normalizedFrequency * Float(colorPalette.count - 1))
        var color = colorPalette[min(colorIndex, colorPalette.count - 1)]
        color.w = fade
        
        // Further increase size for better visibility
        let size = 0.03 + peak.normalizedMagnitude * 0.06
        
        let age = 1.0 - fade
        
        vertexBufferPointer[index] = StarVertex(
            position: simd_float2(ndcX, ndcY),
            color: color,
            size: size,
            age: age
        )
    }
    
    // Log distribution summary once per second
    let currentTime = CACurrentMediaTime()
    if currentTime - lastLogTime > 1.0 {
        logger.debug("""
        === Star Distribution ===
        Range X: [\(String(format: "%.2f", xMin)) to \(String(format: "%.2f", xMax))]
        Range Y: [\(String(format: "%.2f", yMin)) to \(String(format: "%.2f", yMax))]
        Stars by quadrant: \(quadrantCounts.map(String.init).joined(separator: ", "))
        Total stars: \(self.currentVertexCount)
        """)
        lastLogTime = currentTime
    }
}

// Add property to track last log time
private var lastLogTime: CFTimeInterval = 0

// ... existing code ... 