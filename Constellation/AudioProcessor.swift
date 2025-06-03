//
//  AudioProcessor.swift
//  Constellation
//
//  Real-time audio processing with FFT analysis
//  Inspired by Shazam's audio fingerprinting approach
//

import AVFoundation
import Accelerate
import Foundation
import os

@MainActor
class AudioProcessor: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let fftSetup: FFTSetup
    private let bufferSize: Int = AudioConstants.Format.bufferSize
    private let sampleRate: Double = AudioConstants.Format.defaultSampleRate
    
    // Logger instance for audio processing
    private let logger = Logger(subsystem: "com.constellation.audio", category: "AudioProcessor")
    
    @Published var magnitudeSpectrum: [Float] = []
    @Published var isRecording = false
    
    // FFT working buffers
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var splitComplex: DSPSplitComplex
    private var window: [Float]
    
    weak var peakFinder: PeakFinder?
    
    init() {
        inputNode = audioEngine.inputNode
        
        // Initialize FFT setup
        let log2n = vDSP_Length(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        // Initialize working buffers
        realBuffer = Array(repeating: 0.0, count: AudioConstants.FFT.complexBufferSize)
        imagBuffer = Array(repeating: 0.0, count: AudioConstants.FFT.complexBufferSize)
        splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
        
        // Create Hann window for better frequency resolution
        window = Array(repeating: 0.0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), AudioConstants.FFT.windowNormalization)
        
        setupAudioSession()
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try audioSession.setActive(true)
            try audioSession.setPreferredSampleRate(AudioConstants.Format.defaultSampleRate)
        } catch {
            logger.error("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        do {
            let format = inputNode.outputFormat(forBus: 0)
            logger.info("Audio format: \(format.description)")
            logger.info("Sample rate: \(format.sampleRate) Hz")
            
            inputNode.installTap(onBus: 0, bufferSize: UInt32(bufferSize), format: format) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }
            
            try audioEngine.start()
            isRecording = true
            logger.info("Audio recording started successfully")
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        isRecording = false
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        var inputBuffer = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // Debug log input levels
        if let maxLevel = inputBuffer.max(), let minLevel = inputBuffer.min() {
            logger.debug("Audio input levels - Max: \(maxLevel) dB, Min: \(minLevel) dB")
        }
        
        // Ensure we have enough samples
        if inputBuffer.count < bufferSize {
            inputBuffer.append(contentsOf: Array(repeating: 0.0, count: bufferSize - inputBuffer.count))
        } else if inputBuffer.count > bufferSize {
            inputBuffer = Array(inputBuffer.prefix(bufferSize))
        }
        
        // Apply window function
        var windowedBuffer = Array(repeating: Float(0.0), count: bufferSize)
        vDSP_vmul(inputBuffer, 1, window, 1, &windowedBuffer, 1, vDSP_Length(bufferSize))
        
        // Convert to complex split format for FFT
        windowedBuffer.withUnsafeMutableBufferPointer { bufferPointer in
            bufferPointer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: bufferSize / 2) { complexBuffer in
                vDSP_ctoz(complexBuffer, 2, &splitComplex, 1, vDSP_Length(bufferSize / 2))
            }
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(bufferSize))), AudioConstants.FFT.direction)
        
        // Calculate magnitude spectrum
        var magnitudes = Array(repeating: Float(0.0), count: bufferSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))
        
        // Convert to dB scale and normalize
        var logMagnitudes = Array(repeating: Float(0.0), count: bufferSize / 2)
        var one: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &one, &logMagnitudes, 1, vDSP_Length(bufferSize / 2), 0)
        
        // Debug log spectrum stats
        if let maxMag = logMagnitudes.max() {
            logger.debug("FFT Spectrum - Max magnitude: \(maxMag) dB")
        }
        
        // Update on main thread
        Task { @MainActor in
            self.magnitudeSpectrum = logMagnitudes
            
            // Pass data to peak finder for constellation analysis
            peakFinder?.findPeaks(magnitudeSpectrum: logMagnitudes, timeStamp: CACurrentMediaTime())
        }
    }
    
    // Utility function to convert bin to frequency
    func binToFrequency(_ bin: Int) -> Double {
        return Double(bin) * sampleRate / Double(bufferSize)
    }
    
    // Utility function to convert frequency to bin
    func frequencyToBin(_ frequency: Double) -> Int {
        return Int(frequency * Double(bufferSize) / sampleRate)
    }
} 