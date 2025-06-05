//
//  ConstellationRenderer.swift
//  Constellation
//
//  Metal-based high-performance rendering of audio peak constellations
//  Inspired by Shazam's star-like audio fingerprint visualization
//

import Metal
import MetalKit
import SwiftUI
import simd
import os

// Vertex structure for Metal rendering
struct StarVertex {
    let position: simd_float2
    let color: simd_float4
    let size: Float
    let age: Float  // Add age parameter to match shader
}

// Uniforms for shader
struct Uniforms {
    var projectionMatrix: simd_float4x4
    var time: Float
    var fadeTime: Float     // Add fadeTime parameter
    var viewportSize: simd_float2  // Add viewport size
}

@MainActor
class ConstellationRenderer: NSObject, ObservableObject, MTKViewDelegate {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    // Rendering parameters
    private let maxStars = AudioConstants.Rendering.maxStars
    private var currentVertexCount = 0
    private var startTime: Double = 0
    private let basePointSize = AudioConstants.Rendering.basePointSize
    
    // Color palettes for different frequency ranges - cosmic theme
    private let colorPalette = AudioConstants.Rendering.colorPalette
    
    weak var peakFinder: PeakFinder?
    
    // Logger instance for rendering
    private let logger = Logger(subsystem: AudioConstants.Logging.graphicsSubsystem, category: AudioConstants.Logging.rendererCategory)
    
    // Add peaksWithFade property
    private var peaksWithFade: [(peak: Peak, fade: Float)] = []
    
    override init() {
        super.init()
        setupMetal()
        startTime = CACurrentMediaTime()
    }
    
    private func setupMetal() {
        // Initialize Metal device and command queue
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue")
        }
        self.commandQueue = commandQueue
        
        // Create vertex buffer
        let vertexBufferSize = maxStars * MemoryLayout<StarVertex>.stride
        guard let vertexBuffer = device.makeBuffer(length: vertexBufferSize, options: .storageModeShared) else {
            fatalError("Could not create vertex buffer")
        }
        self.vertexBuffer = vertexBuffer
        
