//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/16/21.
//

import Foundation

// GPU abstraction for renderer

public enum GPUFailure : Error {
    case shaderCompilation
}

public protocol GPUAPI {
    associatedtype Failure = GPUFailure
    associatedtype CompiledShader
    associatedtype MeshRuntimeType: GPUMesh
    associatedtype ShaderLibrary: GPUShaderLibrary

    var defaultLibrary: ShaderLibrary { get }
}

public protocol GPUShaderLibrary {
    var shaders: [String] { get }
}

public protocol GPUMesh {
    var attributes: Any { get }
}
