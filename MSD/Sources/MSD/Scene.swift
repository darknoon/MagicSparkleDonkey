//
//  File.swift
//  
//
//  Created by Andrew Pouliot on 4/17/21.
//

public struct Scene {
    public init() {
        root = Entity.ID()
        store[root] = TransformComponent(transform: .identity)
    }

    public var root: Entity.ID
    
    public var store = ComponentStore()
}
