//
//  AudioConstants.swift
//  Constellation
//
//  Centralized configuration for audio processing parameters
//

import Foundation
import Accelerate
import SwiftUI

/// Constants for audio processing configuration
enum AudioConstants {
    /// Audio format configuration
    enum Format {
        /// Default sample rate (Hz)
        static let defaultSampleRate: Double = 48000.0
        
        /// Number of channels
        static let channelCount: Int = 1
        
        /// Buffer size for FFT processing
        static let bufferSize: Int = 4096
        
        /// Default audio format description
        static var description: String {
            "\(channelCount) ch, \(Int(defaultSampleRate)) Hz, Float32"
        }
    }
    
    /// Peak detection configuration
    enum PeakDetection {
        /// Minimum peak height in dB
        static let minPeakHeight: Float = -60.0
        
        /// Minimum distance between peaks (in frequency bins)
        static let minPeakDistance: Int = 5
        
        /// Maximum number of peaks to detect per frame
        static let maxPeaksPerFrame: Int = 10
        
        /// Number of peaks to keep in constellation history
        static let constellationHistorySize: Int = 200
        
        /// Time in seconds before a peak fades from constellation
        static let peakFadeTime: Double = 3.0
        
        /// Window size for adaptive threshold calculation (in bins)
        static let adaptiveWindowSize: Int = 50
        
        /// dB above local noise floor for adaptive threshold
        static let adaptiveThresholdOffset: Float = 10.0
        
        /// Frequency range for fingerprinting
        static let minFingerPrintFreq: Double = 300.0  // Hz
        static let maxFingerPrintFreq: Double = 8000.0 // Hz
    }
    
    /// FFT processing configuration
    enum FFT {
        /// Size of real and imaginary buffers (half of buffer size)
        static let complexBufferSize: Int = Format.bufferSize / 2
        
        /// Window type for FFT
        static let windowNormalization: Int32 = Int32(vDSP_HANN_NORM)
        
        /// FFT direction
        static let direction: FFTDirection = FFTDirection(kFFTDirection_Forward)
    }
    
    /// Rendering and visualization configuration
    enum Rendering {
        /// Maximum number of stars to render
        static let maxStars: Int = 1000
        
        /// Base point size for stars
        static let basePointSize: Float = 10.0
        
        /// Coordinate transformation parameters
        static let frequencySpread: Float = 50.0
        static let magnitudeSpread: Float = 40.0
        
        /// Star size calculation parameters
        static let baseSizeOffset: Float = 0.015
        static let magnitudeSizeMultiplier: Float = 0.04
        static let frequencySizeMultiplier: Float = 0.02
        
        /// Color variation parameters
        static let colorVariationAmplitude: Float = 0.1
        static let colorVariationFrequency: Float = 0.3
        static let colorVariationMinimum: Float = 0.3
        
        /// Randomness parameters for natural distribution
        static let randomnessAmplitudeX: Float = 3.0
        static let randomnessAmplitudeY: Float = 3.0
        static let randomnessFrequencyX: Float = 0.1
        static let randomnessFrequencyY: Float = 0.1
        
        /// Rendering performance settings
        static let preferredFramesPerSecond: Int = 60
        static let enableSetNeedsDisplay: Bool = false
        
        /// Range padding for coordinate calculations
        static let minRangePadding: Float = 0.1
        
        /// Frequency ranges for color mapping (Hz)
        static let lowFreq: Double = 20.0
        static let midLowFreq: Double = 250.0
        static let midFreq: Double = 2000.0
        static let midHighFreq: Double = 8000.0
        static let highFreq: Double = 20000.0
        
        /// Star size configuration
        static let minStarSize: Float = 0.01
        static let maxStarSize: Float = 0.03
        
        /// Cosmic color palette for different frequency ranges
        static let colorPalette: [SIMD4<Float>] = [
            SIMD4<Float>(0.9, 0.95, 1.0, 1.0),   // Brilliant white (high freq)
            SIMD4<Float>(0.8, 0.9, 1.0, 1.0),    // Blue-white (high-mid freq)
            SIMD4<Float>(1.0, 1.0, 0.9, 1.0),    // Warm white (mid freq)
            SIMD4<Float>(1.0, 0.8, 0.6, 1.0),    // Golden orange (mid-low freq)
            SIMD4<Float>(1.0, 0.6, 0.4, 1.0),    // Orange-red (low-mid freq)
            SIMD4<Float>(0.9, 0.5, 0.7, 1.0),    // Pink-red (low freq)
            SIMD4<Float>(0.7, 0.4, 0.9, 1.0),    // Purple (very low freq)
        ]
    }
    
    /// UI and visual design configuration
    enum UI {
        /// Background gradient colors
        static let backgroundGradientTop = Color(red: 0.02, green: 0.02, blue: 0.08)
        static let backgroundGradientBottom = Color(red: 0.05, green: 0.05, blue: 0.15)
        
        /// Status overlay configuration
        static let statusOverlayPadding: CGFloat = 6
        static let statusOverlayCornerRadius: CGFloat = 6
        static let statusOverlayOpacity: Double = 0.6
        
        /// Icon and button configuration
        static let permissionIconSize: CGFloat = 40
        static let permissionIconOpacity: Double = 0.6
        static let uiSpacing: CGFloat = 16
        
        /// Animation timing
        static let autoStartDelay: TimeInterval = 0.5
    }
    
    /// Application logging configuration
    enum Logging {
        /// Subsystem identifiers
        static let audioSubsystem = "com.constellation.audio"
        static let graphicsSubsystem = "com.constellation.graphics"
        
        /// Category identifiers
        static let peakFinderCategory = "PeakFinder"
        static let rendererCategory = "Renderer"
        static let audioProcessorCategory = "AudioProcessor"
    }
} 