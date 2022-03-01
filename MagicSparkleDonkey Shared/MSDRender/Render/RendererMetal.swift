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
    case resourceNotFound(resource: String)
    case textureLoad(mtkError: Error)
}

class RendererMetal: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice

    typealias Failure = RendererError
    
    let commandQueue: MTLCommandQueue
    
    let resourceManager: ResourceManager
    
    // id->state?
    var mesh: MeshRenderState
    
    let bufferAllocator: MDLMeshBufferAllocator
    
    @GPUBufferQueue var uniforms: Uniforms
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
    init(config: RenderConfig, device: MTLDevice) throws {
        self.device = device
        guard let queue = self.device.makeCommandQueue() else { throw Failure.unexpectedMetalError }
        self.commandQueue = queue
        
        _uniforms = try GPUBufferQueue(device: device)
        
        resourceManager = ResourceManager(device: device)
                
        bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        let meshPath = MSD.ResourceBundle(bundle: .main).subdiv.path
        let asset = MDLAsset(url: URL(fileURLWithPath: meshPath, relativeTo: Bundle.main.resourceURL), vertexDescriptor: nil, bufferAllocator: bufferAllocator)
        let meshes = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        if let mesh = meshes.first {
            let inputs = MeshRenderState.Inputs(
                meshResource: 1234,
                textureOverrides: [.diffuse: .textureName(name: "ColorMap")],
                mesh: mesh,
                renderConfig: config)
            self.mesh = try MeshRenderState(from: inputs,
                                        resourceManager: resourceManager,
                                        for: device)
        } else {
            throw RendererError.resourceNotFound(resource: meshPath)
        }
        
        super.init()
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
                
                renderEncoder.pushDebugGroup("Draw Mesh")
                
                // TODO: pull from mesh render state
                renderEncoder.setCullMode(.back)
                renderEncoder.setFrontFacing(.counterClockwise)
                
                renderEncoder.setRenderPipelineState(mesh.pipelineState)
                
                renderEncoder.setDepthStencilState(mesh.depthState)
                
                renderEncoder.setVertexBuffer($uniforms.buffer, offset:$uniforms.offset, index: BufferIndex.uniforms.rawValue)
                renderEncoder.setFragmentBuffer(_uniforms.dynamicUniformBuffer, offset:_uniforms.bufferOffset, index: BufferIndex.uniforms.rawValue)
                
                for (index, element) in mesh.mesh.vertexDescriptor.layouts.enumerated() {
                    guard let layout = element as? MDLVertexBufferLayout else {
                        return
                    }
                    
                    if layout.stride != 0 {
                        let buffer = mesh.mesh.vertexBuffers[index]
                        renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                    }
                }
                
                for (key, value) in mesh.textures {
                    switch key {
                    case .diffuse:
                        renderEncoder.setFragmentTexture(value, index: TextureIndex.color.rawValue)
                    }
                }
                
                for submesh in mesh.mesh.submeshes {
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


// Render state uses this as an input, so we need to rebuild whenever this changes
struct RenderConfig {
    var depthStencilFormat: MTLPixelFormat
    var colorPixelFormat: MTLPixelFormat
    var sampleCount: Int
}

extension MTKView {
    
    var renderConfig: RenderConfig {
        get {
            .init(depthStencilFormat: depthStencilPixelFormat, colorPixelFormat: colorPixelFormat, sampleCount: sampleCount)
        }
        set {
            depthStencilPixelFormat = newValue.depthStencilFormat
            colorPixelFormat = newValue.colorPixelFormat
            sampleCount = newValue.sampleCount
        }
    }
    
}
