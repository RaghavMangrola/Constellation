//
//  PeakFinder.swift
//  Constellation
//
//  Peak detection algorithm for audio fingerprinting
//  Identifies local maxima in frequency-time space like Shazam
//

import Foundation
import Accelerate
import QuartzCore

struct Peak {
    let frequency: Double    // Hz
    let magnitude: Float     // dB
    let time: Double        // seconds
    let bin: Int            // frequency bin index
    
    // Normalized coordinates for rendering (0.0 to 1.0)
    var normalizedFrequency: Float {
        // Map to log scale for better visualization
        return Float(log10(max(frequency, 1.0)) / log10(22050.0))
    }
    
    var normalizedMagnitude: Float {
        // Normalize magnitude to 0-1 range (assuming -80dB to 0dB range)
        return max(0.0, min(1.0, (magnitude + 80.0) / 80.0))
    }
}

@MainActor
class PeakFinder: ObservableObject {
    @Published var currentPeaks: [Peak] = []
    @Published var constellation: [Peak] = []
    
    // Peak detection parameters
    private let minPeakHeight: Float = -60.0  // dB threshold
    private let minPeakDistance: Int = 5      // minimum bins between peaks
    private let maxPeaksPerFrame: Int = 10    // limit peaks per analysis frame
    private let constellationHistory: Int = 200 // number of peaks to keep in constellation
    
    // Time-based constellation management
    private let peakFadeTime: Double = 3.0    // seconds before peak fades from constellation
    private var peakHistory: [(peak: Peak, timestamp: Double)] = []
    
    weak var audioProcessor: AudioProcessor?
    
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
    }
    
    private func cleanupOldPeaks(currentTime: Double) {
        peakHistory.removeAll { entry in
            currentTime - entry.timestamp > peakFadeTime
        }
        
        // Also limit total number of peaks for performance
        if peakHistory.count > constellationHistory {
            peakHistory.removeFirst(peakHistory.count - constellationHistory)
        }
    }
    
    private func updateConstellation() {
        // Create constellation with age-based alpha for fading effect
        let currentTime = CACurrentMediaTime()
        
        constellation = peakHistory.compactMap { entry in
            let age = currentTime - entry.timestamp
            guard age <= peakFadeTime else { return nil }
            
            return entry.peak
        }
    }
    
    // MARK: - Advanced Peak Detection Methods
    
    /// Adaptive threshold peak detection - adjusts threshold based on local noise floor
    func findAdaptivePeaks(magnitudeSpectrum: [Float], timeStamp: Double) {
        guard magnitudeSpectrum.count > minPeakDistance * 4 else { return }
        
        let windowSize = 50 // bins for local threshold calculation
        var detectedPeaks: [Peak] = []
        
        for i in windowSize..<(magnitudeSpectrum.count - windowSize) {
            let currentMagnitude = magnitudeSpectrum[i]
            
            // Calculate local noise floor
            let startIdx = max(0, i - windowSize)
            let endIdx = min(magnitudeSpectrum.count, i + windowSize)
            let localWindow = Array(magnitudeSpectrum[startIdx..<endIdx])
            
            // Use median as noise floor estimate
            let sortedWindow = localWindow.sorted()
            let median = sortedWindow[sortedWindow.count / 2]
            let adaptiveThreshold = median + 10.0 // 10dB above local noise floor
            
            // Check if current point is above adaptive threshold
            guard currentMagnitude > adaptiveThreshold else { continue }
            
            // Check if it's a local maximum
            var isLocalMax = true
            for j in -minPeakDistance...minPeakDistance {
                let idx = i + j
                if idx >= 0 && idx < magnitudeSpectrum.count && j != 0 {
                    if magnitudeSpectrum[idx] >= currentMagnitude {
                        isLocalMax = false
                        break
                    }
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
        
        // Process detected peaks same as regular method
        detectedPeaks.sort { $0.magnitude > $1.magnitude }
        let topPeaks = Array(detectedPeaks.prefix(maxPeaksPerFrame))
        
        currentPeaks = topPeaks
        
        for peak in topPeaks {
            peakHistory.append((peak: peak, timestamp: timeStamp))
        }
        
        cleanupOldPeaks(currentTime: timeStamp)
        updateConstellation()
    }
    
    /// Get peaks suitable for fingerprinting (like Shazam's approach)
    func getFingerprintPeaks() -> [Peak] {
        // Return peaks from multiple time frames for fingerprinting
        // This would typically be used for matching/recognition
        return constellation.filter { peak in
            peak.magnitude > -40.0 && // Strong peaks only
            peak.frequency > 300 && peak.frequency < 8000 // Human-relevant frequency range
        }
    }
    
    /// Get constellation points with fade factor for rendering
    func getConstellationWithFade() -> [(peak: Peak, alpha: Float)] {
        let currentTime = CACurrentMediaTime()
        
        return peakHistory.compactMap { entry in
            let age = currentTime - entry.timestamp
            guard age <= peakFadeTime else { return nil }
            
            // Calculate fade alpha (1.0 = new, 0.0 = old)
            let alpha = Float(1.0 - (age / peakFadeTime))
            return (peak: entry.peak, alpha: max(0.1, alpha))
        }
    }
} 