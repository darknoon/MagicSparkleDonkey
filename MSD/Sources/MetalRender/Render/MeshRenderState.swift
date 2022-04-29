//
//  MeshRenderState.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 2/27/22.
//

import Metal
import MetalKit
import ModelIO
import MSD
import MetalRenderShaders

public enum TextureKey: String {
    case diffuse
}

public enum ColorSpace {
    case linearP3
    
    var name: CFString {
        switch self {
        case .linearP3:
            return CGColorSpace.extendedLinearDisplayP3
        }
    }
}

public enum TextureAttachment {
    // case color(simd_float4, space: ColorSpace)
    case texture(from: URL)
    case textureName(name: String)
}

public enum Shader {
    case physicallyBased
    // Names within the default metallib
    case custom(vertexFunctionName: String, fragmentFunctionName: String)
}

// TODO: unique across meshes
struct MeshRenderState {
    
    typealias Failure = RendererError
    

    struct Inputs {
        var meshResource: Resource.ID
        var textureOverrides: Dictionary<TextureKey, TextureAttachment>
        var mesh: MDLMesh

        var vertexFunctionName: String = "vertexShader"
        var fragmentFunctionName: String = "fragmentShader"
        
        var renderConfig: RenderConfig
    }
    
    let depthState: MTLDepthStencilState
    let pipelineState: MTLRenderPipelineState
    
    let textures: Dictionary<TextureKey, MTLTexture?>
    
    let mesh: MTKMesh
    
    init(from inputs: Inputs, resourceManager: ResourceManager, for device: MTLDevice) throws {
        let mtlVertexDescriptor = Self.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Self.buildRenderPipelineWithDevice(device: device,
                                                                       inputs: inputs,
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
//            mesh = try Self.buildBoxMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
            mesh = try resourceManager.loadMesh(inputs.mesh, vertexDescriptor: mtlVertexDescriptor)
            let tin = resourceManager
                .gatherTextures(from: inputs.mesh)
                .appending(inputs.textureOverrides)
            textures = try tin.mapValues{try resourceManager.loadTexture(t: $0)}
            
            
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            throw Failure.meshBuild(mtkError: error)
        }
        
    }
    
    
    static func buildBoxMesh(device: MTLDevice,
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
    

    static func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let v = MTLVertexDescriptor()
        
        v.attributes[VertexSemantic.position.rawValue].format = MTLVertexFormat.float3
        v.attributes[VertexSemantic.position.rawValue].offset = 0
        v.attributes[VertexSemantic.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        v.attributes[VertexSemantic.texcoord0.rawValue].format = MTLVertexFormat.float2
        v.attributes[VertexSemantic.texcoord0.rawValue].offset = 0
        v.attributes[VertexSemantic.texcoord0.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        v.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        v.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        v.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        v.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        v.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        v.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return v
    }
    
    static func buildRenderPipelineWithDevice(device: MTLDevice,
                                              inputs: Inputs,
                                              mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        // UGLY HARDCODED, but idk how else to fix this. Tried using a sentinel class for the bundle but it says it's part of the main executable. Oh well.
        guard let shaderBundle = Bundle.main.resourceURL?.appendingPathComponent("MSD_MetalRenderShaders.bundle"),
              let libraryURL = Bundle(url: shaderBundle)?.resourceURL?.appendingPathComponent("default.metallib")
        else { throw Failure.shaderBundleNotFound }
        
        print("Opening shaders from \(libraryURL.absoluteURL.path)")
        
        let library = try device.makeLibrary(URL: libraryURL)
        
        guard let vertexFunction = library.makeFunction(name: inputs.vertexFunctionName)
        else { throw Failure.shaderNotFound(name: inputs.vertexFunctionName) }

        guard let fragmentFunction = library.makeFunction(name: inputs.fragmentFunctionName)
        else { throw Failure.shaderNotFound(name: inputs.vertexFunctionName) }
        
        let p = MTLRenderPipelineDescriptor()
        p.label = "RenderPipeline"
        p.sampleCount = inputs.renderConfig.sampleCount
        p.vertexFunction = vertexFunction
        p.fragmentFunction = fragmentFunction
        p.vertexDescriptor = mtlVertexDescriptor
        
        p.colorAttachments[0].pixelFormat = inputs.renderConfig.colorPixelFormat
        p.depthAttachmentPixelFormat = inputs.renderConfig.depthStencilFormat
        p.stencilAttachmentPixelFormat = inputs.renderConfig.depthStencilFormat
        
        return try device.makeRenderPipelineState(descriptor: p)
    }
    

}


extension Dictionary {
    
    func appending(_ other: Self) -> Self {
        var d = self
        for (key, value) in other {
            d[key] = value
        }
        return d
    }
}
