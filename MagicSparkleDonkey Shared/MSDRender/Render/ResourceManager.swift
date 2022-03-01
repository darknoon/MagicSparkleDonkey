//
//  ResourceManager.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 2/27/22.
//

import Metal
import MetalKit
import ModelIO
import MSD

class ResourceManager {
    //TODO: track by resource id!
//    var meshes: [Resource.ID: MDLMesh] = [:]
//    var textures: [Resource.ID: MTLTexture] = [:]

    let device: MTLDevice
    let textureLoader: MTKTextureLoader

    init(device: MTLDevice) {
        self.device = device
        textureLoader = MTKTextureLoader(device: device)
    }

    func loadMesh(_ m: MDLMesh, vertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        let mdlVertexDescriptor = try MTKModelIOVertexDescriptorFromMetalWithError(vertexDescriptor)

        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexSemantic.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexSemantic.texcoord0.rawValue].name = MDLVertexAttributeTextureCoordinate

        m.vertexDescriptor = mdlVertexDescriptor

        return try MTKMesh(mesh: m, device: device)
    }
    
    func gatherTextures(from m: MDLMesh) -> [TextureKey: TextureAttachment] {
        var result: [TextureKey: TextureAttachment] = [:]
        // Load textures for this mesh
        let firstSubmesh = (m.submeshes as! [MDLSubmesh]).first!
        if let p = firstSubmesh.material?.property(with: .baseColor) {
            switch p.type {
            case .URL:
                result[.diffuse] = .texture(from: p.urlValue!)
                
            case .string:
                result[.diffuse] = .textureName(name: p.stringValue!)
            default:
                break
            }
        }
        return result
    }
    
    func loadTexture(t: TextureAttachment) throws -> MTLTexture {
        // TODO: cache textures!

        let opt: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
        ]
        do {
            switch t {
            case .textureName(name: let name):
                return try textureLoader.newTexture(name: name, scaleFactor: 1, bundle: nil, options: opt)
            case .texture(from: let url):
                return try textureLoader.newTexture(URL: url, options: opt)
            }
        } catch {
            throw RendererError.textureLoad(mtkError: error)
        }

    }
}
