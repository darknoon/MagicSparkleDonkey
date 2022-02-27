//
//  Renderer.swift
//  MagicSparkleDonkey Shared
//
//  Created by Andrew Pouliot on 4/6/21.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd
import MSD

enum RendererError: Error {
    case badVertexDescriptor
    case unexpectedMetalError
    case metalAllocationError
    case metalInvalidConfiguration(underlying: Error?)
    case meshBuild(mtkError: Error)
    case textureLoad(mtkError: Error)
}


class RendererMetal: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice

    typealias Failure = RendererError
    
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState


    var colorMap: MTLTexture
    var mesh: MTKMesh
    
    @GPUBufferQueue var uniforms: Uniforms
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
    
    init(metalKitView: MTKView) throws {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { throw Failure.unexpectedMetalError }
        self.commandQueue = queue
        
        _uniforms = try GPUBufferQueue(device: device)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Self.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Self.buildRenderPipelineWithDevice(device: device,
                                                                   metalKitView: metalKitView,
                                                                   mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            throw Failure.metalInvalidConfiguration(underlying: error)
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { throw RendererError.metalInvalidConfiguration(underlying: nil) }
        depthState = state
        
        do {
            mesh = try RendererMetal.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            throw Failure.meshBuild(mtkError: error)
        }
        
        do {
            colorMap = try RendererMetal.loadTexture(device: device, textureName: "ColorMap")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            throw Failure.textureLoad(mtkError: error)
        }
        
        super.init()
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexSemantic.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexSemantic.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexSemantic.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.attributes[VertexSemantic.texcoord0.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexSemantic.texcoord0.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexSemantic.texcoord0.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             vertexFunctionName: String = "vertexShader",
                                             fragmentFunctionName: String = "fragmentShader",
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: vertexFunctionName)
        let fragmentFunction = library?.makeFunction(name: fragmentFunctionName)
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(4, 4, 4),
                                     segments: SIMD3<UInt32>(2, 2, 2),
                                     geometryType: MDLGeometryType.triangles,
                                     inwardNormals:false,
                                     allocator: metalAllocator)
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexSemantic.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexSemantic.texcoord0.rawValue].name = MDLVertexAttributeTextureCoordinate
        
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]
        
        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)
        
    }
    
    private func updateGameState() {
        _uniforms.next()
        
        /// Update any game state before rendering
        
        uniforms.projectionMatrix = projectionMatrix
        
        let rotationAxis = SIMD3<Float>(1, 1, 0)
        let modelMatrix = simd_float4x4(rotation: rotation, axis: rotationAxis)
        let viewMatrix = simd_float4x4(translation: simd_float3(0.0, 0.0, -8.0))
        uniforms.modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        rotation += 0.01
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        _ = _uniforms.inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            commandBuffer.addCompletedHandler { [semaphore = _uniforms.inFlightSemaphore](_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateGameState()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                /// Final pass rendering code here
                renderEncoder.label = "Primary Render Encoder"
                
                renderEncoder.pushDebugGroup("Draw Box")
                
                renderEncoder.setCullMode(.back)
                
                renderEncoder.setFrontFacing(.counterClockwise)
                
                renderEncoder.setRenderPipelineState(pipelineState)
                
                renderEncoder.setDepthStencilState(depthState)
                
                renderEncoder.setVertexBuffer($uniforms.buffer, offset:$uniforms.offset, index: BufferIndex.uniforms.rawValue)
                renderEncoder.setFragmentBuffer(_uniforms.dynamicUniformBuffer, offset:_uniforms.bufferOffset, index: BufferIndex.uniforms.rawValue)
                
                for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
                    guard let layout = element as? MDLVertexBufferLayout else {
                        return
                    }
                    
                    if layout.stride != 0 {
                        let buffer = mesh.vertexBuffers[index]
                        renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                    }
                }
                
                renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
                
                for submesh in mesh.submeshes {
                    renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                        indexCount: submesh.indexCount,
                                                        indexType: submesh.indexType,
                                                        indexBuffer: submesh.indexBuffer.buffer,
                                                        indexBufferOffset: submesh.indexBuffer.offset)
                    
                }
                
                renderEncoder.popDebugGroup()
                
                renderEncoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_float4x4.perspectiveRightHand(fovyRadians: toRadians(degrees: 65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
}
