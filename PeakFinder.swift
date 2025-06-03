struct Peak {
    let frequency: Double    // Hz
    let magnitude: Float     // dB
    let time: Double        // seconds
    let bin: Int            // frequency bin index
    
    // Normalized coordinates for rendering (0.0 to 1.0)
    var normalizedFrequency: Float {
        // Focus on the most useful frequency range for better visualization
        let minFreq: Double = 80.0   // Focus on musically relevant frequencies
        let maxFreq: Double = 12000.0 // Most music content is below this
        
        // Clamp frequency to our desired range
        let clampedFreq = min(max(frequency, minFreq), maxFreq)
        
        // Use mostly logarithmic scale with some linear component for better spread
        let normalizedLog = log10(clampedFreq / minFreq) / log10(maxFreq / minFreq)
        let normalizedLinear = (clampedFreq - minFreq) / (maxFreq - minFreq)
        
        // Mix 80% log, 20% linear for better distribution
        return Float(normalizedLog * 0.8 + normalizedLinear * 0.2)
    }
    
    var normalizedMagnitude: Float {
        // Normalize magnitude to 0-1 range with stronger compression
        // Focus on the -60dB to -10dB range where most content lives
        let minDb: Float = -60.0
        let maxDb: Float = -10.0
        let normalizedDb = (min(max(magnitude, minDb), maxDb) - minDb) / (maxDb - minDb)
        
        // Apply compression curve for better vertical distribution
        return pow(normalizedDb, 0.7)  // More aggressive compression
    }
}

func findPeaks(magnitudeSpectrum: [Float], timeStamp: Double) {
    guard magnitudeSpectrum.count > minPeakDistance * 2 else { return }
    
    var detectedPeaks: [Peak] = []
    
    // Find local maxima using a sliding window approach
    for i in minPeakDistance..<(magnitudeSpectrum.count - minPeakDistance) {
        let currentMagnitude = magnitudeSpectrum[i]
        
        // Check if current point is above threshold
        guard currentMagnitude > minPeakHeight else { continue }
        
        // Check if it's a local maximum
        var isLocalMax = true
        for j in -minPeakDistance...minPeakDistance {
            if j != 0 && magnitudeSpectrum[i + j] >= currentMagnitude {
                isLocalMax = false
                break
            }
        }
        
        if isLocalMax {
            let frequency = audioProcessor?.binToFrequency(i) ?? Double(i * 44100 / 4096)
            let peak = Peak(
                frequency: frequency,
                magnitude: currentMagnitude,
                time: timeStamp,
                bin: i
            )
            detectedPeaks.append(peak)
        }
    }
    
    // Sort by magnitude and take top peaks
    detectedPeaks.sort { $0.magnitude > $1.magnitude }
    let topPeaks = Array(detectedPeaks.prefix(maxPeaksPerFrame))
    
    // Log only the number of peaks and range info
    logger.debug("Peak Analysis: Found \(detectedPeaks.count) peaks, using top \(topPeaks.count)")
    if let strongest = topPeaks.first, let weakest = topPeaks.last {
        logger.debug("Frequency Range: \(Int(strongest.frequency))Hz to \(Int(weakest.frequency))Hz")
        logger.debug("Magnitude Range: \(String(format: "%.1f", strongest.magnitude))dB to \(String(format: "%.1f", weakest.magnitude))dB")
    }
    
    // Update current peaks for immediate visualization
    currentPeaks = topPeaks
    
    // Add to constellation with timestamp
    for peak in topPeaks {
        peakHistory.append((peak: peak, timestamp: timeStamp))
    }
    
    // Clean up old peaks from constellation
    cleanupOldPeaks(currentTime: timeStamp)
    
    // Update constellation for rendering
    updateConstellation()
    
    // Log constellation size only
    logger.debug("Constellation size: \(self.constellation.count)")
} 