//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/16/21.
//

import Foundation
import Metal

// Abstraction for metal rendering on the GPU
class GPUMetal {
    
    func compileShaders() {}
    
    func uploadGPUData() {}
}


extension MTLLibrary : GPU.ShaderLibrary {
    
}
