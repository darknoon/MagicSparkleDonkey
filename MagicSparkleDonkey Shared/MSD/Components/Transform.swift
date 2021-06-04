//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import simd

typealias Transform = simd_float4x4

struct TransformComponent: Component {
    var transform: Transform = .identity
}
