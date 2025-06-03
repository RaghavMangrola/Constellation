//
//  AudioConstants.swift
//  Constellation
//
//  Centralized configuration for audio processing parameters
//

import Foundation
import Accelerate

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
    
    /// Visualization configuration
    enum Visualization {
        /// Maximum number of stars to render
        static let maxStars: Int = 1000
        
        /// Frequency ranges for color mapping (Hz)
        static let lowFreq: Double = 20.0
        static let midLowFreq: Double = 250.0
        static let midFreq: Double = 2000.0
        static let midHighFreq: Double = 8000.0
        static let highFreq: Double = 20000.0
        
        /// Star size configuration
        static let minStarSize: Float = 0.01
        static let maxStarSize: Float = 0.03
    }
} 