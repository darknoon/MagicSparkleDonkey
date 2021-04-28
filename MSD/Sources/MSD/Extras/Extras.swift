//
//  Extras.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 4/6/21.
//

import Foundation
import simd

// = .identity
extension simd_float4x4 {
    static let identity = matrix_identity_float4x4
}

// = .identity
extension simd_float3x3 {
    static let identity = matrix_identity_float3x3
}

extension simd_float4x4 {
    init(translation t: simd_float3) {
        self.init(
            simd_float4(  1,   0,   0,   0),
            simd_float4(  0,   1,   0,   0),
            simd_float4(  0,   0,   1,   0),
            simd_float4(t.x, t.y, t.z,   1)
        )
    }
    
    init(axes: (simd_float3, simd_float3, simd_float3), offset t: simd_float3) {
        self.init(
            simd_float4(  axes.0,   0),
            simd_float4(  axes.1,   0),
            simd_float4(  axes.2,   0),
            simd_float4(  t,        1)
        )
    }
    
    init(scale x: simd_float3) {
        self.init(diagonal: simd_float4(x.x, x.y, x.z, 1.0))
    }
}
