//
//  MSDComponent.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 4/6/21.
//

import Foundation
import simd

// Core

/// Entity is a very minimal type wrapping around an id and a store, maybe not needed?
public struct Entity {
    /// A type representing the stable identity of the entity associated with
    /// an instance.
    public typealias ID = UInt64
}

/// Core Components

//public protocol HasComponents {
//    /// Get the component of type T
//    /// ie `let l: TransformComponent = s.get()`
//    func get<T: Component>() -> T?
//    
//    func set<T: Component>(_ component: T)
//}

// Hmm, maybe not ideal access patterns
//extension Entity : HasComponents {
//
//    // Get the component of type ComponentType for self
//    internal func get<T: Component>(componentType: ComponentStore.ComponentType) -> T {
//        return store.pointee.get(entity: self, componentType: componentType)
//    }
//
//    // Get the component of type T for self
//    public func get<T: Component>() -> T? {
//        guard let componentType = store.components.registry.find(T.self) else { return nil }
//        return get(componentType: componentType)
//    }
//
//    internal func set<T: Component>(component: T, componentType: ComponentStore.ComponentType) {
//        store.components.setComponent(id: id, component: component)
//    }
//
//    public func set<T: Component>(_ component: T) {
//        let componentType = store.components.registry.find(T.self)!
//        return set(component: component, componentType: componentType)
//    }
//}

//protocol HasIdentity {
//    var id: Entity.ID { get }
//}
