//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/16/21.
//

import Foundation
import Metal
import MetalKit

// Abstraction for metal rendering on the GPU
class GPUMetal : GPUAPI {
    
    init(device: MTLDevice) throws {
        self.device = device
        guard let lib = device.makeDefaultLibrary() else {
            throw Failure.shaderCompilation
        }
        self.defaultLibrary = ShaderLibrary(metalLibrary: lib)
    }
    
    let device: MTLDevice
    let defaultLibrary: ShaderLibrary

    struct ShaderLibrary {
        let metalLibrary: MTLLibrary
    }
    
    struct CompiledShader {
        let vertexFunction: MTLFunction
        let fragmentFunction: MTLFunction
    }
    
    struct MeshRuntimeType: GPUMesh {
        var attributes: Any
        let mesh: MTKMesh
    }
    
    func uploadGPUData() {}
}


extension GPUMetal.ShaderLibrary : GPUShaderLibrary {

    var shaders: [String] {
        metalLibrary.functionNames
    }
    
}
