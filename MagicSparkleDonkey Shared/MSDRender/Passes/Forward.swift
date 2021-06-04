//
//  Forward.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 5/25/21.
//

import Foundation

protocol Pass {
    associatedtype GPU: GPUAPI
    func encode(buffer: GPU.CommandBuffer, surface: GPU.SwapChain) throws
}

#if canImport(ModelIO)
import ModelIO
#endif

struct ForwardPass<GPU: GPUAPI> : Pass {
    
    typealias Failure = RendererGeneric<GPU>.Failure
    
    // The 256 byte aligned size of our uniform structure
    let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

    let maxBuffersInFlight = 3

    struct State {
        let depthWriteState: GPU.DepthStencilState
        let pipelineState: GPU.RenderPipelineState
        let dynamicUniformBuffer: GPU.Buffer
        let mesh: GPU.MeshRuntimeType
        var uniformBufferOffset: Int
    }
    
    let state: State
    let device: GPU
    
    var displayList: [GPU.MeshRuntimeType] = []
    
    let outputColorFormat: GPUPixelFormat = .rgba16Float
    let outputDepthFormat: GPUPixelFormat = .depth32Float_stencil8

    static var vertexDescriptor0: GPUVertexDescriptor {
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
    
    #if canImport(ModelIO)
    static func boxGeometry(device: GPU.Device) -> MDLMesh {
        let alloc = GPU.MeshBufferAllocator(device: device)
        return MDLMesh.newBox(
            withDimensions: SIMD3<Float>(4, 4, 4),
            segments: SIMD3<UInt32>(2, 2, 2),
            geometryType: MDLGeometryType.triangles,
            inwardNormals: false,
            allocator: (alloc as! MDLMeshBufferAllocator)
        )
    }
    #endif

    struct InvalidMeshInput: GPUMeshInput {}
    
    static func boxGeometry(device: GPU.Device) -> some GPUMeshInput {
        return InvalidMeshInput()
    }
    
    
    init(device: GPU) throws {
        self.device = device

        guard let library = device.defaultLibrary
        else { throw Failure.shaderCompilationError(underlying: nil) }

        guard let depthWriteState = device.makeDepthStencilState(descriptor: .init(writeDepth: true))
        else { throw Failure.unexpectedMetalError }

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let dynamicUniformBuffer = self.device.makeBuffer(length:uniformBufferSize, storageMode: .shared)
        else { throw Failure.gpuAllocationError }

        let vertexFunction: GPU.Function
        let fragmentFunction: GPU.Function
        do {
            vertexFunction = try library.makeFunction(named: "vertexShader")
            fragmentFunction = try library.makeFunction(named: "fragmentShader")
        } catch {
            throw Failure.shaderCompilationError(underlying: error)
        }
        
        let pipeline: GPU.RenderPipelineState
        do {
            pipeline = try device.makeRenderPipelineState(descriptor: GPURenderPipelineDescriptor<GPU.Function>(label: "Render", vertexFunction: vertexFunction, fragmentFunction: fragmentFunction, sampleCount: 1, descriptor: Self.vertexDescriptor0, colorAttachments: [.init(pixelFormat: outputColorFormat)], depthAttachmentPixelFormat: outputDepthFormat, stencilAttachmentPixelFormat: outputDepthFormat))
        } catch {
            throw Failure.gpuInvalidConfiguration(underlying: error)
        }
        
        let mesh: GPU.MeshRuntimeType
        do {
            mesh = try device.prepareMesh(mesh: Self.boxGeometry(device: device), vertexDescriptor: Self.vertexDescriptor0)
        }

        state = State(depthWriteState: depthWriteState, pipelineState: pipeline, dynamicUniformBuffer: dynamicUniformBuffer, mesh: mesh, uniformBufferOffset: 0)
    }
    
    func encode(buffer: GPU.CommandBuffer, surface: GPU.SwapChain) throws {
        guard let currentRenderPassDescriptor = surface.currentRenderPassDescriptor
        else { return }
        
        try displayList.forEach { mesh in
            print("display: \(mesh)")
            guard var renderEncoder = buffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
            else { throw Failure.gpuAllocationError }

            /// Final pass rendering code here
            renderEncoder.label = "Primary Render Encoder"
            
            renderEncoder.pushDebugGroup("Draw Box")
            
            renderEncoder.setCullMode(.back)
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setRenderPipelineState(state.pipelineState)
            renderEncoder.setDepthStencilState(state.depthWriteState)
            
            renderEncoder.setVertexBuffer(state.dynamicUniformBuffer, offset:state.uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
            renderEncoder.setFragmentBuffer(state.dynamicUniformBuffer, offset:state.uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
            
            for (index, element) in mesh.vertexDescriptor.layouts {
                if element.stride != 0 {
                    let buffer: GPU.MeshBuffer = mesh.vertexBuffers[index]
                    renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                }
            }
            
            //renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
            
            for submesh in mesh.submeshes {
                renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
            }

            renderEncoder.popDebugGroup()
            
            renderEncoder.endEncoding()


//            renderEncoder.draw(mesh: $0, pass: currentRenderPassDescriptor, pipelineState: state.depthWriteState)
        }
    }
}
