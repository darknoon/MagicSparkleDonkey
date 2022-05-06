//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

import simd

public typealias Transform = simd_float4x4

public struct TransformComponent: Component {
    public var transform: Transform = .identity
    
    public init(_ transform: Transform) {
        self.transform = transform
    }
}


public extension Entity {
    var transform: TransformComponent? {
        get { self[TransformComponent.self] }
        set { self[TransformComponent.self] = newValue }
    }
}