        // Create uniform buffer
        guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: .storageModeShared) else {
            fatalError("Could not create uniform buffer")
        }
        self.uniformBuffer = uniformBuffer
        
        setupRenderPipeline()
    }
    
    private func setupRenderPipeline() {
        // Load Metal shaders from the .metal file
        guard let shaderLibrary = device.makeDefaultLibrary() else {
            fatalError("Could not load default Metal library")
        }
        
        guard let vertexFunc = shaderLibrary.makeFunction(name: "star_vertex_shader") else {
            fatalError("Could not find star_vertex_shader function")
        }
        
        guard let fragmentFunc = shaderLibrary.makeFunction(name: "star_fragment_shader") else {
            fatalError("Could not find star_fragment_shader function")
        }
        
        // Create render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Enable point sprites and set size
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.attributes[3].format = .float
        vertexDescriptor.attributes[3].offset = MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride + MemoryLayout<Float>.stride
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<StarVertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // Enable blending for alpha transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state: \(error)")
        }
    }
    
    private func updateVertexBuffer(with peaks: [(peak: Peak, fade: Float)]) {
        let vertexBufferPointer = vertexBuffer.contents().bindMemory(to: StarVertex.self, capacity: maxStars)
        
        self.currentVertexCount = min(peaks.count, maxStars)
        
        logger.debug("Updating \(self.currentVertexCount) vertices")
        
        // First pass: find actual min/max ranges in the data
        var minFreq: Float = 1.0, maxFreq: Float = 0.0
        var minMag: Float = 1.0, maxMag: Float = 0.0
        
        for peakWithFade in peaks {
            let peak = peakWithFade.peak
            minFreq = min(minFreq, peak.normalizedFrequency)
            maxFreq = max(maxFreq, peak.normalizedFrequency)
            minMag = min(minMag, peak.normalizedMagnitude)  
            maxMag = max(maxMag, peak.normalizedMagnitude)
        }
        
        // Add small padding to avoid division by zero
        let freqRange = max(AudioConstants.Rendering.minRangePadding, maxFreq - minFreq)
        let magRange = max(AudioConstants.Rendering.minRangePadding, maxMag - minMag)
        
        logger.debug("Actual ranges - Freq: \(minFreq)-\(maxFreq) (\(freqRange)), Mag: \(minMag)-\(maxMag) (\(magRange))")
        
        // Track final position ranges for debugging
        var minX: Float = 1.0, maxX: Float = -1.0
        var minY: Float = 1.0, maxY: Float = -1.0
        
        for (index, peakWithFade) in peaks.enumerated() {
            guard index < maxStars else { break }
            
            let peak = peakWithFade.peak
            let fade = peakWithFade.fade
            
            // Remap frequency and magnitude to full 0-1 range based on actual data
            let remappedFreq = (peak.normalizedFrequency - minFreq) / freqRange
            let remappedMag = (peak.normalizedMagnitude - minMag) / magRange
            
            // Now apply coordinate transformation to FULL VIEWPORT PIXEL SPACE
            let frequencySpread = AudioConstants.Rendering.frequencySpread   // This will create range -25 to +25
            let magnitudeSpread = AudioConstants.Rendering.magnitudeSpread   // This will create range -20 to +20
            
            // Map to coordinates that span the full expected range
            var x = (remappedFreq - 0.5) * Float(frequencySpread)
            var y = (remappedMag - 0.5) * Float(magnitudeSpread)
            
            // Add controlled randomness for natural distribution
            let seedX = sin(Float(index) * AudioConstants.Rendering.randomnessFrequencyX + peak.normalizedFrequency * 10.0) * AudioConstants.Rendering.randomnessAmplitudeX
            let seedY = cos(Float(index) * AudioConstants.Rendering.randomnessFrequencyY + peak.normalizedMagnitude * 8.0) * AudioConstants.Rendering.randomnessAmplitudeY
            
            x += seedX
            y += seedY
            
            // These coordinates will be properly mapped by the Metal shader
            // X range: approximately -28 to +28
            // Y range: approximately -23 to +23
            // Metal shader will map these to full NDC space (-1 to +1)
            
            // Track ranges
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
            
            logger.trace("Star \(index): original(\(peak.normalizedFrequency), \(peak.normalizedMagnitude)) -> remapped(\(remappedFreq), \(remappedMag)) -> pos(\(x), \(y))")
            
            // Choose color based on original frequency
            let colorIndex = Int(peak.normalizedFrequency * Float(colorPalette.count - 1))
            var color = colorPalette[min(colorIndex, colorPalette.count - 1)]
            
            // Add some color variation for more realistic stars
            let variation = sin(Float(index) * AudioConstants.Rendering.colorVariationFrequency) * AudioConstants.Rendering.colorVariationAmplitude
            color.x = min(1.0, max(AudioConstants.Rendering.colorVariationMinimum, color.x + variation))
            color.y = min(1.0, max(AudioConstants.Rendering.colorVariationMinimum, color.y + variation * 0.5))
            color.z = min(1.0, max(AudioConstants.Rendering.colorVariationMinimum, color.z + variation * 0.8))
            color.w = fade // Apply fade alpha
            
            // Enhanced size calculation based on magnitude and frequency
            let baseMagnitude = peak.normalizedMagnitude
            let frequencyBoost = (1.0 - peak.normalizedFrequency) * 0.3 // Lower freq = bigger stars
            let size = AudioConstants.Rendering.baseSizeOffset + baseMagnitude * AudioConstants.Rendering.magnitudeSizeMultiplier + frequencyBoost * AudioConstants.Rendering.frequencySizeMultiplier
            
            // Calculate age (0.0 = new, 1.0 = old)
            let age = 1.0 - fade
            
            vertexBufferPointer[index] = StarVertex(
                position: simd_float2(x, y),
                color: color,
                size: size,
                age: age
            )
        }
        
        logger.debug("Final position ranges - X: \(minX) to \(maxX), Y: \(minY) to \(maxY)")
    }
    
    func updatePeaks(_ peaks: [(peak: Peak, fade: Float)]) {
        self.peaksWithFade = peaks
        logger.debug("Got \(self.peaksWithFade.count) peaks with fade")
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            logger.error("Failed to create Metal command buffer or drawable")
            return
        }
        
        // Update vertex data from peak finder
        if let peakFinder = peakFinder {
            let peaks = peakFinder.getConstellationWithFade()
            // Convert alpha to fade in the peaks array
            let peaksWithFade = peaks.map { (peak: $0.peak, fade: $0.alpha) }
            updateVertexBuffer(with: peaksWithFade)
            
            // DEBUG: Log first few vertex positions being sent to Metal
            if self.currentVertexCount > 0 {
                let vertexBufferPointer = vertexBuffer.contents().bindMemory(to: StarVertex.self, capacity: maxStars)
                logger.debug("First 5 vertices sent to Metal:")
                for i in 0..<min(5, self.currentVertexCount) {
                    let vertex = vertexBufferPointer[i]
                    logger.debug("  Vertex \(i): pos=(\(vertex.position.x), \(vertex.position.y)), size=\(vertex.size)")
                }
            }
        }
        
        // Update uniforms with all required parameters
        let uniforms = Uniforms(
            projectionMatrix: matrix_identity_float4x4,
            time: Float(CACurrentMediaTime() - startTime),
            fadeTime: Float(AudioConstants.PeakDetection.peakFadeTime),  // Match PeakFinder's fade time
            viewportSize: simd_float2(Float(view.drawableSize.width),
                                    Float(view.drawableSize.height))
        )
        
        logger.debug("Viewport size: \(uniforms.viewportSize), Drawing \(self.currentVertexCount) stars")
        
        uniformBuffer.contents().copyMemory(
            from: [uniforms],
            byteCount: MemoryLayout<Uniforms>.stride
        )
        
        // Clear background to deep space black
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            logger.error("Failed to create Metal render encoder")
            return
        }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        // Draw stars as points
        if self.currentVertexCount > 0 {
            logger.debug("Actually drawing \(self.currentVertexCount) points via Metal")
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: self.currentVertexCount)
        } else {
            logger.warning("No vertices to draw!")
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // Add required MTKViewDelegate method
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }
}

// SwiftUI wrapper for Metal view
struct ConstellationMetalView: UIViewRepresentable {
    let renderer: ConstellationRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = AudioConstants.Rendering.preferredFramesPerSecond
        metalView.enableSetNeedsDisplay = AudioConstants.Rendering.enableSetNeedsDisplay
        metalView.isPaused = false
        metalView.backgroundColor = UIColor.clear
        
        // Enable point sprites
        metalView.sampleCount = 1
        metalView.colorPixelFormat = .bgra8Unorm
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Updates handled by delegate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        let renderer: ConstellationRenderer
        
        init(renderer: ConstellationRenderer) {
            self.renderer = renderer
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }
        
        func draw(in view: MTKView) {
            renderer.draw(in: view)
        }
    }
} 