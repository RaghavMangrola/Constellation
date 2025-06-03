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

// Vertex structure for Metal rendering
struct StarVertex {
    let position: simd_float2
    let color: simd_float4
    let size: Float
}

// Uniforms for shader
struct Uniforms {
    var projectionMatrix: simd_float4x4
    var time: Float
}

@MainActor
class ConstellationRenderer: NSObject, ObservableObject {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    // Rendering parameters
    private let maxStars = 1000
    private var currentVertexCount = 0
    private var startTime: Double = 0
    
    // Color palettes for different frequency ranges
    private let colorPalette: [simd_float4] = [
        simd_float4(0.8, 0.9, 1.0, 1.0),   // Blue-white (high freq)
        simd_float4(1.0, 1.0, 0.8, 1.0),   // Yellow-white (mid-high freq)
        simd_float4(1.0, 0.8, 0.6, 1.0),   // Orange (mid freq)
        simd_float4(1.0, 0.6, 0.4, 1.0),   // Red-orange (low-mid freq)
        simd_float4(0.8, 0.4, 0.6, 1.0),   // Purple-red (low freq)
    ]
    
    weak var peakFinder: PeakFinder?
    
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
    
    func updateVertices(with peaks: [(peak: Peak, alpha: Float)]) {
        let vertexBufferPointer = vertexBuffer.contents().bindMemory(to: StarVertex.self, capacity: maxStars)
        
        currentVertexCount = min(peaks.count, maxStars)
        
        for (index, peakData) in peaks.enumerated() {
            guard index < maxStars else { break }
            
            let peak = peakData.peak
            let alpha = peakData.alpha
            
            // Convert frequency and magnitude to normalized coordinates
            let x = peak.normalizedFrequency * 2.0 - 1.0  // -1 to 1
            let y = peak.normalizedMagnitude * 2.0 - 1.0  // -1 to 1
            
            // Choose color based on frequency
            let colorIndex = Int(peak.normalizedFrequency * Float(colorPalette.count - 1))
            var color = colorPalette[min(colorIndex, colorPalette.count - 1)]
            color.w = alpha // Apply fade alpha
            
            // Size based on magnitude
            let size = 0.01 + peak.normalizedMagnitude * 0.02
            
            vertexBufferPointer[index] = StarVertex(
                position: simd_float2(x, y),
                color: color,
                size: size
            )
        }
    }
    
    func render(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }
        
        // Update vertex data from peak finder
        if let peakFinder = peakFinder {
            let peaksWithFade = peakFinder.getConstellationWithFade()
            updateVertices(with: peaksWithFade)
        }
        
        // Update uniforms
        let uniforms = Uniforms(
            projectionMatrix: matrix_identity_float4x4,
            time: Float(CACurrentMediaTime() - startTime)
        )
        
        uniformBuffer.contents().copyMemory(
            from: [uniforms],
            byteCount: MemoryLayout<Uniforms>.stride
        )
        
        // Clear background to dark blue/black
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        // Draw stars as points
        if currentVertexCount > 0 {
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: currentVertexCount)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// SwiftUI wrapper for Metal view
struct ConstellationMetalView: UIViewRepresentable {
    let renderer: ConstellationRenderer
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.backgroundColor = UIColor.clear
        
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
            renderer.render(in: view)
        }
    }
} 