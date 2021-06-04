//
//  Renderer.swift
//  MagicSparkleDonkey Shared
//
//  Created by Andrew Pouliot on 4/6/21.
//

// Our platform independent renderer class

import simd

import ModelIO

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

class RendererGeneric<GPU: GPUAPI> {
    
    enum Failure: Error {
        case badVertexDescriptor
        case unexpectedMetalError
        case gpuAllocationError
        case gpuInvalidConfiguration(underlying: Error?)
        case shaderCompilationError(underlying: Error?)
        case meshBuild(underlying: Error)
        case resourceNotFound(name: String)
        case textureLoad(underlying: Error)
    }

    public let device: GPU
    
    let commandQueue: GPU.CommandQueue
    var dynamicUniformBuffer: GPU.Buffer
    var pipelineState: GPU.RenderPipelineState
    var depthState: GPU.DepthStencilState


    var colorMap: GPU.Texture
    var mesh: GPU.MeshRuntimeType

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
    
    init(swapChain: GPU.SwapChain) throws {
        self.device = swapChain.device
        guard let queue = self.device.makeCommandQueue() else { throw Failure.unexpectedMetalError }
        self.commandQueue = queue
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, storageMode: .shared)
        else { throw Failure.gpuAllocationError }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        if let dataPtr = dynamicUniformBuffer.data {
            uniforms = dataPtr.bindMemory(to:Uniforms.self, capacity:1)
        }

        // TODO: configure swap chain?
        //        metalKitView.depthStencilPixelFormat = GPUPixelFormat.depth32Float_stencil8
        //        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        //        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Self.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Self.buildRenderPipelineWithDevice(device: device,
                                                                   swapChain: swapChain,
                                                                   mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            throw Failure.gpuInvalidConfiguration(underlying: error)
        }
        
        let depthStateDescriptor = GPUDepthStencilDescriptor(writeDepth: true)
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { throw RendererError.metalInvalidConfiguration(underlying: nil) }
        depthState = state
        
        do {
            mesh = try Self.buildMesh(device: device, vertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            throw Failure.meshBuild(underlying: error)
        }
        
        do {
            colorMap = try Self.loadTexture(device: device, textureName: "ColorMap")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            throw Failure.textureLoad(underlying: error)
        }
    }
    
    class func buildMetalVertexDescriptor() -> GPU.VertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        return .init(
            attributes: [
                VertexSemantic.position.rawValue:
                    .init(format: .float3,
                          offset: 0,
                          bufferIndex: BufferIndex.meshPositions.rawValue
                    ),

                VertexSemantic.texcoord0.rawValue:
                    .init(format: .float2,
                          offset: 0,
                          bufferIndex: BufferIndex.meshGenerics.rawValue
                    ),

            ],
            layouts: [
                BufferIndex.meshPositions.rawValue:
                    .init(stride: 12),

                BufferIndex.meshGenerics.rawValue:
                    .init(stride: 8)
            ])
    }
    
    class func buildRenderPipelineWithDevice(device: GPU.Device,
                                             swapChain: GPU.SwapChain,
                                             mtlVertexDescriptor: GPUVertexDescriptor) throws -> GPU.RenderPipelineState {
        /// Build a render state pipeline object
        
        guard let library = device.defaultLibrary
        else {
            throw Failure.shaderCompilationError(underlying: nil)
        }
        
        // TODO: should be able to autogenerate the function names from our library
        let vertexFunction: GPU.Function
        let fragmentFunction: GPU.Function
        do {
            vertexFunction = try library.makeFunction(named: "vertexShader")
            fragmentFunction = try library.makeFunction(named: "fragmentShader")
        } catch {
            throw Failure.shaderCompilationError(underlying: error)
        }
        
        let config = swapChain.configuration
        
        let pipelineDescriptor = GPURenderPipelineDescriptor(
            label: "RenderPipeline",
            vertexFunction: vertexFunction,
            fragmentFunction: fragmentFunction,
            sampleCount: config.sampleCount,
            descriptor: mtlVertexDescriptor,
            colorAttachments: [
                .init(pixelFormat: config.format)
            ],
            depthAttachmentPixelFormat: config.depthStencilFormat,
            stencilAttachmentPixelFormat: config.depthStencilFormat
        )
            
//            MTLRenderPipelineDescriptor()
//        pipelineDescriptor.label = "RenderPipeline"
//        pipelineDescriptor.sampleCount = metalKitView.sampleCount
//        pipelineDescriptor.vertexFunction = vertexFunction
//        pipelineDescriptor.fragmentFunction = fragmentFunction
//        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
//        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
//        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
//        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildMesh(device: GPU.Device,
                         vertexDescriptor: GPUVertexDescriptor) throws -> GPU.MeshRuntimeType
    where GPU.MeshBufferAllocator : MDLMeshBufferAllocator
    {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let allocator = GPU.MeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
                                     segments: SIMD3<UInt32>(2, 2, 2),
                                     geometryType: MDLGeometryType.triangles,
                                     inwardNormals: false,
                                     allocator: allocator)
        
        return try device.prepareMesh(mesh: mdlMesh, vertexDescriptor: buildMetalVertexDescriptor())
    }
    
    class func loadTexture(device: GPU.Device,
                           textureName: String) throws -> GPU.Texture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = GPU.TextureLoader(device: device)
        
        guard let url = Bundle(for: Self.self).url(forResource: textureName, withExtension: nil)
        else { throw Failure.resourceNotFound(name: textureName) }
        
        return try textureLoader.makeTexture(url: url, options: .init(generateMipMaps: false))
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        if let dataPtr = dynamicUniformBuffer.data {
            uniforms = (dataPtr + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
        }
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
        
        uniforms[0].projectionMatrix = projectionMatrix
        
        let rotationAxis = SIMD3<Float>(1, 1, 0)
        let modelMatrix = simd_float4x4(rotation: rotation, axis: rotationAxis)
        let viewMatrix = simd_float4x4(translation: simd_float3(0.0, 0.0, -8.0))
        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        rotation += 0.01
    }
    
    func draw(in view: GPU.SwapChain) {
        /// Per frame updates hare
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateGameState()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor {
                
                //commandBuffer.draw(mesh: mesh, pass: renderPassDescriptor)
                
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    func mtkView(_ view: GPU.SwapChain, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_float4x4.perspectiveRightHand(fovyRadians: toRadians(degrees: 65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
}
