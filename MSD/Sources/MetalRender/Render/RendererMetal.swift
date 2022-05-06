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
import MetalRenderShaders

public enum RendererError: Error {
    case badVertexDescriptor
    case unexpectedMetalError
    case metalAllocationError
    case metalInvalidConfiguration(underlying: Error?)
    case meshBuild(mtkError: Error)
    case resourceNotFound(resource: String)
    case shaderBundleNotFound
    case shaderNotFound(name: String)
    case textureLoad(mtkError: Error)
}

public class RendererMetal: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice

    typealias Failure = RendererError
    
    let commandQueue: MTLCommandQueue
    
    let resourceManager: ResourceManager
    
    let config: RenderConfig
    
    // id->state?
    var loadedMeshes: [Resource.ID: MeshRenderState] = [:]
    
    let bufferAllocator: MDLMeshBufferAllocator
    
    @GPUBufferQueue var uniforms: Uniforms
    // TODO: store object transforms in an array in an MTLBuffer
    // var draws: DrawCallDataArray
    var perDrawData: GPUMemoryPool
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    public init(config: RenderConfig, device: MTLDevice) throws {
        self.device = device
        self.config = config
        guard let queue = self.device.makeCommandQueue() else { throw Failure.unexpectedMetalError }
        self.commandQueue = queue
        
        _uniforms = try GPUBufferQueue(device: device)
        
        resourceManager = ResourceManager(device: device)
        
        bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        perDrawData = try GPUMemoryPool(device: device, size: 2_097_152)
        
        super.init()

        try loadDefaultResources()
    }
    
    private func load(assetResource: MeshResource, for id: Resource.ID) throws {
        let url = URL(fileURLWithPath: assetResource.path, relativeTo: Bundle.main.resourceURL)
        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: bufferAllocator)
        let meshes = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        if let mesh = meshes.first {
            let inputs = MeshRenderState.Inputs(
                meshResource: 0,
                textureOverrides: [.diffuse: .textureName(name: "ColorMap")],
                mesh: mesh,
                renderConfig: config)
            loadedMeshes[0] = try MeshRenderState(from: inputs,
                                                resourceManager: resourceManager,
                                                for: device)
        } else {
            throw RendererError.resourceNotFound(resource: assetResource.path)
        }
    }
    
    private func loadDefaultResources() throws {
        // Add a default resource
        try load(assetResource: MSD.ResourceBundle(bundle: .main).subdiv, for: Resource.ID(0))
    }

    public var displayListCallback: () -> RenderSystem.DisplayList = { .empty }
    
    private func updateGameState() -> RenderSystem.DisplayList {
        _uniforms.next()
        
        /// Update any game state before rendering
        
        let displayList = displayListCallback()
        
        uniforms.projectionMatrix = projectionMatrix
        
        return displayList
    }
    
    public func draw(in view: MTKView) {
        /// Per frame updates hare
        
        _ = _uniforms.inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        perDrawData.beginFrame()
        
        guard let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            print("Error: Couldn't make command buffer!")
            return
        }
        
        commandBuffer.addCompletedHandler { [semaphore = _uniforms.inFlightSemaphore] _ in
            semaphore.signal()
        }
        
        let displayList = self.updateGameState()
        
        /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
        ///   holding onto the drawable and blocking the display pipeline any longer than necessary
        let renderPassDescriptor = view.currentRenderPassDescriptor
        
        guard  let renderPassDescriptor = renderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            print("Could not make render encoder")
            return
        }
        
        /// Final pass rendering code here
        renderEncoder.label = "Primary Render Encoder"
        
        for display in displayList.displays {
            do {
                
                let resourceId = display.resource
                guard let meshState = loadedMeshes[resourceId]
                else {
                    print("Skipping render for mesh \(resourceId) because it is not loaded.")
                    continue
                }
                renderEncoder.pushDebugGroup("Draw Mesh \(display.entity) \(resourceId) \(meshState.mesh.name)")
                
                // TODO: pull from mesh render state
                renderEncoder.setCullMode(.back)
                renderEncoder.setFrontFacing(.counterClockwise)
                
                renderEncoder.setRenderPipelineState(meshState.pipelineState)
                
                renderEncoder.setDepthStencilState(meshState.depthState)
                
                renderEncoder.setVertexBuffer($uniforms.buffer, offset:$uniforms.offset, index: BufferIndex.uniforms.rawValue)
                let t = displayList.viewMatrix * display.transform
                // renderEncoder.setVertexStruct(MSDDraw(modelViewMatrix: t), index: BufferIndex.perMeshData.rawValue)
                renderEncoder.setVertexBuffer(perDrawData.currentBuffer, offset:try perDrawData.append(MSDDraw(modelViewMatrix: t)), index: BufferIndex.perMeshData.rawValue)
                
                renderEncoder.setFragmentBuffer(_uniforms.dynamicUniformBuffer, offset:_uniforms.bufferOffset, index: BufferIndex.uniforms.rawValue)
                
                for (index, element) in meshState.mesh.vertexDescriptor.layouts.enumerated() {
                    guard let layout = element as? MDLVertexBufferLayout else {
                        return
                    }
                    
                    if layout.stride != 0 {
                        let buffer = meshState.mesh.vertexBuffers[index]
                        renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                    }
                }
                
                for (key, value) in meshState.textures {
                    switch key {
                    case .diffuse:
                        renderEncoder.setFragmentTexture(value, index: TextureIndex.color.rawValue)
                    }
                }
                
                for submesh in meshState.mesh.submeshes {
                    renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                        indexCount: submesh.indexCount,
                                                        indexType: submesh.indexType,
                                                        indexBuffer: submesh.indexBuffer.buffer,
                                                        indexBufferOffset: submesh.indexBuffer.offset)
                    
                }
                
                renderEncoder.popDebugGroup()
            } catch {
                print("Draw \(display) failed: \(error)")
            }
            
        }
        
        perDrawData.finishFrame()

        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_float4x4.perspectiveRightHand(fovyRadians: toRadians(degrees: 65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
    }
}


// Render state uses this as an input, so we need to rebuild whenever this changes
public struct RenderConfig {
    var depthStencilFormat: MTLPixelFormat
    var colorPixelFormat: MTLPixelFormat
    var sampleCount: Int
}

extension MTKView {
    
    public var renderConfig: RenderConfig {
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
